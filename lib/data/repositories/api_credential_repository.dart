import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/providers/llm_provider.dart';

class ApiCredentialRepository {
  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'api_cred_';

  Future<void> saveCredential(String id, ApiCredential credential) async {
    await _storage.write(
      key: '$_keyPrefix$id',
      value: jsonEncode({
        'baseUrl': credential.baseUrl,
        'apiKey': credential.apiKey,
        'authType': credential.authType,
        'extraHeaders': credential.extraHeaders,
      }),
    );
  }

  Future<ApiCredential?> loadCredential(String id) async {
    final data = await _storage.read(key: '$_keyPrefix$id');
    if (data == null) return null;
    try {
      final json = jsonDecode(data);
      return ApiCredential(
        baseUrl: (json['baseUrl'] as String?) ?? '',
        apiKey: (json['apiKey'] as String?) ?? '',
        authType: (json['authType'] as String?) ?? 'bearer',
        extraHeaders: (json['extraHeaders'] as Map?)?.cast<String, String>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCredential(String id) async {
    await _storage.delete(key: '$_keyPrefix$id');
  }

  Future<Map<String, ApiCredential>> listCredentials() async {
    final all = await _storage.readAll();
    final result = <String, ApiCredential>{};
    for (final entry in all.entries) {
      if (entry.key.startsWith(_keyPrefix)) {
        final id = entry.key.substring(_keyPrefix.length);
        try {
          final json = jsonDecode(entry.value);
          result[id] = ApiCredential(
            baseUrl: (json['baseUrl'] as String?) ?? '',
            apiKey: (json['apiKey'] as String?) ?? '',
            authType: (json['authType'] as String?) ?? 'bearer',
            extraHeaders:
                (json['extraHeaders'] as Map?)?.cast<String, String>(),
          );
        } catch (_) {}
      }
    }
    return result;
  }
}
