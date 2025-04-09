import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';

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
      theme: ThemeData(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      // home: const SplashScreen(),

      home: const Stack(
        children: [
          SplashScreen(),
          // 左上角滑动区域
          // Positioned(
          //   left: 0,
          //   top: 0,
          //   child: GestureDetector(
          //     onPanUpdate: (details) {
          //       // 检测向右滑动
          //       if (details.delta.dx > 10) {
          //         // 可以调整这个值来改变灵敏度
          //         _showExitDialog(context);
          //       }
          //     },
          //     child: Container(
          //       height: 100, // 可以调整触摸区域大小
          //       width: 100,
          //       color: Colors.transparent,
          //       // 调试时可以取消注释下面这行来查看触摸区域
          //       // color: Colors.red.withOpacity(0.1),
          //     ),
          //   ),
          // ),
        ],
      ),
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
