import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:plugin_wifi_connect/plugin_wifi_connect.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'startup_messages.dart';
import 'wifi_config.dart';

/// 目标 Wi-Fi 密码统一配置。
///
/// 如果 PAD 设备 Wi-Fi 是开放网络，保持空字符串即可；如果有密码，直接填在这里，
/// 启动页扫描到目标 SSID 后会自动使用这个密码连接。
const String targetWifiPassword = WifiConfig.defaultPassword;

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
/// plugin_wifi_connect 2.0.1 exposes this Dart API but does not implement the
/// native MethodChannel handler. Treat the result as best-effort only.
Future<bool> isWifiEnabled() async {
  try {
    return await PluginWifiConnect.isEnabled;
  } on MissingPluginException {
    return false;
  }
}

/// Requests Android to enable Wi-Fi.
///
/// plugin_wifi_connect 2.0.1 exposes this Dart API but does not implement the
/// native MethodChannel handler, so calling it throws MissingPluginException.
/// Keep this as a no-op wrapper and let scan/connect APIs report the real state.
Future<void> activateWifiIfSupported() async {}

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
/// for deciding whether this looks like an open network. The keyword match
/// happens before this function is called, so the native connection API receives
/// the exact SSID found by scanning.
Future<WifiConnectionResult> connectToScannedAccessPoint(
  WiFiAccessPoint accessPoint, {
  WifiConnectionOptions options = const WifiConnectionOptions(),
}) async {
  final targetSsid = normalizeWifiSsid(accessPoint.ssid);
  if (targetSsid == null || targetSsid.isEmpty) {
    return const WifiConnectionResult(
      success: false,
      message: StartupMessages.wifiConnectEmptySsid,
      targetSsid: '',
    );
  }

  try {
    final currentSsid = await getCurrentWifiSsid();
    if (isSameWifiSsid(currentSsid, targetSsid)) {
      return WifiConnectionResult(
        success: true,
        message: StartupMessages.wifiConnectAlreadyConnected,
        targetSsid: targetSsid,
        currentSsid: currentSsid,
      );
    }

    final needsPassword = _requiresPassword(accessPoint);
    if (needsPassword && !options.hasPassword) {
      return WifiConnectionResult(
        success: false,
        message: StartupMessages.wifiConnectMissingPassword,
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
      message: success
          ? StartupMessages.wifiConnectResultSuccess
          : StartupMessages.wifiConnectResultFailed,
      targetSsid: targetSsid,
      currentSsid: latestSsid,
    );
  } catch (error, stackTrace) {
    debugPrint('===========Error connecting wifi: $error===========');
    debugPrintStack(stackTrace: stackTrace);
    return WifiConnectionResult(
      success: false,
      message: StartupMessages.wifiConnectException,
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

/// *连接的核心方法  通过SSID和密码.
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
