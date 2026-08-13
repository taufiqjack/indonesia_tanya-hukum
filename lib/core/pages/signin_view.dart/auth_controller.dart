import 'package:flutter/foundation.dart';
import 'package:indonesia_law/core/models/app_user.dart';
import 'package:indonesia_law/core/services/auth_service.dart';

/// Holds the signed-in account and drives the sign-in flow.
///
/// The account only ever comes from an explicit [signIn]; nothing is restored
/// on launch, so every run starts on the sign-in page.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? service})
    : _service = service ?? GoogleAuthService();

  final AuthService _service;

  AppUser? _user;
  bool _isBusy = false;
  String? _error;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;

  /// True while an interactive sign-in or a sign-out is running.
  bool get isBusy => _isBusy;

  /// Last failure, ready to be shown. Cancelling leaves this null.
  String? get error => _error;

  Future<void> signIn() async {
    if (_isBusy) return;

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _service.signIn();
      // Null means the user backed out — stay on the page, say nothing.
      if (user != null) _user = user;
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
