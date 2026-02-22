import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';

const _defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: _defaultApiBaseUrl);
});
