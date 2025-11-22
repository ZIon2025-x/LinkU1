# 如何在 Android Studio 中运行应用

## 🎯 运行应用的位置

### 方法 1: 使用顶部工具栏（最常用）

1. **选择设备**：
   - 在 Android Studio 顶部工具栏，找到设备选择下拉菜单
   - 点击下拉菜单，选择你的模拟器或真机
   - 如果没有设备，先创建模拟器（参考 `EMULATOR_TEST_GUIDE.md`）

2. **点击运行按钮**：
   - 在设备选择框旁边，有一个绿色的 **运行按钮（▶️）**
   - 点击这个按钮
   - 或者按快捷键：`Shift + F10`（Windows/Linux）或 `Ctrl + R`（Mac）

3. **等待构建和安装**：
   - Android Studio 会自动编译项目
   - 编译成功后会自动安装到设备
   - 应用会自动启动

### 方法 2: 使用菜单

1. 点击顶部菜单：`Run > Run 'app'`
2. 或者按快捷键：`Shift + F10`

### 方法 3: 右键运行

1. 在项目导航器中，右键点击 `app` 模块
2. 选择 `Run 'app'`

## 📍 运行按钮的位置图示

```
Android Studio 顶部工具栏：

[设备选择下拉菜单 ▼] [▶️ 运行] [🛑 停止] [🐛 调试] [其他工具...]
     ↑                    ↑
   选择设备             点击这里运行
```

## ⚠️ 如果构建失败

### 错误：需要 Compose Compiler 插件

如果看到错误：
```
Starting in Kotlin 2.0, the Compose Compiler Gradle plugin is required
```

**解决方法**：

1. 打开项目根目录的 `build.gradle.kts`（不是 app 目录下的）
2. 添加 Compose Compiler 插件：
```kotlin
plugins {
    id("com.android.application") version "8.1.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "1.9.20" apply false  // 添加这行
}
```

3. 打开 `app/build.gradle.kts`
4. 在 plugins 块中添加：
```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")  // 添加这行
    id("kotlin-kapt")
    id("kotlin-parcelize")
}
```

5. 删除 `composeOptions` 块（如果存在）：
```kotlin
// 删除这段代码
composeOptions {
    kotlinCompilerExtensionVersion = "1.5.3"
}
```

6. 点击 `Sync Now` 同步项目

### 其他常见错误

- **找不到设备**：先创建或启动模拟器
- **编译错误**：查看底部 Build 输出面板的错误信息
- **依赖下载失败**：检查网络连接，点击 `File > Sync Project with Gradle Files`

## ✅ 运行成功的标志

运行成功后，你会看到：

1. **底部 Build 输出**：显示 "BUILD SUCCESSFUL"
2. **模拟器/设备**：应用自动安装并启动
3. **应用界面**：在设备上看到应用的登录界面

## 🔄 重新运行

如果应用已经在运行，想要重新运行：

1. 点击 **停止按钮（🛑）** 停止当前运行
2. 再次点击 **运行按钮（▶️）**

或者直接点击运行按钮，Android Studio 会询问是否要替换当前运行的应用。

## 🐛 调试模式

如果想在调试模式下运行：

1. 点击 **调试按钮（🐛）**（运行按钮旁边）
2. 或者：`Run > Debug 'app'`
3. 或者快捷键：`Shift + F9`

在调试模式下，可以：
- 设置断点
- 查看变量值
- 单步执行代码

## 📱 运行到不同设备

如果想在多个设备上测试：

1. 在设备选择下拉菜单中，选择不同的设备
2. 点击运行按钮
3. 应用会安装到选中的设备

## 💡 快速提示

- **快捷键**：`Shift + F10` 快速运行
- **停止应用**：`Ctrl + F2` 或点击停止按钮
- **查看日志**：底部 `Logcat` 标签查看应用日志
- **查看构建输出**：底部 `Build` 标签查看编译信息

## 🎯 完整流程

1. ✅ 确保模拟器已启动（或真机已连接）
2. ✅ 在顶部工具栏选择设备
3. ✅ 点击运行按钮（▶️）
4. ✅ 等待构建完成
5. ✅ 应用自动启动

## 📚 相关文档

- [EMULATOR_TEST_GUIDE.md](EMULATOR_TEST_GUIDE.md) - 如何创建和使用模拟器
- [ANDROID_STUDIO_TEST_GUIDE.md](ANDROID_STUDIO_TEST_GUIDE.md) - 完整测试指南
- [SETUP.md](SETUP.md) - 项目设置

---

**提示**：如果遇到任何问题，查看底部 `Build` 输出面板的错误信息，这是最快的调试方法！

