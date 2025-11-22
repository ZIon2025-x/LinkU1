# LinkU Android 应用 - 用户端

这是 LinkU 的 Android 原生应用项目（**用户端**），使用 Kotlin + Jetpack Compose 开发。

**注意**: 这是纯用户端应用，不包含客服功能和管理员功能。客服和管理员功能仅在 Web 端提供。

## 📋 项目结构

```
LinkU-Android/
├── app/
│   └── src/
│       └── main/
│           ├── java/com/linku/app/
│           │   ├── MainActivity.kt
│           │   ├── LinkUApplication.kt
│           │   ├── data/              # 数据层
│           │   ├── ui/                # UI层
│           │   ├── viewmodel/         # 视图模型
│           │   └── utils/             # 工具类
│           └── res/                    # 资源文件
└── build.gradle.kts
```

## 🚀 快速开始

### 环境要求

- Android Studio Hedgehog (2023.1.1) 或更高版本
- JDK 17 或更高版本
- Android SDK API 24+ (Android 7.0+)
- Kotlin 1.9.0 或更高版本

### 安装步骤

1. 在 Android Studio 中创建新项目
2. 选择 **Empty Activity** 模板
3. 配置项目信息：
   - **Name**: LinkU
   - **Package name**: com.linku.app
   - **Language**: Kotlin
   - **Minimum SDK**: API 24
4. 将 `android/app/` 下的文件复制到项目中
5. 配置 API 地址（在 `data/api/RetrofitClient.kt` 中）
6. 运行项目

### Windows 用户

如果你使用 Windows 系统：

1. **测试 API**: 使用 `test_api.py` 脚本测试后端 API
2. **测试 WebSocket**: 使用 `test_websocket.html` 测试 WebSocket 连接
3. **代码检查**: 检查 Kotlin 代码和项目结构
4. **Android Studio**: 在 Windows 上可以正常使用 Android Studio

详细说明请查看 [WINDOWS_TESTING_GUIDE.md](WINDOWS_TESTING_GUIDE.md)

## 📱 功能模块（用户端）

- ✅ 用户认证（登录/注册）
- ✅ 任务浏览与发布
- ✅ 跳蚤市场（浏览、发布、管理）
- ✅ 消息系统（WebSocket实时聊天）
- ✅ 个人中心（我的任务、我的发布、钱包）
- ✅ 设置与关于
- ✅ 多语言支持（中英文）

**不包含的功能**:
- ❌ 客服功能（仅在Web端）
- ❌ 管理员功能（仅在Web端）

## 🔧 技术栈

- **语言**: Kotlin 1.9+
- **UI框架**: Jetpack Compose
- **架构**: MVVM + Kotlin Coroutines + Flow
- **网络**: Retrofit + OkHttp
- **数据持久化**: DataStore / Room Database
- **依赖注入**: 手动依赖注入（可升级到 Hilt）

## 📝 注意事项

1. **首次运行前需要配置 API 基础URL**（在 `data/api/RetrofitClient.kt` 中）
2. 需要配置正确的权限（AndroidManifest.xml）
3. 推送通知需要配置 Firebase（可选）
4. WebSocket 连接需要有效的认证token（登录后自动连接）
5. **这是用户端应用**，不包含客服和管理员功能

## 📚 相关文档

- [SETUP.md](SETUP.md) - Android Studio 设置指南
- [QUICK_START.md](QUICK_START.md) - 快速开始指南
- [ARCHITECTURE.md](ARCHITECTURE.md) - 架构说明
- [WINDOWS_TESTING_GUIDE.md](WINDOWS_TESTING_GUIDE.md) - Windows 测试指南

