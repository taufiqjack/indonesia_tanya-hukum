import 'dart:convert';

/// Shape of the answers the app's own backend gives, in one place.
///
/// Success bodies are sometimes wrapped — `{data: ..., message: 'Success'}` —
/// and sometimes bare; failures always carry a `message`, plus a `error` list
/// naming the fields when validation is what failed.
abstract final class ApiResponse {
  static Map<String, Object?> decode(String raw) {
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  /// The `data` object when the body is wrapped, the body itself otherwise.
  static Map<String, Object?> payload(Map<String, Object?> body) {
    final data = body['data'];
    return data is Map<String, Object?> ? data : body;
  }

  /// The `data` list when the body is wrapped, the body itself when the
  /// endpoint answers with a bare array.
  static List<Object?> payloadList(Object? decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, Object?>) {
      final data = decoded['data'];
      if (data is List) return data;
    }
    return const [];
  }

  /// The backend's own wording for a failure, including the field-by-field
  /// list a validation error carries, so the user is told what is wrong.
  static String describe(
    Map<String, Object?> body, {
    required String fallback,
  }) {
    final message = body['message'];
    final headline = message is String && message.trim().isNotEmpty
        ? message.trim()
        : fallback;

    final details = _validationDetails(body['error']);
    if (details.isEmpty) return headline;
    return '$headline:\n${details.map((line) => '• $line').join('\n')}';
  }

  static List<String> _validationDetails(Object? error) {
    if (error is! List) return const [];

    final lines = <String>[];
    for (final entry in error) {
      if (entry is! Map) continue;
      final message = entry['msg'];
      if (message is! String || message.trim().isEmpty) continue;

      final location = entry['loc'];
      final field = location is List && location.isNotEmpty
          ? location.last.toString()
          : null;
      lines.add(field == null ? message.trim() : '$field: ${message.trim()}');
    }
    return lines;
  }
}
