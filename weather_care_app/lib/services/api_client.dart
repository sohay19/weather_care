import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final Duration timeout;

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 6),
  });

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await http.get(uri).timeout(timeout);
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
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
  }
}
