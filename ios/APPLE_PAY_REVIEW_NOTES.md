# Apple Pay Review Notes 说明指南

## 📋 问题说明

App Store 审核团队发现应用二进制文件包含 PassKit 框架，但无法验证 Apple Pay 的集成。需要在 Review Notes 中说明 Apple Pay 的位置和使用方式。

## ✅ 解决方案

应用确实使用了 Apple Pay，通过 **Stripe PaymentSheet** 和 **原生 STPApplePayContext** 两种方式集成。

---

## 📝 App Store Connect Review Notes 内容

在 App Store Connect 中，进入应用的 **App Review Information** 部分，在 **Review Notes** 字段中添加以下内容：

```
Apple Pay 集成说明：

我们的应用集成了 Apple Pay 支付功能，具体位置和使用方式如下：

1. 支付页面位置：
   - 用户发布任务后，需要支付平台服务费时，会进入支付页面
   - 支付页面路径：任务详情页 → 支付按钮 → 支付页面
   - 支付页面显示文件：StripePaymentView.swift

2. Apple Pay 显示方式：
   - 在支付页面上方，有一个"支付方式选择"卡片
   - 如果设备支持 Apple Pay，会显示"Apple Pay"选项
   - 用户可以选择"信用卡/借记卡"或"Apple Pay"作为支付方式

3. Apple Pay 按钮：
   - 当用户选择 Apple Pay 后，会显示黑色的"使用 Apple Pay 支付"按钮
   - 按钮上显示 Apple Logo 和"使用 Apple Pay 支付"文字
   - 点击按钮后，会弹出原生的 Apple Pay 支付表单

4. 测试步骤（供审核团队参考）：
   a) 登录应用
   b) 发布一个新任务（或进入已有任务的支付页面）
   c) 在支付页面，查看支付方式选择卡片
   d) 如果设备支持 Apple Pay，会看到"Apple Pay"选项
   e) 选择"Apple Pay"
   f) 点击"使用 Apple Pay 支付"按钮
   g) 会弹出 Apple Pay 支付表单（需要设备已添加支付卡）

5. 技术实现：
   - 使用 Stripe PaymentSheet SDK 集成 Apple Pay
   - 使用 StripeApplePay 和 PassKit 框架
   - 支持原生 Apple Pay 支付流程
   - 支付处理通过 Stripe 完成

6. 注意事项：
   - Apple Pay 选项仅在设备支持时显示
   - 如果设备不支持 Apple Pay 或用户未添加支付卡，只显示信用卡选项
   - 支付需要有效的 Stripe 账户配置

如果审核团队需要测试账号或遇到任何问题，请随时联系我们。
```

---

## 🔍 Apple Pay 在代码中的位置

### 1. 支付页面视图
**文件**：`ios/link2ur/link2ur/Views/Payment/StripePaymentView.swift`

**关键代码位置**：
- 第 496-527 行：Apple Pay 按钮显示逻辑
- 第 619-631 行：Apple Pay 支付方式选择选项

### 2. 支付视图模型
**文件**：`ios/link2ur/link2ur/ViewModels/PaymentViewModel.swift`

**关键代码位置**：
- 第 7-8 行：导入 StripeApplePay 和 PassKit
- 第 18 行：定义 `applePay` 支付方式类型
- 第 501-504 行：检查设备是否支持 Apple Pay
- 第 506-575 行：Apple Pay 支付实现逻辑

### 3. Apple Pay 辅助类
**文件**：`ios/link2ur/link2ur/Utils/ApplePayHelper.swift`

**功能**：
- 检查设备是否支持 Apple Pay
- 创建 Apple Pay 支付请求
- 处理支付摘要项

### 4. 原生 Apple Pay 视图（备用实现）
**文件**：`ios/link2ur/link2ur/Views/Payment/ApplePayNativeView.swift`

**功能**：
- 完全自定义的 Apple Pay 支付界面
- 使用原生 STPApplePayContext 实现

---

## 🎯 用户使用流程

1. **进入支付页面**：
   - 用户发布任务后，需要支付平台服务费
   - 或进入已有任务的支付页面

2. **选择支付方式**：
   - 在支付页面上方看到"支付方式选择"卡片
   - 显示两个选项：
     - 信用卡/借记卡
     - Apple Pay（如果设备支持）

3. **使用 Apple Pay 支付**：
   - 选择"Apple Pay"选项
   - 点击"使用 Apple Pay 支付"按钮
   - 弹出原生 Apple Pay 支付表单
   - 使用 Face ID/Touch ID 确认支付
   - 完成支付

---

## 📱 测试账号信息（如果需要）

如果审核团队需要测试账号，可以在 Review Notes 中添加：

```
测试账号信息：
- 测试邮箱：[提供测试邮箱]
- 测试密码：[提供测试密码]
- 测试任务ID：[提供一个需要支付的任务ID]

注意：测试支付时，请使用 Stripe 测试模式，不会产生实际费用。
```

---

## ⚠️ 重要提示

1. **确保 Merchant ID 已配置**：
   - 在 Xcode 项目设置中，确保已添加 Apple Pay Capability
   - 确保已配置 Merchant ID

2. **确保 Stripe 配置正确**：
   - Stripe Publishable Key 已配置
   - Apple Pay Merchant ID 已配置

3. **测试设备要求**：
   - 测试设备需要支持 Apple Pay
   - 设备需要已添加支付卡（在 Wallet 应用中）

---

## 🔗 相关文档

- Apple Pay 实现指南：`ios/APPLE_PAY_IMPLEMENTATION_GUIDE.md`
- 支付方式选择实现：`ios/PAYMENT_METHOD_SELECTION_IMPLEMENTATION.md`
- Stripe 配置指南：`ios/STRIPE_IOS_PACKAGE_SETUP.md`

---

## 📞 如果审核团队仍有疑问

如果审核团队回复说仍然找不到 Apple Pay 功能，可以：

1. **提供截图**：
   - 支付页面的截图
   - Apple Pay 选项的截图
   - Apple Pay 支付表单的截图

2. **提供视频演示**：
   - 录制一个简短的视频，展示如何使用 Apple Pay 支付

3. **提供更详细的说明**：
   - 说明具体的导航路径
   - 说明需要满足的条件（设备支持、已添加支付卡等）

---

**最后更新**：2026年1月
