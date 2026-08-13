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
}
