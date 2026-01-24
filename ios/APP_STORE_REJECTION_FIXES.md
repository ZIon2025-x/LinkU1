# App Store 审核被拒绝修复指南

## 📋 审核问题总结

根据 App Store 审核反馈，需要修复以下问题：

1. ✅ **Guideline 3.1.1 - In-App Purchase**: VIP会员需要通过IAP实现
2. ✅ **Guideline 2.3.6 - Age Rating**: 年龄评级设置问题
3. ✅ **Guideline 5.1.2 - App Tracking Transparency**: 需要实现ATT框架
4. ✅ **Guideline 2.1 - PassKit/Apple Pay**: 需要说明或移除PassKit框架
5. ✅ **Guideline 5.1.1(v) - Account Deletion**: 需要实现账户删除功能

---

## ✅ 已完成的修复

### 1. App Tracking Transparency (ATT) - 已完成

**修复内容**：
- ✅ 在 `PermissionManager.swift` 中添加了 ATT 支持
- ✅ 在 `ContentView.swift` 中添加了请求追踪权限的逻辑
- ✅ 在 `InfoPlist.strings` 中添加了 `NSUserTrackingUsageDescription`（英文和中文）
- ✅ 在 `project.pbxproj` 中添加了 `INFOPLIST_KEY_NSUserTrackingUsageDescription`

**文件修改**：
- `ios/link2ur/link2ur/Core/Utils/PermissionManager.swift`
- `ios/link2ur/link2ur/App/ContentView.swift`
- `ios/link2ur/link2ur/en.lproj/InfoPlist.strings`
- `ios/link2ur/link2ur/zh-Hans.lproj/InfoPlist.strings`
- `ios/link2ur.xcodeproj/project.pbxproj`

**说明**：
应用现在会在用户首次启动时请求追踪权限。如果应用实际上不追踪用户，需要在 App Store Connect 中更新隐私标签。

---

### 2. 账户删除功能 - 已完成

**修复内容**：
- ✅ 在后端创建了 `DELETE /api/users/account` API 端点
- ✅ 在 iOS 应用中添加了删除账户的 UI
- ✅ 添加了删除账户的 API 调用
- ✅ 添加了本地化字符串（英文和中文）

**文件修改**：
- `backend/app/routers.py` - 添加了删除账户 API
- `ios/link2ur/link2ur/Services/APIEndpoints.swift` - 添加了端点定义
- `ios/link2ur/link2ur/Services/APIService+Endpoints.swift` - 添加了 API 方法
- `ios/link2ur/link2ur/Views/Profile/SettingsView.swift` - 添加了删除账户 UI
- `ios/link2ur/link2ur/en.lproj/Localizable.strings` - 添加了英文本地化
- `ios/link2ur/link2ur/zh-Hans.lproj/Localizable.strings` - 添加了中文本地化

**功能说明**：
- 用户可以在设置页面找到"删除账户"选项
- 删除前会显示确认对话框
- 删除账户会清除所有相关数据（设备令牌、通知、消息、任务申请、评价、收藏、用户偏好等）
- 如果有进行中的任务，会阻止删除并提示用户

---

### 3. Info.plist 配置 - 已完成

**修复内容**：
- ✅ 添加了 `NSUserTrackingUsageDescription` 权限描述

---

## ⚠️ 需要手动处理的事项

### 1. Guideline 3.1.1 - VIP会员IAP问题

**问题**：应用包含VIP会员功能，但这些内容不能通过应用内购买获得。

**解决方案（二选一）**：

#### 方案A：实现应用内购买（推荐，如果确实需要VIP功能）

1. 在 App Store Connect 中创建 IAP 产品：
   - 登录 App Store Connect
   - 选择应用 → 功能 → App内购买项目
   - 创建订阅或非消耗型产品（根据VIP会员类型选择）
   - 配置产品ID、价格、描述等

2. 在 iOS 应用中集成 StoreKit：
   - 使用 StoreKit 2 或 StoreKit 1 实现购买流程
   - 处理购买成功/失败的回调
   - 验证收据并更新用户VIP状态

3. 移除现有的VIP购买方式（如果存在）：
   - 检查是否有通过网站或其他方式购买VIP的功能
   - 移除这些功能，只保留IAP方式

#### 方案B：移除VIP功能（如果不需要）

1. 移除VIP相关的UI和功能
2. 在 App Store Connect 的 Review Notes 中说明已移除VIP功能
3. 更新应用描述，移除VIP相关说明

**建议**：如果VIP功能是核心功能，建议实现IAP。如果不是，可以考虑暂时移除。

---

### 2. Guideline 2.3.6 - 年龄评级设置

**问题**：年龄评级中选择了"In-App Controls"，但审核人员找不到家长控制或年龄验证机制。

**解决方案**：

1. 登录 App Store Connect
2. 选择应用 → App信息 → 年龄分级
3. 找到"In-App Controls"部分
4. 将"Parental Controls"和"Age Assurance"都设置为"None"
5. 保存更改

**注意**：如果应用确实有家长控制功能，需要在 Review Notes 中说明如何找到这些功能。

---

### 3. Guideline 2.1 - PassKit/Apple Pay问题

**问题**：应用二进制文件包含PassKit框架，但审核人员无法验证Apple Pay集成。

**解决方案**：应用确实使用了Apple Pay，需要在 Review Notes 中详细说明。

#### ✅ 推荐方案：在 Review Notes 中说明 Apple Pay 位置

**详细说明文档**：请参考 `ios/APPLE_PAY_REVIEW_NOTES.md`

**快速操作步骤**：

1. 登录 App Store Connect
2. 选择应用 → **App Review Information**
3. 在 **Review Notes** 字段中，复制粘贴以下内容：

```
Apple Pay 集成说明：

我们的应用集成了 Apple Pay 支付功能，具体位置和使用方式如下：

1. 支付页面位置：
   - 用户发布任务后，需要支付平台服务费时，会进入支付页面
   - 支付页面路径：任务详情页 → 支付按钮 → 支付页面

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
```

**代码位置参考**：
- 支付页面视图：`ios/link2ur/link2ur/Views/Payment/StripePaymentView.swift` (第 496-527 行)
- 支付视图模型：`ios/link2ur/link2ur/ViewModels/PaymentViewModel.swift` (第 506-575 行)
- Apple Pay 辅助类：`ios/link2ur/link2ur/Utils/ApplePayHelper.swift`

**确保功能正常**：
- ✅ 测试 Apple Pay 支付流程
- ✅ 确保 Merchant ID 已正确配置
- ✅ 确保在支持的设备上可以正常使用

---

### 4. App Store Connect 隐私标签更新

**问题**：如果应用实际上不追踪用户，需要更新隐私标签。

**解决方案**：

1. 登录 App Store Connect
2. 选择应用 → App隐私
3. 检查"用于追踪您的数据"部分
4. 如果应用不追踪用户，确保：
   - 所有数据收集都标记为"不用于追踪"
   - 或者移除"用于追踪"的数据类型

**注意**：根据ATT的实现，应用现在会请求追踪权限。如果应用确实不追踪用户，建议：
- 移除ATT权限请求（如果不需要）
- 或者在隐私标签中正确标记数据使用方式

---

## 📝 提交审核前的检查清单

- [ ] 在 App Store Connect 中更新年龄评级设置（移除In-App Controls）
- [ ] 处理VIP会员IAP问题（实现IAP或移除VIP功能）
- [ ] 在 Review Notes 中说明Apple Pay的位置（或移除PassKit）
- [ ] 更新隐私标签（如果应用不追踪用户）
- [ ] 测试账户删除功能
- [ ] 测试ATT权限请求（确保在iOS 14+设备上正常工作）
- [ ] 确保所有新添加的本地化字符串都已正确显示
- [ ] 测试删除账户后是否能正常登出并返回登录页面

---

## 🔍 代码位置参考

### ATT相关
- 权限请求：`ios/link2ur/link2ur/App/ContentView.swift` (第387-409行)
- 权限管理：`ios/link2ur/link2ur/Core/Utils/PermissionManager.swift`

### 账户删除相关
- 后端API：`backend/app/routers.py` (第4423-4510行)
- iOS UI：`ios/link2ur/link2ur/Views/Profile/SettingsView.swift` (第162-190行)
- API端点：`ios/link2ur/link2ur/Services/APIEndpoints.swift` (第69行)

### Apple Pay相关
- 支付视图：`ios/link2ur/link2ur/Views/Payment/StripePaymentView.swift`
- 支付视图模型：`ios/link2ur/link2ur/ViewModels/PaymentViewModel.swift`

---

## 📞 需要帮助？

如果在处理这些问题时遇到困难，可以：
1. 查看 Apple 官方文档
2. 在 App Store Connect 中回复审核团队的问题
3. 联系 Apple Developer Support

---

**最后更新**：2026年1月
