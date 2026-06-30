import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_scan/wifi_scan.dart';

import '../utils/url_config.dart';
import 'webview.dart';

const String _targetWifiSsidKeyword = 'lebai';
const Duration _wifiScanInterval = Duration(seconds: 5);
const Duration _wifiScanResultDelay = Duration(seconds: 2);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _currentUrl = '';
  String _startupMessage = '正在准备启动流程...';
  String? _matchedWifiInfo;
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
    // FIXME: 等待目标 Wi-Fi 准备好
    final isWifiReady = await _waitForTargetWifi();
    if (!mounted || !isWifiReady) return;
    await _checkAppStatus();
  }

  Future<bool> _waitForTargetWifi() async {
    while (mounted) {
      try {
        _setStartupMessage('正在扫描目标 Wi-Fi...');

        final canStartScan = await WiFiScan.instance.canStartScan(
          askPermissions: true,
        );
        if (canStartScan == CanStartScan.notSupported) {
          _setStartupMessage('当前平台不支持 Wi-Fi 扫描，继续检测 Web 服务...');
          return true;
        }
        if (canStartScan != CanStartScan.yes) {
          _setStartupMessage(_scanBlockMessage(canStartScan));
          await Future.delayed(_wifiScanInterval);
          continue;
        }

        final scanStarted = await WiFiScan.instance.startScan();
        if (mounted) {
          _setStartupMessage(
            scanStarted ? 'Wi-Fi 寻找中...' : 'Wi-Fi 触发失败，读取最近扫描结果...',
          );
        }
        await Future.delayed(_wifiScanResultDelay);

        final canGetResults = await WiFiScan.instance.canGetScannedResults(
          askPermissions: true,
        );
        if (canGetResults == CanGetScannedResults.notSupported) {
          _setStartupMessage('当前平台不支持读取 Wi-Fi 扫描结果，继续检测 Web 服务...');
          return true;
        }
        if (canGetResults != CanGetScannedResults.yes) {
          _setStartupMessage(_scanResultsBlockMessage(canGetResults));
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
              _startupMessage = '已找到目标 Wi-Fi，正在检测 Web 服务...';
            });
          }
          return true;
        }

        _setStartupMessage(
          '扫描到 ${accessPoints.length} 个 Wi-Fi，未找到包含 "$_targetWifiSsidKeyword" 的 SSID，稍后重试...',
        );
      } catch (e) {
        debugPrint('===========Error scanning wifi: $e===========');
        _setStartupMessage('Wi-Fi 扫描失败，稍后重试...');
      }

      await Future.delayed(_wifiScanInterval);
    }
    return false;
  }

  WiFiAccessPoint? _findTargetAccessPoint(List<WiFiAccessPoint> accessPoints) {
    accessPoints.forEach((wifi) {
      print('===========wifi名称: ${wifi.ssid}===========');
    });
    final keyword = _targetWifiSsidKeyword.trim().toLowerCase();
    final matches = accessPoints.where((accessPoint) {
      final ssid = accessPoint.ssid.trim();
      if (ssid.isEmpty) return false;
      if (keyword.isEmpty) return true;
      return ssid.toLowerCase().contains(keyword);
    }).toList()..sort((a, b) => b.level.compareTo(a.level));

    return matches.isEmpty ? null : matches.first;
  }

  String _scanBlockMessage(CanStartScan result) {
    switch (result) {
      case CanStartScan.noLocationPermissionRequired:
        return '需要定位权限才能扫描 Wi-Fi，请授权后继续...';
      case CanStartScan.noLocationPermissionDenied:
        return '定位权限已被拒绝，请在系统设置中允许定位权限...';
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        return '需要开启精确定位才能扫描 Wi-Fi...';
      case CanStartScan.noLocationServiceDisabled:
        return '需要开启系统定位服务才能扫描 Wi-Fi...';
      case CanStartScan.failed:
        return 'Wi-Fi 扫描启动失败，稍后重试...';
      case CanStartScan.notSupported:
        return '当前平台不支持 Wi-Fi 扫描...';
      case CanStartScan.yes:
        return 'Wi-Fi 扫描中...';
    }
  }

  String _scanResultsBlockMessage(CanGetScannedResults result) {
    switch (result) {
      case CanGetScannedResults.noLocationPermissionRequired:
        return '需要定位权限才能读取 Wi-Fi 扫描结果，请授权后继续...';
      case CanGetScannedResults.noLocationPermissionDenied:
        return '定位权限已被拒绝，请在系统设置中允许定位权限...';
      case CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
        return '需要开启精确定位才能读取 Wi-Fi 扫描结果...';
      case CanGetScannedResults.noLocationServiceDisabled:
        return '需要开启系统定位服务才能读取 Wi-Fi 扫描结果...';
      case CanGetScannedResults.notSupported:
        return '当前平台不支持读取 Wi-Fi 扫描结果...';
      case CanGetScannedResults.yes:
        return '正在读取 Wi-Fi 扫描结果...';
    }
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
      _setStartupMessage('正在检测 Web 服务...');
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
    _setStartupMessage('Web 服务暂不可用，稍后重试...');
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
                    '目标 Wi-Fi: $_targetWifiSsidKeyword',
                    style: const TextStyle(fontSize: 24, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  if (_lastWifiScanCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '最近扫描: $_lastWifiScanCount 个 Wi-Fi',
                      style: const TextStyle(fontSize: 22, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_matchedWifiInfo != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '匹配 Wi-Fi: $_matchedWifiInfo',
                      style: const TextStyle(fontSize: 22, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_currentUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '当前 URL: $_currentUrl',
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
