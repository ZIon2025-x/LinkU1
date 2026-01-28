# Xcode StoreKit 配置说明

## 添加 In-App Purchase Capability

在 Xcode 中添加 In-App Purchase capability（如果还没有添加）：

1. 在 Xcode 中选择项目 Target: **Link²Ur**
2. 进入 **Signing & Capabilities** 标签
3. 点击 **+ Capability** 按钮
4. 搜索并添加 **In-App Purchase**

**重要提示**：
- In-App Purchase capability **不需要**在 entitlements 文件中手动添加任何键
- 如果 Xcode 自动添加了 `com.apple.developer.in-app-purchase` 键到 entitlements 文件，**请删除它**
- 正确的 entitlements 文件应该只包含 `aps-environment` 和 `com.apple.developer.in-app-payments`（Apple Pay）

### 如果遇到 "Entitlement com.apple.developer.in-app-purchase not found" 错误：

1. **检查 entitlements 文件**：
   - 打开 `Link²Ur.entitlements`
   - 确保**没有** `com.apple.developer.in-app-purchase` 键
   - 如果存在，删除它

2. **清理 Xcode 缓存**：
   - 在 Xcode 菜单中选择 **Product > Clean Build Folder**（或按 `Cmd + Shift + K`）
   - 关闭 Xcode
   - 删除 `~/Library/Developer/Xcode/DerivedData` 中项目相关的文件夹
   - 重新打开 Xcode

3. **重新配置 Capability**：
   - 在 **Signing & Capabilities** 中移除 In-App Purchase capability
   - 重新添加 In-App Purchase capability
   - 确保 entitlements 文件没有被自动修改

4. **验证配置**：
   - 确保 `Link²Ur.entitlements` 文件内容如下：
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>aps-environment</key>
       <string>development</string>
       <key>com.apple.developer.in-app-payments</key>
       <array>
           <string>merchant.com.link2ur</string>
       </array>
   </dict>
   </plist>
   ```

---

## 配置 Scheme 使用 StoreKit Configuration

为了在本地测试 VIP 订阅功能，需要在 Xcode 中配置 Scheme 使用 StoreKit Configuration 文件。

### 步骤：

1. 在 Xcode 中打开项目
2. 选择菜单：**Product > Scheme > Edit Scheme...**（或按 `Cmd + <`）
3. 在左侧选择 **Run**
4. 选择顶部的 **Options** 标签
5. 找到 **StoreKit Configuration** 部分
6. 在下拉菜单中选择 `VIPProducts.storekit`
7. 点击 **Close** 保存

### 验证配置：

配置完成后，运行应用时 StoreKit 将使用本地配置文件进行测试，无需连接 App Store Connect。

---

## 沙盒测试流程

### 1. 创建沙盒测试账户

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 进入 **用户和访问**
3. 选择 **沙盒** 标签
4. 点击 **+** 创建沙盒测试员账户
5. 使用一个不与任何真实 Apple ID 关联的邮箱

### 2. 在设备上测试

1. 在 iPhone 设置中：
   - 打开 **设置 > App Store**
   - 如果已登录真实 Apple ID，先登出（仅从 App Store，不是整个 iCloud）
   
2. 运行应用：
   - 在 Xcode 中运行应用到设备
   - 进入 VIP 购买页面
   - 选择产品并点击购买
   
3. 登录沙盒账户：
   - 系统会提示登录
   - 使用之前创建的沙盒测试账户登录
   - 完成购买流程

### 3. 验证功能

测试以下功能是否正常：
- [ ] 产品列表正确加载
- [ ] 购买流程正常完成
- [ ] VIP 状态正确更新
- [ ] 恢复购买功能正常
- [ ] 订阅到期时间正确显示

---

## 注意事项

- **本地测试**：使用 StoreKit Configuration 文件时，购买是模拟的，不会产生真实费用
- **沙盒测试**：使用沙盒账户时，购买也是测试性的，不会产生真实费用
- **生产环境**：提交审核前，需要在 App Store Connect 中创建真实的 IAP 产品
