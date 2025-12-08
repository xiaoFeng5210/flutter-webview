import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'webview.dart';
import 'dart:io';
import '../utils/url_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _pollingTimer;
  String _currentUrl = '';
  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await UrlConfig.getUrl();
    if (mounted) {
      setState(() {
        _currentUrl = url;
      });
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _checkAppStatus();
  }

  Future<void> _checkAppStatus() async {
    if (!mounted) return;
    try {
      await _loadCurrentUrl();
      await Future.delayed(const Duration(seconds: 2));
      final res = await http.get(Uri.parse(_currentUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _pollingTimer?.cancel();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WebViewScreen()),
          );
        }
        return;
      }
    } catch (e) {
      print('===========Error checking app status: $e===========');
    }
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _checkAppStatus();
    }
  }

  Future<void> _showUrlSettingsDialog() async {
    final TextEditingController urlController = TextEditingController(text: _currentUrl);
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                        final newUrl = urlController.text.trim();
                        if (newUrl.isNotEmpty) {
                          final success = await UrlConfig.saveUrl(newUrl);
                          if (mounted) {
                            Navigator.of(context).pop();
                            if (success) {
                              setState(() {
                                _currentUrl = newUrl;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('URL 保存成功', style: TextStyle(fontSize: 26)),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('URL 保存失败, 请检查URL是否正确, 是否包含端口8092', style: TextStyle(fontSize: 26)),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
          content: Text(success ? 'URL 已重置为默认值' : '重置失败', style: const TextStyle(fontSize: 26)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    side: const BorderSide(color: Colors.green, width: 2),
                  ),
                  child: const Text('设置 WebView URL', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _resetUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                  const Text(
                    '网络连接中 Network connection ...',
                    style: TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 24),
                  if (_currentUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '当前 URL: $_currentUrl',
                        style: const TextStyle(fontSize: 22, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => exit(0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      side: const BorderSide(color: Colors.red, width: 2),
                    ),
                    child: const Text('退出 Exit', style: TextStyle(fontSize: 24)),
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
