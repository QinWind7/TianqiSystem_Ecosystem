import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT 令牌的安全存取封装。
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> readAccessToken() async {
    try {
      return await _storage.read(key: _accessKey);
    } catch (_) {
      // 安全存储不可用时按未登录处理，不阻塞启动。
      return null;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // 清除失败不抛出，避免登录跳转被中断。
    }
  }

  Future<bool> hasAccessToken() async {
    final token = await readAccessToken();
    return token != null && token.isNotEmpty;
  }
}
