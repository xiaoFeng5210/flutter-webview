import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky, // 沉浸式模式
      // SystemUiMode.manual,
      // overlays: [SystemUiOverlay.bottom],
    );

    return MaterialApp(
      // Providing a restorationScopeId allows the Navigator built by the
      // MaterialApp to restore the navigation stack when a user leaves and
      // returns to the app after it has been killed while running in the
      // background.
      restorationScopeId: 'app',
        

      // Basic app theme configuration
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          // 主色：深蓝灰色 #2D3C59
          primary: const Color(0xFF2D3C59),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE8EBF0), // 浅蓝灰色容器
          onPrimaryContainer: const Color(0xFF1A2535), // 深蓝灰色文字
          
          // 次要色：灰绿色 #94A378
          secondary: const Color(0xFF94A378),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE8EDE0), // 浅灰绿色容器
          onSecondaryContainer: const Color(0xFF5A6B4A), // 深灰绿色文字
          
          // 第三色：金黄色 #E5BA41
          tertiary: const Color(0xFFE5BA41),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFFFF4D6), // 浅金黄色容器
          onTertiaryContainer: const Color(0xFF8B6F26), // 深金黄色文字
          
          // 表面色
          surface: Colors.white,
          onSurface: const Color(0xFF2D3C59),
          surfaceContainerHighest: const Color(0xFFF5F7FA), // 最浅的蓝灰色
          
          // 背景色
          background: Colors.white,
          onBackground: const Color(0xFF2D3C59),
          
          // 错误色：偏红色
          error: const Color(0xFFDC3545),
          onError: Colors.white,
          errorContainer: const Color(0xFFFFE5E8), // 浅红色容器
          onErrorContainer: const Color(0xFF8B1A1F), // 深红色文字
          
          // 其他颜色：橙棕色 #D1855C 可用于强调
          outline: const Color(0xFFD1855C),
          outlineVariant: const Color(0xFFE8D4C8), // 浅橙棕色
          shadow: Colors.black26,
        ),
        // 保持向后兼容
        primaryColor: const Color(0xFF2D3C59),
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE8EBF0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          // 主色：深蓝灰色 #2D3C59（暗色模式下稍微调亮）
          primary: const Color(0xFF4A5C7A),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF1A2535), // 深蓝灰色容器
          onPrimaryContainer: const Color(0xFFB8C5D9), // 浅蓝灰色文字
          
          // 次要色：灰绿色 #94A378（暗色模式下稍微调亮）
          secondary: const Color(0xFFB0C098),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFF5A6B4A), // 深灰绿色容器
          onSecondaryContainer: const Color(0xFFD4E0C8), // 浅灰绿色文字
          
          // 第三色：金黄色 #E5BA41（暗色模式下稍微调亮）
          tertiary: const Color(0xFFFFD966),
          onTertiary: Colors.black87,
          tertiaryContainer: const Color(0xFF8B6F26), // 深金黄色容器
          onTertiaryContainer: const Color(0xFFFFF4D6), // 浅金黄色文字
          
          // 表面色
          surface: const Color(0xFF1A1F2E),
          onSurface: const Color(0xFFE8EBF0),
          surfaceContainerHighest: const Color(0xFF2D3C59),
          
          // 背景色
          background: const Color(0xFF121620),
          onBackground: const Color(0xFFE8EBF0),
          
          // 错误色：偏红色
          error: const Color(0xFFFF6B7A),
          onError: Colors.white,
          errorContainer: const Color(0xFF8B1A1F), // 深红色容器
          onErrorContainer: const Color(0xFFFFE5E8), // 浅红色文字
          
          // 其他
          outline: const Color(0xFFD1855C),
          outlineVariant: const Color(0xFF6B4A3A), // 深橙棕色
          shadow: Colors.black54,
        ),
        scaffoldBackgroundColor: const Color(0xFF121620),
        cardColor: const Color(0xFF1A1F2E),
        dividerColor: const Color(0xFF2D3C59),
      ),
      themeMode: ThemeMode.system,

      // home: const SplashScreen(),
      home: const HomeScreen(),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出确认'),
        content: const Text('是否要退出应用？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
