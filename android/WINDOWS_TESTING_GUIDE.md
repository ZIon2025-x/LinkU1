# Windows 上测试 Android 应用指南

## ✅ 好消息

**Android 应用可以在 Windows 上正常开发和测试！**

与 iOS 不同，Android Studio 完全支持 Windows 系统。

## 🚀 快速开始

### 1. 安装 Android Studio

1. 下载 Android Studio: https://developer.android.com/studio
2. 安装 Android Studio（包含 JDK）
3. 打开 Android Studio，完成初始设置

### 2. 创建项目

按照 `SETUP.md` 中的步骤创建项目并添加文件。

### 3. 运行项目

1. 创建 Android 模拟器（AVD）
2. 或连接真实 Android 设备
3. 点击运行按钮（▶️）

## 📱 测试步骤

### 1. 创建模拟器

1. 打开 Android Studio
2. 点击 `Tools > Device Manager`
3. 点击 `Create Device`
4. 选择设备型号（如 Pixel 5）
5. 选择系统镜像（API 33 或更高）
6. 完成创建

### 2. 运行应用

1. 选择创建的模拟器
2. 点击运行按钮
3. 应用会在模拟器中启动

### 3. 真机测试

1. 在手机上启用"开发者选项"
2. 启用"USB调试"
3. 用USB连接手机到电脑
4. 在 Android Studio 中选择设备
5. 运行应用

## 🔧 测试工具

### 使用 Logcat 查看日志

- 在 Android Studio 底部打开 `Logcat` 标签
- 可以查看应用日志、网络请求、错误信息

### 使用 API 测试脚本

可以使用项目根目录的 `test_api.py` 测试后端 API。

## 📋 检查清单

- [ ] Android Studio 已安装
- [ ] JDK 17+ 已配置
- [ ] Android SDK 已安装
- [ ] 模拟器或真机已准备
- [ ] API 地址已配置
- [ ] 权限已配置

## 💡 提示

- Android 应用开发完全支持 Windows
- 可以使用模拟器或真机测试
- Logcat 是调试的好工具
- 可以使用 Postman 测试 API

