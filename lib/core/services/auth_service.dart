import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:indonesia_law/core/config/env.dart';
import 'package:indonesia_law/core/models/app_user.dart';

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

  /// Runs the interactive sign-in flow. Returns null when the user backs out.
  Future<AppUser?> signIn();

  Future<void> signOut();
}

/// Google Sign-In on top of the `google_sign_in` plugin.
///
/// The SDK is only ever reached through the sign-in button. Nothing is resolved
/// on launch — not even silently, since Android's Credential Manager answers a
/// lightweight attempt with an account sheet — so a session that outlives the
/// app is remembered by the app itself, not asked for again here.
class GoogleAuthService implements AuthService {
  Future<void>? _initialization;

  GoogleSignIn get _google => GoogleSignIn.instance;

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
  Future<AppUser?> signIn() async {
    _assertConfigured();
    await initialize();

    if (!_google.supportsAuthenticate()) {
      throw const AuthException(
        'Masuk dengan Google belum didukung di platform ini.',
      );
    }

    try {
      return _toUser(await _google.authenticate());
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
    // The controller drops the account regardless, so a failing SDK call must
    // not keep the app showing the chat as signed in.
    try {
      await _google.signOut();
    } on Object catch (error) {
      debugPrint('Gagal keluar dari Google: $error');
    }
  }

  /// Stops early when the client id this platform reads is missing.
  ///
  /// Neither platform ships a `GoogleService-Info.plist` or a
  /// `google-services.json`, so every client id comes from `.env`. Left unset,
  /// the SDK reports the gap as a generic failure that reads like a network
  /// blip and sends people looking in the wrong place.
  void _assertConfigured() {
    if (kIsWeb) {
      if (Env.googleServerClientId == null) {
        throw const AuthException(
          'GOOGLE_SERVER_CLIENT_ID belum diisi di berkas .env, jadi masuk '
          'dengan Google belum bisa dipakai di web.',
        );
      }
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS || TargetPlatform.macOS
          when Env.googleIosClientId == null:
        throw const AuthException(
          'GOOGLE_IOS_CLIENT_ID belum diisi di berkas .env. Buat OAuth client '
          'bertipe iOS untuk bundle id com.jetorbit.indonesiaLaw di Google '
          'Cloud Console, isikan ke .env, lalu daftarkan skema URL '
          'kebalikannya di ios/Runner/Info.plist.',
        );
      case TargetPlatform.android when Env.googleServerClientId == null:
        throw const AuthException(
          'GOOGLE_SERVER_CLIENT_ID belum diisi di berkas .env, jadi masuk '
          'dengan Google belum bisa dipakai di Android.',
        );
      default:
        return;
    }
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
      GoogleSignInExceptionCode.providerConfigurationError =>
        _configurationHint(),
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

  /// What is worth checking differs per platform, so the text names only the
  /// pieces the running platform actually reads.
  String _configurationHint() {
    const prefix = 'Konfigurasi Google Sign-In belum lengkap. Periksa ';
    if (kIsWeb) {
      return '${prefix}GOOGLE_SERVER_CLIENT_ID di berkas .env dan daftar '
          'origin yang diizinkan pada OAuth client web.';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        '${prefix}GOOGLE_IOS_CLIENT_ID di berkas .env dan skema URL '
            'com.googleusercontent.apps.<client id dibalik> di '
            'ios/Runner/Info.plist.',
      _ =>
        '${prefix}GOOGLE_SERVER_CLIENT_ID di berkas .env dan sidik jari SHA-1 '
            'aplikasi.',
    };
  }
}
