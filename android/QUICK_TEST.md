# Android Studio 快速测试指南

## ⚡ 5分钟快速测试

### 1. 创建项目（2分钟）

```
File > New > New Project
→ Empty Activity
→ Name: LinkU
→ Package: com.linku.app
→ Language: Kotlin
→ Minimum SDK: API 24
→ Finish
```

### 2. 复制文件（2分钟）

从 `android/app/src/main/java/com/linku/app/` 复制到 Android Studio 项目的 `app/src/main/java/com/linku/app/`：

- ✅ `MainActivity.kt`
- ✅ `LinkUApplication.kt`
- ✅ `data/` 文件夹
- ✅ `ui/` 文件夹
- ✅ `viewmodel/` 文件夹
- ✅ `utils/` 文件夹

### 3. 更新 build.gradle.kts（1分钟）

打开 `app/build.gradle.kts`，添加依赖（参考 `SETUP.md` 或项目中的 `build.gradle.kts`）

点击 `Sync Now`

### 4. 配置 API（30秒）

打开 `data/api/RetrofitClient.kt`，更新 `BASE_URL`

### 5. 运行（30秒）

选择模拟器 → 点击运行按钮（▶️）

## 🎯 最小测试

如果只想快速测试 UI，可以：

1. 暂时注释掉 API 调用
2. 使用模拟数据
3. 先测试 UI 界面

## 📱 测试步骤

1. **登录界面** - 检查 UI 是否正常显示
2. **点击登录** - 查看是否有错误提示
3. **如果 API 配置正确** - 应该能登录并跳转
4. **浏览各个页面** - 检查导航是否正常

## 🐛 快速排查

**如果编译失败**：
- 检查 `build.gradle.kts` 是否同步成功
- 检查所有文件是否已复制

**如果运行崩溃**：
- 查看 Logcat 错误信息
- 检查 API 地址是否配置

**如果无法登录**：
- 检查 API 地址是否正确
- 检查网络权限
- 查看 Logcat 中的网络请求

