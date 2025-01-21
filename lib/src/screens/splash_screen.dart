import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'webview.dart';
import 'package:flutter/services.dart';
import 'dart:io';

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
    _startPolling();
    // Timer(const Duration(seconds: 5), () {
    //   Navigator.pushReplacement(
    //     context,
    //     MaterialPageRoute(builder: (context) => const WebViewScreen()),
    //   );
    // });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkAppStatus();
    });
  }

  Future<void> _checkAppStatus() async {
    try {
      final res = await http.get(Uri.parse('http://192.168.22.103:8092'));
      if (res.statusCode == 200) {
        _pollingTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WebViewScreen()),
        );
      }
    } catch (e) {
      print('Error checking app status: $e');
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
              '应用加载中 Application loading ...',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => exit(0),
              child: const Text('退出应用 Exit App'),
            )
          ],
        ),
      ),
    );
  }
}
