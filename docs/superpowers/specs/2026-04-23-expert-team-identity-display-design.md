# 达人团队身份统一显示 — 设计

**日期**: 2026-04-23
**涉及**: backend + link2ur (Flutter)

## 背景

达人团队 (Expert team) 可发布三类内容：服务 (`TaskExpertService`)、活动 (`Activity`)、论坛帖子 (`ForumPost`)。后端以 `owner_type='expert' + owner_id=team_id` (论坛帖用 `ForumPost.expert_id`) 标识团队归属。

当前 Flutter 各页面（列表卡片、详情页头、Feed）普遍把"发布人"渲染为**个人用户身份** (`ownerName`/`ownerAvatar`/`author.name`)。仅 `/api/follow/feed` 做了团队身份替换，其他入口都漏了。

## 目标

所有"达人团队拥有的"内容，在 Flutter 端列表/详情/Feed 三层显示**达人团队身份**（团队名 + 团队头像），点击跳转到达人团队详情页。个人用户发布的内容保持原有行为。

## 非目标

- 不改完成记录、评价、排行榜（个人属性）
- 不重命名现有 `ownerName`/`ownerAvatar`/`author` 字段（避免破坏现有代码）
- 不动 admin/web 前端
- 不改 iOS 原生（已退役）

## 后端改动

### 新增 4 个响应字段

服务、活动、论坛帖子的 list + detail 响应统一追加：

| 字段 | 类型 | 含义 |
|---|---|---|
| `display_name` | `str` | 团队 → 团队名；用户 → 用户昵称 |
| `display_avatar` | `str?` | 团队 → 团队头像；用户 → 用户头像 |
| `owner_type` | `'user' \| 'expert'` | 前端点击分流用 |
| `owner_id` | `int` | 对应 `user_id` 或 `expert_team_id` |

论坛帖子没有原生 `owner_type`/`owner_id`，由后端根据 `ForumPost.expert_id` 是否非空合成：`expert_id` 非空 → `('expert', expert_id)`，否则 `('user', author_id)`。

### 复用 follow_feed 现有逻辑

抽取 helper `_resolve_display_identity(db, owner_type, owner_id) -> (name, avatar)`，放到 `app/services/display_identity.py`（新文件）。`follow_feed_routes.py` 现有内联实现迁入该 helper。

### 涉及端点

- `/api/services/*` (list, detail)
- `/api/activities/*` (list, detail)
- `/api/forum/posts/*` (list, detail)
- `/api/follow/feed`（重构到共享 helper，行为不变）

## Flutter 改动

### Data Models

三个模型加字段（保持向后兼容 — 字段缺失时 fallback 到旧字段）：

- `TaskExpertService` (`lib/data/models/task_expert.dart`)
  - `+ String? displayName`
  - `+ String? displayAvatar`
  - `+ String? ownerType` （现已有 `ownerName`/`ownerAvatar`）
- `Activity` (`lib/data/models/activity.dart`)
  - `+ String? displayName`
  - `+ String? displayAvatar`
  - （`ownerType` / `ownerId` 已存在）
- `ForumPost` (`lib/data/models/forum.dart`)
  - `+ String? ownerType`
  - `+ int? ownerId`
  - `+ String? displayName`
  - `+ String? displayAvatar`

### 新建统一组件 PublisherIdentity

`lib/core/widgets/publisher_identity.dart`：

```dart
class PublisherIdentity extends StatelessWidget {
  final String ownerType;   // 'user' | 'expert'
  final int ownerId;
  final String displayName;
  final String? displayAvatar;
  final bool showBadge;     // expert 时显示"达人团队"徽章
  final double avatarSize;
  // 点击:
  //   ownerType == 'expert' -> context.goToExpertDetail(ownerId)
  //   else                  -> context.goToUserProfile(ownerId)
}
```

### 替换渲染的 View

- 服务
  - `task_expert/views/service_detail_view.dart` (AppBar 头像区)
  - `task_expert/views/task_expert_detail_view.dart` (`_ServiceCard`)
  - `task_expert/views/task_expert_list_view.dart` (`_ExpertCard`)
- 活动
  - `activity/views/activity_detail_view.dart` (作者栏)
  - 活动列表/卡片 (探测所有使用 `Activity.ownerName` 的地方)
- 论坛
  - `forum/views/forum_post_list_view.dart` (`_PostCard`)
  - `forum/views/forum_post_detail_view.dart` (头部作者栏)
- Feed
  - `discover/views/discover_view.dart` Feed 卡片 (改走同组件)

每处改动：原地把 author/owner 头像+名字替换为 `PublisherIdentity(...)`，传入 `display_name` / `display_avatar` / `owner_type` / `owner_id`。

## 数据流

```
DB (owner_type, owner_id, expert_id)
  → backend helper _resolve_display_identity()
  → API response { display_name, display_avatar, owner_type, owner_id, ...existing }
  → Flutter Model.fromJson 解析新字段, fallback 到旧字段
  → PublisherIdentity widget 渲染
  → 点击 → 按 owner_type 分流路由
```

## 错误处理

- 后端 helper 查不到 team/user 时 → fallback 到空串 `display_name=''`, `display_avatar=null`；前端组件对空头像有默认占位图
- 前端新字段缺失（老后端响应）时 → fallback 到旧 `ownerName`/`author.name` 逻辑，不崩

## 验证路径

1. 后端：一个达人团队发一条服务 + 一条活动 + 一条论坛帖；同一个 user (非团队成员) 也发三条对照
2. Flutter 三层显示检查：
   - 服务列表卡片、服务详情头、活动列表卡片、活动详情头、论坛列表卡片、论坛详情头、Feed 卡片
3. 点击跳转：团队内容点击 → `/experts/{team_id}`；个人内容点击 → `/user/{user_id}`
4. `flutter analyze` 无新 warning
5. 旧响应兼容：临时注释掉后端新字段，Flutter 不应崩（fallback 到旧字段）

## 迁移与兼容

- 后端增字段是 additive，老客户端忽略新字段继续用 `ownerName`/`author` — 零破坏
- Flutter fromJson 双向兼容（旧响应 fallback 到老字段）
- 不需要 DB migration

## 风险

- **活动/论坛帖的 owner_type 合成**：后端需要仔细核对每个端点里 ORM 关联字段，避免 N+1（用 `selectinload`/批量 JOIN 一次拉所有 team 信息）
- **ForumPost 旧数据**：`expert_id` 字段早于此改动已存在，但历史帖子可能未正确填充——需抽样核对
- **路由跳转**：`context.goToExpertDetail` 需确认已存在；若无，`app_router.dart` 里补一个
