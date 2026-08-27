import 'dart:async';
import 'dart:convert';

import 'package:alice/alice.dart';
import 'package:alice/model/alice_configuration.dart';
import 'package:alice/model/alice_form_data_file.dart';
import 'package:alice/model/alice_from_data_field.dart';
import 'package:alice/model/alice_http_call.dart';
import 'package:alice/model/alice_http_error.dart';
import 'package:alice/model/alice_http_request.dart';
import 'package:alice/model/alice_http_response.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// On-device inspector for every call the app makes to its backend, to Gemini,
/// and to the auth endpoints.
///
/// Alice keeps the calls in memory and shows them on its own full-screen page.
/// The page is reached three ways: the notification Alice posts for each call,
/// shaking the device, and the entry in the history drawer.
///
/// Requests are captured by wrapping the `http.Client` the services already
/// take, so nothing at the call sites has to change and no call can be
/// forgotten.
///
/// Debug builds only — release builds hand back the plain client, so bearer
/// tokens and answers are never collected on a user's phone.
class ApiLogger {
  ApiLogger._();

  static final ApiLogger instance = ApiLogger._();

  /// Whether traffic is captured at all. Everything else here is inert when
  /// this is false.
  static const bool isEnabled = kDebugMode;

  Alice? _alice;

  /// Alice pushes its inspector onto this navigator, so it has to be the one
  /// `MaterialApp` uses. Null in release builds, which `MaterialApp` accepts.
  GlobalKey<NavigatorState>? get navigatorKey => _alice?.getNavigatorKey();

  /// Starts capturing. Safe to call more than once.
  void start() {
    if (!isEnabled || _alice != null) return;
    _alice = Alice(
      configuration: AliceConfiguration(
        showNotification: true,
        showInspectorOnShake: true,
        showShareButton: true,
      ),
    );
  }

  /// Opens the inspector. Does nothing when capturing is off.
  void showInspector() => _alice?.showInspector();

  /// Returns [inner] wrapped so its traffic reaches the inspector, or [inner]
  /// itself when capturing is off.
  http.Client wrap(http.Client inner) {
    final alice = _alice;
    return alice == null ? inner : _LoggedClient(inner, alice);
  }
}

/// An `http.Client` that reports every request it carries to Alice.
///
/// Responses are passed through as they arrive rather than buffered, so the
/// streamed Gemini answer still reaches the chat word by word; the bytes are
/// collected on the way past and the call is recorded once the body ends.
class _LoggedClient extends http.BaseClient {
  _LoggedClient(this._inner, this._alice);

  static int _lastId = 0;

  final http.Client _inner;
  final Alice _alice;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Read before sending: `send` finalizes the request, and a finalized body
    // is no longer meant to be inspected.
    final logged = _describeRequest(request);

    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } on Object catch (error, stackTrace) {
      _record(
        request,
        logged,
        response: AliceHttpResponse()
          ..status = -1
          ..time = DateTime.now()
          ..body = '$error',
        error: AliceHttpError()
          ..error = error
          ..stackTrace = stackTrace,
      );
      rethrow;
    }

    final body = <int>[];
    return http.StreamedResponse(
      _tee(response.stream, body, () {
        _record(request, logged, response: _describeResponse(response, body));
      }),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request ?? request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();

  /// Yields [source] untouched while copying it into [sink], then runs
  /// [onDone] — also when the reader gives up early, so a call is never left
  /// unrecorded.
  static Stream<List<int>> _tee(
    Stream<List<int>> source,
    List<int> sink,
    VoidCallback onDone,
  ) async* {
    try {
      await for (final chunk in source) {
        sink.addAll(chunk);
        yield chunk;
      }
    } finally {
      onDone();
    }
  }

  AliceHttpRequest _describeRequest(http.BaseRequest request) {
    final headers = Map<String, String>.from(request.headers);
    final logged = AliceHttpRequest()
      ..time = DateTime.now()
      ..headers = headers
      ..contentType = headers['Content-Type'] ?? headers['content-type']
      ..queryParameters = request.url.queryParameters
      ..size = request.contentLength ?? 0;

    if (request is http.MultipartRequest) {
      // The uploaded bytes are left out on purpose — Alice lists the files by
      // name and size instead, which is what a log is for.
      logged
        ..body = request.fields
        ..formDataFields = [
          for (final field in request.fields.entries)
            AliceFormDataField(field.key, field.value),
        ]
        ..formDataFiles = [
          for (final file in request.files)
            AliceFormDataFile(
              file.filename,
              file.contentType.toString(),
              file.length,
            ),
        ];
    } else if (request is http.Request) {
      logged.body = _readBody(request);
    }

    return logged;
  }

  AliceHttpResponse _describeResponse(
    http.StreamedResponse response,
    List<int> body,
  ) {
    return AliceHttpResponse()
      ..status = response.statusCode
      ..time = DateTime.now()
      ..size = body.length
      ..headers = Map<String, String>.from(response.headers)
      ..body = utf8.decode(body, allowMalformed: true);
  }

  void _record(
    http.BaseRequest request,
    AliceHttpRequest logged, {
    required AliceHttpResponse response,
    AliceHttpError? error,
  }) {
    final url = request.url;
    _alice.addHttpCall(
      AliceHttpCall(++_lastId)
        ..client = 'http'
        ..method = request.method
        ..uri = url.toString()
        ..endpoint = url.path.isEmpty ? '/' : url.path
        ..server = url.host
        ..secure = url.scheme == 'https'
        ..loading = false
        ..duration = response.time.difference(logged.time).inMilliseconds
        ..request = logged
        ..response = response
        ..error = error,
    );
  }

  /// A request body is only text if its encoding can read it back; anything
  /// else is summarised rather than dropped.
  static Object _readBody(http.Request request) {
    try {
      return request.body;
    } on Object {
      return '<${request.bodyBytes.length} bytes>';
    }
  }
}
