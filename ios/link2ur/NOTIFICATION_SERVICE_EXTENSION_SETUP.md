# 推送通知本地化设置指南

## 概述

推送通知现在支持多语言，后端会在推送 payload 中包含所有语言的文本，iOS 端通过 Notification Service Extension 根据设备系统语言选择显示。

## 工作原理

1. **后端发送推送**：在 payload 的 `custom.localized` 字段中包含多语言内容
   ```json
   {
     "custom": {
       "localized": {
         "en": {"title": "New Task Application", "body": "..."},
         "zh": {"title": "新任务申请", "body": "..."}
       }
     }
   }
   ```

2. **iOS 端处理**：使用 Notification Service Extension 在通知显示前修改内容

## 设置步骤

### 1. 创建 Notification Service Extension

1. 在 Xcode 中，选择项目 → **File** → **New** → **Target**
2. 选择 **Notification Service Extension**
3. 命名为 `NotificationServiceExtension`
4. 确保 Bundle Identifier 为 `com.link2ur.NotificationServiceExtension`

### 2. 实现 NotificationService.swift

在 Notification Service Extension 的 `NotificationService.swift` 文件中：

```swift
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        
        // 使用 PushNotificationLocalizer 获取本地化内容
        let localizedContent = PushNotificationLocalizer.localizeNotificationContent(request)
        
        // 返回修改后的内容
        contentHandler(localizedContent)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // 如果处理超时，使用原始内容
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```

### 3. 添加本地化工具类

有两种方式添加 `PushNotificationLocalizer.swift`：

**方式 1：使用 Extension 目录中的文件（推荐）**

文件已创建在 `ios/NotificationServiceExtension/PushNotificationLocalizer.swift`，确保该文件已添加到 Extension target：
1. 在 Xcode 中，选择 `NotificationServiceExtension/PushNotificationLocalizer.swift` 文件
2. 在右侧面板的 **File Inspector**（⌘ + Option + 1）中，检查 **Target Membership**
3. 确保 `NotificationServiceExtension` target 已勾选

**方式 2：共享主 App 的文件**

如果想共享主 App 中的文件：
1. 在 Xcode 中，选择 `ios/link2ur/link2ur/Core/Utils/PushNotificationLocalizer.swift` 文件
2. 在右侧面板的 **File Inspector** 中，找到 **Target Membership** 部分
3. 同时勾选 `Link²Ur`（主 App）和 `NotificationServiceExtension` target

**注意**：如果编译时找不到 `PushNotificationLocalizer`，请检查：
- Extension target 的 **Build Phases** → **Compile Sources** 中是否包含该文件
- 确保文件路径正确

### 4. 配置 App Group（可选）

如果需要共享数据，可以配置 App Group：
1. 在 Xcode 中，选择主 App target → **Signing & Capabilities**
2. 点击 **+ Capability** → **App Groups**
3. 创建或选择 App Group（如 `group.com.link2ur.app`）
4. 在 Notification Service Extension target 中添加相同的 App Group

## 注意事项

1. **Notification Service Extension 有时间限制**：必须在 30 秒内完成处理
2. **如果 Extension 失败**：系统会显示原始通知（使用英文作为后备）
3. **测试**：使用 APNs 测试工具或后端发送测试推送来验证本地化是否正常工作

## 简化方案（如果不想使用 Extension）

如果不想创建 Notification Service Extension，也可以：
- 后端根据设备语言发送对应语言的推送（需要存储设备语言）
- 或者使用 APNs 的本地化功能（需要配置本地化字符串文件）

但使用 Extension 的方案更灵活，不需要存储设备语言，也支持用户随时切换语言。
