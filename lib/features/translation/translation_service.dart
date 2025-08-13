import 'package:translator_app/features/translation/translation_types.dart';

/// Abstraction for translation providers.
abstract class TranslationService {
  /// Translate given [text] from [sourceLang] to [targetLang]. If [sourceLang] is 'auto'
  /// the service should attempt detection.
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
    TranslationOptions options = const TranslationOptions(),
  });

  /// Optional: list available models (for model-based providers like Ollama)
  Future<List<String>> listModels() async => const [];

  String get id; // identifier (e.g. 'ollama')
  String get label; // human friendly
}
