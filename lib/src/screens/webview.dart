import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'dart:io';

// import 'package:flutter_webview/src/utils/env.dart';
import 'package:flutter_webview/src/utils/webview_help.dart';
import 'package:flutter_webview/src/utils/url_config.dart';
import 'package:flutter_webview/src/screens/home.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  // WebView 控制器
  InAppWebViewController? webViewController;
  Timer? pollingTimer;

  Timer? _backgroundTimer;

  @override
  void initState() {
    super.initState();
    _startBackgroundProgram();
  }

  @override
  void dispose() {
    super.dispose();
    _backgroundTimer?.cancel();
    pollingTimer?.cancel();
  }

  Future<void> _startBackgroundProgram() async {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkTimeAndClearApp();
    });
  }

  void _checkTimeAndClearApp() {
    if (!mounted) {
      _backgroundTimer?.cancel();
      return;
    }
    final now = DateTime.now();
    final hour = now.hour;
    try {
      debugPrint('当前小时: $hour');
      // 半夜两点退出应用
      if (hour == 2) {
        exit(0);
      }
    } catch (e) {
      debugPrint('Error starting background program: $e');
    }
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
          
          // 注入修复脚本，修复 fetch 相对路径问题
          // 保留 URL 中的 credentials 用于访问，但修复 fetch 中的相对路径解析
          controller.evaluateJavascript(source: '''
            (function() {
              if (window.fetch && !window._fetchFixed) {
                window._fetchFixed = true;
                const originalFetch = window.fetch;
                
                // 清理 URL 中的 credentials（仅用于 fetch，不影响页面访问）
                function cleanUrlForFetch(url) {
                  try {
                    const urlObj = new URL(url, window.location.href);
                    
                    // 移除 credentials（类似浏览器在 fetch 中的行为）
                    if (urlObj.username || urlObj.password) {
                      urlObj.username = '';
                      urlObj.password = '';
                    }
                    
                    return urlObj.href;
                  } catch (e) {
                    // 如果解析失败，尝试手动清理
                    // 移除 credentials（user:pass@host 格式）
                    try {
                      const atIndex = url.indexOf('@');
                      if (atIndex > 0) {
                        const protocolEnd = url.indexOf('://');
                        if (protocolEnd > 0) {
                          const beforeAt = url.substring(0, atIndex);
                          const afterAt = url.substring(atIndex + 1);
                          // 检查 @ 前面是否有冒号（表示有密码）
                          const colonIndex = beforeAt.lastIndexOf(':');
                          if (colonIndex > protocolEnd + 2) {
                            // 有 credentials，移除它们
                            return url.substring(0, protocolEnd + 3) + afterAt;
                          }
                        }
                      }
                    } catch (e2) {
                      console.warn('Failed to clean URL:', e2);
                    }
                    return url;
                  }
                }
                
                window.fetch = function(input, init) {
                  // 处理字符串类型的 URL
                  if (typeof input === 'string') {
                    // 如果是相对路径（如 ./_nuxt/...）
                    if (input.startsWith('./') || input.startsWith('/_nuxt/') || 
                        (input.startsWith('/') && !input.match(/^https?:/))) {
                      try {
                        // 先解析相对路径为绝对路径
                        const resolvedUrl = new URL(input, window.location.href).href;
                        // 清理 credentials（fetch API 不允许 credentials）
                        input = cleanUrlForFetch(resolvedUrl);
                      } catch (e) {
                        console.warn('Failed to resolve fetch URL:', input, e);
                        // 如果解析失败，尝试手动构建
                        if (input.startsWith('./')) {
                          const basePath = window.location.pathname.substring(0, window.location.pathname.lastIndexOf('/') + 1);
                          let fullUrl = window.location.origin + basePath + input.substring(2);
                          input = cleanUrlForFetch(fullUrl);
                        } else if (input.startsWith('/')) {
                          let fullUrl = window.location.origin + input;
                          input = cleanUrlForFetch(fullUrl);
                        }
                      }
                    } else if (input.match(/^https?:/)) {
                      // 即使是绝对路径，也清理 credentials
                      input = cleanUrlForFetch(input);
                    }
                  } else if (input instanceof Request) {
                    // 如果是 Request 对象
                    const url = input.url;
                    if (url) {
                      const cleanedUrl = cleanUrlForFetch(url);
                      if (cleanedUrl !== url) {
                        // 创建新的 Request 对象
                        input = new Request(cleanedUrl, {
                          method: input.method,
                          headers: input.headers,
                          body: input.body,
                          mode: input.mode,
                          credentials: input.credentials,
                          cache: input.cache,
                          redirect: input.redirect,
                          referrer: input.referrer,
                          integrity: input.integrity,
                        });
                      }
                    }
                  }
                  
                  // 调用原始的 fetch
                  return originalFetch.call(this, input, init);
                };
              }
            })();
          ''');
        },
        onLoadStop: (controller, url) async {
          print('加载完成: $url');
          await getBrowserInfo(controller: controller);
        },
      ),

      // 浮动按钮 - 绝对定位在右下角
      floatingActionButton: FloatingActionButton(onPressed: () {
        Navigator.pushReplacement(context, MaterialPageRoute (builder: (context) => const HomeScreen()));
      }, 
        backgroundColor: const Color(0xFFE5BA41),
        foregroundColor: Colors.white,
        child: const Icon(Icons.home),
      ),
    );
  }
}
