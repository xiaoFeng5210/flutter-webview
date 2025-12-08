import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'dart:io';

// import 'package:flutter_webview/src/utils/env.dart';
import 'package:flutter_webview/src/utils/webview_help.dart';
import 'package:flutter_webview/src/utils/url_config.dart';

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
        initialUrlRequest: URLRequest(url: WebUri(UrlConfig.webviewUrl)),
        initialSettings: getWebViewSettings(),
        onWebViewCreated: (controller) async {
          webViewController = controller;

          // 添加 JavaScript 处理器
          controller.addJavaScriptHandler(
            handlerName: 'exitFlutterApp', // 这个名字要记住，网页端会用到
            callback: (args) {
              // 显示退出确认对话框
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('退出确认 Confirm Exit'),
                  content: const Text(
                    '确定要退出应用吗 Are you sure you want to exit the app?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消 Cancel'),
                    ),
                    TextButton(
                      onPressed: () => exit(0), // 退出应用
                      child: const Text('确定 Confirm'),
                    ),
                  ],
                ),
              );
            },
          );

          controller.addJavaScriptHandler(
            handlerName: 'setImmersiveMode',
            callback: (args) async {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            },
          );
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
