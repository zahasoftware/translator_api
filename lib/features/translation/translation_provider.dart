import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator_app/features/translation/ollama_translation_service.dart';
import 'package:translator_app/features/translation/azure_translation_service.dart';
import 'package:translator_app/features/translation/translation_service.dart';
import 'package:translator_app/features/translation/translation_types.dart';

class TranslationProvider extends ChangeNotifier {
  TranslationProvider();

  late TranslationService _service;
  // Ollama settings
  String _baseUrl = 'http://localhost:11434';
  String _model = 'llama3';
  // Azure settings
  String _azureEndpoint = '';
  String _azureKey = '';
  String _azureRegion = '';
  // Active provider id
  String _providerId = 'ollama';

  String get baseUrl => _baseUrl;
  String get model => _model;
  String get providerId => _providerId;
  String get azureEndpoint => _azureEndpoint;
  String get azureKey => _azureKey;
  String get azureRegion => _azureRegion;
  TranslationService get service => _service;

  bool _initialized = false;
  bool get initialized => _initialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _providerId = prefs.getString('provider_id') ?? _providerId;
    _baseUrl = prefs.getString('ollama_base_url') ?? _baseUrl;
    _model = prefs.getString('ollama_model') ?? _model;
    _azureEndpoint = prefs.getString('azure_endpoint') ?? _azureEndpoint;
    _azureKey = prefs.getString('azure_key') ?? _azureKey;
    _azureRegion = prefs.getString('azure_region') ?? _azureRegion;
    _service = _buildService();
    _initialized = true;
    notifyListeners();
  }

  TranslationService _buildService() {
    if (_providerId == 'azure') {
      return AzureTranslationService(endpoint: _azureEndpoint, apiKey: _azureKey, region: _azureRegion);
    }
    return OllamaTranslationService(baseUrl: _baseUrl, model: _model);
  }

  Future<void> updateSettings({
    String? baseUrl,
    String? model,
    String? providerId,
    String? azureEndpoint,
    String? azureKey,
    String? azureRegion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (providerId != null) {
      _providerId = providerId;
      await prefs.setString('provider_id', providerId);
    }
    if (baseUrl != null) { _baseUrl = baseUrl; await prefs.setString('ollama_base_url', baseUrl); }
    if (model != null) { _model = model; await prefs.setString('ollama_model', model); }
    if (azureEndpoint != null) { _azureEndpoint = azureEndpoint; await prefs.setString('azure_endpoint', azureEndpoint); }
    if (azureKey != null) { _azureKey = azureKey; await prefs.setString('azure_key', azureKey); }
    if (azureRegion != null) { _azureRegion = azureRegion; await prefs.setString('azure_region', azureRegion); }
    _service = _buildService();
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
