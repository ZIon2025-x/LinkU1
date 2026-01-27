# R2 存储内容说明

## 📋 概述

当配置 `STORAGE_BACKEND=r2` 后，以下内容会通过 `ImageUploadService` 上传到 Cloudflare R2 存储。

## ✅ 会上传到 R2 的内容

### 1. 公开图片（通过 ImageUploadService）

所有通过 `/api/v2/upload/image` 接口上传的公开图片都会上传到 R2：

#### 1.1 任务图片 (TASK)
- **路径**: `public/images/public/{resource_id}/{filename}`
- **用途**: 任务详情页展示的图片
- **上传接口**: `/api/v2/upload/image?category=task`
- **特点**: 
  - 最大 10MB
  - 自动压缩（质量 85%）
  - 最大尺寸 2048px
  - 自动旋转（根据 EXIF）
  - 移除元数据

#### 1.2 Banner 图片 (BANNER)
- **路径**: `public/images/banner/{resource_id}/{filename}`
- **用途**: 首页/活动页 Banner
- **上传接口**: `/api/v2/upload/image?category=banner`
- **特点**:
  - 最大 5MB
  - 压缩质量 90%
  - 最大尺寸 1920px

#### 1.3 榜单封面 (LEADERBOARD_COVER)
- **路径**: `public/images/leaderboard_covers/{resource_id}/{filename}`
- **用途**: 自定义榜单封面图
- **上传接口**: `/api/v2/upload/image?category=leaderboard_cover`
- **特点**:
  - 最大 5MB
  - 最大尺寸 1280px

#### 1.4 竞品图片 (LEADERBOARD_ITEM)
- **路径**: `public/images/leaderboard_items/{resource_id}/{filename}`
- **用途**: 榜单中的竞品图片
- **上传接口**: `/api/v2/upload/image?category=leaderboard_item`
- **特点**:
  - 最大 5MB
  - 最大尺寸 1280px
  - **会生成缩略图**（thumb 尺寸）

#### 1.5 任务达人头像 (EXPERT_AVATAR)
- **路径**: `public/images/expert_avatars/{resource_id}/{filename}`
- **用途**: 任务达人的头像
- **上传接口**: `/api/v2/upload/image?category=expert_avatar`
- **特点**:
  - 最大 2MB
  - 最大尺寸 512px

#### 1.6 服务图片 (SERVICE_IMAGE)
- **路径**: `public/images/service_images/{resource_id}/{filename}`
- **用途**: 客服系统服务相关图片
- **上传接口**: `/api/v2/upload/image?category=service_image`
- **特点**:
  - 最大 5MB
  - 最大尺寸 1280px

#### 1.7 跳蚤市场商品图片 (FLEA_MARKET)
- **路径**: `flea_market/{resource_id}/{filename}`
- **用途**: 跳蚤市场商品图片
- **上传接口**: `/api/flea-market/upload-image`
- **特点**:
  - 最大 5MB
  - 自动压缩

### 2. 缩略图

对于需要缩略图的图片类别（如 `LEADERBOARD_ITEM`），系统会自动生成并上传缩略图：
- **路径**: `{category}/{resource_id}/thumb_{filename}`
- **特点**: 自动生成，无需手动上传

## ❌ 不会上传到 R2 的内容

### 1. 私密图片和文件（使用本地存储）

以下内容**不会**上传到 R2，而是保存在本地文件系统：

#### 1.1 任务聊天图片
- **存储位置**: `/data/uploads/private_images/tasks/{task_id}/{image_id}.jpg`
- **上传接口**: `/api/upload/image?task_id={task_id}`
- **系统**: `PrivateImageSystem`（直接保存到本地）
- **原因**: 需要签名 URL 访问，涉及权限控制

#### 1.2 客服聊天图片
- **存储位置**: `/data/uploads/private_images/chats/{chat_id}/{image_id}.jpg`
- **上传接口**: `/api/upload/image?chat_id={chat_id}`
- **系统**: `PrivateImageSystem`（直接保存到本地）

#### 1.3 任务聊天文件
- **存储位置**: `/data/uploads/private_files/tasks/{task_id}/{file_id}.{ext}`
- **上传接口**: `/api/upload/file?task_id={task_id}`
- **系统**: `PrivateFileSystem`（直接保存到本地）
- **支持格式**: 图片、PDF、Word、文本等

#### 1.4 客服聊天文件
- **存储位置**: `/data/uploads/private_files/chats/{chat_id}/{file_id}.{ext}`
- **上传接口**: `/api/upload/file?chat_id={chat_id}`
- **系统**: `PrivateFileSystem`（直接保存到本地）

**为什么私密文件不上传到 R2？**
- 需要签名 URL 和权限验证
- 涉及用户隐私，需要更严格的控制
- 当前实现使用本地文件系统 + 签名 URL 机制

## 📊 存储路径结构（R2）

在 R2 存储桶中的目录结构：

```
link2ur/
├── public/
│   └── images/
│       ├── public/              # 任务图片
│       │   └── {task_id}/
│       ├── banner/              # Banner
│       │   └── {banner_id}/
│       ├── leaderboard_covers/ # 榜单封面
│       │   └── {leaderboard_id}/
│       ├── leaderboard_items/   # 竞品图片
│       │   └── {item_id}/
│       ├── expert_avatars/       # 任务达人头像
│       │   └── {user_id}/
│       └── service_images/      # 服务图片
│           └── {resource_id}/
└── flea_market/                 # 跳蚤市场
    └── {item_id}/
```

## 🔗 URL 格式

配置 R2 后，公开图片的 URL 格式为：
```
https://cdn.link2ur.com/{storage_path}
```

例如：
- 任务图片: `https://cdn.link2ur.com/public/images/public/12345/uuid.jpg`
- Banner: `https://cdn.link2ur.com/public/images/banner/1/uuid.jpg`
- 跳蚤市场: `https://cdn.link2ur.com/flea_market/67890/uuid.jpg`

## 📝 注意事项

1. **私密文件不上传**: 所有私密图片和文件（任务聊天、客服聊天）仍使用本地存储
2. **自动压缩**: 所有公开图片都会自动压缩和优化
3. **缩略图**: 部分类别会自动生成缩略图
4. **临时文件**: 创建任务时的临时图片会先上传到 `temp_{user_id}` 目录，任务创建成功后移动到正式目录

## 🔄 迁移私密文件到 R2（未来可选）

如果需要将私密文件也迁移到 R2，需要：
1. 修改 `PrivateImageSystem` 和 `PrivateFileSystem`
2. 使用存储后端替代本地文件保存
3. 确保签名 URL 机制与 R2 兼容
4. 考虑权限控制和访问安全
