adb disconnect 192.168.22.104

sleep 2

adb connect 192.168.22.104
adb shell ps | grep lebai | awk '{print $2}' | xargs adb shell kill &
echo "app is kill"
# 先强制停止应用
adb shell am force-stop com.example.flutter_webview

# 然后启动应用的主 Activity
adb shell am start -n com.example.flutter_webview/com.example.flutter_webview.MainActivity

echo "app is started"
