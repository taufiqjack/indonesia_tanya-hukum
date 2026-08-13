import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:indonesia_law/core/models/chat_message.dart';
import 'package:indonesia_law/core/models/chat_session.dart';
import 'package:indonesia_law/core/services/chat_history_store.dart';
import 'package:indonesia_law/core/services/gemini_service.dart';

/// Holds the conversation transcript, drives the Gemini calls, and keeps the
/// saved history in sync.
class ChatController extends ChangeNotifier {
  ChatController({GeminiService? service, ChatHistoryStore? history})
    : _service = service ?? GeminiService(),
      _history = history ?? LocalChatHistoryStore();

  final GeminiService _service;
  final ChatHistoryStore _history;
  final List<ChatMessage> _messages = <ChatMessage>[];
  List<ChatSession> _sessions = const <ChatSession>[];

  StreamSubscription<String>? _subscription;
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

  /// Reads the saved conversations. Failures leave the list empty — history is
  /// a convenience and must never block the chat.
  Future<void> loadHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      _sessions = await _history.load();
    } on Object catch (error) {
      debugPrint('Gagal memuat riwayat obrolan: $error');
      _sessions = const <ChatSession>[];
    }
    _isLoadingHistory = false;
    notifyListeners();
  }

  /// Sends [text] and streams the answer into the last message.
  Future<void> send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isSending) return;

    final history = List<ChatMessage>.unmodifiable(_messages);
    _messages
      ..add(ChatMessage.user(prompt))
      ..add(const ChatMessage.model('', isStreaming: true));
    _isSending = true;
    notifyListeners();

    final completer = Completer<void>();
    _subscription = _service
        .streamAnswer(prompt: prompt, history: history)
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

  /// Stops an in-flight answer, keeping whatever text arrived so far.
  void stop() {
    if (!_isSending) return;
    _subscription?.cancel();
    _subscription = null;

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
    _isSending = false;

    await _persist();
    _messages.clear();
    _sessionId = null;
    _sessionStartedAt = null;
    notifyListeners();
  }

  /// Replaces the transcript with a saved conversation.
  Future<void> openSession(ChatSession session) async {
    if (session.id == _sessionId) return;

    _subscription?.cancel();
    _subscription = null;
    _isSending = false;

    await _persist();
    _messages
      ..clear()
      ..addAll(session.messages);
    _sessionId = session.id;
    _sessionStartedAt = session.createdAt;
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
      _isSending = false;
      _messages.clear();
      _sessionId = null;
      _sessionStartedAt = null;
    }
    notifyListeners();

    try {
      await _history.delete(id);
    } on Object catch (error) {
      debugPrint('Gagal menghapus riwayat obrolan: $error');
    }
  }

  /// Wipes every saved conversation and the open transcript.
  Future<void> clearHistory() async {
    _subscription?.cancel();
    _subscription = null;
    _isSending = false;
    _messages.clear();
    _sessions = const <ChatSession>[];
    _sessionId = null;
    _sessionStartedAt = null;
    notifyListeners();

    try {
      await _history.clear();
    } on Object catch (error) {
      debugPrint('Gagal menghapus riwayat obrolan: $error');
    }
  }

  /// Re-runs the last question, dropping its previous answer.
  Future<void> retryLast() async {
    if (_isSending || _messages.isEmpty) return;

    final lastUser = _messages.lastIndexWhere((message) => message.isUser);
    if (lastUser < 0) return;

    final prompt = _messages[lastUser].text;
    _messages.removeRange(lastUser, _messages.length);
    notifyListeners();
    await send(prompt);
  }

  /// Writes the open transcript into the history store, creating its session
  /// on the first save. A transcript without a real answer is not worth
  /// keeping, so it is skipped.
  Future<void> _persist() async {
    if (!_isWorthSaving) return;

    final now = DateTime.now();
    _sessionId ??= 'chat-${now.microsecondsSinceEpoch}';
    _sessionStartedAt ??= now;

    final session = ChatSession(
      id: _sessionId!,
      messages: List<ChatMessage>.unmodifiable(
        _messages.map((message) => message.copyWith(isStreaming: false)),
      ),
      createdAt: _sessionStartedAt!,
      updatedAt: now,
    );

    _sessions = [
      session,
      for (final existing in _sessions)
        if (existing.id != session.id) existing,
    ];
    notifyListeners();

    try {
      await _history.save(session);
    } on Object catch (error) {
      debugPrint('Gagal menyimpan riwayat obrolan: $error');
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
    super.dispose();
  }
}
