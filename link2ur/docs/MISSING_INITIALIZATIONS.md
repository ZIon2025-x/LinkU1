# Flutter 未调用/缺失的初始化检查报告

## 一、关键缺失（影响核心功能）

### 1. WeChatShareManager / QQShareManager — 微信/QQ 分享失败

| 方法 | 状态 | 影响 |
|------|------|------|
| `WeChatShareManager.instance.initialize(appId, universalLink)` | ❌ 未调用 | 分享时 `_isInitialized == false`，会输出 "WeChat SDK not initialized" 并返回 |
| `QQShareManager.instance.initialize(appId, universalLink)` | ❌ 未调用 | 同上 |

**依赖**：需要微信 AppID、QQ AppID、Universal Link，当前 `AppConfig` 中无这些字段。

**建议**：
- 在 `AppConfig` 中新增 `wechatAppId`、`qqAppId`、`wechatUniversalLink`（可用 `--dart-define` 传入）
- 在 `main()` 或首屏加载后、用户可能分享前调用 `initialize`
- 若暂不提供 AppID，可考虑在分享面板隐藏微信/QQ 选项，或显示「暂未配置」提示

---

## 二、中等影响

### 3. OfflineManager — 离线队列未启用

| 方法 | 状态 | 影响 |
|------|------|------|
| `OfflineManager.instance.initialize()` | ❌ 未调用 | 网络恢复时的自动同步逻辑未启动 |
| `OfflineManager.instance.addOperation(...)` | ❌ 无调用方 | 从未有代码向离线队列添加操作 |

**结论**：离线功能尚未接入业务（无调用 `addOperation` 的代码）。若未来接入，需先调用 `initialize()`。

---

### 4. PerformanceMonitor — Debug FPS 未启动

| 方法 | 状态 | 影响 |
|------|------|------|
| `PerformanceMonitor.instance.initialize()` | ❌ 未调用 | `FPSMonitor.instance.start()` 未执行，Debug 模式下 FPS 监控不生效 |

网络请求监控（`recordNetworkRequest`）不依赖 `initialize()`，仍可正常工作。

---

## 三、未使用 / 可选

### 5. SecurityManager
- 项目内无任何引用，`initialize()` 未调用
- 若未来需要加密存储等能力，再接入并初始化

### 6. AnalyticsService
- 项目内无任何引用
- 若需埋点/统计，需先接入并初始化

### 7. AppReviewManager
- 项目内无任何引用
- 若需应用内评分引导，再接入

### 8. TranslationService
- 项目内无任何引用
- `initialize(apiService)` 未调用
- 若需翻译能力，需在 `initialize` 后使用

### 9. AppVersion
- `SettingsView` 直接使用 `PackageInfo.fromPlatform()`，未使用 `AppVersion.instance`
- `AppVersion` 可视为冗余，或后续统一迁移到该类

---

## 四、已正确初始化的服务

- `CrashReporter` — main()
- `NetworkMonitor` — main()
- `StorageService` — main()
- `AppConfig` — main()
- `PaymentService` (Stripe) — main() 中的 `_initStripeIfConfigured`
- `DeepLinkHandler` — app.dart initState
- `PushNotificationService` — app.dart 中 `Link2UrApp.initState`：`setRouter(_appRouter.router)`、`setApiService(_apiService)`、`unawaited(PushNotificationService.instance.init())`（init 依赖 StorageService，需在 main 中 StorageService.init 之后；当前在 app 首帧前执行，StorageService 已在 main 完成初始化）
- `Hive` — main()
- `IAPService` — 懒加载（`ensureInitialized` 在 VIP 购买页首次使用时触发）

---

## 五、建议修复优先级

1. **P1**：`WeChatShareManager` / `QQShareManager` — 分享功能已有 UI，缺少 SDK 初始化
2. **P2**：`OfflineManager` — 仅在业务接入 `addOperation` 后再初始化
3. **P3**：`PerformanceMonitor.initialize` — 仅影响 Debug 体验，可选
