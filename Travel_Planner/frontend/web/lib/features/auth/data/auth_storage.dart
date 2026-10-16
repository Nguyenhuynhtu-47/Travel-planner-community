import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// [AuthStorage] manages persistent authentication state on Web.
///
/// SECURITY CONSIDERATION & LIMITATION:
/// On Web browsers, tokens are stored in browser localStorage via [SharedPreferences].
/// LocalStorage does NOT provide hardware encryption (unlike Android Keystore or iOS Keychain)
/// and is vulnerable to Cross-Site Scripting (XSS) if malicious scripts execute in the same origin.
/// In this client-side Single Page Application architecture communicating via Bearer tokens,
/// LocalStorage is the standard mechanism, but it is NOT absolutely secure against XSS.
/// Ensure that all user-supplied content rendered in the DOM is properly sanitized.
class AuthStorage {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_keyUser);
    if (userStr == null || userStr.isEmpty) return null;
    try {
      return jsonDecode(userStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> map = jsonDecode(decoded);
      if (!map.containsKey('exp')) return true;
      final int exp = map['exp'] as int;
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expDate);
    } catch (_) {
      return true;
    }
  }
}
