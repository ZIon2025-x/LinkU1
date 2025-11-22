# Android 项目设置指南

## 📋 在 Android Studio 中创建项目

### 步骤 1: 创建新项目

1. 打开 Android Studio
2. 选择 `File > New > New Project`
3. 选择 `Empty Activity`
4. 填写项目信息：
   - **Name**: LinkU
   - **Package name**: com.linku.app
   - **Save location**: 选择保存位置
   - **Language**: Kotlin
   - **Minimum SDK**: API 24 (Android 7.0)
   - **Build configuration language**: Kotlin DSL
5. 点击 `Finish`

### 步骤 2: 配置 build.gradle.kts

1. 打开 `app/build.gradle.kts`
2. 将项目中的 `build.gradle.kts` 内容复制过去，或手动添加依赖
3. 同步项目（Sync Now）

### 步骤 3: 添加文件到项目

1. 在 Android Studio 项目导航器中，找到 `app/src/main/java/com/linku/app/`
2. 创建以下目录结构：
   ```
   com/linku/app/
   ├── data/
   │   ├── models/
   │   ├── api/
   │   └── websocket/
   ├── ui/
   │   ├── screens/
   │   │   ├── login/
   │   │   ├── home/
   │   │   ├── tasks/
   │   │   ├── fleamarket/
   │   │   ├── message/
   │   │   └── profile/
   │   ├── navigation/
   │   └── theme/
   ├── viewmodel/
   └── utils/
   ```
3. 将项目中的 Kotlin 文件复制到对应目录

### 步骤 4: 验证 API 地址配置

API 地址已配置为：`https://api.link2ur.com`
WebSocket 地址已配置为：`wss://api.link2ur.com`

如果需要修改，请更新：
1. `data/api/RetrofitClient.kt` 中的 `BASE_URL`
2. `data/websocket/WebSocketService.kt` 中的 WebSocket URL

### 步骤 5: 配置权限

确保 `AndroidManifest.xml` 中包含所有必要的权限（已在代码中配置）。

### 步骤 6: 更新 MainActivity

确保 `MainActivity.kt` 使用 Compose 并调用 `AppNavigation()`。

### 步骤 7: 运行项目

1. 选择目标设备（模拟器或真机）
2. 点击运行按钮（▶️）或按 `Shift+F10`
3. 首次运行会显示登录界面

## 🔧 项目配置

### 必需依赖

项目使用以下主要依赖：
- Jetpack Compose
- Retrofit (网络请求)
- OkHttp (HTTP客户端和WebSocket)
- Kotlin Coroutines
- ViewModel

所有依赖已在 `build.gradle.kts` 中配置。

### 权限说明

- **INTERNET**: 网络请求
- **ACCESS_NETWORK_STATE**: 检查网络状态
- **ACCESS_FINE_LOCATION**: 定位服务
- **CAMERA**: 相机拍照
- **READ_EXTERNAL_STORAGE**: 读取相册（API 32及以下）
- **READ_MEDIA_IMAGES**: 读取相册（API 33+）
- **POST_NOTIFICATIONS**: 推送通知（API 33+）

## 🐛 常见问题

**Q: 编译错误 "Cannot resolve symbol 'X'"**
A: 确保所有文件都已添加到项目，并且依赖已同步

**Q: WebSocket 连接失败**
A: 检查 API 地址是否正确，以及网络权限是否配置

**Q: 图片加载失败**
A: 确保添加了 Coil 依赖，并检查图片 URL 是否正确

**Q: 导航不工作**
A: 确保添加了 Navigation Compose 依赖，并检查路由配置

## 📝 下一步

1. 完善各个 Screen 的实现
2. 添加更多 ViewModel
3. 实现图片选择功能
4. 完善 WebSocket 消息处理
5. 添加更多业务逻辑

