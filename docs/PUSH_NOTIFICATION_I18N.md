# 推送通知国际化实现说明

## 概述

推送通知现在支持多语言，采用**客户端本地化**方案：
- 后端在推送 payload 中包含所有语言的文本
- iOS 端通过 Notification Service Extension 根据设备系统语言选择显示
- **不需要在数据库中存储设备语言**

## 架构设计

### 后端实现

1. **推送通知模板** (`backend/app/push_notification_templates.py`)
   - 定义了所有推送通知类型的多语言模板
   - 支持英文（en）和中文（zh）

2. **推送通知服务** (`backend/app/push_notification_service.py`)
   - 自动生成所有语言的本地化内容
   - 将本地化内容放入 payload 的 `custom.localized` 字段

3. **Payload 结构**
   ```json
   {
     "alert": {
       "title": "New Task Application",  // 系统默认显示（英文作为后备）
       "body": "..."
     },
     "custom": {
       "type": "task_application",
       "localized": {
         "en": {
           "title": "New Task Application",
           "body": "John applied for task「Help with moving」"
         },
         "zh": {
           "title": "新任务申请",
           "body": "John 申请了任务「搬家协助」"
         }
       },
       "task_id": 123,
       "application_id": 456
     }
   }
   ```

### iOS 端实现

1. **PushNotificationLocalizer** (`ios/link2ur/link2ur/Core/Utils/PushNotificationLocalizer.swift`)
   - 工具类，用于从 payload 中提取本地化内容
   - 根据设备系统语言选择对应文本

2. **Notification Service Extension**（需要创建）
   - 在通知显示前修改内容
   - 使用 `PushNotificationLocalizer` 获取本地化文本

## 工作流程

1. **后端发送推送**
   - 调用 `send_push_notification()` 时，如果 `title` 或 `body` 为 `None`
   - 自动从模板生成所有语言的本地化内容
   - 将本地化内容放入 payload 的 `custom.localized` 字段

2. **iOS 端接收推送**
   - Notification Service Extension 拦截推送
   - 读取 `custom.localized` 字段
   - 根据设备系统语言（`Locale.preferredLanguages`）选择对应文本
   - 修改通知的 `title` 和 `body` 后显示

3. **后备机制**
   - 如果 Extension 失败或超时，系统显示 `alert` 中的默认内容（英文）
   - 如果设备语言不在支持列表中，使用英文作为后备

## 优势

✅ **不需要数据库字段**：不需要存储设备语言  
✅ **不需要注册时发送语言**：推送 payload 已包含所有语言  
✅ **支持语言切换**：用户切换系统语言后，下次推送自动使用新语言  
✅ **向后兼容**：如果 Extension 失败，系统显示默认英文内容  
✅ **灵活性高**：可以轻松添加新语言支持

## 支持的推送通知类型

所有推送通知类型都已支持国际化：

- `task_application` - 新任务申请
- `application_accepted` - 申请被接受
- `application_rejected` - 申请被拒绝
- `application_withdrawn` - 申请撤回
- `task_completed` - 任务完成
- `task_confirmed` - 任务确认完成
- `task_rejected` - 任务拒绝
- `application_message` - 申请留言/议价
- `application_message_reply` - 申请留言回复
- `negotiation_rejected` - 议价被拒绝
- `message` - 私信消息
- `reply_post` - 论坛回复帖子
- `reply_reply` - 论坛回复评论
- `general` - 通用通知

## 使用示例

### 后端调用

```python
from app.push_notification_service import send_push_notification

# 自动生成多语言内容
send_push_notification(
    db=db,
    user_id=user_id,
    title=None,  # 从模板生成
    body=None,   # 从模板生成
    notification_type="task_application",
    data={"task_id": 123},
    template_vars={
        "applicant_name": "John",
        "task_title": "Help with moving"
    }
)
```

### iOS 端处理

在 Notification Service Extension 中：

```swift
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let localizedContent = PushNotificationLocalizer.localizeNotificationContent(request)
        contentHandler(localizedContent)
    }
}
```

## 添加新语言支持

1. 在 `push_notification_templates.py` 中为每个通知类型添加新语言模板
2. 在 `send_push_notification()` 中更新语言列表（目前是 `["en", "zh"]`）
3. 在 `PushNotificationLocalizer.deviceLanguage` 中添加语言检测逻辑

## 相关文件

- `backend/app/push_notification_templates.py` - 推送通知模板
- `backend/app/push_notification_service.py` - 推送通知服务
- `ios/link2ur/link2ur/Core/Utils/PushNotificationLocalizer.swift` - iOS 本地化工具
- `ios/link2ur/NOTIFICATION_SERVICE_EXTENSION_SETUP.md` - Extension 设置指南
