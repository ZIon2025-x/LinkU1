# 图片上传系统分析与优化建议

## 当前系统架构

### 图片存储结构
```
/data/uploads/
├── public/images/                  # 公开图片
│   ├── public/                     # 任务图片
│   │   ├── {task_id}/             # 按任务ID分类
│   │   └── temp_{user_id}/        # 临时目录（发布任务前）
│   ├── banner/                     # Banner 图片
│   │   ├── {banner_id}/           # 按 Banner ID 分类
│   │   └── temp_{admin_id}/       # 临时目录（创建 Banner 前）
│   ├── leaderboard_covers/         # 榜单封面
│   │   ├── {leaderboard_id}/      # 按榜单ID分类
│   │   └── temp_{user_id}/        # 临时目录（审核前）
│   ├── leaderboard_items/          # 竞品图片
│   │   ├── {item_id}/             # 按竞品ID分类
│   │   └── temp_{user_id}/        # 临时目录（创建竞品前）
│   ├── expert_avatars/             # 任务达人头像
│   │   └── {expert_id}/           # 按达人ID分类
│   └── service_images/             # 服务图片
│       └── {expert_id}/           # 按达人ID分类
├── flea_market/                    # 跳蚤市场商品图片
│   ├── {item_id}/                 # 按商品ID分类
│   └── temp_{user_id}/            # 临时目录（创建商品前）
├── private_images/                 # 私密图片（聊天图片）
│   ├── tasks/{task_id}/           # 任务聊天图片
│   └── chats/{chat_id}/           # 客服聊天图片
└── private_files/                  # 私密文件（聊天附件）
    ├── tasks/{task_id}/           # 任务聊天附件
    └── chats/{chat_id}/           # 客服聊天附件
```

## 上传流程

### 带临时目录的场景（两阶段上传）

1. **上传阶段**：图片保存到 `temp_{user_id}` 临时目录
2. **创建实体阶段**：图片从临时目录移动到 `{entity_id}` 正式目录，URL 同步更新

适用于：
- 任务图片（发布任务时）
- 跳蚤市场商品图片
- 榜单封面（审核通过时移动）
- 竞品图片
- Banner 图片

### 直接存储场景

图片直接保存到 `{entity_id}` 目录，无临时目录：
- 任务达人头像（使用 expert_id = user_id）
- 服务图片（使用 expert_id = user_id）
- 编辑已有实体时的图片上传

## 清理机制

### 1. 定时清理任务（ScheduledCleanupTasks）

每日执行，清理以下内容：

| 清理项 | 触发条件 | 保留时间 |
|--------|---------|---------|
| 任务临时图片 | `temp_*` 目录下的文件 | 24小时 |
| 跳蚤市场临时图片 | `temp_*` 目录下的文件 | 24小时 |
| 榜单封面临时图片 | `temp_*` 目录下的文件 | 24小时 |
| Banner 临时图片 | `temp_*` 目录下的文件 | 24小时 |
| 孤立文件 | 不在预期位置的文件 | 7天（每周检查） |
| 已删除实体的图片 | 数据库中不存在对应实体 | 立即清理 |
| 过期商品图片 | 商品已过期 | 立即清理 |

### 2. 实体删除时的清理

| 场景 | 清理函数 | 说明 |
|------|---------|------|
| 删除任务 | `delete_task_images()` | 清理公开图片 + 私密聊天图片/文件 |
| 删除服务 | `delete_service_images()` | 清理服务图片 |
| 删除竞品 | `delete_leaderboard_item_images()` | 清理竞品图片目录 |
| 删除 Banner | `admin_banner_routes.delete_banner()` | 清理 Banner 图片 |
| 删除商品 | `flea_market_routes` | 清理商品图片目录 |
| 更换头像 | `delete_expert_avatar()` | 清理旧头像 |
| 拒绝榜单申请 | `custom_leaderboard_routes` | 清理临时封面图片 |

## 已完成的优化

### 1. ✅ 统一图片上传服务 (ImageUploadService)

**文件**: `app/services/image_upload_service.py`

创建了统一的图片上传服务，整合所有上传逻辑：

```python
from app.services import ImageUploadService, ImageCategory, get_image_upload_service

service = get_image_upload_service()

# 上传图片
result = service.upload(
    content=image_bytes,
    category=ImageCategory.TASK,
    resource_id="123",
    user_id="user_abc",
    is_temp=False
)

# 从临时目录移动到正式目录
new_urls = service.move_from_temp(
    category=ImageCategory.TASK,
    user_id="user_abc",
    resource_id="123",
    image_urls=["..."]
)

# 删除图片
service.delete(
    category=ImageCategory.TASK,
    resource_id="123"
)
```

**支持的分类** (`ImageCategory`):
- `TASK` - 任务图片
- `BANNER` - Banner 图片
- `LEADERBOARD_COVER` - 榜单封面
- `LEADERBOARD_ITEM` - 竞品图片
- `EXPERT_AVATAR` - 任务达人头像
- `SERVICE_IMAGE` - 服务图片
- `FLEA_MARKET` - 跳蚤市场商品
- `PRIVATE_TASK_CHAT` - 任务聊天图片
- `PRIVATE_CS_CHAT` - 客服聊天图片

### 2. ✅ 存储后端抽象层 (StorageBackend)

**文件**: `app/services/storage_backend.py`

支持本地存储和云存储（AWS S3 / Cloudflare R2）：

```python
from app.services import LocalStorageBackend, S3StorageBackend, get_default_storage

# 自动根据环境变量选择后端
storage = get_default_storage()

# 上传文件
url = storage.upload(content, "public/images/task/123/image.jpg")

# 移动文件
storage.move(src_path, dst_path)

# 删除目录
storage.delete_directory("public/images/task/123")
```

**环境变量配置**:
```bash
# 使用本地存储（默认）
STORAGE_BACKEND=local

# 使用 AWS S3
STORAGE_BACKEND=s3
S3_BUCKET_NAME=your-bucket
S3_PUBLIC_URL=https://cdn.example.com

# 使用 Cloudflare R2
STORAGE_BACKEND=r2
R2_BUCKET_NAME=your-bucket
R2_ENDPOINT_URL=https://xxx.r2.cloudflarestorage.com
R2_PUBLIC_URL=https://cdn.example.com
```

### 3. ✅ 图片处理功能 (ImageProcessor)

**文件**: `app/services/image_processor.py`

自动处理上传的图片：

- **自动压缩**: 根据配置压缩图片（默认质量 85%）
- **格式转换**: 可选转换为 WebP 格式
- **缩略图生成**: 预设尺寸 tiny/thumb/small/medium/large
- **EXIF 自动旋转**: 根据 EXIF 信息自动修正方向
- **元数据移除**: 移除隐私敏感的 EXIF 数据
- **尺寸限制**: 自动缩小超大图片

```python
from app.services import image_processor

# 压缩图片
compressed, ext = image_processor.compress(content, quality=85)

# 转换为 WebP
webp_content, ext = image_processor.convert_to_webp(content)

# 生成缩略图
thumb, ext = image_processor.generate_thumbnail(content, THUMBNAIL_PRESETS["thumb"])

# 批量生成缩略图
thumbnails = image_processor.generate_thumbnails(content, ["thumb", "medium"])
```

### 4. ✅ 优化版上传 API (V2)

**文件**: `app/upload_routes.py`

新的 V2 API 端点：

| 端点 | 方法 | 描述 |
|------|------|------|
| `/api/v2/upload/image` | POST | 上传单张图片（自动压缩） |
| `/api/v2/upload/image/batch` | POST | 批量上传图片 |
| `/api/v2/upload/image` | DELETE | 删除图片 |
| `/api/v2/upload/temp` | DELETE | 清理临时图片 |

**V2 API 优势**:
- 自动压缩减少 30-50% 存储空间
- 自动旋转（根据 EXIF）
- 移除隐私元数据
- 限制最大尺寸（默认 2048px）
- 可选生成缩略图

### 5. ✅ 存储监控指标 (StorageMetricsCollector)

**文件**: `app/services/storage_metrics.py`

管理员可访问的监控 API：

| 端点 | 描述 |
|------|------|
| `/api/v2/storage/metrics` | 完整存储报告 |
| `/api/v2/storage/disk` | 磁盘使用情况 |
| `/api/v2/storage/categories` | 各分类存储统计 |
| `/api/v2/storage/temp-cleanup-preview` | 预览待清理临时文件 |

**监控内容**:
- 磁盘使用率（总容量、已用、可用）
- 各分类存储大小和文件数
- 临时目录占用空间
- 上传成功率和压缩率
- 每小时/每日上传量

## 待优化建议

### 1. 添加图片引用计数

为防止误删正在使用的图片，可以添加图片引用计数表：

```python
class ImageReference(Base):
    __tablename__ = "image_references"
    
    id = Column(Integer, primary_key=True)
    image_url = Column(String, unique=True, index=True)
    reference_count = Column(Integer, default=1)
    created_at = Column(DateTime)
    last_referenced_at = Column(DateTime)
```

### 2. 添加上传队列

对于大量图片上传，可使用 Celery 任务队列异步处理：
- 图片压缩
- 缩略图生成
- 临时目录清理

### 3. CDN 集成

配合云存储使用 CDN 加速图片访问

## 已修复的问题

1. **Banner 图片存储问题**：
   - 问题：Banner 图片上传后未从临时目录移动到正式目录
   - 修复：在 `create_banner()` 中添加临时图片移动逻辑

2. **Banner 临时目录清理**：
   - 问题：Banner 临时目录未纳入定时清理任务
   - 修复：添加 `_cleanup_banner_temp_images()` 方法

## 测试建议

1. 测试各场景的图片上传和存储
2. 验证临时图片移动逻辑
3. 验证删除实体时的图片清理
4. 验证定时清理任务的执行

---
更新时间：2026-01-15（已完成优化实现）
