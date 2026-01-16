# Apple Pay 就绪检查清单

## ✅ 已完成的配置

### 1. Stripe Dashboard 配置 ✅
- [x] Merchant ID 已注册：`merchant.com.link2ur`
- [x] iOS 证书已配置（有效期至 2028/2/13）
- [x] 证书状态：有效

### 2. 代码实现 ✅
- [x] `PaymentViewModel.swift` 中已集成 Apple Pay
- [x] `ApplePayHelper.swift` 辅助类已创建
- [x] `ApplePayNativeView.swift` 原生实现已创建（可选）
- [x] 代码会自动检测 Merchant ID 并启用 Apple Pay

### 3. Entitlements 配置 ✅
- [x] `Link²Ur.entitlements` 中已配置 Merchant ID

---

## ⚠️ 需要确认的配置

### 1. Xcode 项目配置

**检查步骤**：
1. 打开 Xcode 项目
2. 选择项目 → **Target: link2ur** → **Signing & Capabilities**
3. 确认 **Apple Pay** Capability 已添加
4. 确认 Merchant ID 为 `merchant.com.link2ur`

**如果没有添加**：
1. 点击 **+ Capability**
2. 搜索并添加 **Apple Pay**
3. 在 Merchant IDs 中选择 `merchant.com.link2ur`

### 2. 环境变量配置

**检查步骤**：
1. **Product** → **Scheme** → **Edit Scheme...**
2. 选择 **Run** → **Arguments** → **Environment Variables**
3. 确认存在：`APPLE_PAY_MERCHANT_ID = merchant.com.link2ur`

**如果没有配置**：
1. 点击 **+** 添加环境变量
2. Name: `APPLE_PAY_MERCHANT_ID`
3. Value: `merchant.com.link2ur`

**或者**：直接在 `Constants.swift` 中设置默认值（不推荐用于生产）

```swift
#if DEBUG
return "merchant.com.link2ur" // 测试环境
#else
return "merchant.com.link2ur" // 生产环境
#endif
```

### 3. Stripe Publishable Key 配置

**检查步骤**：
确认 `Constants.Stripe.publishableKey` 已正确配置

---

## 🧪 测试 Apple Pay

### 快速测试步骤

1. **在真机上运行应用**
   - 模拟器可能不支持 Apple Pay
   - 确保设备已登录 Apple ID

2. **添加测试卡到 Wallet**
   - 设置 → Wallet & Apple Pay
   - 添加支付卡（使用真实卡号，Stripe 会自动识别测试模式）

3. **进入支付流程**
   - 创建一个任务并尝试支付
   - 或进入任何支付页面

4. **检查 Apple Pay 选项**
   - 在 Payment Sheet 中应该能看到 Apple Pay 选项
   - 如果设备支持且已配置，Apple Pay 会自动显示

### 验证代码

在代码中添加调试信息：

```swift
// 在 PaymentViewModel 的 setupPaymentElement 方法中添加
print("🔍 Apple Pay 配置检查:")
print("  - Merchant ID: \(Constants.Stripe.applePayMerchantIdentifier ?? "未配置")")
print("  - 设备支持: \(ApplePayHelper.isApplePaySupported())")
print("  - Apple Pay 已启用: \(configuration.applePay != nil)")
```

---

## 🚨 常见问题排查

### 问题 1: Apple Pay 选项不显示

**可能原因**：
1. Merchant ID 未配置或配置错误
2. 设备不支持 Apple Pay
3. 用户未添加支付卡到 Wallet
4. Xcode 中未启用 Apple Pay Capability

**解决方法**：
1. 检查环境变量或 Constants.swift 中的 Merchant ID
2. 检查 Xcode → Signing & Capabilities → Apple Pay
3. 在设备上添加支付卡
4. 确认设备支持 Apple Pay（iPhone 6 或更新）

### 问题 2: 支付时出现错误

**可能原因**：
1. Stripe 密钥配置错误
2. 证书问题
3. 网络问题

**解决方法**：
1. 检查 Stripe Publishable Key 是否正确
2. 检查 Stripe Dashboard 中证书状态
3. 检查网络连接

### 问题 3: Merchant ID 读取为 nil

**可能原因**：
1. 环境变量未配置
2. Constants.swift 中返回 nil

**解决方法**：
1. 配置环境变量 `APPLE_PAY_MERCHANT_ID`
2. 或在 Constants.swift 中设置默认值

---

## 📊 当前状态总结

### ✅ 已完成（代码层面）
- [x] 代码实现完整
- [x] Stripe Dashboard 配置完成
- [x] Entitlements 配置完成

### ⚠️ 需要确认（Xcode 配置）
- [ ] Xcode 中 Apple Pay Capability 已启用
- [ ] 环境变量已配置（或 Constants.swift 中有默认值）

### 🧪 需要测试
- [ ] 在真机上测试支付流程
- [ ] 确认 Apple Pay 选项显示
- [ ] 测试完整支付流程

---

## 🎯 快速验证

运行以下命令检查配置：

```bash
# 在 Xcode 控制台运行
print("Merchant ID: \(Constants.Stripe.applePayMerchantIdentifier ?? "❌ 未配置")")
print("设备支持: \(ApplePayHelper.isApplePaySupported() ? "✅" : "❌")")
```

**预期结果**：
- Merchant ID: `merchant.com.link2ur`
- 设备支持: ✅

---

## ✅ 结论

### 代码层面：✅ 已完成
Apple Pay 的代码实现已经完成，包括：
- Payment Sheet 集成
- 原生实现（可选）
- 辅助工具类

### 配置层面：⚠️ 需要确认
需要确认以下配置：
1. Xcode 中 Apple Pay Capability 已启用
2. 环境变量或 Constants.swift 中 Merchant ID 已配置

### 使用状态：🔄 待测试
配置完成后，需要在真机上测试以确认 Apple Pay 正常工作。

---

**下一步**：
1. 确认 Xcode 配置（Capability 和环境变量）
2. 在真机上测试
3. 如果遇到问题，参考故障排除部分
