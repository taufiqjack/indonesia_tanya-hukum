import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to the values declared in `.env`.
///
/// Call [load] once before `runApp` so the values are available everywhere.
abstract final class Env {
  static const _fileName = '.env';

  static Future<void> load() => dotenv.load(fileName: _fileName);

  /// Gemini API key. Empty when `.env` is missing or the key is not set.
  static String get geminiApiKey => dotenv.maybeGet('GEMINI_API_KEY') ?? '';

  /// Gemini model id, e.g. `gemini-3.5-flash`.
  static String get geminiModel =>
      dotenv.maybeGet('GEMINI_MODEL') ?? 'gemini-3.5-flash';

  static bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;

  /// OAuth *web* client id, required by Google Sign-In on Android and web
  /// unless the project ships a `google-services.json`. Null when unset so it
  /// can be passed straight to `GoogleSignIn.initialize`.
  static String? get googleServerClientId => _nullable('GOOGLE_SERVER_CLIENT_ID');

  /// OAuth *iOS* client id, used by Google Sign-In on iOS/macOS builds that do
  /// not ship a `GoogleService-Info.plist`.
  static String? get googleIosClientId => _nullable('GOOGLE_IOS_CLIENT_ID');

  static String? _nullable(String key) {
  final value = dotenv.maybeGet(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
