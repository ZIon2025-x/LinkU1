# Notification Service Extension — 手动添加到 Xcode

扩展源文件已就绪，需在 Xcode 中创建 Target 并关联。

## 步骤

### 1. 打开项目
```bash
cd link2ur/ios
open Runner.xcworkspace
```

### 2. 新建 Target
- **File** → **New** → **Target**
- 选择 **Notification Service Extension**
- 点击 **Next**
- **Product Name**: `NotificationServiceExtension`
- **Language**: Swift
- **Include Tests**: 取消勾选
- 点击 **Finish**
- 弹出 “Activate scheme?” 时选择 **Cancel**

### 3. 替换自动生成的文件
- 删除 Xcode 自动生成的 `NotificationService.swift`
- 将本目录下的 `NotificationService.swift` 和 `PushNotificationLocalizer.swift` 拖入 **NotificationServiceExtension** 群组（或右键 → Add Files to "Runner"）
- 勾选 **Copy items if needed**，**Add to targets** 勾选 **NotificationServiceExtension**

### 4. 配置 Info.plist
- 选中 NotificationServiceExtension target → **Build Settings**
- 搜索 `Info.plist`
- 将 **Info.plist File** 设为 `NotificationServiceExtension/Info.plist`

### 5. 配置 Entitlements
- 选中 NotificationServiceExtension target → **Signing & Capabilities**
- 添加 **Push Notifications** capability（若尚未添加）
- 在 **Build Settings** 中搜索 `Code Signing Entitlements`
- 设为 `NotificationServiceExtension/NotificationServiceExtension.entitlements`

### 6. 设置 Deployment Target
- NotificationServiceExtension 的 **iOS Deployment Target** 应与 Runner 一致（如 16.0）

### 7. 构建顺序
- 选中 Runner target → **Build Phases**
- 确保 **Embed Foundation Extensions** 在 **Run Script**（Flutter）之上；若无此阶段，点 **+** → **New Copy Files Phase** → 选择 **Frameworks**，将 NotificationServiceExtension.appex 拖入

### 8. 验证
```bash
flutter build ios --no-codesign
```

## 后端 Push Payload 格式

本地化需在 payload 中包含 `localized` 或 `custom.localized`：

```json
{
  "aps": {
    "alert": { "title": "Fallback", "body": "Fallback" },
    "sound": "default"
  },
  "localized": {
    "en": { "title": "New message", "body": "You have a new chat message" },
    "zh": { "title": "新消息", "body": "您有一条新的聊天消息" }
  }
}
```
