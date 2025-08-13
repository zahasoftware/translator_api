import 'dart:convert';
import 'package:http/http.dart' as http;

/// Basic API client with timeout + simple error handling.
class ApiClient {
  ApiClient({required this.baseUrl, this.defaultHeaders = const {}, this.timeoutSeconds = 30});

  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final int timeoutSeconds;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse(baseUrl).resolveUri(Uri(path: path, queryParameters: query?.map((k, v) => MapEntry(k, '$v'))));
  }

  Future<http.Response> postJson(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ...defaultHeaders,
      if (headers != null) ...headers,
    };
    final resp = await http
        .post(_uri(path), body: jsonEncode(body ?? {}), headers: mergedHeaders)
        .timeout(Duration(seconds: timeoutSeconds));
    _throwIfError(resp);
    return resp;
  }

  Future<http.Response> get(String path, {Map<String, dynamic>? query, Map<String, String>? headers}) async {
    final mergedHeaders = {
      ...defaultHeaders,
      if (headers != null) ...headers,
    };
    final resp = await http
        .get(_uri(path, query), headers: mergedHeaders)
        .timeout(Duration(seconds: timeoutSeconds));
    _throwIfError(resp);
    return resp;
  }

  void _throwIfError(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiException(r.statusCode, r.body);
    }
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'ApiException($statusCode): $body';
}
