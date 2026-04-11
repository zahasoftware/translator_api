import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  // Hotkey state (added)
  String _sourceText = '';
  TranslationResult? _lastResult;
  String _defaultTargetLang = 'en';

  // Active UI language selections (kept in sync with the dropdowns)
  String _sourceLang = 'auto';
  String _targetLang = 'English';

  // Fix & Gramma behaviour
  bool _fixAndGrammaAutoRun = true;

  String get sourceText => _sourceText;
  TranslationResult? get lastResult => _lastResult;
  String get defaultTargetLang => _defaultTargetLang;
  String get sourceLang => _sourceLang;
  String get targetLang => _targetLang;
  bool get fixAndGrammaAutoRun => _fixAndGrammaAutoRun;

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
    _defaultTargetLang =
        prefs.getString('default_target_lang') ?? _defaultTargetLang;
    _sourceLang = prefs.getString('source_lang') ?? _sourceLang;
    _targetLang = prefs.getString('target_lang') ?? _targetLang;
    _fixAndGrammaAutoRun = prefs.getBool('fix_gramma_auto_run') ?? _fixAndGrammaAutoRun;
    _service = _buildService();
    _initialized = true;
    notifyListeners();
  }

  TranslationService _buildService() {
    if (_providerId == 'azure') {
      return AzureTranslationService(
          endpoint: _azureEndpoint, apiKey: _azureKey, region: _azureRegion);
    }
    return OllamaTranslationService(baseUrl: _baseUrl, model: _model);
  }

  Future<void> setFixAndGrammaAutoRun(bool value) async {
    if (_fixAndGrammaAutoRun == value) return;
    _fixAndGrammaAutoRun = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fix_gramma_auto_run', value);
    notifyListeners();
  }

  Future<void> updateSettings({
    String? baseUrl,
    String? model,
    String? providerId,
    String? azureEndpoint,
    String? azureKey,
    String? azureRegion,
    String? defaultTargetLang,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (providerId != null) {
      _providerId = providerId;
      await prefs.setString('provider_id', providerId);
    }
    if (baseUrl != null) {
      _baseUrl = baseUrl;
      await prefs.setString('ollama_base_url', baseUrl);
    }
    if (model != null) {
      _model = model;
      await prefs.setString('ollama_model', model);
    }
    if (azureEndpoint != null) {
      _azureEndpoint = azureEndpoint;
      await prefs.setString('azure_endpoint', azureEndpoint);
    }
    if (azureKey != null) {
      _azureKey = azureKey;
      await prefs.setString('azure_key', azureKey);
    }
    if (azureRegion != null) {
      _azureRegion = azureRegion;
      await prefs.setString('azure_region', azureRegion);
    }
    if (defaultTargetLang != null) {
      _defaultTargetLang = defaultTargetLang;
      await prefs.setString('default_target_lang', defaultTargetLang);
    }
    _service = _buildService();
    notifyListeners();
  }

  void setSourceText(String v) {
    _sourceText = v;
    notifyListeners();
  }

  void setLanguages({String? sourceLang, String? targetLang}) {
    if (sourceLang != null) _sourceLang = sourceLang;
    if (targetLang != null) _targetLang = targetLang;
    notifyListeners();
  }

  Future<TranslationResult> performTranslate({
    required String text,
    String sourceLang = 'auto',
    String? targetLang,
    String? modelOverride,
  }) async {
    _sourceText = text;
    notifyListeners();
    final r = await _service.translate(
      text: text,
      targetLang: targetLang ?? _defaultTargetLang,
      sourceLang: sourceLang,
      options: TranslationOptions(model: modelOverride ?? _model),
    );
    _lastResult = r;
    notifyListeners();
    return r;
  }

  Future<TranslationResult?> translateCurrent() async {
    if (_sourceText.trim().isEmpty) return null;
    return performTranslate(text: _sourceText);
  }

  Future<TranslationResult?> translateFromClipboard() async {
    final d = await Clipboard.getData('text/plain');
    final t = d?.text?.trim() ?? '';
    if (t.isEmpty) return null;
    return performTranslate(text: t);
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

  /// Improve text (grammar/style) with a chosen [style] (e.g. formal, casual, friendly, business).
  /// Returns improved text or throws if unsupported by current provider.
  Future<String> improveText(
      {required String text, required String style}) async {
    if (text.trim().isEmpty) return text;
    // Only Ollama service currently supports improvement.
    if (_service is OllamaTranslationService) {
      final s = _service as OllamaTranslationService;
      return s.improveText(text: text, style: style, model: _model);
    }
    throw UnsupportedError(
        'Improvement not supported for provider ${_service.id}');
  }

  /// Fix & Gramma: Fix grammar and get alternatives (formal, friendly, cordial).
  Future<FixAndGrammaResult> fixGrammarWithAlternatives(
      {required String text}) async {
    if (text.trim().isEmpty) {
      return FixAndGrammaResult(rawOutput: 'No text provided.');
    }
    if (_service is OllamaTranslationService) {
      final s = _service as OllamaTranslationService;
      return s.fixGrammarWithAlternatives(text: text, model: _model);
    }
    throw UnsupportedError(
        'Fix & Gramma not supported for provider ${_service.id}');
  }
}
