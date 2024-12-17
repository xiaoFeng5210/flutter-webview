#!/bin/bash

# 清理旧的构建文件
flutter clean

# 获取依赖
flutter pub get

# 打包 release 版本
flutter build apk --release

# 移动 APK 到指定目录
mkdir -p builds
cp build/app/outputs/flutter-apk/app-release.apk builds/myapp_$(date +%Y%m%d).apk
