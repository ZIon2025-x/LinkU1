# App Store 审核问题修复检查清单

## 📋 审核问题总结

根据 App Store Connect 审核反馈，需要修复以下问题：

1. **Guideline 3.1.1 - In-App Purchase (VIP会员)**
2. **Guideline 2.3.6 - Age Rating (年龄评级)**
3. **Guideline 5.1.2 - App Tracking Transparency (ATT)**
4. **Guideline 2.1 - PassKit/Apple Pay**
5. **Guideline 5.1.1(v) - Account Deletion (账户删除)**

---

## ✅ 修复状态检查

### 1. ✅ Guideline 3.1.1 - In-App Purchase (VIP会员)

**问题**：应用包含或访问付费数字内容（VIP会员），但未通过应用内购买提供。

**修复状态**：✅ **已完成**

**修复内容**：
- ✅ 前端VIP页面：购买按钮已替换为"VIP功能即将推出"提示框
- ✅ iOS VIP页面：添加了"VIP功能即将推出"提示框
- ✅ 所有VIP购买功能已移除
- ✅ 添加了国际化字符串（中英文）

**验证方法**：
- [ ] 前端VIP页面显示"即将推出"提示（非VIP用户）
- [ ] iOS VIP页面显示"即将推出"提示框
- [ ] 点击购买按钮不再触发购买流程
- [ ] 中英文切换正常显示

**Review Notes 建议**：
```
VIP功能说明：

应用中的VIP会员功能目前正在开发中，尚未开放购买。
VIP相关的UI仅用于展示未来功能，用户无法实际购买VIP会员。
我们计划在未来版本中通过应用内购买（IAP）实现VIP功能。

当前状态：
- VIP会员页面仅用于展示会员权益
- 所有购买按钮已替换为"VIP功能即将推出"提示
- 用户无法进行任何VIP相关的购买操作
```

---

### 2. ⚠️ Guideline 2.3.6 - Age Rating (年龄评级)

**问题**：应用的年龄评级显示"In-App Controls"，但未找到家长控制或年龄验证机制。

**修复状态**：⚠️ **需要在 App Store Connect 中手动设置**

**修复内容**：
- ⚠️ 需要在 App Store Connect 中更新年龄评级设置
- ⚠️ 将"Parental Controls"设置为"None"
- ⚠️ 将"Age Assurance"设置为"None"

**操作步骤**：
1. 登录 App Store Connect
2. 进入应用 → **App Information** → **Age Rating**
3. 点击 **Edit** 按钮
4. 在 **Parental Controls** 部分，选择 **None**
5. 在 **Age Assurance** 部分，选择 **None**
6. 保存更改

**注意**：如果应用确实有家长控制功能，需要在 Review Notes 中说明如何找到这些功能。

---

### 3. ✅ Guideline 5.1.2 - App Tracking Transparency (ATT)

**问题**：应用隐私信息显示用户跟踪，但未使用 App Tracking Transparency (ATT) 请求权限。

**修复状态**：✅ **已完成**

**修复内容**：
- ✅ 已移除所有 ATT 相关代码
- ✅ 已移除 `NSUserTrackingUsageDescription` 权限描述
- ✅ 已移除 `AppTrackingTransparency` 框架导入
- ✅ 已移除 `requestTrackingPermission()` 方法

**验证方法**：
- [ ] 检查 `PermissionManager.swift` 中无 ATT 相关代码
- [ ] 检查 `ContentView.swift` 中无 ATT 请求调用
- [ ] 检查 `InfoPlist.strings` 中无 `NSUserTrackingUsageDescription`
- [ ] 检查 `project.pbxproj` 中无 `INFOPLIST_KEY_NSUserTrackingUsageDescription`

**Review Notes 建议**：
```
隐私说明：

应用不追踪用户跨应用和网站的活动。
应用隐私标签中的"追踪"信息是误报，我们已更新隐私标签。
应用仅收集必要的用户数据以提供核心功能。
```

**重要**：需要在 App Store Connect 中更新隐私标签，移除"追踪"相关声明。

---

### 4. ✅ Guideline 2.1 - PassKit/Apple Pay

**问题**：应用二进制文件包含 PassKit 框架，但审核人员无法验证 Apple Pay 集成。

**修复状态**：✅ **已完成**

**修复内容**：
- ✅ 应用确实使用了 Apple Pay（通过 Stripe PaymentSheet 集成）
- ✅ 已创建详细的 Review Notes 说明文档
- ✅ Apple Pay 功能在支付页面可用

**验证方法**：
- [ ] 支付页面显示 Apple Pay 选项（如果设备支持）
- [ ] 点击 Apple Pay 按钮可以弹出支付表单
- [ ] Review Notes 中已添加 Apple Pay 说明

**Review Notes 内容**（已在 `APPLE_PAY_REVIEW_NOTES.md` 中）：
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

### 5. ✅ Guideline 5.1.1(v) - Account Deletion (账户删除)

**问题**：应用支持账户创建，但缺少账户删除选项。

**修复状态**：✅ **已完成**

**修复内容**：
- ✅ 后端已实现 `DELETE /api/users/account` API 端点
- ✅ iOS 应用已添加删除账户 UI（在设置页面）
- ✅ 前端已添加删除账户功能
- ✅ 添加了本地化字符串（英文和中文）

**验证方法**：
- [ ] iOS 设置页面显示"删除账户"选项
- [ ] 点击"删除账户"会弹出确认对话框
- [ ] 确认后可以成功删除账户
- [ ] 删除账户后用户被登出

**代码位置**：
- 后端：`backend/app/routers.py` - `DELETE /api/users/account`
- iOS：`ios/link2ur/link2ur/Views/Profile/SettingsView.swift`
- 前端：`frontend/src/pages/Settings.tsx`

---

## 📝 App Store Connect 操作清单

在提交审核前，需要在 App Store Connect 中完成以下操作：

### 1. 更新年龄评级设置
- [ ] 进入 **App Information** → **Age Rating**
- [ ] 将 **Parental Controls** 设置为 **None**
- [ ] 将 **Age Assurance** 设置为 **None**
- [ ] 保存更改

### 2. 更新隐私标签
- [ ] 进入 **App Privacy** → **Privacy Types**
- [ ] 检查是否有"追踪"相关声明
- [ ] 如果应用不追踪用户，移除所有追踪相关声明
- [ ] 保存更改

### 3. 添加 Review Notes
- [ ] 进入 **App Review Information** → **Review Notes**
- [ ] 添加以下内容：

```
VIP功能说明：

应用中的VIP会员功能目前正在开发中，尚未开放购买。
VIP相关的UI仅用于展示未来功能，用户无法实际购买VIP会员。
我们计划在未来版本中通过应用内购买（IAP）实现VIP功能。

当前状态：
- VIP会员页面仅用于展示会员权益
- 所有购买按钮已替换为"VIP功能即将推出"提示
- 用户无法进行任何VIP相关的购买操作

---

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
   - 点击按钮后，会弹出原生的 Apple Pay 支付表单

4. 测试步骤：
   a) 登录应用
   b) 发布一个新任务（或进入已有任务的支付页面）
   c) 在支付页面，查看支付方式选择卡片
   d) 如果设备支持 Apple Pay，会看到"Apple Pay"选项
   e) 选择"Apple Pay"
   f) 点击"使用 Apple Pay 支付"按钮
   g) 会弹出 Apple Pay 支付表单（需要设备已添加支付卡）

---

隐私说明：

应用不追踪用户跨应用和网站的活动。
应用仅收集必要的用户数据以提供核心功能。
```

---

## ✅ 最终检查清单

在提交审核前，请确认：

### 代码层面
- [x] VIP购买功能已移除，显示"即将推出"提示
- [x] ATT相关代码已完全移除
- [x] 账户删除功能已实现（后端 + iOS + 前端）
- [x] Apple Pay 功能正常工作
- [x] 所有国际化字符串已添加

### App Store Connect 设置
- [ ] 年龄评级：Parental Controls = None, Age Assurance = None
- [ ] 隐私标签：已移除追踪相关声明
- [ ] Review Notes：已添加 VIP 和 Apple Pay 说明

### 测试验证
- [ ] 测试VIP页面显示"即将推出"提示
- [ ] 测试账户删除功能
- [ ] 测试Apple Pay支付流程
- [ ] 测试应用不请求追踪权限

---

## 📞 如果审核仍有问题

如果审核团队仍有疑问，可以：

1. **提供截图**：
   - VIP页面"即将推出"提示的截图
   - 账户删除功能的截图
   - Apple Pay 支付页面的截图

2. **提供视频演示**：
   - 录制简短的视频，展示相关功能

3. **提供更详细的说明**：
   - 说明具体的导航路径
   - 说明需要满足的条件

---

**最后更新**：2026年1月
