import 'remote_config_service.dart';
import 'user_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  static const _tokenKey = 'api_token';
  static const _authDataKey = 'api_auth_data';

  static String? _tokenCache;
  static String? _authDataCache;
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // 优先读取安全存储；发现旧版明文数据时自动迁移。
  static Future<String?> _readSecureValue(String key) async {
    final secureValue = await _secureStorage.read(key: key);
    final prefs = await SharedPreferences.getInstance();

    if (secureValue != null && secureValue.isNotEmpty) {
      await prefs.remove(key);
      return secureValue;
    }

    final legacyValue = prefs.getString(key);
    if (legacyValue == null || legacyValue.isEmpty) {
      if (legacyValue != null) {
        await prefs.remove(key);
      }
      return null;
    }

    await _secureStorage.write(key: key, value: legacyValue);
    await prefs.remove(key);
    return legacyValue;
  }

  Future<String> getBaseUrl() async {
    final domain = await RemoteConfigService().getActiveDomain();
    // 移除末尾的斜杠（如果有）
    final cleanDomain =
        domain.endsWith('/') ? domain.substring(0, domain.length - 1) : domain;
    return '$cleanDomain/api/v1';
  }

  Future<String?> getToken() async {
    final cached = _tokenCache;
    if (cached != null) return cached;
    final value = await _readSecureValue(_tokenKey);
    _tokenCache = value;
    return value;
  }

  Future<void> setToken(String? token) async {
    _tokenCache = token;
    if (token == null || token.isEmpty) {
      await _secureStorage.delete(key: _tokenKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      return;
    }
    await _secureStorage.write(key: _tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<String?> getAuthData() async {
    final cached = _authDataCache;
    if (cached != null) return cached;
    final value = await _readSecureValue(_authDataKey);
    _authDataCache = value;
    return value;
  }

  Future<void> setAuthData(String? value) async {
    _authDataCache = value;
    if (value == null || value.isEmpty) {
      await _secureStorage.delete(key: _authDataKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authDataKey);
      return;
    }
    await _secureStorage.write(key: _authDataKey, value: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authDataKey);
  }

  Future<void> clearAuth() async {
    _tokenCache = null;
    _authDataCache = null;
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _authDataKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_authDataKey);

    // 清除用户数据缓存
    UserDataService().clearCache();
  }

  Future<void> refreshAuthCache() async {
    _tokenCache = await _readSecureValue(_tokenKey);
    _authDataCache = await _readSecureValue(_authDataKey);
  }
}
