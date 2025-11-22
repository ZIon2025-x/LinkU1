# Android Studio 测试指南

## 🚀 完整步骤

### 步骤 1: 打开 Android Studio

1. 启动 Android Studio
2. 如果是首次使用，完成初始设置向导

### 步骤 2: 创建新项目

1. 点击 `File > New > New Project`
2. 选择 `Empty Activity` 模板
3. 点击 `Next`
4. 填写项目信息：
   - **Name**: `LinkU`
   - **Package name**: `com.linku.app`
   - **Save location**: 选择一个文件夹（**不要**选择现有的 `android` 文件夹）
   - **Language**: `Kotlin`
   - **Minimum SDK**: `API 24: Android 7.0 (Nougat)`
   - **Build configuration language**: `Kotlin DSL (build.gradle.kts)`
5. 点击 `Finish`

### 步骤 3: 等待项目同步

- Android Studio 会自动下载依赖
- 等待 Gradle 同步完成（底部状态栏会显示进度）

### 步骤 4: 复制文件到项目

#### 4.1 复制 Kotlin 文件

1. 在 Android Studio 左侧项目导航器中，找到：
   ```
   app/src/main/java/com/linku/app/
   ```

2. 删除默认的 `MainActivity.kt`（如果存在）

3. 从项目的 `android/app/src/main/java/com/linku/app/` 文件夹中，复制以下目录到 Android Studio 项目中：
   - `data/` 文件夹及其所有内容
   - `ui/` 文件夹及其所有内容
   - `viewmodel/` 文件夹及其所有内容
   - `utils/` 文件夹及其所有内容
   - `MainActivity.kt`
   - `LinkUApplication.kt`

**方法**：
- 可以直接在文件管理器中复制粘贴
- 或者在 Android Studio 中右键点击 `com.linku.app` 包，选择 `New > Package` 创建目录，然后复制文件

#### 4.2 更新 build.gradle.kts

1. 打开 `app/build.gradle.kts`
2. 将项目中的 `android/app/build.gradle.kts` 内容复制过去，或手动添加以下依赖：

```kotlin
dependencies {
    // ... 现有依赖 ...
    
    // Compose
    implementation(platform("androidx.compose:compose-bom:2023.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    
    // ViewModel
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.6.2")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.6.2")
    
    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.5")
    
    // Network
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    
    // Image Loading
    implementation("io.coil-kt:coil-compose:2.5.0")
    
    // DataStore
    implementation("androidx.datastore:datastore-preferences:1.0.0")
}
```

3. 确保 `buildFeatures` 部分包含：
```kotlin
buildFeatures {
    compose = true
}
```

4. 确保 `compileOptions` 和 `kotlinOptions` 配置正确：
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlinOptions {
    jvmTarget = "17"
}
```

5. 点击 `Sync Now` 同步项目

#### 4.3 更新 AndroidManifest.xml

1. 打开 `app/src/main/AndroidManifest.xml`
2. 将项目中的 `AndroidManifest.xml` 内容复制过去，或确保包含：
   - 所有必要的权限
   - `LinkUApplication` 的配置
   - `MainActivity` 的配置

#### 4.4 更新 strings.xml

1. 打开 `app/src/main/res/values/strings.xml`
2. 确保包含：
```xml
<string name="app_name">LinkU</string>
```

### 步骤 5: 配置 API 地址

**重要**: 必须配置正确的 API 地址才能运行！

1. 打开 `app/src/main/java/com/linku/app/data/api/RetrofitClient.kt`
2. 确认 `BASE_URL` 已配置为：`"https://api.link2ur.com"`

WebSocket URL 已配置为：`"wss://api.link2ur.com/ws/chat/{userId}"`

**注意**: 如果代码中还是占位符，需要更新为上述地址。

### 步骤 6: 创建 Android 模拟器（如果没有真机）

**详细步骤请参考**: [EMULATOR_TEST_GUIDE.md](EMULATOR_TEST_GUIDE.md)

快速步骤：
1. 点击 `Tools > Device Manager`
2. 点击 `Create Device`
3. 选择设备型号（如 `Pixel 5`）
4. 选择系统镜像（推荐 `API 33` 或更高）
5. 点击 `Next` 然后 `Finish`
6. 启动模拟器（点击播放按钮 ▶️）

### 步骤 7: 运行项目

1. 在顶部工具栏选择创建的模拟器或连接的设备
2. 点击运行按钮（▶️）或按 `Shift + F10`
3. 等待应用编译和安装
4. 应用会在设备/模拟器上启动

### 步骤 8: 测试功能

#### 登录测试
- 使用现有的用户账号登录
- 如果登录成功，会自动跳转到主页

#### 功能测试
- 浏览任务列表
- 浏览跳蚤市场
- 查看消息（需要 WebSocket 连接）
- 查看个人中心

## 🐛 常见问题解决

### 问题 1: 编译错误 "Unresolved reference"

**解决方法**：
1. 点击 `File > Invalidate Caches / Restart`
2. 选择 `Invalidate and Restart`
3. 等待重新索引完成

### 问题 2: Gradle 同步失败

**解决方法**：
1. 检查网络连接
2. 检查 `build.gradle.kts` 中的依赖版本
3. 点击 `File > Sync Project with Gradle Files`

### 问题 3: 找不到某些类

**解决方法**：
1. 确保所有文件都已正确复制到项目中
2. 检查包名是否正确（`com.linku.app`）
3. 检查文件是否在正确的目录中

### 问题 4: API 请求失败

**解决方法**：
1. 检查 `RetrofitClient.kt` 中的 `BASE_URL` 是否正确
2. 检查网络权限是否已配置
3. 查看 Logcat 中的错误信息

### 问题 5: WebSocket 连接失败

**解决方法**：
1. 检查 `WebSocketService.kt` 中的 URL 是否正确
2. 检查是否已登录（需要 token）
3. 查看 Logcat 中的连接日志

## 📱 使用 Logcat 调试

1. 在 Android Studio 底部打开 `Logcat` 标签
2. 选择你的应用包名：`com.linku.app`
3. 可以查看：
   - 应用日志
   - 网络请求日志
   - 错误信息
   - WebSocket 连接状态

**过滤日志**：
- 在搜索框输入关键词，如 `WebSocket`、`API`、`Error`

## 🔍 检查清单

在运行前确保：

- [ ] 所有 Kotlin 文件已复制到项目
- [ ] `build.gradle.kts` 已更新并同步成功
- [ ] `AndroidManifest.xml` 已配置权限
- [ ] API 地址已更新（`RetrofitClient.kt`）
- [ ] WebSocket 地址已更新（`WebSocketService.kt`）
- [ ] 模拟器或真机已准备
- [ ] 项目可以编译（无红色错误）

## 💡 调试技巧

### 1. 使用断点
- 在代码行号左侧点击设置断点
- 运行应用，程序会在断点处暂停
- 可以查看变量值、调用栈等

### 2. 查看网络请求
- 在 Logcat 中搜索 `OkHttp` 可以看到所有网络请求
- 可以看到请求 URL、请求体、响应等

### 3. 查看 WebSocket 日志
- 在 Logcat 中搜索 `WebSocket` 可以看到连接状态和消息

### 4. 使用 Compose Preview
- 在 Compose 函数上右键，选择 `Preview`
- 可以快速预览 UI，无需运行整个应用

## 📝 快速测试流程

1. **创建项目** (5分钟)
2. **复制文件** (10分钟)
3. **配置 API** (2分钟)
4. **同步项目** (5分钟)
5. **运行测试** (2分钟)

**总计**: 约 25 分钟

## 🎯 预期结果

运行成功后，你应该看到：
1. 登录界面（首次运行）
2. 输入邮箱和密码
3. 点击登录
4. 如果 API 配置正确，会跳转到主页
5. 底部有 5 个导航标签：首页、任务、跳蚤市场、消息、我的

## ⚠️ 注意事项

1. **API 地址必须配置**，否则无法登录和加载数据
2. **首次运行可能需要较长时间**（下载依赖、编译等）
3. **如果遇到错误**，先查看 Logcat 中的错误信息
4. **网络权限已配置**，但需要确保设备/模拟器有网络连接

## 📚 相关文档

- [EMULATOR_TEST_GUIDE.md](EMULATOR_TEST_GUIDE.md) - **虚拟机测试详细指南** ⭐
- [SETUP.md](SETUP.md) - 详细设置说明
- [QUICK_START.md](QUICK_START.md) - 快速开始
- [README.md](README.md) - 项目说明

---

**提示**: 如果遇到任何问题，查看 Logcat 日志是最快的调试方法！

