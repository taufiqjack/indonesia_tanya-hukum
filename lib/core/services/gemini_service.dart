import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:indonesia_law/core/config/env.dart';
import 'package:indonesia_law/core/models/chat_attachment.dart';
import 'package:indonesia_law/core/models/chat_message.dart';

/// Raised when the Gemini API cannot answer; carries a message meant to be
/// shown to the user as-is.
class GeminiException implements Exception {
  const GeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin client over the Gemini `generateContent` REST API.
///
/// Streaming is used (`streamGenerateContent` + SSE) so answers appear word by
/// word instead of after a long pause.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'generativelanguage.googleapis.com';
  static const _basePath = '/v1beta/models';

  /// Keeps requests small; older turns beyond this are dropped.
  static const _maxHistoryTurns = 20;

  /// Ceiling on the inline attachment bytes carried by one request. Gemini
  /// rejects payloads over 20 MB, so attachments are dropped once this is
  /// reached — the current turn's claim the budget first.
  static const _maxInlineBytes = 12 * 1024 * 1024;

  static const systemInstruction = '''
Kamu adalah "Hukum AI", asisten hukum berbahasa Indonesia.

Panduan menjawab:
- Selalu jawab dalam Bahasa Indonesia yang jelas dan mudah dipahami orang awam.
- Fokus pada hukum yang berlaku di Indonesia (UU, KUHP, KUHPerdata, PP, dan
  peraturan turunannya).
- Sebutkan dasar hukumnya (nomor pasal dan nama peraturan) bila relevan, dan
  katakan terus terang bila kamu tidak yakin atau aturannya sudah berubah.
- Susun jawaban secara ringkas dan terstruktur; gunakan poin-poin bila perlu.
- Jangan mengarang pasal, nomor putusan, atau kutipan peraturan.
- Untuk pertanyaan di luar topik hukum, jawab singkat lalu arahkan kembali ke
  konsultasi hukum.
- Tutup jawaban yang bersifat nasihat dengan pengingat singkat bahwa ini bukan
  pengganti konsultasi dengan advokat.
- Bila pengguna melampirkan berkas atau foto, baca isinya lebih dulu lalu
  kaitkan jawabanmu dengan isi lampiran tersebut.
''';

  final http.Client _client;

  /// Streams the answer for [prompt] given the prior [history].
  ///
  /// Yields the cumulative answer text, so the caller can render the latest
  /// value directly. [history] must not include [prompt] itself.
  Stream<String> streamAnswer({
    required String prompt,
    List<ChatMessage> history = const [],
    List<ChatAttachment> attachments = const [],
  }) async* {
    if (!Env.hasGeminiKey) {
      throw const GeminiException(
        'GEMINI_API_KEY belum diatur. Tambahkan di berkas .env lalu jalankan '
        'ulang aplikasi.',
      );
    }

    final request = http.Request('POST', _endpoint('streamGenerateContent'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(
        _payload(prompt: prompt, history: history, attachments: attachments),
      );

    final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } on Object catch (error) {
      throw GeminiException(_networkMessage(error));
    }

    final buffer = StringBuffer();
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw GeminiException(_apiErrorMessage(response.statusCode, body));
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;

        final chunk = _textOf(jsonDecode(payload));
        if (chunk.isEmpty) continue;

        buffer.write(chunk);
        yield buffer.toString();
      }
    } on GeminiException {
      rethrow;
    } on Object catch (error) {
      throw GeminiException(_networkMessage(error));
    }

    if (buffer.isEmpty) {
      throw const GeminiException(
        'Model tidak mengembalikan jawaban. Coba ulangi pertanyaan Anda.',
      );
    }
  }

  void dispose() => _client.close();

  Uri _endpoint(String method) {
    return Uri.https(_host, '$_basePath/${Env.geminiModel}:$method', {
      'key': Env.geminiApiKey,
      if (method.startsWith('stream')) 'alt': 'sse',
    });
  }

  Map<String, Object?> _payload({
    required String prompt,
    required List<ChatMessage> history,
    required List<ChatAttachment> attachments,
  }) {
    final trimmed = history.length > _maxHistoryTurns
        ? history.sublist(history.length - _maxHistoryTurns)
        : history;

    // The question is about the attachments sent with it, so they get first
    // claim on the inline-bytes budget; earlier turns take what is left.
    var budget = _maxInlineBytes;
    final currentParts = <Map<String, Object?>>[];
    for (final attachment in attachments) {
      if (!attachment.isSendable || attachment.size > budget) continue;
      budget -= attachment.size;
      currentParts.add(_inlinePart(attachment));
    }
    currentParts.add({'text': prompt});

    final contents = <Map<String, Object?>>[
      for (final message in trimmed)
        if (!message.isError &&
            (message.text.trim().isNotEmpty || message.hasAttachments))
          {
            'role': message.isUser ? 'user' : 'model',
            'parts': _historyParts(message, () => budget, (int used) {
              budget -= used;
            }),
          },
      {'role': 'user', 'parts': currentParts},
    ];

    return {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
        'thinkingConfig': {'thinkingLevel': 'low'},
      },
    };
  }

  /// Rebuilds one earlier turn. Attachments whose bytes are still in memory
  /// are re-sent so follow-up questions can refer back to them; the rest —
  /// anything restored from saved history — degrade to a short note.
  List<Map<String, Object?>> _historyParts(
    ChatMessage message,
    int Function() remaining,
    void Function(int used) spend,
  ) {
    final parts = <Map<String, Object?>>[];
    final dropped = <String>[];

    for (final attachment in message.attachments) {
      if (attachment.isSendable && attachment.size <= remaining()) {
        spend(attachment.size);
        parts.add(_inlinePart(attachment));
      } else {
        dropped.add(attachment.name);
      }
    }

    final text = message.text.trim();
    parts.add({
      'text': [
        if (text.isNotEmpty) text,
        if (dropped.isNotEmpty) '[lampiran sebelumnya: ${dropped.join(', ')}]',
      ].join('\n'),
    });
    return parts;
  }

  Map<String, Object?> _inlinePart(ChatAttachment attachment) => {
    'inlineData': {
      'mimeType': attachment.mimeType,
      'data': attachment.base64Data,
    },
  };

  /// Pulls the visible answer out of one streamed chunk, skipping the model's
  /// internal "thought" parts.
  String _textOf(Object? decoded) {
    if (decoded is! Map<String, Object?>) return '';

    final error = decoded['error'];
    if (error is Map<String, Object?>) {
      throw GeminiException(_messageOf(error));
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';

    final first = candidates.first;
    if (first is! Map<String, Object?>) return '';

    final content = first['content'];
    if (content is! Map<String, Object?>) return '';

    final parts = content['parts'];
    if (parts is! List) return '';

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map<String, Object?>) continue;
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String) buffer.write(text);
    }
    return buffer.toString();
  }

  String _apiErrorMessage(int statusCode, String body) {
    String detail = '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final error = decoded['error'];
        if (error is Map<String, Object?>) detail = _messageOf(error);
      }
    } on FormatException {
      detail = '';
    }

    return switch (statusCode) {
      400 => 'Permintaan ditolak Gemini. $detail'.trim(),
      401 || 403 =>
        'API key Gemini tidak valid atau tidak memiliki akses. '
            'Periksa GEMINI_API_KEY di berkas .env.',
      404 =>
        'Model "${Env.geminiModel}" tidak tersedia untuk API key ini. '
            'Ubah GEMINI_MODEL di berkas .env.',
      429 => 'Kuota Gemini habis untuk saat ini. Coba lagi beberapa saat lagi.',
      >= 500 => 'Server Gemini sedang bermasalah. Coba lagi sebentar lagi.',
      _ => 'Gagal menghubungi Gemini (kode $statusCode). $detail'.trim(),
    };
  }

  String _messageOf(Map<String, Object?> error) {
    final message = error['message'];
    return message is String ? message : '';
  }

  String _networkMessage(Object error) {
    if (error is TimeoutException) {
      return 'Waktu tunggu habis. Periksa koneksi internet Anda.';
    }
    return 'Tidak dapat terhubung ke Gemini. Periksa koneksi internet Anda.';
  }
}
