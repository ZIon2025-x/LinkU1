#!/bin/bash
set -e

# 安装 Flutter SDK
echo "Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable ~/flutter
export PATH="$HOME/flutter/bin:$PATH"
flutter config --enable-web --no-analytics
flutter doctor -v

# 安装依赖并构建
echo "Building Flutter Web..."
flutter pub get
flutter build web --release

echo "Build complete. Output in build/web"
