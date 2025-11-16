# 图片上传逻辑检查报告

## 检查时间
2024年检查

## 图片上传接口分类

### 1. 公开图片上传 (`/api/upload/public-image`)
用于需要公开访问的图片，支持分类和资源ID参数。

#### ✅ 已正确配置的位置：

1. **TaskExpertDashboard.tsx - 任务达人头像**
   - 位置：`handleUploadAvatar` 函数
   - 配置：`category=expert_avatar&resource_id=${expertId}`
   - 文件夹：`/data/uploads/public/images/expert_avatars/{expert_id}/`
   - 命名：`expert_avatar_{uuid}.{ext}`
   - 状态：✅ 正确

2. **TaskExpertDashboard.tsx - 服务图片**
   - 位置：`ServiceEditModal` 组件
   - 配置：`category=service_image&resource_id=${expertId}`
   - 文件夹：`/data/uploads/public/images/service_images/{expert_id}/`
   - 命名：`service_image_{uuid}.{ext}`
   - 状态：✅ 正确

3. **AdminDashboard.tsx - 任务达人头像**
   - 位置：任务达人管理表单
   - 配置：`category=expert_avatar&resource_id=${expertId}`
   - 文件夹：`/data/uploads/public/images/expert_avatars/{expert_id}/`
   - 命名：`expert_avatar_{uuid}.{ext}`
   - 状态：✅ 正确

4. **PublishTask.tsx - 任务图片**
   - 位置：`handleImageUpload` 函数
   - 配置：默认 `category=public`，无 `resource_id`（使用临时文件夹）
   - 文件夹：`/data/uploads/public/images/public/temp_{user_id}/`（临时）
   - 命名：`public_{uuid}.{ext}`
   - 迁移：任务创建成功后自动迁移到 `{task_id}` 文件夹
   - 状态：✅ 正确（使用临时文件夹，后续自动迁移）

### 2. 私有图片上传 (`/api/upload/image`)
用于聊天消息中的私密图片，支持按任务ID或聊天ID分类存储。

#### ✅ 已正确配置的位置：

1. **Message.tsx - 任务聊天图片**
   - 位置：`sendImage` 和 `sendImageFromModal` 函数
   - 接口：`/api/upload/image?task_id={task_id}`（任务聊天）
   - 接口：`/api/upload/image?chat_id={chat_id}`（客服聊天）
   - 系统：私有图片系统 (`image_system.py`)
   - 文件夹：
     - 任务聊天：`/data/uploads/private_images/tasks/{task_id}/`
     - 客服聊天：`/data/uploads/private_images/chats/{chat_id}/`
   - 命名：`{user_id}_{timestamp}_{random}.{ext}`
   - 状态：✅ 已更新（按任务ID或聊天ID分类）

2. **MessageInput.tsx - 消息输入组件**
   - 位置：`handleImageUpload` 函数
   - 接口：`/api/upload/image?task_id={task_id}` 或 `/api/upload/image?chat_id={chat_id}`
   - 系统：私有图片系统
   - 状态：✅ 已更新（支持传递taskId和chatId参数）

## 文件结构总结

```
/data/uploads/
├── public/
│   └── images/
│       ├── expert_avatars/          # 任务达人头像
│       │   └── {expert_id}/
│       │       └── expert_avatar_{uuid}.{ext}
│       ├── service_images/          # 服务图片
│       │   └── {expert_id}/
│       │       └── service_image_{uuid}.{ext}
│       └── public/                   # 任务相关图片
│           ├── {task_id}/           # 正式任务图片
│           │   └── public_{uuid}.{ext}
│           └── temp_{user_id}/      # 临时图片（发布新任务时）
│               └── public_{uuid}.{ext}
└── private_images/                  # 私密图片（聊天消息）
    ├── tasks/                        # 任务聊天图片
    │   └── {task_id}/
    │       └── {user_id}_{timestamp}_{random}.{ext}
    └── chats/                        # 客服聊天图片
        └── {chat_id}/
            └── {user_id}_{timestamp}_{random}.{ext}
```

## 自动迁移机制

- **临时图片迁移**：任务创建成功后，自动将 `temp_{user_id}` 文件夹中的图片迁移到 `{task_id}` 文件夹
- **清理机制**：定期清理超过24小时未使用的临时图片

## 结论

所有图片上传逻辑已正确配置：
- ✅ 任务达人相关图片按任务达人ID分类
- ✅ 用户上传的任务图片按任务ID分类（临时图片会自动迁移）
- ✅ 任务聊天中的私密图片按任务ID分类存储
- ✅ 客服聊天中的私密图片按聊天ID（chat_id）分类存储
- ✅ 所有图片都有清晰的分类和命名规则，便于管理和清理

