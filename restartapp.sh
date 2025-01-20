# 先强制停止应用
adb shell am force-stop com.example.flutter_webview

# 然后启动应用的主 Activity
adb shell am start -n com.example.flutter_webview/com.example.flutter_webview.MainActivity
