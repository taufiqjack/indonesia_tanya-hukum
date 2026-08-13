import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:indonesia_law/core/models/chat_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where saved conversations live.
///
/// Only a local implementation ships today; a remote one can be dropped in
/// later without touching the controller or the UI.
abstract class ChatHistoryStore {
  /// Newest conversation first.
  Future<List<ChatSession>> load();

  /// Inserts or replaces [session].
  Future<void> save(ChatSession session);

  Future<void> delete(String id);

  Future<void> clear();
}

/// Keeps the whole history in `SharedPreferences` as one JSON document.
///
/// Transcripts are small text, so a single key stays simpler than one entry
/// per conversation and keeps ordering trivial.
class LocalChatHistoryStore implements ChatHistoryStore {
  /// [_preferences] is only passed in by tests; production resolves it lazily.
  LocalChatHistoryStore([this._preferences]);

  static const _key = 'chat_history_v1';

  /// Older conversations are dropped past this count.
  static const maxSessions = 50;

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<List<ChatSession>> load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final sessions = <ChatSession>[
        for (final item in decoded)
          if (item is Map<String, Object?>) ChatSession.fromJson(item),
      ];
      return _sorted(sessions);
    } on FormatException catch (error) {
      // Corrupted payload: drop it rather than blocking the chat forever.
      debugPrint('Riwayat obrolan rusak, dibuang: $error');
      await prefs.remove(_key);
      return [];
    }
  }

  @override
  Future<void> save(ChatSession session) async {
    final sessions = await load()
      ..removeWhere((existing) => existing.id == session.id)
      ..add(session);
    await _write(_sorted(sessions));
  }

  @override
  Future<void> delete(String id) async {
    final sessions = await load()
      ..removeWhere((session) => session.id == id);
    await _write(sessions);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_key);
  }

  Future<void> _write(List<ChatSession> sessions) async {
    final capped = sessions.length > maxSessions
        ? sessions.sublist(0, maxSessions)
        : sessions;
    final prefs = await _prefs;
    await prefs.setString(
      _key,
      jsonEncode([for (final session in capped) session.toJson()]),
    );
  }

  List<ChatSession> _sorted(List<ChatSession> sessions) {
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }
}
