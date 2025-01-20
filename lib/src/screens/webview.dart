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
  }

  @override
  void dispose() {
    super.dispose();
    pollingTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(getBaseUrl()),
        ),
        initialSettings: getWebViewSettings(),
        onWebViewCreated: (controller) async {
          webViewController = controller;
        },
        onLoadStart: (controller, url) {
          print('开始加载: $url');
        },
        onLoadStop: (controller, url) async {
          print('加载完成: $url');
          await getBrowserInfo(controller: controller);
        },
      ),
    );
  }
}
