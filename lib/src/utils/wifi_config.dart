import 'package:shared_preferences/shared_preferences.dart';

class WifiConfig {
  static const String _key = 'target_wifi_ssid';
  static const String defaultSsid = 'Staff';

  static Future<String> getTargetSsid() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key)?.trim();
    if (value == null || value.isEmpty) {
      return defaultSsid;
    }
    return value;
  }

  static Future<bool> saveTargetSsid(String ssid) async {
    final value = ssid.trim();
    if (value.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_key, value);
  }
}
