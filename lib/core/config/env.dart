import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to the values declared in `.env`.
///
/// Call [load] once before `runApp` so the values are available everywhere.
abstract final class Env {
  static const _fileName = '.env';

  static Future<void> load() => dotenv.load(fileName: _fileName);

  /// Reading a value before [load] has run — or after it failed — throws
  /// inside dotenv, so every getter below goes through here and treats a
  /// missing file as an unset value.
  static String? _read(String key) =>
      dotenv.isInitialized ? dotenv.maybeGet(key) : null;

  /// Base URL of the app's own backend, e.g. `https://rag.ipanel.id/`. Empty
  /// when `.env` is missing or `DOMAIN` is not set.
  static String get domain => _read('DOMAIN')?.trim() ?? '';

  static bool get hasDomain => domain.isNotEmpty;

  /// Joins [path] onto [domain], tolerating a trailing slash on one side and a
  /// leading slash on the other so the endpoint constants can be written
  /// either way.
  static Uri apiUri(String path) {
    final base = domain.endsWith('/')
        ? domain.substring(0, domain.length - 1)
        : domain;
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$suffix');
  }

  /// Gemini API key. Empty when `.env` is missing or the key is not set.
  static String get geminiApiKey => _read('GEMINI_API_KEY') ?? '';

  /// Gemini model id, e.g. `gemini-3.5-flash`.
  static String get geminiModel =>
      _read('GEMINI_MODEL') ?? 'gemini-3.5-flash';

  static bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;

  /// OAuth *web* client id, required by Google Sign-In on Android and web
  /// unless the project ships a `google-services.json`. Null when unset so it
  /// can be passed straight to `GoogleSignIn.initialize`.
  static String? get googleServerClientId => _nullable('GOOGLE_SERVER_CLIENT_ID');

  /// OAuth *iOS* client id, used by Google Sign-In on iOS/macOS builds that do
  /// not ship a `GoogleService-Info.plist`.
  static String? get googleIosClientId => _nullable('GOOGLE_IOS_CLIENT_ID');

  static String? _nullable(String key) {
    final value = _read(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
