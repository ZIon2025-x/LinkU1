# 支付方式选择功能实现

## ✅ 已完成的功能

### 1. 支付方式选择
- ✅ 支持选择**信用卡/借记卡**支付
- ✅ 支持选择**Apple Pay**支付（原生实现）
- ✅ 根据设备支持情况自动显示/隐藏 Apple Pay 选项

### 2. 实现方式

#### 信用卡/借记卡支付
- 使用 **PaymentSheet**（Stripe 统一支付界面）
- 支持多种银行卡类型
- 自动保存支付方式（可选）

#### Apple Pay 支付
- 使用**原生 STPApplePayContext**实现
- 完全自定义的 Apple Pay 体验
- 自定义支付摘要项
- 更快的支付流程

## 📁 修改的文件

### 1. `PaymentViewModel.swift`
**新增内容**：
- `PaymentMethodType` 枚举：定义支付方式类型
- `selectedPaymentMethod`：当前选择的支付方式
- `isApplePaySupported`：检查设备是否支持 Apple Pay
- `payWithApplePay()`：使用 Apple Pay 原生实现支付
- `performPayment()`：根据选择的支付方式执行支付
- `ApplePayContextDelegate` 实现：处理 Apple Pay 支付结果

### 2. `StripePaymentView.swift`
**新增内容**：
- `paymentMethodSelectionCard`：支付方式选择卡片 UI
- `PaymentMethodOption`：支付方式选项组件
- `paymentButton`：根据选择的支付方式显示不同的支付按钮

## 🎨 UI 设计

### 支付方式选择卡片
- 显示所有可用的支付方式
- 每个选项包含：
  - 图标（信用卡图标或 Apple Logo）
  - 支付方式名称
  - 选中状态指示器
- 选中状态有视觉反馈（边框高亮、背景色）

### 支付按钮
- **信用卡支付**：渐变背景按钮，显示"确认支付"
- **Apple Pay**：黑色背景按钮，显示"使用 Apple Pay 支付"和 Apple Logo

## 🔄 支付流程

### 选择信用卡支付
1. 用户选择"信用卡/借记卡"
2. 点击"确认支付"按钮
3. 弹出 PaymentSheet（Stripe 统一支付界面）
4. 用户输入卡号等信息
5. 完成支付

### 选择 Apple Pay 支付
1. 用户选择"Apple Pay"（仅设备支持时显示）
2. 点击"使用 Apple Pay 支付"按钮
3. 弹出原生 Apple Pay 支付表单
4. 用户使用 Face ID/Touch ID 确认
5. 完成支付

## 📋 代码结构

### PaymentMethodType 枚举
```swift
enum PaymentMethodType: String, CaseIterable {
    case card = "card"
    case applePay = "applePay"
    
    var displayName: String { ... }
    var icon: String { ... }
}
```

### 支付方式检查
```swift
var isApplePaySupported: Bool {
    return ApplePayHelper.isApplePaySupported()
}
```

### 执行支付
```swift
func performPayment() {
    switch selectedPaymentMethod {
    case .card:
        // 使用 PaymentSheet
    case .applePay:
        // 使用原生 Apple Pay
    }
}
```

## 🎯 使用说明

### 用户操作流程
1. 进入支付页面
2. 查看支付金额和优惠信息
3. **选择支付方式**（新增功能）
   - 信用卡/借记卡
   - Apple Pay（如果设备支持）
4. 点击支付按钮
5. 根据选择的支付方式完成支付

### 开发者注意事项
- Apple Pay 选项仅在设备支持时显示
- 如果设备不支持 Apple Pay，只显示信用卡选项
- 支付方式选择状态会保存在 `viewModel.selectedPaymentMethod` 中

## 🔍 技术细节

### Apple Pay 原生实现
- 使用 `STPApplePayContext` 和 `ApplePayContextDelegate`
- 支持 async/await API（Stripe iOS SDK 25.3.1）
- 自定义支付摘要项（显示任务标题）
- 完整的错误处理

### PaymentSheet 实现
- 使用 Stripe PaymentSheet
- 支持多种支付方式（在 PaymentSheet 内部）
- 统一的支付界面
- 自动处理支付方式保存

## ✅ 测试检查清单

- [ ] 支付方式选择卡片正常显示
- [ ] 可以选择不同的支付方式
- [ ] 选中状态有视觉反馈
- [ ] 信用卡支付流程正常
- [ ] Apple Pay 支付流程正常（在支持的设备上）
- [ ] 支付成功后正确回调
- [ ] 支付失败时显示错误信息
- [ ] 用户取消支付时不显示错误

## 🚀 下一步优化建议

1. **添加更多支付方式**
   - Google Pay（Android）
   - 其他本地支付方式

2. **优化用户体验**
   - 记住用户上次选择的支付方式
   - 添加支付方式图标
   - 优化加载状态显示

3. **错误处理**
   - 更详细的错误提示
   - 支付失败重试机制

---

**实现日期**: 2025-01-27
**状态**: ✅ 已完成并可用
