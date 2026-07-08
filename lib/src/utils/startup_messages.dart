import 'package:wifi_scan/wifi_scan.dart';

class StartupMessages {
  const StartupMessages._();

  static const preparing = '正在准备启动流程...';

  static const targetWifiLabel = '目标 Wi-Fi';
  static const latestScanLabel = '最近扫描';
  static const matchedWifiLabel = '匹配 Wi-Fi';
  static const wifiConnectionLabel = 'WIFI连接状态';
  static const currentUrlLabel = '当前 URL';

  static const manualRetryTriggered = '已手动触发重试，正在重新检测...';

  static const wifiFindScanning = '正在查找 Wi-Fi...';
  static const wifiFindSearching = 'Wi-Fi 查找中...';
  static const wifiFindSuccess = 'Wi-Fi 查找成功，正在连接...';
  static const wifiFindFailed = 'Wi-Fi 未查找成功，稍后重试...';
  static const deviceWifiDisabled = '请先开启设备(PAD)的wifi...';
  static const wifiFindUnsupported = '当前平台不支持 Wi-Fi 查找，继续检测 Web 服务...';
  static const wifiResultUnsupported = '当前平台不支持读取 Wi-Fi 结果，继续检测 Web 服务...';

  static const wifiKnownConnecting = '正在连接上次成功的 Wi-Fi...';
  static const wifiConnectSuccess = 'Wi-Fi 连接成功，正在检测 Web 服务...';
  static const wifiConnectRetry = 'Wi-Fi 连接失败，稍后重试...';
  static const wifiConnectAlreadyConnected = '已连接目标 Wi-Fi';
  static const wifiConnectResultSuccess = '目标 Wi-Fi 连接成功';
  static const wifiConnectResultFailed = '目标 Wi-Fi 连接失败';
  static const wifiConnectEmptySsid = '目标 Wi-Fi SSID 为空，无法连接';
  static const wifiConnectMissingPassword = '目标 Wi-Fi 需要密码，请先配置密码';
  static const wifiConnectException = '目标 Wi-Fi 连接异常';
  static const wifiConnectTimeout = '连接上次 Wi-Fi 超时';

  static const fastStartupChecking = '已连接目标 Wi-Fi，正在检测 Web 服务...';

  static const webChecking = '正在检测 Web 服务...';
  static const webUnavailable = 'Web 服务未连接上，稍后重试...';

  static String scanCount(int count) => '$count 个 Wi-Fi';

  static String wifiNotFound(int count, String keyword) {
    return '未找到目标 Wi-Fi "$keyword", 请检查机器人是否开机? 会重新尝试连接...';
  }

  static String wifiConnectionDetail(String message, String? currentSsid) {
    return currentSsid == null ? '暂无' : '$message ($currentSsid)';
  }

  static String wifiConnectFailed(String message) => '$message，稍后重试...';

  static String scanBlock(CanStartScan result) {
    switch (result) {
      case CanStartScan.noLocationPermissionRequired:
        return '需要定位权限才能查找 Wi-Fi，请授权后继续...';
      case CanStartScan.noLocationPermissionDenied:
        return '定位权限已被拒绝，请在系统设置中允许定位权限...';
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        return '需要开启精确定位才能查找 Wi-Fi...';
      case CanStartScan.noLocationServiceDisabled:
        return '需要开启系统定位服务才能查找 Wi-Fi...';
      case CanStartScan.failed:
        return 'Wi-Fi 查找启动失败，稍后重试...';
      case CanStartScan.notSupported:
        return wifiFindUnsupported;
      case CanStartScan.yes:
        return wifiFindSearching;
    }
  }

  static String scanResultsBlock(CanGetScannedResults result) {
    switch (result) {
      case CanGetScannedResults.noLocationPermissionRequired:
        return '需要定位权限才能读取 Wi-Fi 结果，请授权后继续...';
      case CanGetScannedResults.noLocationPermissionDenied:
        return '定位权限已被拒绝，请在系统设置中允许定位权限...';
      case CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
        return '需要开启精确定位才能读取 Wi-Fi 结果...';
      case CanGetScannedResults.noLocationServiceDisabled:
        return '需要开启系统定位服务才能读取 Wi-Fi 结果...';
      case CanGetScannedResults.notSupported:
        return wifiResultUnsupported;
      case CanGetScannedResults.yes:
        return '正在读取 Wi-Fi 结果...';
    }
  }
}
