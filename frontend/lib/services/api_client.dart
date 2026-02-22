import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Future<List<Map<String, dynamic>>> getPantry({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/pantry'),
      headers: _authHeaders(accessToken),
    );

    final payload = _decode(response);
    return (payload['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> togglePantryItem({
    required String accessToken,
    required int ingredientId,
    required bool status,
    String? quantity,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pantry/toggle'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        'ingredient_id': ingredientId,
        'status': status,
        'quantity': quantity,
      }),
    );

    final payload = _decode(response);
    return (payload['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String text,
    required String accessToken,
    String? groqApiKey,
  }) async {
    final headers = _authHeaders(accessToken);
    if (groqApiKey != null && groqApiKey.isNotEmpty) {
      headers['x-custom-api-key'] = groqApiKey;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/chat/message'),
      headers: headers,
      body: jsonEncode({
        'text': text,
        'provider': 'groq',
      }),
    );

    return _decode(response);
  }

  Map<String, String> _authHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  Map<String, dynamic> _decode(http.Response response) {
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final detail = payload['detail'] ?? response.body;
      throw Exception('Request failed: ${response.statusCode} $detail');
    }
    return payload;
  }
}
