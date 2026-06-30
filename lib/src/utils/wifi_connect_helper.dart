import 'package:flutter/foundation.dart';
import 'package:plugin_wifi_connect/plugin_wifi_connect.dart';
import 'package:wifi_scan/wifi_scan.dart';

/// 目标 Wi-Fi 密码统一配置。
///
/// 如果 PAD 设备 Wi-Fi 是开放网络，保持空字符串即可；如果有密码，直接填在这里，
/// 启动页扫描到目标 SSID 后会自动使用这个密码连接。
const String targetWifiPassword = '';

/// 目标 Wi-Fi 连接参数统一配置。
const WifiConnectionOptions targetWifiConnectionOptions = WifiConnectionOptions(
  password: targetWifiPassword,
  saveNetwork: true,
);

/// Wi-Fi connection options shared by the startup flow.
///
/// Keep app-level choices here instead of spreading plugin flags through
/// screens. Most IoT/device AP flows either use an open network or one shared
/// password. Leave [password] empty for open networks.
class WifiConnectionOptions {
  const WifiConnectionOptions({
    this.password = '',
    this.saveNetwork = false,
    this.isWep = false,
    this.isWpa3 = false,
    this.isHidden = false,
  });

  final String password;
  final bool saveNetwork;
  final bool isWep;
  final bool isWpa3;
  final bool isHidden;

  bool get hasPassword => password.isNotEmpty;
}

/// A small, screen-friendly result for Wi-Fi connection attempts.
class WifiConnectionResult {
  const WifiConnectionResult({
    required this.success,
    required this.message,
    required this.targetSsid,
    this.currentSsid,
    this.error,
  });

  final bool success;
  final String message;
  final String targetSsid;
  final String? currentSsid;
  final Object? error;
}

/// Returns whether Android Wi-Fi is enabled.
///
/// The plugin only supports this check on Android. Other platforms return
/// false from the plugin, so callers should treat this as Android-specific.
Future<bool> isWifiEnabled() => PluginWifiConnect.isEnabled;

/// Requests Android to enable Wi-Fi.
///
/// On modern Android versions the OS may ignore direct Wi-Fi toggles or require
/// user action. This helper intentionally does not throw for unsupported
/// platforms; the following scan/connect step remains the source of truth.
Future<void> activateWifiIfSupported() => PluginWifiConnect.activateWifi();

/// Reads the currently connected SSID and strips platform quoting.
Future<String?> getCurrentWifiSsid() async {
  final ssid = await PluginWifiConnect.ssid;
  return normalizeWifiSsid(ssid);
}

/// Disconnects from a network connected through plugin_wifi_connect.
Future<bool> disconnectFromPluginWifi() async {
  final disconnected = await PluginWifiConnect.disconnect();
  return disconnected ?? false;
}

/// Connects to a scanned Wi-Fi access point.
///
/// [accessPoint] comes from wifi_scan and gives us the SSID plus capabilities
/// for deciding whether this looks like an open network. plugin_wifi_connect
/// connects by SSID/prefix, not by BSSID, so the selected access point's SSID is
/// the value passed to the native connection API.
Future<WifiConnectionResult> connectToScannedAccessPoint(
  WiFiAccessPoint accessPoint, {
  WifiConnectionOptions options = const WifiConnectionOptions(),
}) async {
  final targetSsid = normalizeWifiSsid(accessPoint.ssid);
  if (targetSsid == null || targetSsid.isEmpty) {
    return const WifiConnectionResult(
      success: false,
      message: '目标 Wi-Fi SSID 为空，无法连接',
      targetSsid: '',
    );
  }

  try {
    final currentSsid = await getCurrentWifiSsid();
    if (isSameWifiSsid(currentSsid, targetSsid)) {
      return WifiConnectionResult(
        success: true,
        message: '已连接目标 Wi-Fi',
        targetSsid: targetSsid,
        currentSsid: currentSsid,
      );
    }

    await activateWifiIfSupported();

    final needsPassword = _requiresPassword(accessPoint);
    if (needsPassword && !options.hasPassword) {
      return WifiConnectionResult(
        success: false,
        message: '目标 Wi-Fi 需要密码，请先配置密码',
        targetSsid: targetSsid,
        currentSsid: currentSsid,
      );
    }

    final connected = await _connectByAccessPointSecurity(
      accessPoint,
      targetSsid: targetSsid,
      options: options,
    );
    final latestSsid = await getCurrentWifiSsid();
    final success = connected || isSameWifiSsid(latestSsid, targetSsid);

    return WifiConnectionResult(
      success: success,
      message: success ? '目标 Wi-Fi 连接成功' : '目标 Wi-Fi 连接失败',
      targetSsid: targetSsid,
      currentSsid: latestSsid,
    );
  } catch (error, stackTrace) {
    debugPrint('===========Error connecting wifi: $error===========');
    debugPrintStack(stackTrace: stackTrace);
    return WifiConnectionResult(
      success: false,
      message: '目标 Wi-Fi 连接异常',
      targetSsid: targetSsid,
      error: error,
    );
  }
}

/// Connects to an open network by exact SSID.
Future<bool> connectToOpenWifi(String ssid, {bool saveNetwork = false}) async {
  final connected = await PluginWifiConnect.connect(
    ssid,
    saveNetwork: saveNetwork,
  );
  return connected ?? false;
}

/// Connects to a secure network by exact SSID.
Future<bool> connectToSecureWifi(
  String ssid,
  String password, {
  bool isWep = false,
  bool isWpa3 = false,
  bool saveNetwork = false,
  bool isHidden = false,
}) async {
  final connected = await PluginWifiConnect.connectToSecureNetwork(
    ssid,
    password,
    isWep: isWep,
    isWpa3: isWpa3,
    saveNetwork: saveNetwork,
    isHidden: isHidden,
  );
  return connected ?? false;
}

/// Connects to the nearest open network whose SSID starts with [ssidPrefix].
Future<bool> connectToOpenWifiByPrefix(
  String ssidPrefix, {
  bool saveNetwork = false,
}) async {
  final connected = await PluginWifiConnect.connectByPrefix(
    ssidPrefix,
    saveNetwork: saveNetwork,
  );
  return connected ?? false;
}

/// Connects to the nearest secure network whose SSID starts with [ssidPrefix].
Future<bool> connectToSecureWifiByPrefix(
  String ssidPrefix,
  String password, {
  bool isWep = false,
  bool isWpa3 = false,
  bool saveNetwork = false,
}) async {
  final connected = await PluginWifiConnect.connectToSecureNetworkByPrefix(
    ssidPrefix,
    password,
    isWep: isWep,
    isWpa3: isWpa3,
    saveNetwork: saveNetwork,
  );
  return connected ?? false;
}

/// Removes Android/iOS SSID quoting so comparisons are stable.
String? normalizeWifiSsid(String? ssid) {
  final value = ssid?.trim();
  if (value == null || value.isEmpty || value == '<unknown ssid>') {
    return null;
  }
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

bool isSameWifiSsid(String? left, String? right) {
  final normalizedLeft = normalizeWifiSsid(left);
  final normalizedRight = normalizeWifiSsid(right);
  if (normalizedLeft == null || normalizedRight == null) return false;
  return normalizedLeft == normalizedRight;
}

Future<bool> _connectByAccessPointSecurity(
  WiFiAccessPoint accessPoint, {
  required String targetSsid,
  required WifiConnectionOptions options,
}) {
  if (options.hasPassword || _requiresPassword(accessPoint)) {
    return connectToSecureWifi(
      targetSsid,
      options.password,
      isWep: options.isWep || _isWepNetwork(accessPoint),
      isWpa3: options.isWpa3 || _isWpa3Network(accessPoint),
      saveNetwork: options.saveNetwork,
      isHidden: options.isHidden,
    );
  }

  return connectToOpenWifi(targetSsid, saveNetwork: options.saveNetwork);
}

bool _requiresPassword(WiFiAccessPoint accessPoint) {
  final capabilities = accessPoint.capabilities.toUpperCase();
  return capabilities.contains('WEP') ||
      capabilities.contains('WPA') ||
      capabilities.contains('PSK') ||
      capabilities.contains('EAP') ||
      capabilities.contains('SAE');
}

bool _isWepNetwork(WiFiAccessPoint accessPoint) {
  return accessPoint.capabilities.toUpperCase().contains('WEP');
}

bool _isWpa3Network(WiFiAccessPoint accessPoint) {
  final capabilities = accessPoint.capabilities.toUpperCase();
  return capabilities.contains('SAE') || capabilities.contains('WPA3');
}
