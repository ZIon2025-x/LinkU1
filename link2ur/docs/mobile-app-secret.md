# 移动端请求签名（MOBILE_APP_SECRET）

后端对 iOS/Android 请求会校验 **X-App-Signature** 与 **X-App-Timestamp**，用于确认请求来自正式 App。若未带签名，会话仍可验证通过，但会打 WARNING：`移动端验证失败: 缺少签名或时间戳`。

## 约定

- **Header 名称**：`X-App-Signature`、`X-App-Timestamp`（与后端一致）
- **签名算法**：`HMAC-SHA256(message, MOBILE_APP_SECRET)`，hex 输出  
  - `message = session_id + timestamp`（无分隔符，均为字符串）
- **时间戳**：Unix 秒，后端允许 ±5 分钟
- **其他**：请求头中需同时有 `X-Platform`（ios/android）、`User-Agent`（含 Link2Ur-iOS / Link2Ur-Android）、`X-Session-ID`（会话 ID）

以上逻辑已在 `lib/data/services/api_service.dart` 的 `_onRequest` 中实现；`X-Platform` 与 `User-Agent` 来自 `ApiConfig.defaultHeaders`。

## 构建时传入密钥

密钥与后端环境变量 **MOBILE_APP_SECRET** 必须一致，且**不要提交到代码库**。通过 `--dart-define` 在构建/运行时传入。

### 命令行

```bash
# 运行（开发）
flutter run --dart-define=MOBILE_APP_SECRET=你的密钥

# 构建 iOS
flutter build ios --dart-define=MOBILE_APP_SECRET=你的密钥

# 构建 Android
flutter build apk --dart-define=MOBILE_APP_SECRET=你的密钥
```

### Xcode（iOS 正式/TestFlight）

1. 在 Xcode 中打开 `ios/Runner.xcworkspace`
2. 选中 Runner → Edit Scheme → Run → Arguments
3. 在 **Arguments Passed On Launch** 中添加：  
   `--dart-define=MOBILE_APP_SECRET=你的密钥`  
   （注意与后端 Railway 等环境中的 `MOBILE_APP_SECRET` 一致）
4. Archive / 运行时会带上该 define，App 即可发送签名与时间戳

### Android

- 本地/CI 构建时在 `flutter build apk` 或 `flutter build appbundle` 后追加：  
  `--dart-define=MOBILE_APP_SECRET=你的密钥`
- CI 中请从 secrets 读取密钥，不要写死在脚本里

## 未配置时行为

- `MOBILE_APP_SECRET` 未传入时，`AppConfig.mobileAppSecret` 为空，客户端**不会**发送 `X-App-Signature`、`X-App-Timestamp`。
- 后端仍按会话校验请求，但会打 WARNING；配置密钥并重新构建后即可消除。
