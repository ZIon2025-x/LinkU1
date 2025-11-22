# Android 应用快速开始指南 - 用户端

> **注意**: 这是 LinkU 的用户端 Android 应用，不包含客服和管理员功能。

## 🚀 快速测试步骤

### 1. 在 Android Studio 中打开项目

按照 `SETUP.md` 中的步骤创建项目并添加文件。

### 2. 配置 API 地址

**重要**: 在运行前必须配置正确的 API 地址！

打开 `app/src/main/java/com/linku/app/data/api/RetrofitClient.kt`，确认已配置：

```kotlin
private const val BASE_URL = "https://api.link2ur.com"
```

WebSocket URL 已配置为：`"wss://api.link2ur.com/ws/chat/{userId}"`

### 3. 配置权限

确保 `AndroidManifest.xml` 中包含所有必要的权限（已在代码中配置）。

### 4. 运行项目

1. 选择目标设备（模拟器或真机）
2. 点击运行按钮（▶️）
3. 首次运行会显示登录界面

### 5. 测试功能

#### 登录测试
- 使用现有的用户账号登录
- 登录成功后会自动连接 WebSocket

#### 功能测试清单（用户端功能）
- ✅ 登录/注册
- ✅ 任务列表浏览
- ✅ 任务详情查看
- ✅ 跳蚤市场浏览
- ✅ 消息收发（需要 WebSocket 连接）
- ✅ 个人中心（我的任务、我的发布、钱包）
- ✅ 设置与关于

**不包含的功能**:
- ❌ 客服功能
- ❌ 管理员功能

## 🔧 开发环境要求

- Android Studio Hedgehog (2023.1.1) 或更高版本
- JDK 17 或更高版本
- Android SDK API 24+ (Android 7.0+)
- Kotlin 1.9.0 或更高版本

## 📱 功能状态

### ✅ 已实现
- 应用架构和导航
- 用户认证（登录/注册）
- API 服务基础框架
- WebSocket 服务
- 基础视图（首页、任务、跳蚤市场、消息、个人中心）
- 数据模型

### 🚧 待完善
- 完整的 API 端点实现
- 图片上传功能
- 推送通知集成
- 定位服务
- 更多业务逻辑

## 🐛 常见问题

### WebSocket 连接失败
- 检查 API 地址是否正确
- 检查网络连接
- 查看 Logcat 日志

### API 请求失败
- 检查 `BASE_URL` 配置
- 检查网络权限
- 查看错误日志

### 编译错误
- 确保所有文件都已添加到项目
- 检查依赖是否已同步
- 清理构建缓存：`Build > Clean Project`

## 📝 下一步开发

1. 完善各个 API 端点调用
2. 实现图片选择器
3. 完善消息功能
4. 添加推送通知
5. 优化 UI/UX

## 💡 提示

- 使用 Android Studio 的断点调试功能
- 查看 Logcat 网络请求日志
- 使用 Compose Preview 快速预览界面
- 定期测试 WebSocket 连接

