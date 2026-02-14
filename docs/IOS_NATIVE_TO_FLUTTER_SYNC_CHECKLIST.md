# iOS 原生项目 → Flutter 项目 配置/代码同步清单

本文档列出从 **ios/**（原生 Swift 项目）需要复制或对齐到 **link2ur/ios/**（Flutter iOS 平台）的配置与代码。

> **2025-02 更新**：高优先级与中优先级项已通过代码完成；NotificationServiceExtension 源文件已就绪，需在 Xcode 中手动添加 Target（见 `link2ur/ios/NotificationServiceExtension/README.md`）。

---

## 一、已同步（Flutter 已有）

| 项目 | 原生位置 | Flutter 位置 | 说明 |
|------|----------|--------------|------|
| 地图选点 | `ios/link2ur/.../LocationPickerView.swift` | `link2ur/ios/Runner/LocationPickerView.swift` | 已移植，含 LocationService、LocationSearchCompleter |
| URL Scheme | Link-Ur-Info.plist | Runner/Info.plist | `link2ur://` 已配置 |
| LSApplicationQueriesSchemes | Link-Ur-Info.plist | Runner/Info.plist | 微信、QQ 等已配置 |
| 隐私权限描述 | 原生 Info.plist | Runner/Info.plist | 相机、定位、Face ID、相册 |
| Entitlements | Link²Ur.entitlements | Runner/Runner.entitlements | aps-environment、associated-domains、in-app-payments |
| Stripe Connect Onboarding | 原生 Swift | Runner/StripeConnectOnboardingHandler.swift | 已实现，通过 MethodChannel 调用 |
| AppDelegate 扩展 | 原生 | Runner/AppDelegate.swift | 推送、角标、地图选点、Stripe Connect channel |
| UIScene 生命周期 | - | Runner/Info.plist | 已配置 UIApplicationSceneManifest |

---

## 二、已完成（本次同步）

| 项目 | 状态 |
|------|------|
| Stripe Connect 条款 URL | ✅ 已改为 `www.link2ur.com` |
| Apple Pay Merchant ID | ✅ `app_config.dart` 已统一为 `merchant.com.link2ur` |
| CFBundleKeywords | ✅ 已添加到 `Runner/Info.plist` |
| URL Scheme `com.link2ur.app` | ✅ 已添加到 `Runner/Info.plist` |
| NotificationServiceExtension 源文件 | ✅ 已创建于 `link2ur/ios/NotificationServiceExtension/` |

---

## 三、待手动完成

### 1. NotificationServiceExtension — 在 Xcode 中添加 Target

**作用**：根据设备语言显示推送的本地化标题和正文（中/英）。

**已完成**：源文件已创建（`NotificationService.swift`、`PushNotificationLocalizer.swift`、`Info.plist`、`NotificationServiceExtension.entitlements`）。

**待操作**：按 `link2ur/ios/NotificationServiceExtension/README.md` 在 Xcode 中新建 Notification Service Extension target，并关联上述文件。

---

### 2. Xcode Scheme 环境变量（可选）

**原生**（link2ur.xcscheme）：
- `STRIPE_PUBLISHABLE_KEY` = pk_test_xxx
- `APPLE_PAY_MERCHANT_ID` = merchant.com.link2ur

**说明**：Flutter 的 Stripe 密钥主要从 Dart `AppConfig` 传入；若原生插件需要读取环境变量，可在 Runner scheme 中补上。

**操作**：`Product → Scheme → Edit Scheme → Run → Environment Variables` 添加上述变量。

---

### 3. VIPProducts.storekit（IAP 测试，可选）

**作用**：在 Xcode 中用 StoreKit Configuration 测试内购。

**原生**：`ios/link2ur/VIPProducts.storekit`，并在 scheme 中引用。

**操作**：若 Flutter 使用 `in_app_purchase` 且需本地测试 IAP，可将 `VIPProducts.storekit` 复制到 `link2ur/ios/`，并在 Runner scheme 的 Run 中配置 StoreKit Configuration File。

---

### 4. Associated Domains（Universal Links）

**Flutter**：
```xml
<string>applinks:www.link2ur.com</string>
<string>applinks:link2ur.com</string>
```

**原生**：存在重复的 `applinks:www.link2ur.com` 条目。

**操作**：Flutter 当前配置更合理，无需从原生覆盖。确保 `apple-app-site-association` 已在 `www.link2ur.com` 和 `link2ur.com` 正确配置。

---

## 四、不需要同步

| 项目 | 说明 |
|------|------|
| Constants.swift 的 API baseURL | Flutter 使用 Dart 的 `AppConfig.baseUrl` |
| Constants 的 Stripe key | Flutter 通过 `AppConfig.stripePublishableKey` 和 `--dart-define` 传入 |
| 原生业务 View / ViewModel | 业务逻辑在 Flutter 的 Dart 中实现 |
| APIService、APIEndpoints | Flutter 使用 Dio + api_endpoints.dart |

---

## 五、推荐执行顺序

1. ~~**高优先级**：修正 Stripe Connect 的 terms/privacy URL~~ ✅ 已完成
2. ~~**高优先级**：统一 Apple Pay Merchant ID~~ ✅ 已完成
3. **中优先级**：在 Xcode 中添加 NotificationServiceExtension target（源文件已就绪）
4. ~~**中优先级**：在 Info.plist 中添加 CFBundleKeywords~~ ✅ 已完成
5. ~~**低优先级**：URL scheme `com.link2ur.app` 兼容~~ ✅ 已完成
6. **低优先级**：Runner scheme 环境变量、StoreKit 配置

---

## 六、快速对照表

| 配置项 | 原生 | Flutter | 状态 |
|--------|------|---------|------|
| Bundle ID | com.link2ur | com.link2ur | ✅ 一致 |
| URL Scheme | link2ur, com.link2ur.app | link2ur, com.link2ur.app | ✅ 已同步 |
| Stripe pk_test | 已配置 | 已配置 | ✅ 一致 |
| merchant.com | merchant.com.link2ur | merchant.com.link2ur | ✅ 已统一 |
| Terms/Privacy URL | www.link2ur.com | www.link2ur.com | ✅ 已修正 |
| NotificationServiceExtension | 有 | 源文件已创建 | ⏳ 需在 Xcode 添加 target |
| CFBundleKeywords | 有 | 有 | ✅ 已添加 |
| UIScene | - | 有 | ✅ Flutter 已更新 |
