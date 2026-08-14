import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:indonesia_law/core/models/app_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the signed-in account is remembered between launches.
///
/// Only a local implementation ships today; a remote one can be dropped in
/// later without touching the controller or the UI.
abstract class SessionStore {
  /// The account saved by the last [write], or null when nobody is signed in.
  Future<AppUser?> read();

  Future<void> write(AppUser user);

  Future<void> clear();
}

/// Keeps the account in `SharedPreferences` as one JSON document, next to the
/// chat history.
class LocalSessionStore implements SessionStore {
  /// [_preferences] is only passed in by tests; production resolves it lazily.
  LocalSessionStore([this._preferences]);

  static const _key = 'auth_session_v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<AppUser?> read() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final user = AppUser.fromJson(decoded);
      // A payload without an id is useless — the gate keys the chat on it.
      return user.id.isEmpty ? null : user;
    } on FormatException catch (error) {
      // Corrupted payload: drop it and start on the sign-in page rather than
      // wedging the app on a broken session.
      debugPrint('Sesi tersimpan rusak, dibuang: $error');
      await prefs.remove(_key);
      return null;
    }
  }

  @override
  Future<void> write(AppUser user) async {
    final prefs = await _prefs;
    await prefs.setString(_key, jsonEncode(user.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_key);
  }
}
