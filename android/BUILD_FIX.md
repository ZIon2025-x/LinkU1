# 构建错误修复说明

## 问题

错误信息：
```
Plugin [id: 'org.jetbrains.kotlin.plugin.compose', version: '1.9.20', apply: false] was not found
```

## 原因

`org.jetbrains.kotlin.plugin.compose` 插件只在 **Kotlin 2.0+** 版本中可用。当前项目使用的是 Kotlin 1.9.20，所以找不到这个插件。

## 解决方案

对于 Kotlin 1.9.20，应该使用 `composeOptions` 而不是 Compose Compiler 插件。

### 已修复的文件

1. **`build.gradle.kts`** (项目根目录)
   - 移除了 `id("org.jetbrains.kotlin.plugin.compose")` 插件

2. **`app/build.gradle.kts`**
   - 移除了 `id("org.jetbrains.kotlin.plugin.compose")` 插件
   - 添加了 `composeOptions` 配置：
     ```kotlin
     composeOptions {
         kotlinCompilerExtensionVersion = "1.5.3"
     }
     ```

## 验证

修复后，应该可以正常构建项目了。如果还有问题，请：

1. 点击 `File > Sync Project with Gradle Files`
2. 或者点击 `Build > Clean Project`，然后 `Build > Rebuild Project`

## 注意事项

- Kotlin 1.9.20 使用 `composeOptions`
- Kotlin 2.0+ 使用 `org.jetbrains.kotlin.plugin.compose` 插件
- 当前配置适用于 Kotlin 1.9.20

