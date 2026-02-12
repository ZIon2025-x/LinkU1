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

# 构建参数：通过 Vercel 环境变量注入 Stripe 密钥
BUILD_ARGS="--release --base-href /"
if [ -n "$STRIPE_PUBLISHABLE_KEY_LIVE" ]; then
  BUILD_ARGS="$BUILD_ARGS --dart-define=STRIPE_PUBLISHABLE_KEY_LIVE=$STRIPE_PUBLISHABLE_KEY_LIVE"
  echo "Stripe live key configured."
fi

flutter build web $BUILD_ARGS

echo "Build complete. Output in build/web"
