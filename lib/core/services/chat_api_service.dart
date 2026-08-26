import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:indonesia_law/core/config/env.dart';
import 'package:indonesia_law/core/consts/constants.dart';
import 'package:indonesia_law/core/models/chat_attachment.dart';
import 'package:indonesia_law/core/models/chat_message.dart';
import 'package:indonesia_law/core/models/chat_session.dart';
import 'package:indonesia_law/core/services/api_response.dart';

/// Raised when the chat backend cannot answer; carries a message meant to be
/// shown to the user as-is.
class ChatApiException implements Exception {
  const ChatApiException(this.message, {this.isUnauthorized = false});

  final String message;

  /// True when the session's token was refused, i.e. signing in again is the
  /// only way forward.
  final bool isUnauthorized;

  @override
  String toString() => message;
}

/// The conversation, as the app's own backend keeps it.
///
/// Two calls make a turn: a conversation is created once to get its id
/// ([createSession]), and every question after that is posted to that id's
/// messages endpoint, which answers with the assistant's reply. History is
/// read the same way — a list of rows, then one row's transcript.
class ChatApiService {
  ChatApiService({required this.accessToken, http.Client? client})
    : _client = client ?? http.Client();

  /// Answers come from a retrieval pass plus a model, so they are slow by
  /// nature; anything shorter cuts off replies that were on their way.
  static const _answerTimeout = Duration(minutes: 3);
  static const _readTimeout = Duration(seconds: 30);

  /// Bearer token of the signed-in account; every call carries it.
  final String accessToken;
  final http.Client _client;

  /// Conversations, newest first.
  Future<List<ChatSession>> listSessions() async {
    final response = await _get(chatSessions, timeout: _readTimeout);
    final rows = ApiResponse.payloadList(_decodeJson(response.body));

    final sessions = <ChatSession>[
      for (final row in rows)
        if (row is Map<String, Object?>) ChatSession.fromApi(row),
    ];
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  /// One conversation together with its transcript.
  Future<ChatSession> fetchSession(String id) async {
    final response = await _get(_sessionPath(id), timeout: _readTimeout);
    return ChatSession.fromApi(
      ApiResponse.payload(ApiResponse.decode(response.body)),
    );
  }

  /// Opens a conversation and returns it, so the caller has its id before the
  /// first question goes out.
  Future<ChatSession> createSession() async {
    final response = await _send(
      () => _client.post(_uri(chatSessions), headers: _headers()),
      fallback: 'Gagal memulai obrolan baru.',
      timeout: _readTimeout,
    );
    return ChatSession.fromApi(
      ApiResponse.payload(ApiResponse.decode(response.body)),
    );
  }

  /// Posts a question into [sessionId] and returns the answer.
  ///
  /// Attachments go to the upload endpoint instead, which takes the same text
  /// alongside the files. Only attachments whose bytes are still around can be
  /// sent — one restored from history is a label, not a file.
  Future<ChatMessage> sendMessage({
    required String sessionId,
    required String content,
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) async {
    final sendable = attachments.where((file) => file.isSendable).toList();
    final response = sendable.isEmpty
        ? await _send(
            () => _client.post(
              _uri(_messagesPath(sessionId)),
              headers: _headers(json: true),
              body: jsonEncode({'content': content}),
            ),
            fallback: 'Gagal mengirim pertanyaan.',
            timeout: _answerTimeout,
          )
        : await _send(
            () => _upload(
              sessionId: sessionId,
              content: content,
              attachments: sendable,
            ),
            fallback: 'Gagal mengirim lampiran.',
            timeout: _answerTimeout,
          );

    final answer = ChatMessage.fromApi(
      ApiResponse.payload(ApiResponse.decode(response.body)),
    );
    if (answer.text.trim().isEmpty) {
      throw const ChatApiException(
        'Server menjawab tanpa isi. Coba tanyakan lagi.',
      );
    }
    return answer;
  }

  Future<void> deleteSession(String id) async {
    await _send(
      () => _client.delete(_uri(_sessionPath(id)), headers: _headers()),
      fallback: 'Gagal menghapus obrolan.',
      timeout: _readTimeout,
    );
  }

  void dispose() => _client.close();

  Future<http.Response> _upload({
    required String sessionId,
    required String content,
    required List<ChatAttachment> attachments,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri(_uploadPath(sessionId)))
          ..headers.addAll(_headers())
          ..fields['content'] = content;

    for (final attachment in attachments) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          attachment.bytes!,
          filename: attachment.name,
          contentType: _mediaType(attachment.mimeType),
        ),
      );
    }

    return http.Response.fromStream(await _client.send(request));
  }

  /// `http.MultipartFile` wants the type split in two, and refuses a value it
  /// cannot split — an unknown type is better sent as bytes than not at all.
  static http.MediaType _mediaType(String mimeType) {
    final parts = mimeType.split('/');
    if (parts.length != 2 || parts.any((part) => part.trim().isEmpty)) {
      return http.MediaType('application', 'octet-stream');
    }
    return http.MediaType(parts.first.trim(), parts.last.trim());
  }

  Future<http.Response> _get(String path, {required Duration timeout}) {
    return _send(
      () => _client.get(_uri(path), headers: _headers()),
      fallback: 'Gagal memuat obrolan.',
      timeout: timeout,
    );
  }

  Map<String, String> _headers({bool json = false}) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $accessToken',
    if (json) 'Content-Type': 'application/json',
  };

  String _sessionPath(String id) => '$chatSessions/$id';

  String _messagesPath(String id) =>
      chatMessages.replaceFirst('{sessionId}', id);

  String _uploadPath(String id) => '${_messagesPath(id)}/upload';

  Uri _uri(String path) {
    if (!Env.hasDomain) {
      throw const ChatApiException(
        'DOMAIN belum diatur di berkas .env, jadi aplikasi belum tahu ke mana '
        'harus mengirim pertanyaan.',
      );
    }
    return Env.apiUri(path);
  }

  /// Runs [request] and returns its response, turning every non-2xx answer and
  /// every transport failure into a [ChatApiException].
  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required String fallback,
    required Duration timeout,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ChatApiException(
        'Server terlalu lama menjawab. Coba tanyakan lagi.',
      );
    } on ChatApiException {
      rethrow;
    } on Object catch (error) {
      debugPrint('Gagal menghubungi server obrolan: $error');
      throw const ChatApiException(
        'Tidak bisa menghubungi server. Periksa koneksi internet Anda lalu '
        'coba lagi.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    debugPrint(
      'Permintaan obrolan ditolak (${response.statusCode}): ${response.body}',
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ChatApiException(
        'Sesi Anda sudah berakhir. Keluar lalu masuk lagi untuk melanjutkan.',
        isUnauthorized: true,
      );
    }
    throw ChatApiException(
      ApiResponse.describe(
        ApiResponse.decode(response.body),
        fallback: fallback,
      ),
    );
  }

  /// The list endpoint answers with a bare array, so the body is decoded
  /// without assuming an object.
  Object? _decodeJson(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
