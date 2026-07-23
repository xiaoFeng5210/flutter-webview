import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_webview/src/utils/wifi_connect_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizes Android SSID values', () {
    expect(normalizeWifiSsid('"Robot-WiFi"'), 'Robot-WiFi');
    expect(normalizeWifiSsid(' Robot-WiFi '), 'Robot-WiFi');
    expect(normalizeWifiSsid('<unknown ssid>'), isNull);
  });

  test('compares normalized SSIDs', () {
    expect(isSameWifiSsid('"Robot-WiFi"', 'Robot-WiFi'), isTrue);
    expect(isSameWifiSsid('Robot-WiFi', 'Other-WiFi'), isFalse);
  });

  test('repairs the Android route using the normalized current SSID', () async {
    const channel = MethodChannel('com.example.flutter_webview/network_route');
    MethodCall? receivedCall;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return true;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect(await repairCurrentWifiRoute('"Robot-WiFi"'), isTrue);
    expect(receivedCall?.method, 'repairWifiRoute');
    expect(receivedCall?.arguments, {'ssid': 'Robot-WiFi'});
  });

  test('cancels a pending native Wi-Fi request on Android', () async {
    const channel = MethodChannel('plugin_wifi_connect');
    MethodCall? receivedCall;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return true;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await cancelPendingPluginWifiConnection();
    expect(receivedCall?.method, 'disconnect');
  });
}
