import 'dart:convert';

import 'package:translator_app/core/api_client.dart';
import 'package:translator_app/features/translation/translation_service.dart';
import 'package:translator_app/features/translation/translation_types.dart';

/// Ollama local API translation via a prompt engineering approach.
/// Assumes Ollama server running at provided baseUrl (default http://localhost:11434/)
class OllamaTranslationService implements TranslationService {
  OllamaTranslationService({required String baseUrl, String? model})
      : _client = ApiClient(baseUrl: baseUrl),
        _model = model ?? 'llama3';

  final ApiClient _client;
  String _model;

  @override
  String get id => 'ollama';
  @override
  String get label => 'Ollama (Local LLM)';

  set model(String value) => _model = value;
  String get model => _model;

  @override
  Future<List<String>> listModels() async {
    try {
      final resp = await _client.get('/api/tags');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final models = (data['models'] as List<dynamic>?)?.map((e) => e['name'] as String).toList() ?? [];
      return models;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
    TranslationOptions options = const TranslationOptions(),
  }) async {
    final modelToUse = options.model ?? _model;
    // Construct a concise translation prompt
    final prompt = _buildPrompt(text: text, target: targetLang, source: sourceLang);

    final body = {
      'model': modelToUse,
      'prompt': prompt,
      'stream': false,
    };

    final resp = await _client.postJson('/api/generate', body: body);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final output = data['response'] as String? ?? '';
    return TranslationResult(text: _extractTranslation(output));
  }

  String _buildPrompt({required String text, required String target, required String source}) {
    final srcPart = source == 'auto' ? '' : '($source)';
    return 'You are a translation engine. Translate the following text $srcPart into $target only. Do not add explanations. Text: ```$text```';
  }

  String _extractTranslation(String raw) {
    // Simple cleanup; optionally strip code fences.
    final cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      final idx = cleaned.indexOf('\n');
      if (idx != -1) {
        return cleaned.substring(idx + 1).replaceAll('```', '').trim();
      }
    }
    return cleaned;
  }
}
