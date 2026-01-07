# iOS 依赖安装详细指南

本指南详细说明如何在 Xcode 中安装 Stripe iOS SDK 依赖。

## 📋 前置条件

- macOS 系统
- Xcode 已安装（推荐 Xcode 14.0 或更高版本）
- 网络连接（用于下载依赖）

## 🎯 方法选择

### 使用 CocoaPods
- ✅ 适合已有 CocoaPods 配置的项目
- ✅ 依赖管理更灵活
- ❌ 需要额外安装 CocoaPods

### 使用 Swift Package Manager（推荐）
- ✅ Xcode 内置，无需额外工具
- ✅ 更现代的依赖管理方式
- ✅ Apple 官方推荐
- ❌ 需要 Xcode 11.0+

## 🚀 方法一：使用 CocoaPods

### 第一步：安装 CocoaPods

#### 检查是否已安装

在终端运行：
```bash
pod --version
```

如果显示版本号（如 `1.12.0`），说明已安装，可以跳过安装步骤。

#### 安装 CocoaPods

**方法 A：使用 gem（需要 Ruby）**

```bash
sudo gem install cocoapods
```

**方法 B：使用 Homebrew（推荐）**

```bash
brew install cocoapods
```

**方法 C：使用 Bundler（适合团队项目）**

在项目根目录创建 `Gemfile`：
```ruby
source 'https://rubygems.org'
gem 'cocoapods', '~> 1.12'
```

然后运行：
```bash
bundle install
```

### 第二步：安装项目依赖

1. **打开终端**，进入 iOS 项目目录：
   ```bash
   cd /Users/dyf/Downloads/LinkU1/stripe-sample-code/ios
   ```

2. **安装依赖**：
   ```bash
   pod install
   ```

   这个命令会：
   - 读取 `Podfile` 配置
   - 下载 Stripe iOS SDK 到 `Pods/` 目录
   - 创建 `Pods.xcodeproj`
   - 创建 `.xcworkspace` 文件

3. **查看安装结果**：
   ```
   Analyzing dependencies
   Downloading dependencies
   Installing StripePaymentSheet (25.3.1)
   Installing StripeCore (25.3.1)
   Generating Pods project
   Integrating client project
   
   [!] Please close any current Xcode sessions and use `StripePaymentSample.xcworkspace` for this project from now on.
   ```

### 第三步：在 Xcode 中打开项目

⚠️ **重要**：必须使用 `.xcworkspace` 文件！

**方法 A：从 Finder 打开**

1. 在 Finder 中打开 `ios` 目录
2. 找到 `StripePaymentSample.xcworkspace` 文件
3. 双击打开

**方法 B：从终端打开**

```bash
cd /Users/dyf/Downloads/LinkU1/stripe-sample-code/ios
open StripePaymentSample.xcworkspace
```

**方法 C：从 Xcode 打开**

1. 打开 Xcode
2. **File** → **Open...**
3. 选择 `StripePaymentSample.xcworkspace`（不是 `.xcodeproj`）

### 验证安装

在 Xcode 中：

1. 打开 `CheckoutViewController.swift`
2. 检查导入语句：
   ```swift
   import StripePaymentSheet
   import StripeCore
   ```
3. 如果没有红色错误提示，说明安装成功

### 常见问题

#### 问题 1：`pod: command not found`

**原因**：CocoaPods 未安装或未在 PATH 中

**解决方案**：
```bash
# 重新安装
sudo gem install cocoapods

# 或者使用 Homebrew
brew install cocoapods

# 检查 PATH
echo $PATH
```

#### 问题 2：`pod install` 很慢或失败

**原因**：网络问题或仓库需要更新

**解决方案**：
```bash
# 更新 CocoaPods 仓库
pod repo update

# 清理缓存后重新安装
pod cache clean --all
pod install --repo-update
```

#### 问题 3：找不到 `Podfile`

**原因**：不在正确的目录

**解决方案**：
```bash
# 确认当前目录
pwd

# 应该显示：/Users/dyf/Downloads/LinkU1/stripe-sample-code/ios

# 如果不在，切换到正确目录
cd /Users/dyf/Downloads/LinkU1/stripe-sample-code/ios
```

#### 问题 4：打开项目后找不到 Stripe 模块

**原因**：使用了 `.xcodeproj` 而不是 `.xcworkspace`

**解决方案**：
1. 关闭当前 Xcode 窗口
2. 使用 `.xcworkspace` 文件重新打开项目

#### 问题 5：构建错误 "No such module 'StripePaymentSheet'"

**原因**：依赖未正确链接

**解决方案**：
```bash
# 清理并重新安装
cd ios
rm -rf Pods Podfile.lock
pod install
```

然后在 Xcode 中：
1. **Product** → **Clean Build Folder** (⌘ + Shift + K)
2. 重新构建项目

### 更新依赖

```bash
# 更新所有依赖到最新版本
pod update

# 只更新 Stripe SDK
pod update StripePaymentSheet StripeCore
```

---

## 🚀 方法二：使用 Swift Package Manager（推荐）

### 第一步：在 Xcode 中打开项目

1. 打开 Xcode
2. **File** → **Open...**
3. 选择 `StripePaymentSample.xcodeproj` 文件
   - 注意：使用 SPM 时，可以直接打开 `.xcodeproj`，不需要 `.xcworkspace`

### 第二步：添加 Stripe 包依赖

1. **选择项目**：
   - 在 Xcode 左侧项目导航器中，点击最顶部的项目图标（蓝色）

2. **选择 Target**：
   - 在中间面板，选择 **TARGETS** 下的 **StripePaymentSample**

3. **打开 Package Dependencies**：
   - 切换到 **Package Dependencies** 标签（在 **General**、**Signing & Capabilities** 等标签旁边）

4. **添加包**：
   - 点击左下角的 **"+"** 按钮
   - 或者点击 **Package Dependencies** 列表下方的 **"+"** 按钮

5. **输入包 URL**：
   - 在搜索框中输入：`https://github.com/stripe/stripe-ios`
   - 或者直接粘贴完整 URL
   - 点击 **Add Package**

6. **选择版本**：
   - **Dependency Rule** 选择：
     - **Up to Next Major Version**：`25.0.0`（推荐，自动更新到 25.x.x 的最新版本）
     - **Exact Version**：`25.3.1`（固定版本）
     - **Branch**：`main`（使用最新开发版本，不推荐）
   - 点击 **Add Package**

7. **选择产品**：
   - 在 **Add to Target** 部分，勾选：
     - ✅ **StripePaymentSheet**
     - ✅ **StripeCore**
   - 点击 **Add Package**

8. **等待下载**：
   - Xcode 会自动下载 Stripe SDK
   - 可以在顶部状态栏看到下载进度
   - 这可能需要几分钟，取决于网络速度

### 第三步：验证安装

1. **检查 Package Dependencies**：
   - 在 **Package Dependencies** 标签中，应该能看到：
     ```
     stripe-ios
     https://github.com/stripe/stripe-ios
     ```

2. **检查代码**：
   - 打开 `CheckoutViewController.swift`
   - 确认导入语句没有错误：
     ```swift
     import StripePaymentSheet
     import StripeCore
     ```

3. **尝试构建**：
   - 按 **⌘ + B** 构建项目
   - 如果没有错误，说明安装成功

### 更新依赖

1. 在 **Package Dependencies** 标签中
2. 选择 `stripe-ios` 包
3. 点击右侧的 **Update to Latest Package Versions** 按钮
4. 或者右键点击包，选择 **Update Package**

### 常见问题

#### 问题 1：找不到 "Package Dependencies" 标签

**原因**：Xcode 版本过低（需要 Xcode 11.0+）

**解决方案**：
- 更新 Xcode 到最新版本
- 或者使用 CocoaPods 方法

#### 问题 2：下载很慢或失败

**原因**：网络问题

**解决方案**：
1. 检查网络连接
2. 如果在中国，可能需要使用代理
3. 尝试重新添加包

#### 问题 3：构建错误 "No such module"

**原因**：包未正确链接到 Target

**解决方案**：
1. 检查 **Package Dependencies** 中是否选择了正确的产品
2. 确保在 **Add to Target** 中勾选了 Target
3. 清理构建：**Product** → **Clean Build Folder** (⌘ + Shift + K)
4. 重新构建

#### 问题 4：版本冲突

**原因**：多个包依赖不同版本的 Stripe

**解决方案**：
1. 在 **Package Dependencies** 中检查所有依赖
2. 统一使用相同版本的 Stripe SDK
3. 或者让 Xcode 自动解决冲突

---

## 🔄 从 CocoaPods 迁移到 SPM

如果你之前使用 CocoaPods，想迁移到 SPM：

1. **备份项目**
2. **删除 CocoaPods 文件**：
   ```bash
   cd ios
   rm -rf Pods Podfile.lock .xcworkspace
   ```
3. **按照 SPM 方法添加依赖**
4. **使用 `.xcodeproj` 打开项目**（不再需要 `.xcworkspace`）

---

## ✅ 安装检查清单

安装完成后，确认以下项目：

- [ ] 依赖已成功下载（CocoaPods 或 SPM）
- [ ] 项目可以正常打开（使用正确的文件）
- [ ] 代码中没有红色错误提示
- [ ] `import StripePaymentSheet` 可以正常导入
- [ ] 项目可以成功构建（⌘ + B）
- [ ] 可以运行项目（⌘ + R）

---

## 📚 相关资源

- [CocoaPods 官方文档](https://guides.cocoapods.org/)
- [Swift Package Manager 文档](https://swift.org/package-manager/)
- [Stripe iOS SDK GitHub](https://github.com/stripe/stripe-ios)

