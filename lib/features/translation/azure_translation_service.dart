import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:translator_app/features/translation/translation_service.dart';
import 'package:translator_app/features/translation/translation_types.dart';

/// Azure Cognitive Services Translator implementation.
/// Endpoint example: https://YOUR_RESOURCE.cognitiveservices.azure.com
class AzureTranslationService implements TranslationService {
  AzureTranslationService({
    required String endpoint,
    required String apiKey,
    required String region,
  })  : _endpoint = _normalizeEndpoint(endpoint),
        _apiKey = apiKey,
        _region = region;

  static String _normalizeEndpoint(String e) {
    var out = e.trim();
    if (out.endsWith('/')) out = out.substring(0, out.length - 1);
    return out;
  }

  final String _endpoint;
  final String _apiKey;
  final String _region;

  @override
  String get id => 'azure';
  @override
  String get label => 'Azure Translator';

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
    TranslationOptions options = const TranslationOptions(),
  }) async {
    final params = <String, String>{
      'api-version': '3.0',
      'to': _langCode(targetLang),
    };
    if (sourceLang != 'auto') params['from'] = _langCode(sourceLang);
  // Azure Translator endpoint format:
  //   https://{resource-name}.cognitiveservices.azure.com/translate?api-version=3.0&to=fr
  // Global endpoint:
  //   https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=fr
  // Older samples occasionally show /translator/text/v3.0/translate which returns 404 now.
  final base = _endpoint.endsWith('/translate')
    ? _endpoint
    : (_endpoint.endsWith('/translator/text/v3.0/translate')
      // Normalize legacy path to modern path
      ? _endpoint.replaceFirst('/translator/text/v3.0/translate', '/translate')
      : '$_endpoint/translate');
  final uri = Uri.parse(base).replace(queryParameters: params);
    final body = jsonEncode([
      {'text': text},
    ]);
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Ocp-Apim-Subscription-Key': _apiKey,
        'Ocp-Apim-Subscription-Region': _region,
      },
      body: body,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Azure error ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as List<dynamic>;
    if (data.isEmpty) return TranslationResult(text: '');
    final first = data.first as Map<String, dynamic>;
    final translations = first['translations'] as List<dynamic>?;
    final translated = translations != null && translations.isNotEmpty
        ? (translations.first as Map<String, dynamic>)['text'] as String? ?? ''
        : '';
    final detected = (first['detectedLanguage'] as Map<String, dynamic>?)?['language'] as String?;
    return TranslationResult(text: translated, detectedSourceLang: detected);
  }

  String _langCode(String display) {
    const map = {
      'auto': 'auto',
      'English': 'en',
      'Spanish': 'es',
      'French': 'fr',
      'German': 'de',
      'Italian': 'it',
      'Portuguese': 'pt',
      'Chinese': 'zh-Hans',
      'Japanese': 'ja',
      'Korean': 'ko',
      'Arabic': 'ar',
      'Russian': 'ru',
    };
    return map[display] ?? display.toLowerCase();
  }

  @override
  Future<List<String>> listModels() async => const [];
}
