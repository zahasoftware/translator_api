import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator_app/features/translation/ollama_translation_service.dart';
import 'package:translator_app/features/translation/translation_service.dart';
import 'package:translator_app/features/translation/translation_types.dart';

class TranslationProvider extends ChangeNotifier {
  TranslationProvider();

  late TranslationService _service;
  String _baseUrl = 'http://localhost:11434';
  String _model = 'llama3';

  String get baseUrl => _baseUrl;
  String get model => _model;
  TranslationService get service => _service;

  bool _initialized = false;
  bool get initialized => _initialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('ollama_base_url') ?? _baseUrl;
    _model = prefs.getString('ollama_model') ?? _model;
    _service = OllamaTranslationService(baseUrl: _baseUrl, model: _model);
    _initialized = true;
    notifyListeners();
  }

  Future<void> updateSettings({String? baseUrl, String? model}) async {
    final prefs = await SharedPreferences.getInstance();
    if (baseUrl != null) {
      _baseUrl = baseUrl;
      await prefs.setString('ollama_base_url', baseUrl);
    }
    if (model != null) {
      _model = model;
      await prefs.setString('ollama_model', model);
    }
    _service = OllamaTranslationService(baseUrl: _baseUrl, model: _model);
    notifyListeners();
  }

  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
    String? model,
  }) async {
    final result = await _service.translate(
      text: text,
      targetLang: targetLang,
      sourceLang: sourceLang,
      options: TranslationOptions(model: model),
    );
    return result;
  }
}
