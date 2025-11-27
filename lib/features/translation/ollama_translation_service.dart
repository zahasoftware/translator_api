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
      final models = (data['models'] as List<dynamic>?)
              ?.map((e) => e['name'] as String)
              .toList() ??
          [];
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
    final prompt =
        _buildPrompt(text: text, target: targetLang, source: sourceLang);

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

  String _buildPrompt(
      {required String text, required String target, required String source}) {
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

  /// Improve grammar/clarity/style of the input [text] according to [style].
  /// Returns only the improved text (no explanations).
  Future<String> improveText({
    required String text,
    required String style,
    String? model,
  }) async {
    final modelToUse = model ?? _model;
    final prompt = _buildImprovePrompt(text: text, style: style);
    final body = {
      'model': modelToUse,
      'prompt': prompt,
      'stream': false,
    };
    final resp = await _client.postJson('/api/generate', body: body);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final output = (data['response'] as String? ?? '').trim();
    return _extractTranslation(output);
  }

  String _buildImprovePrompt({required String text, required String style}) {
    return 'You are a writing assistant. Rewrite the following text to improve grammar, clarity and correctness. Tone/style: $style. Preserve meaning. Output ONLY the improved text. Text: ```\n$text\n```';
  }

  /// Fix & Gramma: Fix grammar and provide alternatives (formal, friendly, cordial).
  Future<ChoiceYouResult> fixGrammarWithAlternatives({
    required String text,
    String? model,
  }) async {
    final modelToUse = model ?? _model;
    final prompt = _buildChoiceYouPrompt(text: text);
    final body = {
      'model': modelToUse,
      'prompt': prompt,
      'stream': false,
    };
    final resp = await _client.postJson('/api/generate', body: body);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = (data['response'] as String? ?? '').trim();
    return ChoiceYouResult(rawOutput: raw);
  }

  String _buildChoiceYouPrompt({required String text}) {
    return 'You are an expert editor. Fix any grammar, spelling, or clarity issues in the following text. Then provide three style alternatives: formal, friendly, and cordial. Format your response clearly with sections for: corrected text, explanation of fixes, formal version, friendly version, and cordial version. Text: ```\n$text\n```';
  }
}
