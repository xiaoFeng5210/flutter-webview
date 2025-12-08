import 'package:shared_preferences/shared_preferences.dart';

class UrlConfig {
  static const String _key = 'base_url';
  static const String _defaultUrl = 'http://192.168.22.103:8092';

  // 全局变量，用于存储当前的URL
  static String webviewUrl = '$_defaultUrl/';

  // 读取URL配置
  static Future<String> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null || value.isEmpty) {
      webviewUrl = _defaultUrl;
      return _defaultUrl;
    } else {
      webviewUrl = value;
      return value;
    }
  }

  // 保存url配置
  static Future<bool> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    bool ok = await prefs.setString(_key, url);
    if (ok) {
      webviewUrl = url;
      return true;
    } else {
      return false;
    }
  }
  
  // 检查是否存在
  static Future<bool> hasUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
  
}
