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

  Future<List<Map<String, dynamic>>> getIngredients({
    required String accessToken,
    String? search,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final uri = Uri.parse('$baseUrl/ingredients').replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: _authHeaders(accessToken),
    );
    final payload = _decode(response);
    return (payload['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createIngredient({
    required String accessToken,
    required String name,
    required String category,
    required String defaultUnit,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ingredients'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        'name': name,
        'category': category,
        'default_unit': defaultUnit,
      }),
    );
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> togglePantryItem({
    required String accessToken,
    required int ingredientId,
    required bool status,
    String? quantity,
    bool sendQuantity = false,
  }) async {
    final body = <String, dynamic>{
      'ingredient_id': ingredientId,
      'status': status,
    };
    if (sendQuantity) {
      body['quantity'] = quantity;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/pantry/toggle'),
      headers: _authHeaders(accessToken),
      body: jsonEncode(body),
    );

    final payload = _decode(response);
    return (payload['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String text,
    required String accessToken,
    String? groqApiKey,
    String? extraBudgetInr,
    int? peopleCount,
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
        if (extraBudgetInr != null && extraBudgetInr.trim().isNotEmpty)
          'extra_budget_inr': extraBudgetInr.trim(),
        'people_count': peopleCount,
        'provider': 'groq',
      }),
    );

    return _decode(response);
  }

  Future<Map<String, dynamic>> getRecipeAssistant({
    required String accessToken,
    required String dishName,
    String? question,
    String? groqApiKey,
  }) async {
    final headers = _authHeaders(accessToken);
    if (groqApiKey != null && groqApiKey.isNotEmpty) {
      headers['x-custom-api-key'] = groqApiKey;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/chat/recipe-assistant'),
      headers: headers,
      body: jsonEncode({
        'dish_name': dishName,
        if (question != null && question.trim().isNotEmpty) 'question': question.trim(),
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
