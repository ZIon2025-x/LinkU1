# 图片/文件上传路径与编辑逻辑检查报告

本文档汇总各端上传接口的 `category`、`resource_id` 使用情况，以及后端是否在创建/更新时做 `move_from_temp`，避免文件长期留在临时目录或被误删。

## 后端上传入口

| 入口 | 路径 | 说明 |
|------|------|------|
| **upload_routes** | `POST /api/v2/upload/image` | 主上传接口，支持 category + resource_id；管理员上传 expert_avatar/service_image 未传 resource_id 时 **400** |
| **routers** | `POST /upload/public-image` | 公开图片，支持管理员/用户；管理员上传 expert_avatar/service_image 未传 resource_id 时 **400**（与 v2 一致） |
| **flea_market_routes** | `POST /api/flea-market/upload-image` | 跳蚤市场专用，query `item_id` 为 resource_id；无则 temp，创建商品时 move_from_temp |
| **admin_banner_routes** | `POST /api/admin/banners/upload-image` | Banner 专用，query `banner_id` 为 resource_id；无则 temp，创建 Banner 时 move_from_temp |

## 按业务分类检查结果

### 1. 任务达人头像 (expert_avatar)

| 端 | 行为 | resource_id | 结论 |
|----|------|-------------|------|
| 管理后台 ExpertManagement | 编辑达人头像上传 | `editModal.formData.id`（达人 user_id） | ✅ 已修复，传 resource_id |
| 前端 TaskExpertDashboard | 达人头像/服务图 | `expertId` 有则传 | ✅ 正确 |
| 后端 upload_routes / routers | 管理员未传 resource_id | — | ✅ 返回 400，强制传达人 id |

存储路径：`public/images/expert_avatars/{expert_id}/`。孤儿清理仅保留 `users` 表存在的 user_id，故**必须**用达人 user_id 做目录，不能用管理员 id。

### 2. 任务达人服务图片 (service_image)

| 端 | 行为 | resource_id | 结论 |
|----|------|-------------|------|
| 管理后台 ExpertManagement | 编辑达人下的服务图片 | `editModal.formData.id`（达人 user_id） | ✅ 已修复 |
| 前端 TaskExpertDashboard | 服务图片 | `expertId` 有则传 | ✅ 正确 |
| 后端 | 同上 expert_avatar | 管理员必须传 resource_id | ✅ |

存储路径：`public/images/service_images/{expert_id}/`。

### 3. 官方活动图片 (activity)

| 端 | 行为 | resource_id | 结论 |
|----|------|-------------|------|
| 管理后台 OfficialActivityManagement | 编辑活动上传图 | `activityModal.formData.id`（活动 id） | ✅ 已修复 |
| 管理后台 OfficialActivityManagement | 新建活动上传图 | 不传 | 先 temp，创建时后端 move_from_temp ✅ |
| 后端 admin_official_routes | create_official_activity | — | ✅ 创建后对 data.images 做 move_from_temp(ACTIVITY, admin.id, activity.id) |

存储路径：`public/images/activities/{activity_id}/`。routers 的 category_map 未包含 activity，活动仅走 v2 上传。

### 4. 论坛帖子图片 (forum_post)

| 端 | 行为 | resource_id | 结论 |
|----|------|-------------|------|
| 前端 api.ts uploadForumPostImage | 发帖/编辑前上传 | 不传 | temp ✅ |
| Flutter forum_repository uploadPostImage | 同上 | 不传 | temp ✅ |
| 后端 forum_routes | 创建/更新帖子 | — | ✅ move_from_temp(FORUM_POST, uploader_id, post_id, images) |

存储路径：`public/images/forum_posts/{post_id}/`。

### 5. 跳蚤市场 (flea_market)

| 端 | 行为 | resource_id | 结论 |
|----|------|-------------|------|
| Flutter flea_market_repository | 上传图 | `itemId` 有则作 query `item_id` | ✅ 编辑传 item_id |
| Flutter 创建商品 | 上传图 | 不传 itemId | temp，创建时后端 move_from_temp ✅ |
| 后端 flea_market_routes | 上传接口 | `item_id` → resource_id | ✅ 有则正式目录，无则 temp；创建/更新商品时 move_from_temp |

存储路径：`flea_market/{item_id}/`（或 temp_{user_id}）。

### 6. 任务图片 (task / public)

| 端 | 行为 | resource_id | 结论 |
|----|------|-------------|------|
| Flutter task_repository uploadTaskImage | 发任务前上传 | 不传 | temp ✅ |
| 后端 async_routers | 创建任务 | — | ✅ move_from_temp(TASK, user_id, task_id, task.images) |

存储路径：`public/images/public/{task_id}/`。

### 7. 排行榜 (leaderboard_cover / leaderboard_item)

| 端 | 行为 | resource_id | 结论 |
|----|------|-------------|------|
| 前端 CustomLeaderboardsTab | 封面 | `resource_id` 传参 | ✅ |
| 前端 CustomLeaderboardDetail | 竞品图 | `resource_id` 临时标识 | temp，后端创建/更新时 move ✅ |
| 后端 custom_leaderboard_routes | 创建/更新榜单/竞品 | — | ✅ move_from_temp + delete_temp |

### 8. Banner

| 端 | 行为 | resource_id | 结论 |
|----|------|-------------|------|
| 管理后台 | 上传 | 专用接口，query `banner_id` | ✅ 有则正式目录；新建时 image_url 为 temp 则创建后 move_from_temp |

### 9. 其它

- **前端 Message.tsx / 任务聊天图**：`/api/upload/image?task_id=...`，为**私密任务聊天图片**，走私有图片体系，非公开 category。
- **admin api.ts `uploadImage(file)`**：调用 `/api/v2/upload/image` 且**未传 category/resource_id**，默认 category=task、temp。当前未在 admin 内发现调用方；若将来使用，建议改为显式传 `category` 与 `resource_id`，避免长期进 temp。

## 本次修改摘要

1. **routers.py `upload_public_image`**：管理员上传 `expert_avatar` 或 `service_image` 且未传 `resource_id` 时返回 400，与 upload_routes 行为一致，避免存到 `expert_avatars/{管理员id}/` 被孤儿清理误删。
2. 其余项在之前的修复中已完成：管理后台达人头像/服务图传 resource_id、官方活动编辑传 resource_id、官方活动创建后 move_from_temp、upload_routes 管理员 expert_avatar/service_image 强制 resource_id。

## 建议

- 新加任何「管理员代传」的公开图片（尤其是按「实体 id」建目录的），都应显式传 `resource_id`，避免用当前登录管理员 id 当目录。
- 新建实体且图片先传 temp 时，在创建接口内对传入的图片 URL 做一次 `move_from_temp`，并写回正式 URL，避免依赖临时目录长期保留。
