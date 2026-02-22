import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _groqApiKeyKey = 'groq_api_key';

  Future<void> saveGroqApiKey(String key) async {
    await _storage.write(key: _groqApiKeyKey, value: key);
  }

  Future<String?> loadGroqApiKey() {
    return _storage.read(key: _groqApiKeyKey);
  }
}
