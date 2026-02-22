import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final groqApiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return storage.loadGroqApiKey();
});
