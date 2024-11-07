import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebViewExample extends StatefulWidget {
  const WebViewExample({super.key});

  @override
  State<WebViewExample> createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    // 添加这段代码来设置平台实现
    if (WebViewPlatform.instance == null) {
      if (identical(0, 0.0)) {
        WebViewPlatform.instance = WebKitWebViewPlatform();
      } else {
        WebViewPlatform.instance = AndroidWebViewPlatform();
      }
    }

    // 添加这段平台初始化代码
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          print('onPageStarted: $url');
        },
        onPageFinished: (String url) {
          print('onPageFinished: $url');
        },
        onWebResourceError: (WebResourceError error) {
          print('onWebResourceError: ${error.description}');
        },
      ))
      ..loadRequest(Uri.parse('http://localhost:5173/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebViewWidget(controller: controller),
    );
  }
}
