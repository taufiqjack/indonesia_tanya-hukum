import 'package:flutter/foundation.dart';
import 'package:indonesia_law/core/models/app_user.dart';
import 'package:indonesia_law/core/services/auth_service.dart';
import 'package:indonesia_law/core/services/session_store.dart';

/// Holds the signed-in account and drives the sign-in flow.
///
/// A session only ever starts with an explicit [signIn], and then survives
/// restarts: the account is saved on the device and read back by [restore], so
/// closing the app no longer means signing in again. It ends when the user
/// taps sign out — never on its own, and never for an account that merely
/// happens to sit on the device.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? service, SessionStore? store})
    : _service = service ?? GoogleAuthService(),
      _store = store ?? LocalSessionStore();

  final AuthService _service;
  final SessionStore _store;

  AppUser? _user;
  bool _isBusy = false;
  bool _isRestoring = true;
  String? _error;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;

  /// True while an interactive sign-in or a sign-out is running.
  bool get isBusy => _isBusy;

  /// True until [restore] has answered. The gate waits on this instead of
  /// flashing the sign-in page in front of an already signed-in user.
  bool get isRestoring => _isRestoring;

  /// Last failure, ready to be shown. Cancelling leaves this null.
  String? get error => _error;

  /// Brings back the account saved by the last [signIn], if any.
  ///
  /// The saved account is the whole answer: Google is never asked anything on
  /// launch. Even its silent call goes through Android's Credential Manager,
  /// which greets an already signed-in user with an account sheet over the
  /// chat — and the name and photo shown here are not worth that.
  Future<void> restore() async {
    try {
      _user = await _store.read();
    } on Object catch (error) {
      // An unreadable store is a sign-in away from being fixed; never a splash
      // the app cannot leave.
      debugPrint('Gagal membaca sesi tersimpan: $error');
    }

    _isRestoring = false;
    notifyListeners();
  }

  Future<void> signIn() async {
    if (_isBusy) return;

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _service.signIn();
      // Null means the user backed out — stay on the page, say nothing.
      if (user != null) {
        _user = user;
        // Failing to remember the account costs the next launch a sign-in; it
        // must not turn a sign-in that worked into an error.
        try {
          await _store.write(user);
        } on Object catch (error) {
          debugPrint('Gagal menyimpan sesi: $error');
        }
      }
    } on AuthException catch (error) {
      _error = error.message;
    } on Object catch (error) {
      debugPrint('Gagal masuk: $error');
      _error = 'Gagal masuk dengan Google. Coba lagi.';
    }

    _isBusy = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_isBusy) return;

    _isBusy = true;
    notifyListeners();

    try {
      await _service.signOut();
    } on Object catch (error) {
      debugPrint('Gagal keluar: $error');
    }

    // Dropped even if the SDK call failed, so a signed-out user is not handed
    // the chat again on the next launch.
    try {
      await _store.clear();
    } on Object catch (error) {
      debugPrint('Gagal menghapus sesi tersimpan: $error');
    }

    _user = null;
    _error = null;
    _isBusy = false;
    notifyListeners();
  }

  /// Drops the error banner, e.g. once the user starts another attempt.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
