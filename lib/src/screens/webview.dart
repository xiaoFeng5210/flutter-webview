import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_webview/src/utils/env.dart';
import 'package:flutter_webview/src/utils/webview_help.dart';
import 'package:permission_handler/permission_handler.dart';

// 添加这个检测来验证真实版本
Future<void> verifyRealChromeVersion(InAppWebViewController controller) async {
  final realSupport = await controller.evaluateJavascript(
    source: '''
    (function() {
      // 直接测试语法支持
      let optionalChainingWorks = false;
      let nullishCoalescingWorks = false;
      
      try {
        // 测试可选链
        const obj = { a: { b: 1 } };
        const result = obj?.a?.b;
        optionalChainingWorks = (result === 1);
      } catch(e) {
        console.log('Optional chaining test failed:', e.message);
      }
      
      try {
        // 测试空值合并
        const test1 = null ?? 'default';
        const test2 = undefined ?? 'default';
        const test3 = 0 ?? 'default';
        nullishCoalescingWorks = (test1 === 'default' && test2 === 'default' && test3 === 0);
      } catch(e) {
        console.log('Nullish coalescing test failed:', e.message);
      }
      
      return {
        userAgent: navigator.userAgent,
        optionalChainingWorks: optionalChainingWorks,
        nullishCoalescingWorks: nullishCoalescingWorks,
        chromeVersionFromUA: navigator.userAgent.match(/Chrome\/([0-9]+)/)?.[1],
        // 尝试检测真实的Chrome版本
        realChromeFeatures: {
          es2020: optionalChainingWorks && nullishCoalescingWorks,
          es2019: true, // 假设支持
          es2018: true  // 假设支持
        }
      };
    })()
  ''',
  );

  print('🔍 真实Chrome版本验证:');
  print(realSupport);
  // print('   可选链实际工作: ${realSupport['optionalChainingWorks']}');
  // print('   空值合并实际工作: ${realSupport['nullishCoalescingWorks']}');
  // print('   ES2020支持: ${realSupport['realChromeFeatures']['es2020']}');
}

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
        initialUrlRequest: URLRequest(url: WebUri(getBaseUrl())),
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
        },
        onLoadStart: (controller, url) {
          print('开始加载: $url');
        },
        onLoadStop: (controller, url) async {
          print('加载完成: $url');
          await getBrowserInfo(controller: controller);
        },

        // 添加控制台消息监听
        onConsoleMessage: (controller, consoleMessage) {
          print(
            'Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}',
          );

          // 如果是错误级别的消息，可以进行特殊处理
          if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
            print('❌ JavaScript Error detected: ${consoleMessage.message}');
          }
        },
        // 添加页面加载错误监听
        onReceivedError: (controller, request, error) {
          print('❌ Page load error: ${error.description}');
        },
        // 添加HTTP错误监听
        onReceivedHttpError: (controller, request, errorResponse) {
          print(
            '❌ HTTP Error: ${errorResponse.statusCode} - ${errorResponse.reasonPhrase}',
          );
        },

        // onPermissionRequest: (controller, request) async {
        //   // 自动授予所有权限请求
        //   return PermissionResponse(
        //     resources: request.resources,
        //     action: PermissionResponseAction.GRANT,
        //   );
        // },
        onPermissionRequest:
            (
              InAppWebViewController controller,
              PermissionRequest permissionRequest,
            ) async {
              print('🔐 收到权限请求:');
              print('   来源: ${permissionRequest.origin}');
              print('   请求资源: ${permissionRequest.resources}');

              // 检查是否包含音频相关权限
              bool hasAudioPermission = permissionRequest.resources.any(
                (resource) =>
                    resource == PermissionResourceType.MICROPHONE ||
                    resource == PermissionResourceType.AUTOPLAY,
              );
              if (hasAudioPermission) {
                print('🎤 检测到音频权限请求，正在处理...');

                // 检查当前权限状态
                PermissionStatus currentStatus =
                    await Permission.microphone.status;
                print('🎤 当前麦克风权限状态: $currentStatus');

                // 如果权限被永久拒绝，引导用户到设置
                if (currentStatus.isPermanentlyDenied) {
                  print('❌ 权限被永久拒绝，需要手动开启');
                  // 可以显示对话框引导用户到设置
                  return PermissionResponse(
                    resources: permissionRequest.resources,
                    action: PermissionResponseAction.DENY,
                  );
                }

                // 如果权限未授予，请求权限
                if (!currentStatus.isGranted) {
                  print('🎤 正在请求麦克风权限...');
                  final PermissionStatus newStatus = await Permission.microphone
                      .request();
                  print('🎤 权限请求结果: $newStatus');

                  if (newStatus.isGranted) {
                    print('✅ 麦克风权限已授予');
                    return PermissionResponse(
                      resources: permissionRequest.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  } else {
                    print('❌ 麦克风权限被拒绝');
                    return PermissionResponse(
                      resources: permissionRequest.resources,
                      action: PermissionResponseAction.DENY,
                    );
                  }
                } else {
                  print('✅ 麦克风权限已存在，直接授予');
                  return PermissionResponse(
                    resources: permissionRequest.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                }
              }

              // 对于其他权限，默认授予（如地理位置、通知等）
              print('✅ 授予所有权限');
              return PermissionResponse(
                resources: permissionRequest.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
      ),
    );
  }
}
