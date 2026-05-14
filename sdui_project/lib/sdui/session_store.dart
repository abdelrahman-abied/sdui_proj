import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for the JWT session token.
/// Tokens persist across app launches; `clear()` is called on logout/401.
class SessionStore {
  static const _kTokenKey = 'sdui.session.token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
  }
}
