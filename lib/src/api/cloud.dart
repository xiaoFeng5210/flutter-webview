import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

/// 设备信息模型
class Device {
  final String id;
  final String nickname;
  final String dealerName;
  final bool online;

  Device({
    required this.id,
    required this.nickname,
    required this.dealerName,
    required this.online,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['_id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      dealerName: json['dealer_name'] as String? ?? '',
      online: json['online'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nickname': nickname,
      'dealer_name': dealerName,
      'online': online,
    };
  }
}

/// 设备列表数据模型
class DeviceListData {
  final List<Device> list;
  final int total;

  DeviceListData({
    required this.list,
    required this.total,
  });

  factory DeviceListData.fromJson(Map<String, dynamic> json) {
    return DeviceListData(
      list: (json['list'] as List<dynamic>?)
              ?.map((item) => Device.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
    );
  }
}

/// API 响应模型
class DeviceListResponse {
  final int code;
  final DeviceListData data;

  DeviceListResponse({
    required this.code,
    required this.data,
  });

  factory DeviceListResponse.fromJson(Map<String, dynamic> json) {
    return DeviceListResponse(
      code: json['code'] as int? ?? -1,
      data: DeviceListData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

/// 登录请求参数
class SignInRequest {
  final String username;
  final String password;

  SignInRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

/// 登录响应模型
class SignInResponse {
  final int code;
  final Map<String, dynamic>? data;
  final String? message;

  SignInResponse({
    required this.code,
    this.data,
    this.message,
  });

  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    return SignInResponse(
      code: json['code'] as int? ?? -1,
      data: json['data'] as Map<String, dynamic>?,
      message: json['message'] as String?,
    );
  }

  bool get isSuccess => code == 200 || code == 0;
}

/// 获取设备列表的请求参数
class DeviceListParams {
  final String integrator;
  final String dealer;
  final int startTime;
  final int endTime;
  final String keyword;
  final String sn;
  final int pn;
  final int ps;

  DeviceListParams({
    this.integrator = '',
    this.dealer = '',
    this.startTime = 0,
    this.endTime = 0,
    this.keyword = '',
    this.sn = '',
    this.pn = 1,
    this.ps = 20,
  });

  Map<String, dynamic> toJson() {
    return {
      'integrator': integrator,
      'dealer': dealer,
      'start_time': startTime,
      'end_time': endTime,
      'keyword': keyword,
      'sn': sn,
      'pn': pn,
      'ps': ps,
    };
  }
}

/// 云服务 API 客户端
class CloudApi {
  static const String baseUrl = 'https://shop.lebai.ltd/api';
  static const Duration timeout = Duration(seconds: 10);

  final http.Client _client;
  CookieJar? _cookieJar;
  bool _cookieJarInitialized = false;

  CloudApi({http.Client? client}) : _client = client ?? http.Client();

  /// 初始化 Cookie 管理器
  Future<void> _initCookieJar() async {
    if (_cookieJarInitialized) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cookiePath = '${directory.path}/.cookies/';
      _cookieJar = PersistCookieJar(
        storage: FileStorage(cookiePath),
      );
      _cookieJarInitialized = true;
    } catch (e) {
      // 如果初始化失败，使用内存 CookieJar
      _cookieJar = CookieJar();
      _cookieJarInitialized = true;
    }
  }

  /// 获取 Cookie 字符串
  Future<String> _getCookieString(Uri uri) async {
    await _initCookieJar();
    if (_cookieJar == null) return '';
    
    final cookies = await _cookieJar!.loadForRequest(uri);
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  /// 保存响应中的 Cookie
  Future<void> _saveCookies(Uri uri, http.Response response) async {
    await _initCookieJar();
    if (_cookieJar == null) return;
    
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      final cookies = _parseSetCookieHeaders(setCookieHeaders);
      await _cookieJar!.saveFromResponse(uri, cookies);
    }
  }

  /// 解析 Set-Cookie 响应头
  List<Cookie> _parseSetCookieHeaders(String setCookieHeader) {
    final cookies = <Cookie>[];
    final cookieStrings = setCookieHeader.split(',').map((s) => s.trim()).toList();
    
    for (final cookieString in cookieStrings) {
      try {
        final parts = cookieString.split(';');
        if (parts.isEmpty) continue;
        
        final nameValue = parts[0].split('=');
        if (nameValue.length != 2) continue;
        
        final cookie = Cookie(nameValue[0].trim(), nameValue[1].trim());
        
        // 解析其他属性
        for (var i = 1; i < parts.length; i++) {
          final part = parts[i].trim().toLowerCase();
          if (part.startsWith('domain=')) {
            cookie.domain = part.substring(7);
          } else if (part.startsWith('path=')) {
            cookie.path = part.substring(5);
          } else if (part == 'httponly') {
            cookie.httpOnly = true;
          } else if (part == 'secure') {
            cookie.secure = true;
          } else if (part.startsWith('max-age=')) {
            final maxAge = int.tryParse(part.substring(8));
            if (maxAge != null) {
              cookie.maxAge = maxAge;
            }
          } else if (part.startsWith('expires=')) {
            // 可以在这里解析 expires，但 Cookie 类不直接支持
            // 如果需要可以扩展
          }
        }
        
        cookies.add(cookie);
      } catch (e) {
        // 忽略解析失败的 cookie
        continue;
      }
    }
    
    return cookies;
  }

  /// 清除所有 Cookie
  Future<void> clearCookies() async {
    await _initCookieJar();
    if (_cookieJar != null) {
      final uri = Uri.parse(baseUrl);
      await _cookieJar!.delete(uri);
    }
  }

  /// 登录
  /// 
  /// [request] 登录请求参数
  /// 
  /// 返回 [SignInResponse] 登录响应
  /// 
  /// 抛出异常如果请求失败或超时
  Future<SignInResponse> signIn(SignInRequest request) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/signin');
      
      // 获取已有的 Cookie
      final cookieString = await _getCookieString(uri);
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (cookieString.isNotEmpty) {
        headers['Cookie'] = cookieString;
      }
      
      final body = json.encode(request.toJson());

      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(timeout, onTimeout: () {
        throw Exception('请求超时');
      });

      // 保存响应中的 Cookie
      await _saveCookies(uri, response);

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return SignInResponse.fromJson(jsonData);
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('登录失败: $e');
    }
  }

  /// 获取设备列表
  /// 
  /// [params] 请求参数
  /// 
  /// 返回 [DeviceListResponse] 设备列表响应
  /// 
  /// 抛出异常如果请求失败或超时
  Future<DeviceListResponse> getDeviceList(DeviceListParams params) async {
    try {
      final uri = Uri.parse('$baseUrl/device/list').replace(
        queryParameters: params.toJson().map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );

      // 获取已有的 Cookie
      final cookieString = await _getCookieString(uri);
      final headers = <String, String>{};
      if (cookieString.isNotEmpty) {
        headers['Cookie'] = cookieString;
      }

      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout, onTimeout: () {
        throw Exception('请求超时');
      });

      // 保存响应中的 Cookie（如果有新的）
      await _saveCookies(uri, response);

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return DeviceListResponse.fromJson(jsonData);
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('获取设备列表失败: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
