# iOS 证书和配置文件设置指南

## 什么是这两个证书？

### 1. 生产环境证书（Distribution Certificate）

**作用**：
- 用于签名 App Store 分发的应用
- 证明应用是由你的开发者账号签名的
- 是上传到 App Store 的必需证书

**类型**：
- **App Store Distribution Certificate**：用于 App Store 分发
- **Ad Hoc Distribution Certificate**：用于测试设备分发（不需要）

### 2. App Store 分发配置文件（Provisioning Profile）

**作用**：
- 将证书、App ID 和设备信息绑定在一起
- 告诉 iOS 系统这个应用可以在哪些设备上运行
- App Store 分发配置文件允许应用在 App Store 上分发

**类型**：
- **App Store Provisioning Profile**：用于 App Store 分发（必需）
- **Ad Hoc Provisioning Profile**：用于测试设备分发（不需要）
- **Development Provisioning Profile**：用于开发测试（已有）

## 如何检查是否已有这些证书？

### 方法 1：在 Xcode 中检查（最简单）

1. **打开 Xcode**
2. **打开项目**：`ios/link2ur.xcodeproj`
3. **选择项目**：在左侧导航栏选择项目名称
4. **选择 Target**：选择 "Link²Ur"
5. **打开 Signing & Capabilities 标签**
6. **查看签名配置**：

   - **Team**：应该显示你的开发团队（如：9BH6D242HU）
   - **Signing Certificate**：
     - Debug：`Apple Development`（开发证书，已有）
     - Release：`Apple Distribution`（分发证书，需要检查）

### 方法 2：在 Apple Developer 网站检查

1. **登录 Apple Developer**：https://developer.apple.com/account
2. **进入 Certificates**：
   - 点击 "Certificates, Identifiers & Profiles"
   - 点击左侧 "Certificates"
3. **检查证书**：
   - 查找类型为 **"Apple Distribution"** 的证书
   - 如果存在且未过期，说明已有分发证书 ✅
4. **进入 Profiles**：
   - 点击左侧 "Profiles"
   - 查找类型为 **"App Store"** 的配置文件
   - 如果存在且未过期，说明已有配置文件 ✅

### 方法 3：使用命令行检查

```bash
# 检查本地证书
security find-identity -v -p codesigning

# 应该看到类似输出：
# 1) ABC123... "Apple Development: Your Name (XXXXXXXXXX)"
# 2) DEF456... "Apple Distribution: Your Name (YYYYYYYYYY)"  ← 这个就是分发证书
```

## 如何创建这些证书？

### 自动创建（推荐，最简单）

**Xcode 会自动创建**，如果你使用自动签名：

1. **在 Xcode 中**：
   - 打开项目设置
   - 选择 Target "Link²Ur"
   - 打开 "Signing & Capabilities"
   - 确保 **"Automatically manage signing"** 已勾选 ✅
   - 选择你的 **Team**
   - Xcode 会自动创建所需的证书和配置文件

2. **验证**：
   - 构建项目（Product → Build）
   - 如果成功，说明证书已自动创建 ✅

### 手动创建（如果需要）

#### 创建 Distribution Certificate

1. **登录 Apple Developer**：https://developer.apple.com/account
2. **进入 Certificates**：
   - Certificates, Identifiers & Profiles → Certificates
   - 点击 "+" 创建新证书
3. **选择类型**：
   - 选择 **"App Store and Ad Hoc"**
   - 点击 "Continue"
4. **上传 CSR 文件**：
   - 在 Mac 上打开 "钥匙串访问"（Keychain Access）
   - 钥匙串访问 → 证书助理 → 从证书颁发机构请求证书
   - 填写信息，保存 CSR 文件
   - 上传 CSR 文件到 Apple Developer
5. **下载证书**：
   - 下载证书文件（.cer）
   - 双击安装到钥匙串

#### 创建 App Store Provisioning Profile

1. **进入 Profiles**：
   - Certificates, Identifiers & Profiles → Profiles
   - 点击 "+" 创建新配置文件
2. **选择类型**：
   - 选择 **"App Store"**
   - 点击 "Continue"
3. **选择 App ID**：
   - 选择 `com.link2ur`（你的 Bundle ID）
   - 点击 "Continue"
4. **选择证书**：
   - 选择刚才创建的 Distribution Certificate
   - 点击 "Continue"
5. **命名并下载**：
   - 输入配置文件名称（如：Link²Ur App Store）
   - 点击 "Generate"
   - 下载配置文件（.mobileprovision）
   - 双击安装到 Xcode

## 检查清单

### ✅ 必需项检查

- [ ] **Apple Developer Program 会员资格**
  - 费用：$99/年
  - 如果没有，需要先注册：https://developer.apple.com/programs/

- [ ] **开发团队配置**
  - 在 Xcode 中已选择 Team
  - 当前显示：`9BH6D242HU` ✅

- [ ] **Distribution Certificate（分发证书）**
  - 类型：Apple Distribution
  - 状态：有效且未过期
  - 检查方法：见上方

- [ ] **App Store Provisioning Profile（分发配置文件）**
  - 类型：App Store
  - Bundle ID：com.link2ur
  - 状态：有效且未过期
  - 检查方法：见上方

### 🔍 快速检查步骤

1. **打开 Xcode**
2. **打开项目**：`ios/link2ur.xcodeproj`
3. **选择项目** → **Target "Link²Ur"** → **Signing & Capabilities**
4. **检查以下内容**：

   ```
   ✅ Team: 9BH6D242HU (已选择)
   ✅ Bundle Identifier: com.link2ur
   ✅ Automatically manage signing: ✅ (已勾选)
   ✅ Signing Certificate (Release): Apple Distribution
   ✅ Provisioning Profile (Release): Link²Ur App Store
   ```

5. **如果显示错误**：
   - 红色错误提示：需要修复
   - 黄色警告：通常可以忽略（Xcode 会自动处理）

## 常见问题

### Q: 我没有 Apple Developer Program 会员资格怎么办？

**A**: 
- 需要先注册 Apple Developer Program（$99/年）
- 注册地址：https://developer.apple.com/programs/
- 注册需要：身份证明、支付信息、D-U-N-S 编号（组织账号需要）

### Q: Xcode 显示 "No signing certificate found" 怎么办？

**A**: 
1. 确保已登录 Apple Developer 账号
2. 确保 "Automatically manage signing" 已勾选
3. 选择正确的 Team
4. Xcode 会自动创建证书

### Q: 证书过期了怎么办？

**A**: 
- 如果使用自动签名，Xcode 会自动更新证书
- 如果使用手动签名，需要在 Apple Developer 网站重新创建

### Q: 我可以使用开发证书上传到 App Store 吗？

**A**: 
- ❌ **不可以**
- 必须使用 **Distribution Certificate**（分发证书）
- 开发证书只能用于开发和测试

### Q: 配置文件过期了怎么办？

**A**: 
- 如果使用自动签名，Xcode 会自动更新配置文件
- 如果使用手动签名，需要在 Apple Developer 网站重新创建

## 当前项目状态

根据项目配置（`project.pbxproj`），你的项目已配置：

- ✅ **Team ID**: `9BH6D242HU`
- ✅ **Bundle Identifier**: `com.link2ur`
- ✅ **Code Signing Style**: `Automatic`（自动签名）
- ✅ **Entitlements**: `Link²Ur.entitlements`

**这意味着**：
- 如果你已登录 Apple Developer 账号
- 并且 "Automatically manage signing" 已启用
- Xcode 应该已经自动创建了所需的证书和配置文件 ✅

## 验证步骤

### 1. 检查 Xcode 配置

```bash
# 打开项目
open ios/link2ur.xcodeproj
```

在 Xcode 中：
1. 选择项目 → Target "Link²Ur" → Signing & Capabilities
2. 检查是否有错误提示
3. 如果没有错误，说明证书已配置 ✅

### 2. 尝试构建 Archive

1. 在 Xcode 中选择：**Product → Archive**
2. 如果成功，说明证书配置正确 ✅
3. 如果失败，查看错误信息并修复

### 3. 检查 Apple Developer 网站

1. 登录：https://developer.apple.com/account
2. 检查 Certificates 和 Profiles
3. 确认有 Distribution Certificate 和 App Store Profile

---

**最后更新**：2025年1月27日
