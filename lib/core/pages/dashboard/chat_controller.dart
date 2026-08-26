import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:indonesia_law/core/models/chat_attachment.dart';
import 'package:indonesia_law/core/models/chat_message.dart';
import 'package:indonesia_law/core/models/chat_session.dart';
import 'package:indonesia_law/core/services/chat_api_service.dart';
import 'package:indonesia_law/core/services/chat_history_store.dart';
import 'package:indonesia_law/core/services/gemini_service.dart';

/// Holds the conversation transcript, asks for the answers, and keeps the
/// saved history in sync.
///
/// Where those answers come from depends on the session. An account signed in
/// on the app's own backend gets the legal assistant that lives there: the
/// conversation is opened once for its id, every question is posted to it, and
/// the history is the server's. Without a token — a Google session — the chat
/// falls back to talking to Gemini directly and saving transcripts on the
/// device.
class ChatController extends ChangeNotifier {
  ChatController({
    GeminiService? service,
    ChatHistoryStore? history,
    ChatApiService? api,
    String? accessToken,
  }) : _service = service ?? GeminiService(),
       _history = history ?? LocalChatHistoryStore(),
       _api =
           api ??
           ((accessToken != null && accessToken.trim().isNotEmpty)
               ? ChatApiService(accessToken: accessToken.trim())
               : null);

  final GeminiService _service;
  final ChatHistoryStore _history;

  /// The backend chat, or null when this session has no token to use it with.
  final ChatApiService? _api;

  final List<ChatMessage> _messages = <ChatMessage>[];
  List<ChatSession> _sessions = const <ChatSession>[];

  StreamSubscription<String>? _subscription;

  /// Counts the questions sent to the backend. A reply whose number is no
  /// longer the current one was abandoned — stopped, or overtaken — and is
  /// dropped instead of landing in a transcript that has moved on.
  int _request = 0;

  bool _isSending = false;
  bool _isLoadingHistory = false;
  bool _disposed = false;

  /// Id of the conversation the transcript belongs to. Created lazily so an
  /// untouched screen never leaves an empty row behind.
  String? _sessionId;
  DateTime? _sessionStartedAt;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  bool get isEmpty => _messages.isEmpty;

  /// Saved conversations, newest first.
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoadingHistory => _isLoadingHistory;
  bool get hasHistory => _sessions.isNotEmpty;
  String? get activeSessionId => _sessionId;

  /// True when questions go to the app's own backend rather than to Gemini.
  bool get usesBackend => _api != null;

  /// Reads the saved conversations. Failures leave the list empty — history is
  /// a convenience and must never block the chat.
  Future<void> loadHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      _sessions = await (_api?.listSessions() ?? _history.load());
    } on Object catch (error) {
      debugPrint('Gagal memuat riwayat obrolan: $error');
      _sessions = const <ChatSession>[];
    }
    _isLoadingHistory = false;
    notifyListeners();
  }

  /// Question used when the composer only carries attachments, so the
  /// assistant still gets an instruction to go with the file.
  static const attachmentOnlyPrompt =
      'Tolong baca lampiran ini dan jelaskan isinya dari sisi hukum '
      'yang berlaku di Indonesia.';

  /// Sends [text] plus any [attachments], streaming the answer into the last
  /// message. Either the text or an attachment is enough to send.
  Future<void> send(
    String text, {
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) async {
    final typed = text.trim();
    if ((typed.isEmpty && attachments.isEmpty) || _isSending) return;

    final prompt = typed.isEmpty ? attachmentOnlyPrompt : typed;
    final history = List<ChatMessage>.unmodifiable(_messages);
    _messages
      ..add(
        ChatMessage.user(
          typed,
          attachments: List<ChatAttachment>.unmodifiable(attachments),
        ),
      )
      ..add(const ChatMessage.model('', isStreaming: true));
    _isSending = true;
    notifyListeners();

    final api = _api;
    if (api != null) {
      return _ask(api, prompt: prompt, attachments: attachments);
    }

    final completer = Completer<void>();
    _subscription = _service
        .streamAnswer(
          prompt: prompt,
          history: history,
          attachments: attachments,
        )
        .listen(
          (answer) =>
              _replaceLast(ChatMessage.model(answer, isStreaming: true)),
          onError: (Object error) {
            _replaceLast(ChatMessage.model(_describe(error), isError: true));
            _finish();
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            final last = _messages.last;
            if (last.isStreaming) {
              _replaceLast(last.copyWith(isStreaming: false));
            }
            _finish();
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    return completer.future;
  }

  /// One turn against the backend: open the conversation if this is its first
  /// question, post the question, show the answer.
  ///
  /// The transcript already ends with the pending pair when this starts, and
  /// the answer replaces the empty half of it.
  Future<void> _ask(
    ChatApiService api, {
    required String prompt,
    required List<ChatAttachment> attachments,
  }) async {
    final request = ++_request;

    try {
      final sessionId = _sessionId ?? (await api.createSession()).id;
      if (request != _request) return;
      _sessionId = sessionId;
      _sessionStartedAt ??= DateTime.now();

      final answer = await api.sendMessage(
        sessionId: sessionId,
        content: prompt,
        attachments: attachments,
      );
      if (request != _request) return;
      // Whatever role the server labels it with, this reply belongs in the
      // pending answer bubble — together with the articles it cites.
      _replaceLast(
        ChatMessage.model(answer.text, citations: answer.citations),
      );
    } on Object catch (error) {
      if (request != _request) return;
      debugPrint('Gagal mengirim pertanyaan: $error');
      _replaceLast(ChatMessage.model(_describe(error), isError: true));
    }

    if (request != _request) return;
    _isSending = false;
    notifyListeners();
    unawaited(_persist());
  }

  /// Stops an in-flight answer, keeping whatever text arrived so far.
  void stop() {
    if (!_isSending) return;
    _subscription?.cancel();
    _subscription = null;
    // Nothing can be cancelled halfway on the backend — the reply is simply
    // no longer waited for.
    _request++;

    final last = _messages.last;
    if (last.isStreaming) {
      _replaceLast(
        last.text.trim().isEmpty
            ? const ChatMessage.model('Dihentikan.', isError: true)
            : last.copyWith(isStreaming: false),
      );
    }
    _isSending = false;
    notifyListeners();
    unawaited(_persist());
  }

  /// Saves the current transcript and returns the page to its empty state.
  Future<void> startNewChat() async {
    _subscription?.cancel();
    _subscription = null;
    _request++;
    _isSending = false;

    await _persist();
    _messages.clear();
    _sessionId = null;
    _sessionStartedAt = null;
    notifyListeners();
  }

  /// Replaces the transcript with a saved conversation, fetching its messages
  /// when the history list only carried the row.
  Future<void> openSession(ChatSession session) async {
    if (session.id == _sessionId) return;

    _subscription?.cancel();
    _subscription = null;
    _request++;
    _isSending = false;

    await _persist();

    var opened = session;
    final api = _api;
    if (api != null && session.isSummary) {
      _isLoadingHistory = true;
      notifyListeners();
      try {
        opened = await api.fetchSession(session.id);
        // Keep what was fetched, so reopening the row is instant.
        _sessions = [
          for (final existing in _sessions)
            if (existing.id == opened.id) opened else existing,
        ];
      } on Object catch (error) {
        debugPrint('Gagal memuat isi obrolan: $error');
      }
      _isLoadingHistory = false;
    }

    _messages
      ..clear()
      ..addAll(opened.messages);
    _sessionId = opened.id;
    _sessionStartedAt = opened.createdAt;
    notifyListeners();
  }

  /// Removes one saved conversation; clears the transcript when it is the one
  /// currently open.
  Future<void> deleteSession(String id) async {
    _sessions = [
      for (final session in _sessions)
        if (session.id != id) session,
    ];
    if (id == _sessionId) {
      _subscription?.cancel();
      _subscription = null;
      _request++;
      _isSending = false;
      _messages.clear();
      _sessionId = null;
      _sessionStartedAt = null;
    }
    notifyListeners();

    await _forget(id);
  }

  /// Wipes every saved conversation and the open transcript.
  Future<void> clearHistory() async {
    _subscription?.cancel();
    _subscription = null;
    _request++;
    _isSending = false;
    _messages.clear();

    final removed = _sessions;
    _sessions = const <ChatSession>[];
    _sessionId = null;
    _sessionStartedAt = null;
    notifyListeners();

    final api = _api;
    if (api == null) {
      try {
        await _history.clear();
      } on Object catch (error) {
        debugPrint('Gagal menghapus riwayat obrolan: $error');
      }
      return;
    }

    // The backend deletes one conversation at a time; a row that refuses to go
    // comes back on the next load, which is better than stopping halfway.
    await Future.wait([for (final session in removed) _forget(session.id)]);
  }

  /// Re-runs the last question, dropping its previous answer.
  Future<void> retryLast() async {
    if (_isSending || _messages.isEmpty) return;

    final lastUser = _messages.lastIndexWhere((message) => message.isUser);
    if (lastUser < 0) return;

    final question = _messages[lastUser];
    _messages.removeRange(lastUser, _messages.length);
    notifyListeners();
    await send(question.text, attachments: question.attachments);
  }

  /// Re-asks the question at [index] with [text], dropping the old wording,
  /// its answer, and every turn that came after it. The transcript is cut
  /// first, so the new answer lands exactly where the old one stood.
  Future<void> editQuestion(
    int index,
    String text, {
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) async {
    if (_isSending) return;
    if (index < 0 || index >= _messages.length) return;
    if (!_messages[index].isUser) return;
    if (text.trim().isEmpty && attachments.isEmpty) return;

    _messages.removeRange(index, _messages.length);
    notifyListeners();
    await send(text, attachments: attachments);
  }

  /// Removes the question at [index] together with the answers it produced.
  /// The saved conversation follows the transcript — it is dropped when what
  /// is left is no longer a real exchange.
  Future<void> deleteQuestion(int index) async {
    if (_isSending) return;
    if (index < 0 || index >= _messages.length) return;
    if (!_messages[index].isUser) return;

    // Everything up to the next question belongs to this one.
    var end = index + 1;
    while (end < _messages.length && !_messages[end].isUser) {
      end++;
    }
    _messages.removeRange(index, end);
    notifyListeners();

    if (_isWorthSaving) {
      await _persist();
      return;
    }

    final id = _sessionId;
    _sessionId = null;
    _sessionStartedAt = null;
    if (id == null) return;

    _sessions = [
      for (final session in _sessions)
        if (session.id != id) session,
    ];
    notifyListeners();
    await _forget(id);
  }

  /// Writes the open transcript into the history list, creating its session on
  /// the first save. A transcript without a real answer is not worth keeping,
  /// so it is skipped.
  ///
  /// Only the local history is written here: a backend conversation was
  /// already stored as the questions went out, and its row is refreshed in
  /// place so the drawer keeps up.
  Future<void> _persist() async {
    if (!_isWorthSaving) return;
    // A backend conversation always has its server id by now; without one
    // there is nothing to attach the transcript to.
    if (_api != null && _sessionId == null) return;

    final now = DateTime.now();
    _sessionId ??= 'chat-${now.microsecondsSinceEpoch}';
    _sessionStartedAt ??= now;

    final messages = List<ChatMessage>.unmodifiable(
      _messages.map((message) => message.copyWith(isStreaming: false)),
    );
    final previous = _sessions
        .where((session) => session.id == _sessionId)
        .firstOrNull;
    final session = ChatSession(
      id: _sessionId!,
      messages: messages,
      createdAt: _sessionStartedAt!,
      updatedAt: now,
      remoteTitle: previous?.remoteTitle,
      messageCount: messages.length,
    );

    _sessions = [
      session,
      for (final existing in _sessions)
        if (existing.id != session.id) existing,
    ];
    notifyListeners();

    if (_api != null) return;

    try {
      await _history.save(session);
    } on Object catch (error) {
      debugPrint('Gagal menyimpan riwayat obrolan: $error');
    }
  }

  /// Drops one conversation wherever this session keeps its history.
  Future<void> _forget(String id) async {
    try {
      await (_api?.deleteSession(id) ?? _history.delete(id));
    } on Object catch (error) {
      debugPrint('Gagal menghapus riwayat obrolan: $error');
    }
  }

  /// True once the transcript holds a question and at least one answer that is
  /// not an error bubble.
  bool get _isWorthSaving {
    if (_messages.length < 2) return false;
    return _messages.any(
      (message) =>
          !message.isUser && !message.isError && message.text.trim().isNotEmpty,
    );
  }

  void _replaceLast(ChatMessage message) {
    _messages[_messages.length - 1] = message;
    notifyListeners();
  }

  void _finish() {
    _subscription = null;
    _isSending = false;
    notifyListeners();
    unawaited(_persist());
  }

  String _describe(Object error) {
    if (error is ChatApiException) return error.message;
    if (error is GeminiException) return error.message;
    return 'Terjadi kesalahan tak terduga. Coba lagi.';
  }

  /// Saving runs in the background, so a notification can land after the page
  /// is gone.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _service.dispose();
    _api?.dispose();
    super.dispose();
  }
}
