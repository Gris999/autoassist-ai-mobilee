import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/autenticacion_seguridad/domain/auth_user.dart';

class TokenStorage {
  static const _tokenKey = 'autoassist_token';
  static const _rememberSessionKey = 'autoassist_remember_session';
  static const _userKey = 'autoassist_user';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<void> saveRememberSession(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberSessionKey, value);
  }

  static Future<bool> getRememberSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberSessionKey) ?? false;
  }

  static Future<void> saveUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<AuthUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_userKey);

    if (rawUser == null || rawUser.isEmpty) return null;

    try {
      return AuthUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_userKey);
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_rememberSessionKey);
  }
}
