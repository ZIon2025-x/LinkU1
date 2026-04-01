# 论坛技能板块设计

## 概述

在论坛板块列表中新增"技能板块"，每个技能板块对应一个现有任务类型（如编程、翻译、摄影等）。进入技能板块后展示混合 feed，将帖子、任务和服务三种内容按权重混排在一个列表中。任务和服务自动聚合（按 `task_type` / 技能类型匹配），用户也可以在技能板块内发帖讨论。

## 数据模型变更

### 后端

#### ForumCategory 表扩展

- 新增 `skill_type` 字段（VARCHAR(50), nullable），存储关联的任务类型标识（如 `'programming'`、`'translation'`）
- 现有 `type` 字段新增枚举值 `'skill'`
- 通过 migration SQL 预填充技能板块（遍历现有任务类型，每个创建一条 `type='skill'` 的 category 记录）

#### FeedItem Pydantic Schema（新增）

```python
class FeedItemType(str, Enum):
    post = "post"
    task = "task"
    service = "service"

class FeedItem(BaseModel):
    item_type: FeedItemType
    data: dict          # 对应类型的完整数据
    sort_score: float   # 排序分数
    created_at: datetime
```

### 前端

#### ForumCategory 扩展

- `ForumCategory` model 新增 `skillType` 字段（`String?`）

#### FeedItem 模型（新增 `feed_item.dart`）

```dart
enum FeedItemType { post, task, service }

class FeedItem extends Equatable {
  final FeedItemType itemType;
  final dynamic data;  // ForumPost / Task / ExpertService
  final double sortScore;
  final DateTime createdAt;
}
```

## 后端 API

### 新增接口

#### `GET /api/forum/categories/{id}/feed`

技能板块混合 feed。

**参数：**
- `page`（int, 默认 1）
- `page_size`（int, 默认 20）
- `sort_by`（string, 默认 `'weight'`，可选 `'time'`）

**逻辑：**
1. 查询该 category 的 `skill_type`，校验 `type == 'skill'`
2. 并行查三个来源：
   - 该 category 下的帖子（`category_id` 匹配）
   - `task_type` 匹配且 `status='open'`、`is_visible=true` 的任务
   - 该技能类型相关的活跃专家服务（`is_active=true`）
3. 合并并按权重排序
4. 分页返回 `FeedItem` 列表

**响应：**
```json
{
  "items": [
    {
      "item_type": "task",
      "data": { ... },
      "sort_score": 5200.0,
      "created_at": "2026-04-01T10:00:00Z"
    }
  ],
  "total": 45,
  "page": 1,
  "page_size": 20,
  "has_more": true
}
```

### 现有接口适配

- **`GET /api/forum/forums/visible`**：返回结果包含 `type='skill'` 的板块，前端可按 type 分组展示
- **`POST /api/forum/posts`**：当 `category_id` 指向技能板块时，正常创建帖子（无需改动）

### 不需要改动的接口

- 帖子 CRUD、回帖、点赞、收藏 — 全部复用现有接口
- 任务和服务 CRUD — 各自保持独立，仅被 feed 接口聚合读取

## 排序权重规则

```
置顶帖:                score = 10000
新任务（≤24h）:         score = 5000 + (24h - age_hours) * 200
新服务（≤24h）:         score = 4000 + (24h - age_hours) * 160
普通帖子/旧任务/旧服务:  score = unix_timestamp（越新越大）
```

- 同权重层内按时间倒序
- 已关闭/已完成的任务不出现在 feed
- 服务只展示 `is_active=true` 的

## 分页策略

- 使用 `page` + `page_size` 偏移分页（与现有论坛接口一致）
- 后端一次查询合并排序后返回，前端不需要做合并

## 前端架构

### ForumBloc 扩展

新增事件：
- `ForumLoadFeed(categoryId, sortBy)` — 加载技能板块混合 feed
- `ForumLoadMoreFeed(categoryId)` — 加载更多

State 新增字段：
- `feedItems: List<FeedItem>` — 混合 feed 数据
- `feedStatus: ForumStatus` — feed 加载状态
- `feedHasMore: bool` — 是否有更多
- `feedPage: int` — 当前页码

### 视图层

#### 板块列表（forum_view.dart）

- 技能板块在列表中正常展示，可用图标或标签与普通板块区分
- 点击技能板块时，判断 `category.type == 'skill'`，跳转到混合 feed 页面

#### 新增 `skill_feed_view.dart`

- **顶部**：板块名称 + 技能描述
- **列表**：混合 feed，根据 `FeedItem.itemType` 渲染不同卡片：
  - `post` → 现有帖子卡片样式
  - `task` → 任务卡片（标题、价格、状态、技能标签），点击跳转任务详情
  - `service` → 服务卡片（专家头像、评分、价格），点击跳转服务详情
- 每种卡片左上角有类型标签（"讨论"/"任务"/"服务"）区分
- 右下角 FAB 发帖按钮（复用 `create_post_view.dart`）

#### Repository

- `ForumRepository` 新增 `getSkillFeed(categoryId, page, pageSize, sortBy)` 方法

### 路由

- 新增路由 `/community/skill/:categoryId`，对应 `SkillFeedView`

## 数据初始化

通过 migration SQL 为每个任务类型创建 `forum_categories` 记录：

- `type = 'skill'`
- `skill_type` = 任务类型标识（`programming`、`translation`、`photography` 等）
- `name_zh` / `name_en` = 任务类型中英文名称
- `icon` = 技能对应图标标识
- `is_visible = true`
- `sort_order` 从 100 开始递增（排在普通板块之后）

## 错误处理与边界情况

### 空状态

- 技能板块无任何内容：显示空状态引导，鼓励发第一个帖子
- 只有任务/服务没有帖子：正常展示

### 权限

- 技能板块对所有用户可见（不需要学生认证等门槛）
- 发帖权限复用现有论坛权限逻辑
- 任务和服务卡片为只读展示，点击跳转各自详情页

### Feed 内容过滤

- 任务：`status='open'` 且 `is_visible=true`
- 服务：`is_active=true`
- 帖子：`is_deleted=false` 且 `is_visible=true`（复用现有逻辑）

### 错误码

- `skill_feed_load_failed` — feed 加载失败
- `skill_feed_load_more_failed` — 加载更多失败

添加到三个 ARB 文件（en、zh、zh_Hant）。
