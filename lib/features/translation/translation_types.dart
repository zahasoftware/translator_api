class TranslationResult {
  TranslationResult({required this.text, this.detectedSourceLang});
  final String text;
  final String? detectedSourceLang;
}

class TranslationOptions {
  const TranslationOptions({this.model});
  final String? model;
}

/// Result for grammar/style improvement with explanation.
class ImprovementResult {
  ImprovementResult({required this.improved, required this.explanation});
  final String improved; // The corrected / styled text
  final String explanation; // Rationale of key changes
}

/// Result for "Choice You" feature - raw AI output.
class ChoiceYouResult {
  ChoiceYouResult({required this.rawOutput});
  final String rawOutput; // Raw AI model output with corrections and alternatives
}
