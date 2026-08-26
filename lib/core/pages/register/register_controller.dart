import 'package:flutter/foundation.dart';
import 'package:indonesia_law/core/models/app_user.dart';
import 'package:indonesia_law/core/services/api_auth_service.dart';
import 'package:indonesia_law/core/services/auth_service.dart';

/// Outcome of a registration, as far as the page has to care.
class RegisterResult {
  const RegisterResult({required this.user});

  /// The account when the backend opened a session for it, null when it only
  /// created the account and expects a sign-in next.
  final AppUser? user;

  bool get isSignedIn => user != null;
}

/// Drives the register form: one request, a busy flag and the failure to show.
class RegisterController extends ChangeNotifier {
  RegisterController({ApiAuthService? api}) : _api = api ?? ApiAuthService();

  final ApiAuthService _api;

  bool _isBusy = false;
  String? _error;

  bool get isBusy => _isBusy;
  String? get error => _error;

  /// Creates the account. Returns null when it failed, with [error] already set
  /// for the page to show.
  Future<RegisterResult?> submit({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    if (_isBusy) return null;

    _isBusy = true;
    _error = null;
    notifyListeners();

    RegisterResult? result;
    try {
      result = RegisterResult(
        user: await _api.register(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          password: password,
        ),
      );
    } on AuthException catch (error) {
      _error = error.message;
    } on Object catch (error) {
      debugPrint('Gagal mendaftar: $error');
      _error = 'Gagal mendaftar. Coba lagi.';
    }

    _isBusy = false;
    notifyListeners();
    return result;
  }

  /// Drops the error banner, e.g. once the user starts another attempt.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
