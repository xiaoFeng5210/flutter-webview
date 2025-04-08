# 生产环境构建apk
flutter build apk --release --dart-define=ENV=prod

# 2. 安装到设备
adb install -r build/app/outputs/flutter-apk/app-release.apk

# 先强制停止应用
adb shell am force-stop com.example.flutter_webview

# 然后启动应用的主 Activity
adb shell am start -n com.example.flutter_webview/com.example.flutter_webview.MainActivity
