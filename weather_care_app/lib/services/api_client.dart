import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const _definedTestAccessKey =
      String.fromEnvironment('TEST_ACCESS_KEY');
  static const _testHost = 'weather-test-api.codesoha.com';
  final String baseUrl;
  final Duration timeout;
  final String testAccessKey;

  Map<String, String> get _testHeaders =>
      testAccessKey.isNotEmpty && Uri.parse(baseUrl).host == _testHost
          ? {'X-Weather-Care-Test-Key': testAccessKey}
          : const {};

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 6),
    String? testAccessKey,
  }) : testAccessKey = testAccessKey ?? _definedTestAccessKey;

  /// Authenticated operations use headers, never URL query parameters. Do not
  /// include response bodies, tokens or coordinates in exception messages.
  Future<Map<String, dynamic>> requestJson(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final client = http.Client();
    try {
      final request = http.Request(method, uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          ..._testHeaders,
          ...?headers,
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        } catch (_) {
          throw const ApiException(502, 'INVALID_RESPONSE');
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
            response.statusCode,
            data['error'] is String
                ? data['error'] as String
                : 'REQUEST_FAILED');
      }
      return data;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response =
        await http.get(uri, headers: _testHeaders).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = response.body.isEmpty ? '{}' : response.body;
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  Future<void> putJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await http
        .put(
          uri,
          headers: {'Content-Type': 'application/json', ..._testHeaders},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
  }
}

class ApiException implements Exception {
  final int status;
  final String code;
  const ApiException(this.status, this.code);
  @override
  String toString() => 'API request failed ($status)';
}
