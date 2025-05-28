import 'package:flutter_inappwebview/flutter_inappwebview.dart';

InAppWebViewSettings getWebViewSettings() {
  return InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: false, // 允许媒体自动播放
    // Android 特定设置
    useHybridComposition: true,
    // iOS 特定设置
    allowsInlineMediaPlayback: true,

    javaScriptEnabled: true, // 启用javascript支持
    domStorageEnabled: true, // 启用DOM存储
    // 允许加载本地内容
    allowFileAccess: true,
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true, // 允许通用的跨域访问
    // 缩放相关设置
    supportZoom: false, // 支持缩放功能
    builtInZoomControls: false, // 启用内置缩放控件
    displayZoomControls: false, // 不显示缩放按钮
    initialScale: 100, // 初始缩放比例 100%
    // 视图相关设置
    // useWideViewPort: true, // 使用宽视图
    loadWithOverviewMode: true, // 自动适应屏幕

    userAgent:
        "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Mobile Safari/537.36",
  );
}

String? _getChromeVersion(String userAgent) {
  // 使用正则表达式匹配 Chrome/版本号
  final RegExp regExp = RegExp(r'Chrome/([0-9]+)');
  final Match? match = regExp.firstMatch(userAgent);

  // 如果匹配到了，返回版本号，否则返回 null
  return match?.group(0);
}

Future<void> getBrowserInfo({
  required InAppWebViewController? controller,
}) async {
  if (controller != null) {
    final userAgent = await controller.evaluateJavascript(
      source: 'navigator.userAgent',
    );
    final chromeVersion = _getChromeVersion(userAgent);
    print('🔍 ==================== 浏览器内核详细信息 ====================');
    print('chromeVersion: $chromeVersion');
  }
}
