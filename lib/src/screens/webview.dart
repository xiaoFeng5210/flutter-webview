import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';

import 'package:flutter_webview/src/utils/env.dart';
import 'package:flutter_webview/src/utils/webview_help.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  // WebView 控制器
  InAppWebViewController? webViewController;
  Timer? pollingTimer;

  @override
  void initState() {
    super.initState();

    // Timer(const Duration(seconds: 10), () {
    //   webViewController?.evaluateJavascript(
    //       source: 'window.alert("Hello, World!");');
    // });
  }

  @override
  void dispose() {
    super.dispose();
    pollingTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 隐藏标题栏
      // appBar: AppBar(
      //   title: const Text('WebView 示例'),
      // ),
      body: InAppWebView(
        // 初始化时加载的URL
        initialUrlRequest: URLRequest(
          url: WebUri(getBaseUrl()),
        ),
        // 添加 initialSettings 配置
        initialSettings: getWebViewSettings(),
        // WebView 控制器初始化回调
        onWebViewCreated: (controller) async {
          webViewController = controller;
        },
        // 页面开始加载回调
        onLoadStart: (controller, url) {
          print('开始加载: $url');
        },
        // 页面加载完成回调
        onLoadStop: (controller, url) async {
          print('加载完成: $url');
          await getBrowserInfo(controller: controller);
        },
      ),
    );
  }
}
