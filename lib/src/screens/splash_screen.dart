import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_iot/wifi_iot.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../utils/startup_messages.dart';
import '../utils/url_config.dart';
import '../utils/wifi_config.dart';
import '../utils/wifi_connect_helper.dart';
import 'webview.dart';

const Duration _wifiScanInterval = Duration(seconds: 8);
const Duration _wifiScanResultDelay = Duration(seconds: 2);
const Duration _wifiScanRetryDelay = Duration(seconds: 3);
const Color _primaryActionColor = Color(0xFF1F7A55);
const Color _secondaryActionColor = Colors.blueAccent;
const Color _dangerActionColor = Color(0xFFC0392B);
const Color _mutedTextColor = Color(0xFF667085);
const Color _lineColor = Color(0xFFE4E7EC);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _currentUrl = '';
  String _targetWifiSsid = WifiConfig.defaultSsid;
  String _startupMessage = StartupMessages.preparing;
  String? _wifiConnectionInfo;
  WiFiAccessPoint? _matchedWifiPoint;
  int _startupFlowId = 0;

  CanStartScan? _canStartScan;

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

  Future<void> _loadTargetWifiSsid() async {
    final ssid = await WifiConfig.getTargetSsid();
    if (mounted) {
      setState(() {
        _targetWifiSsid = ssid;
      });
    }
  }

  void _startStartupFlow() {
    final flowId = ++_startupFlowId;
    _runStartupFlow(flowId);
  }

  bool _isActiveStartupFlow(int flowId) {
    return mounted && flowId == _startupFlowId;
  }

  Future<void> _runStartupFlow(int flowId) async {
    await _loadTargetWifiSsid();
    await _loadCurrentUrl();
    if (!_isActiveStartupFlow(flowId)) return;

    final isWifiFound = await _waitForTargetWifi(flowId);
    if (!_isActiveStartupFlow(flowId) || !isWifiFound) return;

    if (_matchedWifiPoint != null) {
      final isWifiConnected = await _waitForWifiConnection(flowId);
      if (!_isActiveStartupFlow(flowId) || !isWifiConnected) return;
    }

    await _checkAppStatus(flowId);
  }

  Future<bool> _waitForTargetWifi(int flowId) async {
    while (_isActiveStartupFlow(flowId)) {
      try {
        final isDeviceWifiEnabled = await WiFiForIoTPlugin.isEnabled();
        debugPrint('===========isDeviceWifiEnabled: $isDeviceWifiEnabled============');
        if (!_isActiveStartupFlow(flowId)) return false;
        if (!isDeviceWifiEnabled) {
          _setStartupMessage(
            StartupMessages.deviceWifiDisabled,
            flowId: flowId,
          );
          _showTopErrorSnackBar(StartupMessages.deviceWifiDisabled);
          await Future.delayed(const Duration(seconds: 4));
          continue;
        }

        _setStartupMessage(StartupMessages.wifiFindScanning, flowId: flowId);

        _canStartScan = await WiFiScan.instance.canStartScan(
          askPermissions: true,
        );
        if (!_isActiveStartupFlow(flowId)) return false;
        if (_canStartScan == CanStartScan.notSupported) {
          _setStartupMessage(
            StartupMessages.wifiFindUnsupported,
            flowId: flowId,
          );
          return true;
        }
        if (_canStartScan != CanStartScan.yes) {
          _setStartupMessage(
            StartupMessages.scanBlock(_canStartScan!),
            flowId: flowId,
          );
          await Future.delayed(_wifiScanInterval);
          continue;
        }

        final scanStarted = await WiFiScan.instance.startScan();
        if (_isActiveStartupFlow(flowId)) {
          _setStartupMessage(
            StartupMessages.wifiFindSearching,
            flowId: flowId,
          );
          if (!scanStarted) {
            await Future.delayed(_wifiScanRetryDelay);
            continue;
          }
        }
        await Future.delayed(_wifiScanResultDelay);
        if (!_isActiveStartupFlow(flowId)) return false;

        final canGetResults = await WiFiScan.instance.canGetScannedResults(
          askPermissions: true,
        );
        if (!_isActiveStartupFlow(flowId)) return false;
        if (canGetResults == CanGetScannedResults.notSupported) {
          _setStartupMessage(
            StartupMessages.wifiResultUnsupported,
            flowId: flowId,
          );
          return true;
        }
        if (canGetResults != CanGetScannedResults.yes) {
          _setStartupMessage(
            StartupMessages.scanResultsBlock(canGetResults),
            flowId: flowId,
          );
          await Future.delayed(_wifiScanInterval);
          continue;
        }

        final accessPoints = await WiFiScan.instance.getScannedResults();
        if (!_isActiveStartupFlow(flowId)) return false;
        final matchedAccessPoint = _findTargetAccessPoint(accessPoints);

        if (matchedAccessPoint != null) {
          if (_isActiveStartupFlow(flowId)) {
            setState(() {
              _startupMessage = StartupMessages.wifiFindSuccess;
            });
          }
          _matchedWifiPoint = matchedAccessPoint;
          return true;
        }

        _setStartupMessage(
          StartupMessages.wifiNotFound(accessPoints.length, _targetWifiSsid),
          flowId: flowId,
        );
      } catch (e) {
        debugPrint('===========Error scanning wifi: $e===========');
        _setStartupMessage(StartupMessages.wifiFindFailed, flowId: flowId);
      }

      await Future.delayed(_wifiScanInterval);
    }
    return false;
  }

  WiFiAccessPoint? _findTargetAccessPoint(List<WiFiAccessPoint> accessPoints) {
    final keyword = _targetWifiSsid.trim().toLowerCase();
    final matches = accessPoints.where((accessPoint) {
      final ssid = accessPoint.ssid.trim();
      if (ssid.isEmpty) return false;
      if (keyword.isEmpty) return true;
      return ssid.toLowerCase().contains(keyword);
    }).toList()..sort((a, b) => b.level.compareTo(a.level));

    return matches.isEmpty ? null : matches.first;
  }

  Future<bool> _connectMatchedWifi(int flowId) async {
    final accessPoint = _matchedWifiPoint;
    if (accessPoint == null) return false;

    final result = await connectToScannedAccessPoint(
      accessPoint,
      options: targetWifiConnectionOptions,
    );

    if (!_isActiveStartupFlow(flowId)) return false;
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

  Future<bool> _waitForWifiConnection(int flowId) async {
    while (_isActiveStartupFlow(flowId)) {
      final connected = await _connectMatchedWifi(flowId);
      if (connected) return true;
      await Future.delayed(_wifiScanInterval);
    }
    return false;
  }

  void _setStartupMessage(String message, {int? flowId}) {
    if (!mounted || (flowId != null && flowId != _startupFlowId)) return;
    setState(() {
      _startupMessage = message;
    });
  }

  void _showTopErrorSnackBar(String message) {
    if (!mounted) return;
    final bottomMargin = MediaQuery.sizeOf(context).height - 132;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 32)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 48,
          right: 48,
          bottom: bottomMargin > 0 ? bottomMargin : 0,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _checkAppStatus(int flowId) async {
    if (!_isActiveStartupFlow(flowId)) return;
    final navigator = Navigator.of(context);
    try {
      await _loadCurrentUrl();
      if (!_isActiveStartupFlow(flowId)) return;
      _setStartupMessage(StartupMessages.webChecking, flowId: flowId);
      await Future.delayed(const Duration(seconds: 2));
      if (!_isActiveStartupFlow(flowId)) return;
      final res = await http
          .get(Uri.parse(_currentUrl))
          .timeout(const Duration(seconds: 8));
      if (!_isActiveStartupFlow(flowId)) return;
      if (res.statusCode == 200) {
        if (_isActiveStartupFlow(flowId) && navigator.mounted) {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const WebViewScreen()),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('===========Error checking app status: $e===========');
    }
    _setStartupMessage(StartupMessages.webUnavailable, flowId: flowId);
    await Future.delayed(const Duration(seconds: 3));
    if (_isActiveStartupFlow(flowId)) {
      await _checkAppStatus(flowId);
    }
  }

  Future<void> _showWifiSettingsDialog() async {
    final TextEditingController wifiController = TextEditingController(
      text: _targetWifiSsid,
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
                  '设置目标 Wi-Fi',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: wifiController,
                  decoration: const InputDecoration(
                    labelText: 'Wi-Fi 名称',
                    labelStyle: TextStyle(fontSize: 24),
                    hintText: '例如: Staff',
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
                        final newSsid = wifiController.text.trim();
                        if (newSsid.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Wi-Fi 名称不能为空',
                                style: TextStyle(fontSize: 26),
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        final success = await WifiConfig.saveTargetSsid(
                          newSsid,
                        );
                        if (mounted) {
                          navigator.pop();
                          if (success) {
                            setState(() {
                              _targetWifiSsid = newSsid;
                              _matchedWifiPoint = null;
                              _wifiConnectionInfo = null;
                              _startupMessage = StartupMessages.preparing;
                            });
                            _startStartupFlow();
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                success ? '目标 Wi-Fi 保存成功' : '目标 Wi-Fi 保存失败',
                                style: const TextStyle(fontSize: 26),
                              ),
                              backgroundColor: success
                                  ? Colors.green
                                  : Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
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
                  '设置 Web URL',
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
            success ? 'Web URL 已重置为默认值' : 'Web URL 重置失败',
            style: const TextStyle(fontSize: 26),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  ButtonStyle _controlButtonStyle({
    Color color = _primaryActionColor,
    double minWidth = 128,
  }) {
    return ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: color,
      minimumSize: Size(minWidth, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      side: BorderSide(color: color.withValues(alpha: 0.72), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildConfigRow({
    required String label,
    required String value,
    required List<Widget> actions,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;
        final title = Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF344054),
          ),
        );
        final valueText = Text(
          value,
          maxLines: isCompact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22, color: _mutedTextColor),
        );

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _lineColor)),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 6),
                    valueText,
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: actions,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 128, child: title),
                    Expanded(child: valueText),
                    const SizedBox(width: 24),
                    Wrap(spacing: 12, runSpacing: 12, children: actions),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildControlPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 680 ? 24.0 : 48.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            40,
            horizontalPadding,
            12,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildConfigRow(
                  label: '目标 Wi-Fi',
                  value: _targetWifiSsid,
                  actions: [
                    ElevatedButton(
                      onPressed: _showWifiSettingsDialog,
                      style: _controlButtonStyle(color: _secondaryActionColor),
                      child: const Text('修改WIFI'),
                    ),
                  ],
                ),
                _buildConfigRow(
                  label: 'Web URL',
                  value: _currentUrl.isEmpty ? '未设置' : _currentUrl,
                  actions: [
                    ElevatedButton(
                      onPressed: _showUrlSettingsDialog,
                      style: _controlButtonStyle(),
                      child: const Text('修改URL'),
                    ),
                    ElevatedButton(
                      onPressed: _resetUrl,
                      style: _controlButtonStyle(
                        color: _mutedTextColor,
                        minWidth: 112,
                      ),
                      child: const Text('重置'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildControlPanel(),
          // * 主要内容区域
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24),
                    child: Text(
                      _startupMessage,
                      style: const TextStyle(fontSize: 36),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Text(
                  //   '${StartupMessages.targetWifiLabel}: $_targetWifiSsid',
                  //   style: const TextStyle(fontSize: 24, color: Colors.grey),
                  //   textAlign: TextAlign.center,
                  // ),
                  ...[
                    const SizedBox(height: 12),
                    Text(
                      '${StartupMessages.wifiConnectionLabel}: $_wifiConnectionInfo',
                      style: const TextStyle(fontSize: 22, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  // if (_currentUrl.isNotEmpty)
                  //   Padding(
                  //     padding: const EdgeInsets.symmetric(horizontal: 24),
                  //     child: Text(
                  //       '${StartupMessages.currentUrlLabel}: $_currentUrl',
                  //       style: const TextStyle(
                  //         fontSize: 22,
                  //         color: Colors.grey,
                  //       ),
                  //       textAlign: TextAlign.center,
                  //     ),
                  //   ),
                  // const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => exit(0),
                    style: _controlButtonStyle(
                      color: _dangerActionColor,
                      minWidth: 160,
                    ),
                    child: const Text('退出'),
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
