import 'package:shared_preferences/shared_preferences.dart';

class WifiConfig {
  static const String _ssidKey = 'target_wifi_ssid';
  static const String _passwordKey = 'target_wifi_password';
  static const String defaultSsid = 'robot-noodles';
  static const String defaultPassword = 'lebairobot';

  static Future<String> getTargetSsid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_ssidKey)?.trim();
      if (value == null || value.isEmpty) {
        return defaultSsid;
      }
      return value;
    } catch (e) {
      return defaultSsid;
    }
  }

  static Future<String> getTargetPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_passwordKey)?.trim();
      if (value == null || value.isEmpty) {
        return defaultPassword;
      }
      return value;
    } catch (e) {
      return defaultPassword;
    }
  }

  static Future<bool> saveTargetSsid(String ssid) async {
    final value = ssid.trim();
    if (value.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_ssidKey, value);
  }

  static Future<bool> saveTargetPassword(String password) async {
    final value = password.trim();
    if (value.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_passwordKey, value);
  }

  static Future<bool> saveTargetWifi({
    required String ssid,
    required String password,
  }) async {
    final ssidValue = ssid.trim();
    final passwordValue = password.trim();
    if (ssidValue.isEmpty || passwordValue.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final ssidSaved = await prefs.setString(_ssidKey, ssidValue);
    final passwordSaved = await prefs.setString(_passwordKey, passwordValue);
    return ssidSaved && passwordSaved;
  }

  static Future<bool> resetTargetWifi() async {
    final prefs = await SharedPreferences.getInstance();
    final ssidRemoved =
        !prefs.containsKey(_ssidKey) || await prefs.remove(_ssidKey);
    final passwordRemoved =
        !prefs.containsKey(_passwordKey) || await prefs.remove(_passwordKey);
    return ssidRemoved && passwordRemoved;
  }
}
