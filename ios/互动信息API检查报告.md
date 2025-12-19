# 互动信息API和数据类型检查报告

## 检查时间
2025-12-17

## 问题发现

### 1. 后端有两个独立的通知系统

#### 1.1 普通通知系统 (`NotificationOut`)
- **API端点**: `/api/users/notifications`
- **Schema**: `NotificationOut`
- **字段结构**:
  ```python
  {
    "id": int,
    "user_id": str,
    "type": str,           # 通知类型
    "title": str,          # 通知标题
    "content": str,        # 通知内容
    "related_id": int,     # 关联ID
    "is_read": int,        # 是否已读 (0/1)
    "created_at": datetime
  }
  ```
- **用途**: 主要用于任务相关的通知（task_cancelled, task_application等）

#### 1.2 论坛通知系统 (`ForumNotificationOut`)
- **API端点**: `/api/forum/notifications`
- **Schema**: `ForumNotificationOut`
- **字段结构**:
  ```python
  {
    "id": int,
    "notification_type": str,  # 注意：字段名是 notification_type，不是 type
    "target_type": str,        # "post" 或 "reply"
    "target_id": int,          # 注意：字段名是 target_id，不是 related_id
    "post_id": int,            # 帖子ID（当target_type="reply"时）
    "from_user": UserInfo,     # 发送者信息
    "is_read": bool,           # 注意：是 bool，不是 int
    "created_at": datetime
  }
  ```
- **通知类型**: 
  - `reply_post` - 回复帖子
  - `reply_reply` - 回复回复
  - `like_post` - 点赞帖子
  - `like_reply` - 点赞回复
  - `pin_post` - 置顶帖子
  - `feature_post` - 加精帖子
- **用途**: 专门用于论坛相关的通知

### 2. iOS端当前实现的问题

#### 2.1 只使用了普通通知API
- iOS端目前只调用了 `/api/users/notifications`
- 这个API不返回论坛和排行榜相关的通知
- 因此互动信息页面看不到论坛相关的通知

#### 2.2 数据模型不匹配
- iOS端的 `SystemNotification` 模型期望字段：
  - `type` (String?)
  - `title` (String)
  - `content` (String)
  - `relatedId` (Int?)
  - `isRead` (Int?)
  
- 论坛通知的字段：
  - `notification_type` (不是 `type`)
  - 没有 `title` 和 `content` 字段
  - `target_id` (不是 `related_id`)
  - `is_read` (Bool，不是 Int)

#### 2.3 筛选逻辑不匹配
- iOS端筛选条件：
  ```swift
  type == "forum_reply" ||
  type == "forum_like" ||
  type == "forum_favorite" ||
  type == "forum_mention" ||
  type.hasPrefix("forum_")
  ```
  
- 后端实际的通知类型：
  - `reply_post` (不是 `forum_reply`)
  - `reply_reply`
  - `like_post` (不是 `forum_like`)
  - `like_reply`
  - 没有 `forum_favorite` 和 `forum_mention`

### 3. 排行榜通知

- **未找到**: 后端代码中没有找到排行榜相关的通知实现
- **可能原因**: 
  - 排行榜通知功能尚未实现
  - 或者使用其他方式处理（如实时推送）

## 解决方案建议

### 方案1: 使用论坛通知API（推荐）

1. **添加论坛通知API调用**
   - 在 `NotificationViewModel` 中添加 `loadForumNotifications()` 方法
   - 调用 `/api/forum/notifications` 端点

2. **创建论坛通知数据模型**
   ```swift
   struct ForumNotification: Codable, Identifiable {
       let id: Int
       let notificationType: String  // notification_type
       let targetType: String        // target_type
       let targetId: Int             // target_id
       let postId: Int?              // post_id
       let fromUser: User?           // from_user
       let isRead: Bool              // is_read (注意是Bool)
       let createdAt: String        // created_at
   }
   ```

3. **合并两个通知列表**
   - 在 `InteractionMessageView` 中同时加载普通通知和论坛通知
   - 将论坛通知转换为统一的显示格式

### 方案2: 修改后端统一通知系统

1. **后端修改**
   - 将论坛通知也写入普通通知表
   - 使用统一的 `type` 字段命名（如 `forum_reply`, `forum_like`）
   - 添加 `title` 和 `content` 字段

2. **iOS端修改**
   - 保持现有实现
   - 更新筛选逻辑以匹配新的通知类型

### 方案3: 创建统一的通知适配器

1. **创建通知适配器类**
   - 将 `ForumNotification` 转换为 `SystemNotification` 格式
   - 生成 `title` 和 `content` 字段

2. **统一显示**
   - 在UI层统一显示两种通知

## 推荐实现方案

**推荐使用方案1**，因为：
1. 不需要修改后端代码
2. 可以立即使用现有的论坛通知功能
3. 保持两个通知系统的独立性

## 需要修改的文件

1. `link2ur/link2ur/ViewModels/NotificationViewModel.swift`
   - 添加 `loadForumNotifications()` 方法

2. `link2ur/link2ur/Models/Notification.swift`
   - 添加 `ForumNotification` 和 `ForumNotificationListResponse` 模型

3. `link2ur/link2ur/Views/Message/MessageView.swift`
   - 修改 `InteractionMessageView` 以同时加载两种通知
   - 更新筛选和跳转逻辑

4. `link2ur/link2ur/Services/APIService+Endpoints.swift`
   - 添加 `getForumNotifications()` 方法

## 注意事项

1. **排行榜通知**: 如果后端没有实现，需要与后端团队确认是否需要添加
2. **通知类型映射**: 需要将后端的 `reply_post` 等类型映射到iOS端的显示逻辑
3. **跳转逻辑**: 论坛通知使用 `target_id` 和 `post_id`，需要相应调整跳转逻辑

