# Stripe / 密钥配置说明

## 密钥有没有导入？

**没有。** 本 Flutter 项目**不会**从 `.env` 或任何文件自动读取密钥，所有密钥都需要在**运行或构建时**通过 `--dart-define` 传入。

不传时：
- **Stripe 公钥**为空 → 支付（信用卡 / Apple Pay / 支付宝）会报错或显示「加载失败」；
- **MOBILE_APP_SECRET** 为空 → 请求仍可访问后端，但会触发「缺少签名或时间戳」的 WARNING。

---

## 需要配置的密钥

| 密钥 | 用途 | 开发/测试 | 生产 |
|------|------|-----------|------|
| `STRIPE_PUBLISHABLE_KEY_TEST` | Stripe 支付（测试） | 必传 | 不传 |
| `STRIPE_PUBLISHABLE_KEY_LIVE` | Stripe 支付（正式） | 不传 | 必传 |
| `MOBILE_APP_SECRET` | 移动端请求签名（与后端一致） | 可选 | 建议传 |

Stripe 公钥从 [Stripe Dashboard](https://dashboard.stripe.com/apikeys) 获取（Developers → API keys），`pk_test_xxx` 为测试、`pk_live_xxx` 为正式。

---

## 如何「导入」密钥（传入方式）

### 1. 命令行运行

在 `link2ur/` 目录下：

```bash
# 开发运行（测试环境，用测试公钥）
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_你的密钥

# 同时传签名密钥（可选）
flutter run \
  --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx \
  --dart-define=MOBILE_APP_SECRET=你的密钥
```

### 2. 构建

```bash
# iOS 测试
flutter build ios --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx

# iOS 正式
flutter build ios --dart-define=STRIPE_PUBLISHABLE_KEY_LIVE=pk_live_xxx --dart-define=MOBILE_APP_SECRET=xxx

# Android
flutter build apk --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx
```

### 3. VS Code / Cursor 运行配置

在项目根目录创建或修改 `.vscode/launch.json`，在对应配置的 `args` 里加入 dart-define（**勿提交含真实密钥的 launch.json**）：

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (link2ur)",
      "request": "launch",
      "type": "Dart",
      "program": "link2ur/lib/main.dart",
      "cwd": "link2ur",
      "args": [
        "--dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_你的测试公钥",
        "--dart-define=MOBILE_APP_SECRET=你的密钥"
      ]
    }
  ]
}
```

### 4. Xcode（iOS 真机/Archive）

1. 打开 `link2ur/ios/Runner.xcworkspace`
2. 菜单 **Product → Scheme → Edit Scheme…** → 左侧选 **Run** → **Arguments**
3. 在 **Arguments Passed On Launch** 中添加一行：  
   `--dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx`  
   （正式包用 `STRIPE_PUBLISHABLE_KEY_LIVE=pk_live_xxx`，需要签名时再加 `MOBILE_APP_SECRET=xxx`）

---

## 验证是否生效

- 启动 App 后查看控制台：若配置正确，会看到 `Stripe configuration validated successfully for development`；若 Stripe 公钥为空，会看到 `Stripe 配置缺失` 的警告。
- 进入支付页使用信用卡/Apple Pay/支付宝：若仍「加载失败」，多半是未传 Stripe 公钥或传错 key（测试/正式混用）。

---

## 相关文档

- 移动端签名密钥：`link2ur/docs/mobile-app-secret.md`
- 应用环境与 Stripe key 选择逻辑：`link2ur/lib/core/config/app_config.dart`（`stripePublishableKey`、`_validateConfiguration`）
