class TranslationResult {
  TranslationResult({required this.text, this.detectedSourceLang});
  final String text;
  final String? detectedSourceLang;
}

class TranslationOptions {
  const TranslationOptions({this.model});
  final String? model;
}
