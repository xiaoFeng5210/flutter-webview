import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_scan/wifi_scan.dart';

import '../utils/startup_messages.dart';
import '../utils/url_config.dart';
import '../utils/wifi_connect_helper.dart';
import 'webview.dart';

const String _targetWifiSsidKeyword = 'Guest';
const Duration _wifiScanInterval = Duration(seconds: 5);
const Duration _wifiScanResultDelay = Duration(seconds: 2);
const Duration _wifiScanRetryDelay = Duration(seconds: 10);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _currentUrl = '';
  String _startupMessage = StartupMessages.preparing;
  String? _matchedWifiInfo;
  String? _wifiConnectionInfo;
  WiFiAccessPoint? _matchedWifiPoint;
  int _lastWifiScanCount = 0;

  @override
  void initState() {
    super.initState();
    _startStartupFlow();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await UrlConfig.getUrl();
    if (mounted) {
      setState(() {
        _currentUrl = url;
      });
    }
  }

  void _startStartupFlow() {
    _runStartupFlow();
  }

  Future<void> _runStartupFlow() async {
    await _loadCurrentUrl();
    final isWifiFound = await _waitForTargetWifi();
    if (!mounted || !isWifiFound) return;

    if (_matchedWifiPoint != null) {
      final isWifiConnected = await _waitForWifiConnection();
      if (!mounted || !isWifiConnected) return;
    }

    await _checkAppStatus();
  }

  Future<bool> _waitForTargetWifi() async {
    while (mounted) {
      try {
        _setStartupMessage(StartupMessages.wifiFindScanning);

        final canStartScan = await WiFiScan.instance.canStartScan(
          askPermissions: true,
        );
        if (canStartScan == CanStartScan.notSupported) {
          _setStartupMessage(StartupMessages.wifiFindUnsupported);
          return true;
        }
        if (canStartScan != CanStartScan.yes) {
          _setStartupMessage(StartupMessages.scanBlock(canStartScan));
          await Future.delayed(_wifiScanInterval);
          continue;
        }

        final scanStarted = await WiFiScan.instance.startScan();
        if (mounted) {
          _setStartupMessage(
            scanStarted
                ? StartupMessages.wifiFindSearching
                : StartupMessages.wifiFindOpenDeviceWifi,
          );

          // TODO: 如果扫描失败，则继续扫描
          if (!scanStarted) {
            await Future.delayed(_wifiScanRetryDelay);
            continue;
          }
        }
        await Future.delayed(_wifiScanResultDelay);

        final canGetResults = await WiFiScan.instance.canGetScannedResults(
          askPermissions: true,
        );
        if (canGetResults == CanGetScannedResults.notSupported) {
          _setStartupMessage(StartupMessages.wifiResultUnsupported);
          return true;
        }
        if (canGetResults != CanGetScannedResults.yes) {
          _setStartupMessage(StartupMessages.scanResultsBlock(canGetResults));
          await Future.delayed(_wifiScanInterval);
          continue;
        }

        final accessPoints = await WiFiScan.instance.getScannedResults();
        final matchedAccessPoint = _findTargetAccessPoint(accessPoints);
        if (mounted) {
          setState(() {
            _lastWifiScanCount = accessPoints.length;
          });
        }

        if (matchedAccessPoint != null) {
          final ssid = matchedAccessPoint.ssid.trim();
          if (mounted) {
            setState(() {
              _matchedWifiInfo = '$ssid (${matchedAccessPoint.level} dBm)';
              _startupMessage = StartupMessages.wifiFindSuccess;
            });
          }
          _matchedWifiPoint = matchedAccessPoint;
          return true;
        }

        _setStartupMessage(
          StartupMessages.wifiNotFound(
            accessPoints.length,
            _targetWifiSsidKeyword,
          ),
        );
      } catch (e) {
        debugPrint('===========Error scanning wifi: $e===========');
        _setStartupMessage(StartupMessages.wifiFindFailed);
      }

      await Future.delayed(_wifiScanInterval);
    }
    return false;
  }

  WiFiAccessPoint? _findTargetAccessPoint(List<WiFiAccessPoint> accessPoints) {
    final keyword = _targetWifiSsidKeyword.trim().toLowerCase();
    final matches = accessPoints.where((accessPoint) {
      final ssid = accessPoint.ssid.trim();
      if (ssid.isEmpty) return false;
      if (keyword.isEmpty) return true;
      return ssid.toLowerCase().contains(keyword);
    }).toList()..sort((a, b) => b.level.compareTo(a.level));

    return matches.isEmpty ? null : matches.first;
  }

  Future<bool> _connectMatchedWifi() async {
    final accessPoint = _matchedWifiPoint;
    if (accessPoint == null) return false;

    final result = await connectToScannedAccessPoint(
      accessPoint,
      options: targetWifiConnectionOptions,
    );

    if (!mounted) return false;
    setState(() {
      _wifiConnectionInfo = StartupMessages.wifiConnectionDetail(
        result.message,
        result.currentSsid,
      );
      _startupMessage = result.success
          ? StartupMessages.wifiConnectSuccess
          : StartupMessages.wifiConnectFailed(result.message);
    });
    return result.success;
  }

  Future<bool> _waitForWifiConnection() async {
    while (mounted) {
      final connected = await _connectMatchedWifi();
      if (connected) return true;
      await Future.delayed(_wifiScanInterval);
    }
    return false;
  }

  void _setStartupMessage(String message) {
    if (!mounted) return;
    setState(() {
      _startupMessage = message;
    });
  }

  Future<void> _checkAppStatus() async {
    if (!mounted) return;
    try {
      await _loadCurrentUrl();
      _setStartupMessage(StartupMessages.webChecking);
      await Future.delayed(const Duration(seconds: 2));
      final res = await http
          .get(Uri.parse(_currentUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WebViewScreen()),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('===========Error checking app status: $e===========');
    }
    _setStartupMessage(StartupMessages.webUnavailable);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _checkAppStatus();
    }
  }

  Future<void> _showUrlSettingsDialog() async {
    final TextEditingController urlController = TextEditingController(
      text: _currentUrl,
    );
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(32),
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '设置 WebView URL',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL 地址',
                    labelStyle: TextStyle(fontSize: 24),
                    hintText: '例如: http://192.168.22.103:8092',
                    hintStyle: TextStyle(fontSize: 22),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                  ),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('返回', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final newUrl = urlController.text.trim();
                        if (newUrl.isNotEmpty) {
                          final success = await UrlConfig.saveUrl(newUrl);
                          if (mounted) {
                            navigator.pop();
                            if (success) {
                              setState(() {
                                _currentUrl = newUrl;
                              });
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'URL 保存成功',
                                    style: TextStyle(fontSize: 26),
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'URL 保存失败, 请检查URL是否正确, 是否包含端口8092',
                                    style: TextStyle(fontSize: 26),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('保存', style: TextStyle(fontSize: 24)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resetUrl() async {
    const defaultUrl = 'http://192.168.22.103:8092';
    final success = await UrlConfig.saveUrl(defaultUrl);
    if (mounted) {
      setState(() {
        _currentUrl = defaultUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'URL 已重置为默认值' : '重置失败',
            style: const TextStyle(fontSize: 26),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 顶部按钮区域
          Padding(
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _showUrlSettingsDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    side: const BorderSide(color: Colors.green, width: 2),
                  ),
                  child: const Text(
                    '设置 WebView URL',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _resetUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    side: const BorderSide(color: Colors.orange, width: 2),
                  ),
                  child: const Text('重置 URL', style: TextStyle(fontSize: 24)),
                ),
              ],
            ),
          ),
          // 主要内容区域
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    _startupMessage,
                    style: const TextStyle(fontSize: 36),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${StartupMessages.targetWifiLabel}: $_targetWifiSsidKeyword',
                    style: const TextStyle(fontSize: 24, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  if (_lastWifiScanCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${StartupMessages.latestScanLabel}: ${StartupMessages.scanCount(_lastWifiScanCount)}',
                      style: const TextStyle(fontSize: 22, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_matchedWifiInfo != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${StartupMessages.matchedWifiLabel}: $_matchedWifiInfo',
                      style: const TextStyle(fontSize: 22, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_wifiConnectionInfo != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${StartupMessages.wifiConnectionLabel}: $_wifiConnectionInfo',
                      style: const TextStyle(fontSize: 22, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_currentUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '${StartupMessages.currentUrlLabel}: $_currentUrl',
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => exit(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      side: const BorderSide(color: Colors.red, width: 2),
                    ),
                    child: const Text(
                      '退出 Exit',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
