# 勋章全局显示 — InlineBadgeTag 全覆盖实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `InlineBadgeTag` 在所有显示用户名的地方出现（论坛、任务、跳蚤市场、排行榜、聊天、评价、服务等），后端统一补全 `displayed_badge` 字段。

**Architecture:** 后端提取共享的 `enrich_displayed_badges()` 工具函数（sync + async 两版），为 `UserBrief` schema 加 `displayed_badge` 字段；各端点批量注入勋章数据。前端为缺失 `displayedBadge` 的 model 补字段，所有显示用户名的 view 加 `InlineBadgeTag`。

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/Dart (frontend)

---

## 现状

| 区域 | 后端是否返回 `displayed_badge` | 前端 model 有 `displayedBadge` | 视图有 `InlineBadgeTag` |
|------|------|------|------|
| 论坛帖子列表/详情 | ✅ via preload_badge_cache | ✅ UserBrief | ✅ 部分（帖子作者有，评论作者没有） |
| 任务详情 poster/taker | ❌ UserBrief 无此字段 | ✅ UserBrief | ❌ |
| 任务申请人 | ❌ | ❌ 只有 applicantName 字符串 | ❌ |
| 跳蚤市场 seller | ❌ | ❌ 只有 sellerName 字符串 | ❌ |
| 聊天消息 sender | ❌ | ❌ 只有 senderName 字符串 | ❌ |
| 排行榜 | ❌ build_user_info 没传 _badge_cache | ✅ UserBrief | ❌ |
| 服务评价 reviewer | ❌ | ✅ UserBrief（Review model） | ❌ |
| 首页发现卡片 | ❌ | ❌ 只有 userName 字符串 | ❌ |
| 个人服务申请 | ❌ | ❌ 只有 applicant_name 字符串 | ❌ |
| 技能排行榜 | ❌ | ❌ 只有 userName 字符串 | ❌ |

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| **Create** | `backend/app/utils/badge_helpers.py` | 共享 badge enrichment 工具（sync + async） |
| **Modify** | `backend/app/schemas.py:13-21` | `UserBrief` 加 `displayed_badge` 字段 |
| **Modify** | `backend/app/routers.py:1520-1523` | 任务详情 poster/taker 注入 badge |
| **Modify** | `backend/app/routers.py:4726-4727` | 我的任务列表 poster 注入 badge |
| **Modify** | `backend/app/flea_market_routes.py` | 商品详情/列表 seller 加 `displayed_badge` |
| **Modify** | `backend/app/forum_routes.py:704-751` | `preload_badge_cache` 改为调用共享工具 |
| **Modify** | `backend/app/custom_leaderboard_routes.py` | `build_user_info` 调用时传 `_badge_cache` |
| **Modify** | `link2ur/lib/data/models/flea_market.dart` | `FleaMarketItem` 加 `displayedBadge` |
| **Modify** | `link2ur/lib/data/models/chat.dart` 或 `message.dart` | `Message` 加 `senderDisplayedBadge` |
| **Modify** | `link2ur/lib/features/forum/views/forum_post_detail_view.dart` | 评论作者加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/forum/views/skill_feed_view.dart` | 作者名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/tasks/views/task_detail_view.dart` | poster/taker 名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/tasks/views/task_detail_components.dart` | 申请人、评价者加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart` | 卖家名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/home/views/home_view.dart` | 发现卡片用户名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/home/views/home_discovery_cards.dart` | 发现卡片用户名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/skill_leaderboard/views/widgets/leaderboard_item_widget.dart` | 排行榜用户名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/chat/widgets/message_group_bubble.dart` | 聊天 sender 名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/personal_service/views/service_reviews_view.dart` | 评价者名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/personal_service/views/received_applications_view.dart` | 申请者名加 InlineBadgeTag |
| **Modify** | `link2ur/lib/features/task_expert/views/expert_applications_management_view.dart` | 申请者名加 InlineBadgeTag |

---

## Task 1: 后端 — 共享 badge enrichment 工具函数

**Files:**
- Create: `backend/app/utils/badge_helpers.py`
- Modify: `backend/app/schemas.py:13-21`

提取论坛 `preload_badge_cache` 的核心逻辑为两个独立函数（sync 用于 routers.py 等同步路由，async 用于 forum_routes.py 等异步路由）。

- [ ] **Step 1: 创建 `badge_helpers.py`**

```python
"""
勋章数据补全工具函数
提供 sync / async 两个版本，供各路由批量补全 displayed_badge 字段。
"""

from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import models

import logging
logger = logging.getLogger(__name__)


def enrich_displayed_badges_sync(db: Session, user_ids: list[str]) -> dict:
    """同步版：批量获取用户展示勋章，返回 {user_id: badge_dict}。"""
    if not user_ids:
        return {}
    try:
        badges = (
            db.query(models.UserBadge)
            .filter(
                models.UserBadge.user_id.in_(user_ids),
                models.UserBadge.is_displayed == True,
            )
            .all()
        )
        if not badges:
            return {}

        skill_cats = {b.skill_category for b in badges}
        cat_map = {}
        if skill_cats:
            rows = (
                db.query(
                    models.SkillCategory.task_type,
                    models.SkillCategory.name_zh,
                    models.SkillCategory.name_en,
                )
                .filter(models.SkillCategory.task_type.in_(skill_cats))
                .all()
            )
            for row in rows:
                cat_map[row.task_type] = (row.name_zh, row.name_en)

        cache = {}
        for b in badges:
            names = cat_map.get(b.skill_category, (b.skill_category, b.skill_category))
            cache[b.user_id] = {
                "id": b.id,
                "badge_type": b.badge_type,
                "skill_category": b.skill_category,
                "skill_name_zh": names[0] or b.skill_category,
                "skill_name_en": names[1] or b.skill_category,
                "city": b.city,
                "rank": b.rank,
                "is_displayed": True,
            }
        return cache
    except Exception as e:
        logger.warning(f"Failed to load badge cache: {e}")
        return {}


async def enrich_displayed_badges_async(db: AsyncSession, user_ids: list[str]) -> dict:
    """异步版：批量获取用户展示勋章，返回 {user_id: badge_dict}。"""
    if not user_ids:
        return {}
    try:
        badge_result = await db.execute(
            select(models.UserBadge).where(
                models.UserBadge.user_id.in_(user_ids),
                models.UserBadge.is_displayed == True,
            )
        )
        badges = badge_result.scalars().all()
        if not badges:
            return {}

        skill_cats = {b.skill_category for b in badges}
        cat_map = {}
        if skill_cats:
            cat_result = await db.execute(
                select(
                    models.SkillCategory.task_type,
                    models.SkillCategory.name_zh,
                    models.SkillCategory.name_en,
                ).where(models.SkillCategory.task_type.in_(skill_cats))
            )
            for row in cat_result.all():
                cat_map[row.task_type] = (row.name_zh, row.name_en)

        cache = {}
        for b in badges:
            names = cat_map.get(b.skill_category, (b.skill_category, b.skill_category))
            cache[b.user_id] = {
                "id": b.id,
                "badge_type": b.badge_type,
                "skill_category": b.skill_category,
                "skill_name_zh": names[0] or b.skill_category,
                "skill_name_en": names[1] or b.skill_category,
                "city": b.city,
                "rank": b.rank,
                "is_displayed": True,
            }
        return cache
    except Exception as e:
        logger.warning(f"Failed to load badge cache: {e}")
        return {}
```

- [ ] **Step 2: `UserBrief` schema 加 `displayed_badge` 字段**

在 `backend/app/schemas.py` 的 `UserBrief` 类中添加：

```python
class UserBrief(BaseModel):
    """用户简要信息（嵌套在任务等对象中返回）"""
    id: str
    name: str
    avatar: Optional[str] = None
    is_verified: Optional[int] = 0
    displayed_badge: Optional[dict] = None

    class Config:
        from_attributes = True
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/utils/badge_helpers.py backend/app/schemas.py
git commit -m "feat: shared badge enrichment helpers (sync+async) and UserBrief.displayed_badge"
```

---

## Task 2: 后端 — 论坛路由迁移至共享工具

**Files:**
- Modify: `backend/app/forum_routes.py:704-751`

将 `preload_badge_cache` 改为调用 `enrich_displayed_badges_async`，减少重复代码。

- [ ] **Step 1: 替换 `preload_badge_cache` 实现**

```python
async def preload_badge_cache(db: AsyncSession, user_ids: list[str]) -> dict:
    """预加载一批用户的展示勋章，返回 {user_id: badge_dict} 映射。
    供列表端点在构建 UserInfo 前调用，传给 build_user_info._badge_cache。
    """
    from app.utils.badge_helpers import enrich_displayed_badges_async
    return await enrich_displayed_badges_async(db, user_ids)
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/forum_routes.py
git commit -m "refactor: forum preload_badge_cache delegates to shared helper"
```

---

## Task 3: 后端 — 任务端点注入 badge

**Files:**
- Modify: `backend/app/routers.py:1515-1524` (任务详情)
- Modify: `backend/app/routers.py:4720-4730` (我的任务列表)

`UserBrief.model_validate()` 不会自动填充 `displayed_badge`（ORM model 没有这个属性），需要在 `model_dump()` 后手动注入。

- [ ] **Step 1: 任务详情 — poster/taker 注入 badge**

在 `routers.py` 的任务详情端点中，`model_dump()` 后注入 badge：

```python
# 在构建 task_dict 之后、return 之前:
from app.utils.badge_helpers import enrich_displayed_badges_sync

# 收集需要查 badge 的 user_id
_badge_user_ids = []
if task.poster is not None:
    _badge_user_ids.append(task.poster.id)
if task.taker is not None:
    _badge_user_ids.append(task.taker.id)
_badge_cache = enrich_displayed_badges_sync(db, _badge_user_ids)

if task.poster is not None:
    task_dict["poster"] = schemas.UserBrief.model_validate(task.poster).model_dump()
    task_dict["poster"]["displayed_badge"] = _badge_cache.get(task.poster.id)
if task.taker is not None:
    task_dict["taker"] = schemas.UserBrief.model_validate(task.taker).model_dump()
    task_dict["taker"]["displayed_badge"] = _badge_cache.get(task.taker.id)
```

- [ ] **Step 2: 我的任务列表 — poster 注入 badge**

在 `routers.py` 的 `/my-tasks` 端点中，先批量加载所有 poster 的 badge，然后逐个注入：

```python
from app.utils.badge_helpers import enrich_displayed_badges_sync

# 在循环外：收集所有 poster_id
_poster_ids = [t.poster.id for t in tasks if t.poster is not None]
_badge_cache = enrich_displayed_badges_sync(db, _poster_ids)

# 在循环内：
if t.poster is not None:
    task_dict["poster"] = schemas.UserBrief.model_validate(t.poster).model_dump()
    task_dict["poster"]["displayed_badge"] = _badge_cache.get(t.poster.id)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat: inject displayed_badge into task detail/list poster & taker"
```

---

## Task 4: 后端 — 跳蚤市场端点注入 badge

**Files:**
- Modify: `backend/app/flea_market_routes.py`

跳蚤市场目前返回 `seller_name`/`seller_avatar` 等平铺字符串。最小改动方式：在返回字典中增加 `seller_displayed_badge` 字段。

- [ ] **Step 1: 找到商品详情/列表序列化代码**

搜索 `flea_market_routes.py` 中所有 `"seller_name"` 出现的位置，在同级添加 `"seller_displayed_badge"` 字段。

对于商品详情端点（单个商品），seller_id 已知，调用：
```python
from app.utils.badge_helpers import enrich_displayed_badges_sync
_badge_cache = enrich_displayed_badges_sync(db, [seller.id])
# 在序列化 dict 中加：
"seller_displayed_badge": _badge_cache.get(seller.id),
```

对于列表端点（多个商品），先收集所有 seller_id 批量查：
```python
seller_ids = list({item.seller_id for item in items if item.seller_id})
_badge_cache = enrich_displayed_badges_sync(db, seller_ids)
# 每个 item dict 加：
"seller_displayed_badge": _badge_cache.get(item.seller_id),
```

同样对 `buyer_name` 出现的位置加 `buyer_displayed_badge`。

- [ ] **Step 2: Commit**

```bash
git add backend/app/flea_market_routes.py
git commit -m "feat: inject seller/buyer displayed_badge in flea market endpoints"
```

---

## Task 5: 后端 — 自定义排行榜端点注入 badge

**Files:**
- Modify: `backend/app/custom_leaderboard_routes.py`

当前 `build_user_info` 调用未传 `_badge_cache`，导致 `displayed_badge` 始终为 null。

- [ ] **Step 1: 在每个调用 `build_user_info` 的端点中预加载 badge**

```python
from app.forum_routes import build_user_info, preload_badge_cache

# 在每个端点函数内，调用 build_user_info 之前:
_badge_cache = await preload_badge_cache(db, [leaderboard.applicant_id])
applicant_info = await build_user_info(db, leaderboard.applicant, _badge_cache=_badge_cache)
```

对于列表端点，批量收集所有 applicant_id：
```python
applicant_ids = [lb.applicant_id for lb in leaderboards if lb.applicant_id]
_badge_cache = await preload_badge_cache(db, applicant_ids)
# 循环内传入
applicant_info = await build_user_info(db, lb.applicant, _badge_cache=_badge_cache)
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/custom_leaderboard_routes.py
git commit -m "feat: inject displayed_badge in custom leaderboard user info"
```

---

## Task 6: 前端 model — 补全缺失的 `displayedBadge` 字段

**Files:**
- Modify: `link2ur/lib/data/models/flea_market.dart` — `FleaMarketItem` 加 `sellerDisplayedBadge`
- Modify: `link2ur/lib/data/models/flea_market.dart` — `PurchaseRequest` 加 `buyerDisplayedBadge`
- Modify: `link2ur/lib/features/chat/` 相关 model — MessageGroup 加 `senderDisplayedBadge`（如果 message model 有结构化 sender）

对于使用平铺字符串（如 `sellerName`）的 model，添加一个 `UserBadge?` 字段，从 JSON 的 `seller_displayed_badge` 解析。

- [ ] **Step 1: `FleaMarketItem` 加 `sellerDisplayedBadge`**

```dart
// 字段声明
final UserBadge? sellerDisplayedBadge;

// fromJson
sellerDisplayedBadge: json['seller_displayed_badge'] != null
    ? UserBadge.fromJson(json['seller_displayed_badge'])
    : null,

// toJson
'seller_displayed_badge': sellerDisplayedBadge?.toJson(),

// copyWith
UserBadge? sellerDisplayedBadge,
// ...
sellerDisplayedBadge: sellerDisplayedBadge ?? this.sellerDisplayedBadge,

// Equatable props 加入
sellerDisplayedBadge,
```

- [ ] **Step 2: `PurchaseRequest` 加 `buyerDisplayedBadge`**

同上模式，字段名为 `buyerDisplayedBadge`，JSON key 为 `buyer_displayed_badge`。

- [ ] **Step 3: 检查聊天 MessageGroup**

查看 `message_group_bubble.dart` 的 `MessageGroup` 数据来源。如果 sender 信息来自已有的 `UserBrief`（从 participants 列表匹配），则不需要新字段 — 直接用 `UserBrief.displayedBadge`。如果 sender 信息是平铺字符串，需要补字段。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/models/
git commit -m "feat: add displayedBadge fields to FleaMarketItem, PurchaseRequest models"
```

---

## Task 7: 前端 view — 论坛评论/回复加 InlineBadgeTag

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`
- Modify: `link2ur/lib/features/forum/views/skill_feed_view.dart`

论坛的 `ForumReply.author` 是 `UserBrief`，已有 `displayedBadge`，只需在 view 层添加。

- [ ] **Step 1: `forum_post_detail_view.dart` — 评论作者名后加 badge**

在每个显示 `reply.author?.name` 的 `Text` widget 旁，加入：

```dart
// 在 Text(reply.author?.name ?? ...) 后面的 Row 或 Wrap 中追加：
if (reply.author?.displayedBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: reply.author!.displayedBadge!),
],
```

需要处理的位置：
- 约 line 1121：一级评论作者
- 约 line 1226：回复中提到的用户
- 约 line 1640：引用的父评论作者

- [ ] **Step 2: `skill_feed_view.dart` — 帖子作者加 badge**

约 line 237，`post.author!.name` 的 `Text` 后加：

```dart
if (post.author?.displayedBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: post.author!.displayedBadge!),
],
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/forum/
git commit -m "feat: show InlineBadgeTag on forum reply/comment authors"
```

---

## Task 8: 前端 view — 任务详情 poster/taker/applicant/reviewer 加 InlineBadgeTag

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart`
- Modify: `link2ur/lib/features/tasks/views/task_detail_components.dart`

- [ ] **Step 1: `task_detail_view.dart` — poster 信息区域**

找到显示 poster name 的位置，在其 `Text` widget 后加 `InlineBadgeTag`：

```dart
if (task.poster?.displayedBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: task.poster!.displayedBadge!),
],
```

- [ ] **Step 2: `task_detail_components.dart` — 申请人列表**

约 line 1034，applicant name 旁。注意：申请人目前只有 `applicantName` 字符串，没有 `displayedBadge`。如果后端已在申请人数据中加入 badge（Task 3 未覆盖此处），需要先确认数据源。

**如果申请人数据不含 badge，跳过此位置（或在后续迭代中补后端）。**

- [ ] **Step 3: `task_detail_components.dart` — 评价区域**

约 line 1369-1378，reviewer name 旁。`review.reviewer` 是 `UserBrief`，可直接使用：

```dart
if (review.reviewer?.displayedBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: review.reviewer!.displayedBadge!),
],
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/tasks/
git commit -m "feat: show InlineBadgeTag on task poster, taker, and reviewer"
```

---

## Task 9: 前端 view — 跳蚤市场卖家加 InlineBadgeTag

**Files:**
- Modify: `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart`

- [ ] **Step 1: 卖家名旁加 badge**

约 line 2393，`item.sellerName` 的 `Text` 后：

```dart
if (item.sellerDisplayedBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: item.sellerDisplayedBadge!),
],
```

确保 `Text` 和 `InlineBadgeTag` 在同一个 `Row` 或 `Wrap` 中。

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/features/flea_market/
git commit -m "feat: show InlineBadgeTag on flea market seller name"
```

---

## Task 10: 前端 view — 首页/发现卡片加 InlineBadgeTag

**Files:**
- Modify: `link2ur/lib/features/home/views/home_view.dart`
- Modify: `link2ur/lib/features/home/views/home_discovery_cards.dart`

首页卡片的用户名一般来自 API 的 map 数据。需要确认后端是否已在发现 feed 端点返回了 `displayed_badge`。

- [ ] **Step 1: 检查发现 feed 数据结构**

确认 `home_view.dart` 中 `item.userName` 的数据来源。如果来自 `UserBrief` 对象，直接用其 `displayedBadge`。如果是平铺字符串，需要在 model 加字段并确保后端返回。

- [ ] **Step 2: 在用户名 Text 后加 InlineBadgeTag**

```dart
if (item.displayedBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: item.displayedBadge!),
],
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/home/
git commit -m "feat: show InlineBadgeTag on home/discovery user names"
```

---

## Task 11: 前端 view — 排行榜用户名加 InlineBadgeTag

**Files:**
- Modify: `link2ur/lib/features/skill_leaderboard/views/widgets/leaderboard_item_widget.dart`

- [ ] **Step 1: 检查数据源**

`SkillLeaderboardEntry` model 是否有 `displayedBadge`。如果排行榜数据是从后端获取的且包含 user_brief，则可用；如果只有 `userName` 字符串，需要在 model 补字段 + 确认后端返回。

- [ ] **Step 2: 约 line 128 用户名后加 badge**

```dart
if (entry.displayedBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: entry.displayedBadge!),
],
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/skill_leaderboard/
git commit -m "feat: show InlineBadgeTag on skill leaderboard entries"
```

---

## Task 12: 前端 view — 聊天消息 sender 加 InlineBadgeTag

**Files:**
- Modify: `link2ur/lib/features/chat/widgets/message_group_bubble.dart`

- [ ] **Step 1: 检查 MessageGroup 中 sender 的数据来源**

如果 sender 信息来自 `UserBrief`（从 TaskChat.participants 匹配），badge 已可用。如果来自 `Message.senderName` 平铺字符串，需要补前端 model 字段和后端数据。

- [ ] **Step 2: 约 line 191 sender name 后加 badge**

```dart
if (senderBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: senderBadge),
],
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/chat/
git commit -m "feat: show InlineBadgeTag on chat message sender name"
```

---

## Task 13: 前端 view — 服务评价/申请加 InlineBadgeTag

**Files:**
- Modify: `link2ur/lib/features/personal_service/views/service_reviews_view.dart`
- Modify: `link2ur/lib/features/personal_service/views/received_applications_view.dart`
- Modify: `link2ur/lib/features/task_expert/views/expert_applications_management_view.dart`

- [ ] **Step 1: `service_reviews_view.dart` — 评价者名加 badge**

约 line 232，`reviewerName` 后。数据来源是 `review['reviewer_name']` 字符串 — 需要确认后端是否返回了 `reviewer_displayed_badge`。如果有：

```dart
final reviewerBadge = review['reviewer_displayed_badge'] != null
    ? UserBadge.fromJson(review['reviewer_displayed_badge'])
    : null;
// ...
if (reviewerBadge != null) ...[
  const SizedBox(width: 4),
  InlineBadgeTag(badge: reviewerBadge),
],
```

- [ ] **Step 2: `received_applications_view.dart` — 申请者名加 badge**

约 line 247，同上模式。

- [ ] **Step 3: `expert_applications_management_view.dart` — 申请者名加 badge**

约 line 267，同上模式。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/personal_service/ link2ur/lib/features/task_expert/
git commit -m "feat: show InlineBadgeTag on service review/application user names"
```

---

## Task 14: 验证 & 最终检查

- [ ] **Step 1: 全局搜索确认覆盖率**

```bash
# 搜索所有使用 InlineBadgeTag 的位置
grep -rn "InlineBadgeTag" link2ur/lib/

# 搜索可能遗漏的用户名显示（人工审核）
grep -rn "\.name\b" link2ur/lib/features/ --include="*.dart" | grep -i "user\|author\|poster\|seller\|buyer\|sender\|reviewer\|applicant"
```

- [ ] **Step 2: Flutter analyze**

```bash
cd link2ur && flutter analyze
```

- [ ] **Step 3: 运行现有测试**

```bash
cd link2ur && flutter test
```

- [ ] **Step 4: Final commit (如有修正)**

```bash
git add -A && git commit -m "fix: badge display adjustments from final review"
```

---

## 注意事项

1. **批量查询，避免 N+1**：所有列表端点必须先批量 `enrich_displayed_badges_sync/async`，不要在循环内逐个查。
2. **null safety**：前端所有 `InlineBadgeTag` 添加必须包裹在 `if (xxx.displayedBadge != null)` 条件中。
3. **布局兼容**：`InlineBadgeTag` 需要在 `Row`/`Wrap` 中与 `Text` 同行显示。如果原布局是 `Column`，需要将 name `Text` 包裹进 `Row`。
4. **数据可用性**：Task 7-13 中每个 Step 1 都有"检查数据源"环节 — 如果后端尚未返回 badge 数据，该视图暂时跳过（标注为 blocked by backend task）。
5. **向后兼容**：`displayed_badge` 全部是 Optional，老版本客户端 parse 不到也不会崩溃。
