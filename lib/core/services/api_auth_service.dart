import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:indonesia_law/core/config/env.dart';
import 'package:indonesia_law/core/consts/constants.dart';
import 'package:indonesia_law/core/models/app_user.dart';
import 'package:indonesia_law/core/services/api_logger.dart';
import 'package:indonesia_law/core/services/api_response.dart';
import 'package:indonesia_law/core/services/auth_service.dart';

/// Email-and-password accounts on the app's own backend, at `DOMAIN` in `.env`.
///
/// The two endpoints do not speak the same dialect: `signin` takes a
/// form-encoded body, `signup` takes JSON. Both answer with a `message` the
/// backend already writes in Indonesian, so failures are shown as they come
/// back instead of being flattened into one generic line.
class ApiAuthService {
  ApiAuthService({http.Client? client})
    : _client = client ?? ApiLogger.instance.wrap(http.Client());

  static const _timeout = Duration(seconds: 30);

  final http.Client _client;

  /// Signs in and returns the account together with its bearer token.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final body = await _send(
      () => _client.post(
        _uri(signin),
        headers: const {'Accept': 'application/json'},
        body: {'email': email, 'password': password},
      ),
      fallback: 'Gagal masuk. Coba lagi.',
    );

    final user = _readUser(body);
    if (user == null) {
      throw const AuthException(
        'Balasan server tidak dikenali. Coba lagi nanti.',
      );
    }
    return user;
  }

  /// Creates an account.
  ///
  /// Returns the signed-in account when the backend hands back a token, and
  /// null when it only confirms the account was created — the caller then sends
  /// the user to the sign-in page.
  Future<AppUser?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final body = await _send(
      () => _client.post(
        _uri(signup),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
        }),
      ),
      fallback: 'Gagal mendaftar. Coba lagi.',
    );

    final user = _readUser(body);
    // No token means the account exists but no session was opened; that is a
    // success, not a failure.
    return user?.accessToken == null ? null : user;
  }

  Uri _uri(String path) {
    if (!Env.hasDomain) {
      throw const AuthException(
        'DOMAIN belum diatur di berkas .env, jadi aplikasi belum tahu ke mana '
        'harus mengirim permintaan.',
      );
    }
    return Env.apiUri(path);
  }

  /// Runs [request] and returns its decoded body, turning every non-2xx answer
  /// and every transport failure into an [AuthException].
  Future<Map<String, Object?>> _send(
    Future<http.Response> Function() request, {
    required String fallback,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const AuthException(
        'Server tidak menjawab. Periksa koneksi internet Anda lalu coba lagi.',
      );
    } on AuthException {
      rethrow;
    } on Object catch (error) {
      debugPrint('Gagal menghubungi server: $error');
      throw const AuthException(
        'Tidak bisa menghubungi server. Periksa koneksi internet Anda lalu '
        'coba lagi.',
      );
    }

    final body = ApiResponse.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    debugPrint(
      'Permintaan auth ditolak (${response.statusCode}): ${response.body}',
    );
    throw AuthException(ApiResponse.describe(body, fallback: fallback));
  }

  /// Pulls the account out of a success body.
  ///
  /// The shape seen in the wild is `{data: {user: {...}}, access_token: ...}`,
  /// but the token has also been observed beside the user, so both spots are
  /// checked rather than pinning the parser to one.
  AppUser? _readUser(Map<String, Object?> body) {
    final scope = ApiResponse.payload(body);
    final raw = scope['user'] ?? body['user'];
    if (raw is! Map<String, Object?>) return null;

    final token = _token(body) ?? _token(scope) ?? _token(raw);
    return AppUser.fromApi(raw, accessToken: token);
  }

  String? _token(Map<String, Object?> scope) {
    for (final key in const ['access_token', 'accessToken', 'token']) {
      final value = scope[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
