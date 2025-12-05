import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'webview.dart';
import 'dart:io';
import '../utils/env.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (currentEnv == Environment.dev) {
      // 3秒后跳转到webview
      _startPolling();
    } else {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _checkAppStatus();
  }

  Future<void> _checkAppStatus() async {
    try {
      final res = await http.get(Uri.parse('http://192.168.22.103:8092')).timeout(const Duration(seconds: 8));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 这里可以放置你的应用 Logo
            // FlutterLogo(size: 100),
            const SizedBox(height: 24),
            // 可以添加一个加载指示器
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              '网络连接中 Network connection ...',
              style: TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => exit(0),
              child: const Text('退出 Exit', style: TextStyle(fontSize: 36),),
            ),
          ],
        ),
      ),
    );
  }
}
