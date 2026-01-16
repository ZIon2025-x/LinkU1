# Apple Pay 配置状态

## ✅ iOS 证书配置（已完成）

根据 Stripe Dashboard 信息：

- **Merchant ID**: `merchant.com.link2ur`
- **证书创建时间**: 2026/1/14 下午7:30
- **证书过期时间**: 2028/2/13 上午1:19
- **状态**: ✅ 已配置并有效

### 证书信息
- 证书有效期约 2 年（2026-2028）
- 证书已正确配置在 Stripe Dashboard 中
- 无需立即操作，证书将在 2028 年 2 月过期前需要更新

---

## 🌐 Web 域名配置（可选）

### 说明
如果需要在**网页版**（Web）上使用 Apple Pay，需要配置支付方式域名。

**注意**：
- iOS 应用使用 Apple Pay **不需要**配置 Web 域名
- 只有网页版（Safari、Chrome 等）才需要配置 Web 域名
- Web 域名配置已迁移到新的**支付方式域名页面**

### 配置步骤（如果需要网页版 Apple Pay）

1. **访问支付方式域名页面**
   - 在 Stripe Dashboard 中，访问新的支付方式域名页面
   - 或直接访问：`https://dashboard.stripe.com/settings/payment_method_domains`

2. **添加域名**
   - 点击 **添加域名** 或 **Add domain**
   - 输入你的网站域名（例如：`link2ur.com` 或 `www.link2ur.com`）
   - 注意：`www` 是子域名，需要单独注册

3. **验证域名**
   - Stripe 会提供验证文件
   - 将验证文件上传到你的服务器
   - 确保可以通过 HTTPS 访问验证文件
   - 在 Stripe Dashboard 中完成验证

4. **API 方式配置（可选）**
   ```bash
   curl https://api.stripe.com/v1/payment_method_domains \
     -u "<<YOUR_SECRET_KEY>>:" \
     -d domain_name="link2ur.com"
   ```

### 需要配置的域名
- **主域名**: `link2ur.com`
- **www 子域名**: `www.link2ur.com`（如果使用）
- **其他子域名**: 根据实际使用的子域名添加

---

## 📋 完整配置检查清单

### iOS 应用配置

- [x] **Apple Merchant ID 已注册**
  - Merchant ID: `merchant.com.link2ur`
  - 状态: ✅ 已完成

- [x] **iOS 证书已配置**
  - 证书状态: ✅ 已配置
  - 有效期: 2026/1/14 - 2028/2/13
  - 状态: ✅ 有效

- [ ] **Xcode 中已启用 Apple Pay Capability**
  - 项目设置 → Signing & Capabilities → Apple Pay
  - 确认 Merchant ID: `merchant.com.link2ur`
  - 状态: ⚠️ 需要确认

- [ ] **环境变量已配置**
  - Xcode Scheme → Run → Environment Variables
  - `APPLE_PAY_MERCHANT_ID = merchant.com.link2ur`
  - 状态: ⚠️ 需要确认

- [ ] **代码中已配置**
  - `Constants.swift` 中 `applePayMerchantIdentifier` 已配置
  - 或通过环境变量读取
  - 状态: ⚠️ 需要确认

### Web 域名配置（可选）

- [ ] **支付方式域名已配置**（仅网页版需要）
  - 主域名: `link2ur.com`
  - www 子域名: `www.link2ur.com`
  - 验证文件已上传
  - 状态: ⚠️ 如果需要网页版 Apple Pay，需要配置

---

## 🚀 下一步操作

### 1. 确认 Xcode 配置

1. 打开 Xcode 项目
2. 选择项目 → **Target** → **Signing & Capabilities**
3. 确认 **Apple Pay** Capability 已添加
4. 确认 Merchant ID 为 `merchant.com.link2ur`

### 2. 确认环境变量

1. **Product** → **Scheme** → **Edit Scheme...**
2. 选择 **Run** → **Arguments** → **Environment Variables**
3. 确认 `APPLE_PAY_MERCHANT_ID = merchant.com.link2ur`

### 3. 测试 Apple Pay（iOS）

1. 在真机上运行应用
2. 进入支付流程
3. 确认 Apple Pay 选项显示
4. 测试支付流程

### 4. 配置 Web 域名（如果需要）

如果需要在网页版使用 Apple Pay：

1. 访问 Stripe Dashboard → 支付方式域名页面
2. 添加 `link2ur.com` 和 `www.link2ur.com`
3. 上传验证文件到服务器
4. 完成验证

---

## 📝 证书更新提醒

### 证书过期时间
- **过期日期**: 2028/2/13 上午1:19
- **建议更新日期**: 2028/1/13（提前 1 个月）

### 更新步骤（2028 年 1 月）

1. 访问 [Stripe Dashboard iOS 证书页面](https://dashboard.stripe.com/settings/ios_certificates)
2. 点击 **添加新应用程序** 或 **更新证书**
3. 下载新的 CSR 文件
4. 在 Apple Developer 中创建新证书
5. 上传新证书到 Stripe（如果需要）

---

## 🔍 验证配置

### 检查 iOS 配置

```swift
// 在代码中检查 Merchant ID 是否正确读取
print("Merchant ID: \(Constants.Stripe.applePayMerchantIdentifier ?? "未配置")")

// 检查设备是否支持 Apple Pay
if ApplePayHelper.isApplePaySupported() {
    print("✅ 设备支持 Apple Pay")
} else {
    print("❌ 设备不支持 Apple Pay")
}
```

### 检查 Web 域名（如果需要）

1. 访问 Stripe Dashboard → 支付方式域名页面
2. 确认域名状态为 **已验证** 或 **Active**
3. 在网页上测试 Apple Pay 按钮是否显示

---

## 📚 相关文档

- [Apple Pay 实现指南](./APPLE_PAY_IMPLEMENTATION_GUIDE.md)
- [Apple Pay 集成总结](./APPLE_PAY_SUMMARY.md)
- [Stripe 支付方式域名文档](https://docs.stripe.com/payments/payment-methods/pmd-registration)
- [Stripe Dashboard - 支付方式域名](https://dashboard.stripe.com/settings/payment_method_domains)

---

**最后更新**: 2025-01-27
**证书有效期**: 2026/1/14 - 2028/2/13
