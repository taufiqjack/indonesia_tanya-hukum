import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:indonesia_law/core/config/env.dart';
import 'package:indonesia_law/core/models/app_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raised when signing in fails; carries a message meant to be shown to the
/// user as-is.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Who is signed in, and how that changes.
///
/// Only a Google implementation ships today; another provider can be dropped in
/// later without touching the controller or the UI.
abstract class AuthService {
  /// Prepares the underlying SDK. Must complete before anything else is called.
  Future<void> initialize();

  /// Returns the previous session without showing any UI, or null when there is
  /// none to restore.
  Future<AppUser?> restore();

  /// Runs the interactive sign-in flow. Returns null when the user backs out.
  Future<AppUser?> signIn();

  Future<void> signOut();
}

/// Google Sign-In on top of the `google_sign_in` plugin.
///
/// The account is also cached in `SharedPreferences`: the silent flow needs the
/// network and a platform credential store, so the cache is what keeps the user
/// signed in after a relaunch on a plane or a flaky connection.
class GoogleAuthService implements AuthService {
  /// [_preferences] is only passed in by tests; production resolves it lazily.
  GoogleAuthService([this._preferences]);

  static const _key = 'auth_user_v1';

  SharedPreferences? _preferences;
  Future<void>? _initialization;

  GoogleSignIn get _google => GoogleSignIn.instance;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  /// `GoogleSignIn.initialize` may only run once per process, so the first
  /// call's future is reused.
  @override
  Future<void> initialize() {
    return _initialization ??= _google.initialize(
      // Web takes the web client id as `clientId`; the other platforms take the
      // iOS one there and the web one as `serverClientId`.
      clientId: kIsWeb ? Env.googleServerClientId : Env.googleIosClientId,
      serverClientId: kIsWeb ? null : Env.googleServerClientId,
    );
  }

  @override
  Future<AppUser?> restore() async {
    await initialize();
    final cached = await _cachedUser();

    final attempt = _google.attemptLightweightAuthentication();
    // Null means the platform (web FedCM) only reports through its event
    // stream, so there is nothing to wait for here.
    if (attempt == null) return cached;

    try {
      final account = await attempt;
      if (account == null) return cached;
      final user = _toUser(account);
      await _cache(user);
      return user;
    } on Object catch (error) {
      // A silent attempt failing is not worth an error screen — fall back to
      // the cached session, if any.
      debugPrint('Gagal memulihkan sesi Google: $error');
      return cached;
    }
  }

  @override
  Future<AppUser?> signIn() async {
    await initialize();

    if (!_google.supportsAuthenticate()) {
      throw const AuthException(
        'Masuk dengan Google belum didukung di platform ini.',
      );
    }

    try {
      final user = _toUser(await _google.authenticate());
      await _cache(user);
      return user;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      // The user-facing text is deliberately short, so the code and the
      // platform's own description — the parts that say *why* — are logged.
      debugPrint(
        'Gagal masuk dengan Google: ${error.code.name} — '
        '${error.description ?? 'tanpa keterangan'} '
        '(${error.details ?? 'tanpa detail'})',
      );
      throw AuthException(_describe(error));
    } on Object catch (error) {
      debugPrint('Gagal masuk dengan Google: $error');
      throw const AuthException(
        'Gagal masuk dengan Google. Periksa koneksi internet Anda lalu coba '
        'lagi.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    // The local session is dropped first: even if the SDK call fails, the app
    // must not keep showing the chat as signed in.
    final prefs = await _prefs;
    await prefs.remove(_key);
    try {
      await _google.signOut();
    } on Object catch (error) {
      debugPrint('Gagal keluar dari Google: $error');
    }
  }

  Future<AppUser?> _cachedUser() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final user = AppUser.fromJson(decoded);
      return user.id.isEmpty ? null : user;
    } on FormatException catch (error) {
      debugPrint('Sesi tersimpan rusak, dibuang: $error');
      await prefs.remove(_key);
      return null;
    }
  }

  Future<void> _cache(AppUser user) async {
    final prefs = await _prefs;
    await prefs.setString(_key, jsonEncode(user.toJson()));
  }

  AppUser _toUser(GoogleSignInAccount account) => AppUser(
    id: account.id,
    email: account.email,
    name: account.displayName,
    photoUrl: account.photoUrl,
  );

  String _describe(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode
          .providerConfigurationError => 'Konfigurasi Google Sign-In belum '
          'lengkap. Periksa GOOGLE_SERVER_CLIENT_ID di berkas .env dan sidik '
          'jari SHA-1 aplikasi.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Layanan Google tidak tersedia di perangkat ini.',
      GoogleSignInExceptionCode.interrupted =>
        'Proses masuk terputus. Coba lagi.',
      GoogleSignInExceptionCode.userMismatch =>
        'Akun yang dipilih berbeda dengan yang diminta. Coba lagi.',
      // Android's Credential Manager reports both "the device has no Google
      // account" and "this build's package name + SHA-1 is not on the OAuth
      // client" as NoCredentialException, which the plugin forwards as an
      // unknownError. Naming both keeps the message actionable — the generic
      // fallback below reads as a network blip and sends people looking in the
      // wrong place.
      GoogleSignInExceptionCode.unknownError
          when error.description?.contains('No credential available') ??
              false =>
        'Tidak ada akun Google yang bisa dipakai. Tambahkan akun Google lewat '
            'Setelan perangkat, lalu pastikan OAuth client Android (package '
            'name + SHA-1) sudah terdaftar di Google Cloud Console.',
      _ => 'Gagal masuk dengan Google. Coba lagi.',
    };
  }
}
