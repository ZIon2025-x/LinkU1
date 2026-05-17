# Forum 体验优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把帖子板块从必选改为可选话题，同时把详情页评论改为「根评论按热度排序 + 渐进式分批展开」。

**Architecture:** 两部分独立但合并在一个 spec：
- **Part 1（板块可选）**：`forum_posts.category_id` 改 nullable；发帖路由跳过 NULL 时的 category 校验；列表查询 `visible_ids` 过滤改为 `OR category_id IS NULL`；Flutter / Web 端把 `categoryId` 改可空 + chip 条件渲染。
- **Part 2（评论）**：重构 `GET /api/forum/posts/{id}/replies` 只返根评论 + 每根 preview 3 子回复 + `total_children` 计数 + `sort` 参数；新增 `GET /api/forum/replies/{root_id}/children?offset&limit` 分批端点；Flutter BLoC state 管理已加载 `Map<rootId, List<reply>>`；`@xxx` 跳转兼容折叠。

**Tech Stack:** FastAPI + SQLAlchemy 2.x async + Pydantic v2 + PostgreSQL；Flutter 3.33+ BLoC + Equatable；React + TS（Web）。

**Spec:** `docs/superpowers/specs/2026-05-15-forum-category-optional-design.md`

**Critical reminders (per CLAUDE.md memory):**
- ⚠️ **Migration before deploy** ([memory](feedback_migration_before_deploy.md))：Task 1 的 migration 必须**先在 linktest staging DB 执行**，**再** push 后端代码到 main。否则 Railway 自动部署到没改列的 DB 会让 forum 读路径 500。
- ⚠️ **Direct to main**：每个 task 完成直接 `git commit` 到 main，不开 feature 分支。
- ⚠️ **Flutter env vars**：每次跑 Flutter 命令前先设 `$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; $env:GRADLE_USER_HOME = "F:\DevCache\.gradle"`。
- ⚠️ 每个 task 完成后必跑 `flutter analyze`（Flutter 端）/ `pytest backend/tests/` (后端) 验证。

---

## File Structure

### Part 1 — 板块可选

| Operation | File | Responsibility |
|---|---|---|
| Create | `backend/migrations/234_make_forum_post_category_optional.sql` | DDL: ALTER COLUMN nullable |
| Modify | `backend/app/models.py:2517` | `ForumPost.category_id` nullable=True |
| Modify | `backend/app/schemas.py:3894, 3998, 4037` | `ForumPostBase.category_id` Optional; `ForumPostOut.category` Optional |
| Modify | `backend/app/routes/forum_posts_routes.py:498-540, ~820` | create / update 路由跳过 NULL category check |
| Modify | `backend/app/routes/forum_discovery_routes.py:73-104` (+ 类似 list 端点) | `visible_ids.in_()` 改成 `or_(in_, is_(None))` |
| Add | `backend/tests/test_forum_post_optional_category.py` | NULL category 创建 + 列表可见性回归测试 |
| Modify | `link2ur/lib/data/models/forum.dart:299-340, 654-680` | `ForumPost.categoryId` / `CreatePostRequest.categoryId` → `int?` |
| Modify | `link2ur/lib/features/forum/views/create_post_view.dart:283-286` | 移除"未选板块"warning + 文案改"话题（可选）" |
| Modify | `link2ur/lib/features/forum/views/edit_post_view.dart` | 允许清空 |
| Modify | `link2ur/lib/features/forum/views/forum_post_list_view.dart` + 卡片 widget | category chip 条件渲染 |
| Modify | `link2ur/lib/features/forum/views/forum_post_detail_view.dart` | 同上 |
| Modify | `link2ur/lib/l10n/app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb` | 新增 `forumAddTopicOptional` 等 key |
| Modify | `frontend/src/pages/ForumCreatePost.tsx` / `Forum.tsx` / `ForumPostList.tsx` / `ForumPostDetail.tsx` | Web 同步：可选 + chip 条件渲染 |

### Part 2 — 评论排序 + 渐进折叠

| Operation | File | Responsibility |
|---|---|---|
| Modify | `backend/app/schemas.py:4088` | `ForumReplyOut` 加 `total_children: int = 0` 字段不改原结构 |
| Add | `backend/app/schemas.py` (after `ForumReplyListResponse`) | `ForumRootReplyOut`（extends ForumReplyOut，加 `preview_children`+ `total_children`）+ `ForumReplyChildrenPage` |
| Modify | `backend/app/schemas.py:4104` | `ForumReplyListResponse.replies: List[ForumRootReplyOut]` |
| Modify | `backend/app/routes/forum_replies_routes.py:55-187` | `get_replies` 重构：只根评论 + sort 参数 + 每根 preview 3 + total_children |
| Add | `backend/app/routes/forum_replies_routes.py` (new endpoint) | `GET /replies/{root_id}/children` offset/limit 分批 |
| Add | `backend/tests/test_forum_replies_sort_and_pagination.py` | sort=hot/time + children 分页测试 |
| Modify | `link2ur/lib/data/models/forum.dart:538-end` | `ForumReply` 加 `previewChildren` / `totalChildren` + 新增 `ForumReplyChildrenPage` |
| Modify | `link2ur/lib/data/repositories/forum_repository.dart` | `getReplies(sort)` + `getReplyChildren(rootId, offset, limit)` |
| Modify | `link2ur/lib/features/forum/bloc/forum_bloc.dart:101, 226, 410` | state 加 `loadedChildren` / `hasMoreChildren` / `currentSort`；event `ReplySortChanged` / `LoadMoreChildren` |
| Modify | `link2ur/lib/features/forum/views/forum_post_detail_view.dart` | 排序 chip + 展开按钮 + @xxx 跳转自动展开 |
| Modify | `frontend/src/pages/ForumPostDetail.tsx` | Web 同步：sort + 渐进展开 |

---

## Part 1: 板块可选化

### Task 1: Migration + ForumPost 模型可空

**Files:**
- Create: `backend/migrations/234_make_forum_post_category_optional.sql`
- Modify: `backend/app/models.py:2517`

- [ ] **Step 1: 创建 migration 文件**

文件内容：

```sql
-- Migration 234: make forum_posts.category_id nullable
-- Background: 板块从必选改为可选话题（spec 2026-05-15-forum-category-optional-design.md）
-- 必须先在 staging DB 跑完，再 push backend 代码

BEGIN;

ALTER TABLE forum_posts ALTER COLUMN category_id DROP NOT NULL;

COMMIT;
```

- [ ] **Step 2: 在 linktest staging DB 运行 migration**

获取 staging DB 连接 URL（通常在 Railway dashboard）。运行：

```bash
psql "$LINKTEST_DATABASE_URL" -f backend/migrations/234_make_forum_post_category_optional.sql
```

预期输出：`BEGIN`, `ALTER TABLE`, `COMMIT`。

验证：

```bash
psql "$LINKTEST_DATABASE_URL" -c "\d forum_posts" | grep category_id
```

预期 `category_id` 后**不**出现 `not null`。

- [ ] **Step 3: 改 `backend/app/models.py:2517`**

```python
# 原:
category_id = Column(Integer, ForeignKey("forum_categories.id", ondelete="CASCADE"), nullable=False)

# 改为:
category_id = Column(Integer, ForeignKey("forum_categories.id", ondelete="CASCADE"), nullable=True)
```

- [ ] **Step 4: 验证 model import 不报错**

```bash
cd backend && python -c "from app.models import ForumPost; print(ForumPost.__table__.columns['category_id'].nullable)"
```

预期输出：`True`

- [ ] **Step 5: Commit**

```bash
git add backend/migrations/234_make_forum_post_category_optional.sql backend/app/models.py
git commit -m "$(cat <<'EOF'
feat(forum): migration 234 让 forum_posts.category_id 可空

板块从必选改为可选话题的第一步（spec 2026-05-15）。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Pydantic schemas 可选

**Files:**
- Modify: `backend/app/schemas.py:3894, 3998, 4037`

- [ ] **Step 1: 改 `ForumPostBase.category_id` 为 Optional**

`backend/app/schemas.py:3894`：

```python
# 原:
class ForumPostBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200, description="帖子标题，1-200字符")
    title_en: Optional[str] = Field(None, max_length=200, description="帖子标题（英文）")
    title_zh: Optional[str] = Field(None, max_length=200, description="帖子标题（中文）")
    content: str = Field(..., min_length=10, max_length=50000, description="帖子内容，10-50000字符")
    content_en: Optional[str] = Field(None, max_length=50000, description="帖子内容（英文）")
    content_zh: Optional[str] = Field(None, max_length=50000, description="帖子内容（中文）")
    category_id: int = Field(..., description="板块ID")

# 改为:
class ForumPostBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200, description="帖子标题，1-200字符")
    title_en: Optional[str] = Field(None, max_length=200, description="帖子标题（英文）")
    title_zh: Optional[str] = Field(None, max_length=200, description="帖子标题（中文）")
    content: str = Field(..., min_length=10, max_length=50000, description="帖子内容，10-50000字符")
    content_en: Optional[str] = Field(None, max_length=50000, description="帖子内容（英文）")
    content_zh: Optional[str] = Field(None, max_length=50000, description="帖子内容（中文）")
    category_id: Optional[int] = Field(None, description="板块ID（可选，留空表示帖子不归属任何话题/板块）")
```

- [ ] **Step 2: 改 `ForumPostOut.category` 为 Optional**

`backend/app/schemas.py:3998`：

```python
# 原 (在 ForumPostOut 里):
    category: CategoryInfo

# 改为:
    category: Optional[CategoryInfo] = None
```

- [ ] **Step 3: 改 `ForumPostAdminOut.category` 为 Optional**

`backend/app/schemas.py:4037` 同样改：

```python
# 原:
    category: CategoryInfo

# 改为:
    category: Optional[CategoryInfo] = None
```

- [ ] **Step 4: 验证 import 不报错**

```bash
cd backend && python -c "from app.schemas import ForumPostBase, ForumPostOut, ForumPostAdminOut; print('OK')"
```

预期：`OK`

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat(forum): schemas 把 category_id/category 改可选

承接 migration 234，让 Pydantic 层接受 null。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 创建/编辑路由跳过 NULL category check

**Files:**
- Modify: `backend/app/routes/forum_posts_routes.py:498-540`（create_post）+ update_post 同位置

- [ ] **Step 1: 写失败测试**

新建 `backend/tests/test_forum_post_optional_category.py`：

```python
"""Test forum post creation with NULL category_id (spec 2026-05-15 Part 1)."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_create_post_with_null_category(
    async_client: AsyncClient, user_session_cookie: dict
):
    """发帖时 category_id 为 null 应当成功，post 落库 category_id=NULL。"""
    response = await async_client.post(
        "/api/forum/posts",
        json={
            "title": "Test post without category",
            "content": "Content body, at least 10 chars long.",
            "category_id": None,
        },
        cookies=user_session_cookie,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["category"] is None


@pytest.mark.asyncio
async def test_create_post_with_category_still_works(
    async_client: AsyncClient, user_session_cookie: dict, general_category_id: int
):
    """旧路径：传 category_id 时行为不变。"""
    response = await async_client.post(
        "/api/forum/posts",
        json={
            "title": "Test post with category",
            "content": "Content body, at least 10 chars long.",
            "category_id": general_category_id,
        },
        cookies=user_session_cookie,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["category"] is not None
    assert data["category"]["id"] == general_category_id
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd backend && pytest tests/test_forum_post_optional_category.py -v
```

预期：FAIL，因为路由还有 `if not category: raise 404` 在拒绝 NULL。

- [ ] **Step 3: 改 create_post 路由 `backend/app/routes/forum_posts_routes.py:498-540`**

把整段 category 验证 + 权限 + 达人板块 check 包在 `if post.category_id is not None:` 里：

```python
    # 验证板块是否存在并检查权限（仅当 category_id 提供时）
    # 对于学校板块，需要学生认证；对于普通板块，所有用户都可以发帖
    expert_id = None
    is_expert = False
    if post.category_id is not None:
        category_result = await db.execute(
            select(models.ForumCategory).where(models.ForumCategory.id == post.category_id)
        )
        category = category_result.scalar_one_or_none()
        if not category:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="板块不存在",
                headers={"X-Error-Code": "CATEGORY_NOT_FOUND"}
            )

        # 检查板块可见性（学校板块需要权限）
        if not is_admin_user:
            await assert_forum_visible(current_user, post.category_id, db, raise_exception=True)

        # 检查板块是否可见
        if not category.is_visible:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="该板块已隐藏",
                headers={"X-Error-Code": "CATEGORY_HIDDEN"}
            )

        # 检查板块是否禁止用户发帖
        if category.is_admin_only:
            if not is_admin_user:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="该板块只允许管理员发帖",
                    headers={"X-Error-Code": "ADMIN_ONLY_CATEGORY"}
                )

        # 达人板块发帖权限检查
        is_expert, expert_id = await is_expert_board(db, post.category_id)
        if is_expert:
            if not current_user:
                raise HTTPException(status_code=401, detail="达人板块需要登录后发帖")
            can_post = await check_expert_board_post_permission(db, expert_id, current_user.id)
            if not can_post:
                raise HTTPException(status_code=403, detail="只有达人团队成员才能在此板块发帖")
```

注意：`expert_id` / `is_expert` 已经在外层声明（默认 None / False），保留后续 `post_expert_id = expert_id if is_expert else None` 行为。

- [ ] **Step 4: 改 update_post 路由（同文件 line 801+）**

Grep 找到 update_post 里类似的 category 验证块，同样包在 `if updated_category_id is not None:` 里。如果 update_post 没有重新校验 category，跳过此步。

```bash
grep -n "category_id" backend/app/routes/forum_posts_routes.py | head -40
```

把任何对 `post.category_id` / `updates.category_id` 的强制校验（404 / 403）包在 `is not None` 守卫里。

- [ ] **Step 5: 跑测试验证通过**

```bash
cd backend && pytest tests/test_forum_post_optional_category.py -v
```

预期：两个测试 PASS。

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/forum_posts_routes.py backend/tests/test_forum_post_optional_category.py
git commit -m "feat(forum): 发帖路由跳过 NULL category_id 的板块校验

发帖 / 编辑帖子时,如果 category_id 为 None,跳过 category 存在 / 可见性 / admin_only / 达人板块所有校验。
传具体 id 时行为不变。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Discovery 列表 visibility filter 兼容 NULL（**关键风险点**）

**Files:**
- Modify: `backend/app/routes/forum_discovery_routes.py:73-104, 234-249, 408-420`（凡是 `visible_category_ids.in_()` 都要改）

- [ ] **Step 1: 写失败测试**

`backend/tests/test_forum_post_optional_category.py` 追加：

```python
@pytest.mark.asyncio
async def test_null_category_post_appears_in_discovery_feed(
    async_client: AsyncClient, user_session_cookie: dict
):
    """NULL category 帖子必须出现在社区发现流（spec 风险点 1）。"""
    # 1. 创建无 category 的帖子
    create_resp = await async_client.post(
        "/api/forum/posts",
        json={
            "title": "Null category test discovery",
            "content": "Should appear in discovery feed at least 10 chars.",
            "category_id": None,
        },
        cookies=user_session_cookie,
    )
    assert create_resp.status_code == 200
    post_id = create_resp.json()["id"]

    # 2. 调发现流 list
    list_resp = await async_client.get("/api/forum/posts", cookies=user_session_cookie)
    assert list_resp.status_code == 200
    ids = [p["id"] for p in list_resp.json()["posts"]]
    assert post_id in ids, "NULL category 帖被 visible_ids filter 吞掉了"


@pytest.mark.asyncio
async def test_null_category_post_not_in_specific_board(
    async_client: AsyncClient, user_session_cookie: dict, general_category_id: int
):
    """NULL category 帖子不应该出现在任何具体板块详情页。"""
    create_resp = await async_client.post(
        "/api/forum/posts",
        json={
            "title": "Null category test board exclusion",
            "content": "Should NOT appear in specific board listing.",
            "category_id": None,
        },
        cookies=user_session_cookie,
    )
    post_id = create_resp.json()["id"]

    list_resp = await async_client.get(
        f"/api/forum/posts?category_id={general_category_id}",
        cookies=user_session_cookie,
    )
    ids = [p["id"] for p in list_resp.json()["posts"]]
    assert post_id not in ids
```

- [ ] **Step 2: 跑测试，第一个 fail 第二个 pass**

```bash
cd backend && pytest tests/test_forum_post_optional_category.py::test_null_category_post_appears_in_discovery_feed -v
```

预期：FAIL（NULL 帖被过滤掉）

- [ ] **Step 3: 改 `forum_discovery_routes.py` search_posts（line 100-104）**

```python
# 原:
            # 3. 只搜索可见板块的帖子
            if visible_category_ids:
                query = query.where(models.ForumPost.category_id.in_(visible_category_ids))
            else:
                # 如果用户没有任何可见板块（理论上不应该发生），返回空结果
                query = query.where(models.ForumPost.category_id == -1)  # 不存在的ID

# 改为:
            # 3. 只搜索可见板块的帖子，以及 NULL category 的帖子（无板块归属，全局可见）
            from sqlalchemy import or_
            if visible_category_ids:
                query = query.where(
                    or_(
                        models.ForumPost.category_id.in_(visible_category_ids),
                        models.ForumPost.category_id.is_(None),
                    )
                )
            else:
                # 没有任何可见板块时仍允许看 NULL 帖
                query = query.where(models.ForumPost.category_id.is_(None))
```

- [ ] **Step 4: 改其他类似位置**

grep 找其他 `visible_category_ids.in_` 用法：

```bash
grep -n "visible_category_ids" backend/app/routes/forum_discovery_routes.py
```

每处都按同样模式改成 `or_(in_, is_(None))`。如果还有其他 routes 文件（如 `forum_posts_routes.py` 的 list 路由）有同样模式，也一并改。

```bash
grep -rn "visible_category_ids" backend/app/routes/
```

- [ ] **Step 5: 跑两个测试都 PASS**

```bash
cd backend && pytest tests/test_forum_post_optional_category.py -v
```

预期：4 个测试全 PASS。

- [ ] **Step 6: 注意通知可见性检查（spec Part 1 改动面 #4 次）**

打开 `backend/app/routes/forum_discovery_routes.py`，看 line 298-303 这种 `if category_id and category_id in visible_category_ids` 的位置：

```python
                category_id = post_category_map.get(n.target_id)
                if category_id and category_id in visible_category_ids:
```

这里逻辑是"category_id 存在且在 visible 列表里"才放行。NULL category 在我们设计里是"全局可见"，所以条件应该变成：

```python
                category_id = post_category_map.get(n.target_id)
                # NULL category 视为对所有用户可见（无板块隔离需求）
                if category_id is None or category_id in visible_category_ids:
```

把同文件所有类似 `category_id and category_id in visible_category_ids` 的判断都按此模式改。

- [ ] **Step 7: 跑全套 forum 测试确保没回归**

```bash
cd backend && pytest tests/ -v -k forum
```

预期：所有 forum 测试 PASS。

- [ ] **Step 8: Commit**

```bash
git add backend/app/routes/forum_discovery_routes.py backend/tests/test_forum_post_optional_category.py
git commit -m "feat(forum): discovery/notification 列表 visibility filter 兼容 NULL category

加 OR category_id IS NULL 让无板块归属的帖子出现在社区发现流但不出现在具体板块详情页。
spec 标记的关键风险点 1。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Flutter ForumPost / CreatePostRequest model 可空

**Files:**
- Modify: `link2ur/lib/data/models/forum.dart:299-340, 654-680`

- [ ] **Step 1: 改 ForumPost.categoryId 为 int?**

`link2ur/lib/data/models/forum.dart:339`：

```dart
// 原:
  final int categoryId;

// 改为:
  final int? categoryId;
```

构造函数 `required this.categoryId` 改成 `this.categoryId`：

```dart
// 原 line 301:
    required this.categoryId,

// 改为:
    this.categoryId,
```

fromJson `link2ur/lib/data/models/forum.dart:413`：

```dart
// 原:
      categoryId: _parseInt(json['category_id'], fallback: json['category'] != null ? _parseInt((json['category'] as Map<String, dynamic>)['id']) : 0),

// 改为 (NULL safe — 不存在或显式 null 时为 null):
      categoryId: json['category_id'] != null
          ? _parseInt(json['category_id'])
          : (json['category'] != null
              ? _parseInt((json['category'] as Map<String, dynamic>)['id'])
              : null),
```

toJson `link2ur/lib/data/models/forum.dart:461`：保持 `'category_id': categoryId,`（int? 序列化为 null 是正常的）。

copyWith 里若有 categoryId 参数，类型改 `int?`。

- [ ] **Step 2: 改 CreatePostRequest.categoryId 为 int?**

`link2ur/lib/data/models/forum.dart:654`：

```dart
// 原:
    required this.categoryId,

// 改为:
    this.categoryId,
```

`link2ur/lib/data/models/forum.dart:664`：

```dart
// 原:
  final int categoryId;

// 改为:
  final int? categoryId;
```

toJson `link2ur/lib/data/models/forum.dart:675`：保持 `'category_id': categoryId,`。

- [ ] **Step 3: flutter analyze**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/data/models/forum.dart
```

预期：0 error（可能有 warning 关于其他位置 nullable 解构，下一 task 处理）。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/models/forum.dart
git commit -m "feat(forum/flutter): ForumPost.categoryId 与 CreatePostRequest.categoryId 改可空

承接后端 schemas 改可选；fromJson/toJson 兼容 null。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Flutter 发帖页 + 编辑页可选话题

**Files:**
- Modify: `link2ur/lib/features/forum/views/create_post_view.dart:283-286`
- Modify: `link2ur/lib/features/forum/views/edit_post_view.dart`（grep 找类似强制校验位置）
- Modify: `link2ur/lib/l10n/app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb`

- [ ] **Step 1: 移除 create_post_view 的"未选板块" warning**

`link2ur/lib/features/forum/views/create_post_view.dart:283-286`：

```dart
// 原:
    if (_selectedCategoryId == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }

// 改为: 直接删除整个 if 块。category_id 现在可选。
```

- [ ] **Step 2: 改 section label 文案**

找文件里 `forumSelectCategory` / 类似 key 的引用，对应位置改成新的 l10n key `forumAddTopicOptional`。

- [ ] **Step 3: 加 l10n key**

`link2ur/lib/l10n/app_en.arb`：

```json
  "forumAddTopicOptional": "Add a topic (optional)",
  "@forumAddTopicOptional": {
    "description": "Topic picker section label on create-post page"
  },
```

`link2ur/lib/l10n/app_zh.arb`：

```json
  "forumAddTopicOptional": "添加话题（可选）",
```

`link2ur/lib/l10n/app_zh_Hant.arb`：

```json
  "forumAddTopicOptional": "新增話題（可選）",
```

- [ ] **Step 4: 重新生成 l10n**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 5: edit_post_view 允许清空话题**

打开 `link2ur/lib/features/forum/views/edit_post_view.dart`，找 categoryId 必填校验（如果有），同样删除。AppSelectField 配置加 `clearable: true`（如果 widget 支持）；否则在 onChanged 里允许 null。

- [ ] **Step 6: flutter analyze**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

预期：0 error。

- [ ] **Step 7: 跑 dev 验证手动**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter run -d web-server
```

打开 dev URL，进入"发帖"页，**不选话题**直接发布。预期：成功 → 跳回；社区流能看到新帖且没有话题 chip。

- [ ] **Step 8: Commit**

```bash
git add link2ur/lib/features/forum/views/create_post_view.dart link2ur/lib/features/forum/views/edit_post_view.dart link2ur/lib/l10n/
git commit -m "feat(forum/flutter): 发帖/编辑页话题改为可选

去掉 _selectedCategoryId == null 的强制 warning；
section label 改 forumAddTopicOptional；
edit_post_view 允许清空话题。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Flutter 帖子卡片 chip 条件渲染

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_list_view.dart`
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`
- 任何其他渲染 `post.category.name` 的位置

- [ ] **Step 1: Grep 找所有渲染 category 的位置**

```bash
grep -rn "post.category" link2ur/lib/features/forum/ link2ur/lib/core/widgets/
```

- [ ] **Step 2: 每处包条件渲染**

伪代码模式：

```dart
// 原:
Chip(label: Text(post.category.displayName(locale))),

// 改为:
if (post.category != null)
  Chip(label: Text(post.category!.displayName(locale))),
```

或者对 Row 里的 Chip：

```dart
// 原:
Row(children: [
  Avatar(...),
  CategoryChip(post.category),
  ...,
])

// 改为:
Row(children: [
  Avatar(...),
  if (post.category != null) CategoryChip(post.category!),
  ...,
])
```

注意：`post.category` 本身是 CategoryInfo？object 还是 raw int？看 Flutter 端 ForumPost 模型 — 上面 Task 5 改的是 `categoryId`。但 ForumPost 还可能有 `category: CategoryInfo` object 字段。grep 一下：

```bash
grep -n "category " link2ur/lib/data/models/forum.dart
```

如果 ForumPost 有 `final CategoryInfo? category`（或类似 object 字段），同样改为可空，fromJson 兼容 null。

- [ ] **Step 3: flutter analyze**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

预期：0 error。

- [ ] **Step 4: 手动验证**

跑 dev，确认：
- 普通帖子（有 category）：chip 正常显示
- 上一步刚发的 NULL category 帖：chip 不显示，其他字段正常

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/forum/views/ link2ur/lib/data/models/forum.dart link2ur/lib/core/widgets/
git commit -m "feat(forum/flutter): 帖子卡片 category chip 条件渲染

post.category == null 时不渲染 chip，列表/详情页一致。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Web frontend 同步（Part 1）

**Files:**
- Modify: `frontend/src/pages/ForumCreatePost.tsx`
- Modify: `frontend/src/pages/Forum.tsx` / `ForumPostList.tsx` / `ForumPostDetail.tsx`
- Modify: `frontend/src/api.ts`（如果 type 定义中 category_id 是 number）

- [ ] **Step 1: Grep web 端 category 引用**

```bash
grep -rn "category_id" frontend/src/ | head -30
grep -rn "post.category" frontend/src/ | head -30
```

- [ ] **Step 2: 改 type 定义**

`frontend/src/api.ts`（或 forum type 文件），找 ForumPost type：

```ts
// 原:
interface ForumPost {
  category: CategoryInfo;
  category_id: number;
  ...
}

// 改为:
interface ForumPost {
  category: CategoryInfo | null;
  category_id: number | null;
  ...
}
```

CreatePostRequest 同样改 `category_id?: number | null`。

- [ ] **Step 3: 改 ForumCreatePost.tsx 表单逻辑**

找 form validation：删除 `if (!categoryId) { ... 必选错误 }`；submit 时 categoryId 没选传 null。

- [ ] **Step 4: 改 ForumPostList.tsx / ForumPostDetail.tsx**

chip 渲染包 `{post.category && <Chip>...</Chip>}`。

- [ ] **Step 5: 构建验证**

```bash
cd frontend && npm run build
```

预期：build 成功，0 error。如果有 TS error 需要修。

- [ ] **Step 6: 本地跑验证手动**

```bash
cd frontend && npm run dev
```

打开 http://localhost:5173/forum，确认发帖无话题、列表、详情 chip 条件渲染都对。

- [ ] **Step 7: Commit**

```bash
git add frontend/src/
git commit -m "feat(forum/web): 同步 Part 1 — 话题可选 + chip 条件渲染

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

**🚦 Part 1 完成检查点。Push 前再次确认 staging migration 已跑：**

```bash
psql "$LINKTEST_DATABASE_URL" -c "\d forum_posts" | grep "category_id"
# 预期看到 "category_id | integer | "（无 not null）
```

确认后：

```bash
git push origin main
```

等 Railway linktest 部署完，curl 验证：

```bash
curl https://linktest.up.railway.app/api/forum/posts | jq '.posts | length'
# 应 >0
```

---

## Part 2: 评论排序 + 渐进折叠

### Task 9: Schemas - ForumRootReplyOut + ForumReplyChildrenPage

**Files:**
- Modify: `backend/app/schemas.py:4088-4109`

- [ ] **Step 1: 加新 schemas**

`backend/app/schemas.py` 在 `class ForumReplyOut` 之后、`class ForumReplyListResponse` 之前插入：

```python
class ForumRootReplyOut(ForumReplyOut):
    """根评论输出（仅用于列表 API 的 root 项）

    比 ForumReplyOut 多两个字段：
    - preview_children: 该根评论的前 3 条子回复，按时间正序
    - total_children: 该根评论下子回复总数（用于"展开剩余 N 条"按钮）
    """
    preview_children: List[ForumReplyOut] = Field(
        default_factory=list,
        description="前 3 条子回复（按 created_at ASC）",
    )
    total_children: int = Field(
        default=0,
        description="该根评论下子回复总数（不含软删 is_deleted=True 的）",
    )


class ForumReplyChildrenPage(BaseModel):
    """根评论的子回复分页响应"""
    replies: List[ForumReplyOut]
    has_more: bool = Field(description="是否还有更多未加载的子回复")
    next_offset: int = Field(description="下一批分页 offset")
```

- [ ] **Step 2: 改 ForumReplyListResponse.replies 类型**

`backend/app/schemas.py:4104`：

```python
# 原:
class ForumReplyListResponse(BaseModel):
    """回复列表响应"""
    replies: List[ForumReplyOut]
    total: int
    page: int
    page_size: int

# 改为:
class ForumReplyListResponse(BaseModel):
    """回复列表响应（重构后：仅根评论 + 每根 preview 3 子回复 + total_children；
    total 字段语义改为"根评论总数"，子回复数请用 ForumPost.reply_count）"""
    replies: List[ForumRootReplyOut]
    total: int
    page: int
    page_size: int
```

- [ ] **Step 3: 验证 import**

```bash
cd backend && python -c "from app.schemas import ForumRootReplyOut, ForumReplyChildrenPage, ForumReplyListResponse; print('OK')"
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat(forum): 加 ForumRootReplyOut + ForumReplyChildrenPage schemas

为 Part 2 的渐进折叠回复 API 准备。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: 重构 `GET /posts/{id}/replies` — 只返根评论 + preview + sort

**Files:**
- Modify: `backend/app/routes/forum_replies_routes.py:42-187`

- [ ] **Step 1: 写失败测试**

新建 `backend/tests/test_forum_replies_sort_and_pagination.py`：

```python
"""Test reply hot sort + progressive children loading (spec 2026-05-15 Part 2)."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_replies_returns_only_root_with_preview(
    async_client: AsyncClient, post_with_5_root_4_children: dict
):
    """重构后 GET /posts/{id}/replies 只返根评论 + preview 前 3 children。"""
    post_id = post_with_5_root_4_children["post_id"]
    resp = await async_client.get(f"/api/forum/posts/{post_id}/replies?sort=hot")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 5  # 5 个根评论
    for root in data["replies"]:
        assert root["parent_reply_id"] is None
        assert len(root["preview_children"]) <= 3
        assert root["total_children"] == 4  # 每根 4 条子回复


@pytest.mark.asyncio
async def test_sort_hot_orders_by_like_count(
    async_client: AsyncClient, post_with_mixed_likes: dict
):
    """sort=hot 时根评论按 like_count DESC 排序。"""
    post_id = post_with_mixed_likes["post_id"]
    resp = await async_client.get(f"/api/forum/posts/{post_id}/replies?sort=hot")
    likes = [r["like_count"] for r in resp.json()["replies"]]
    assert likes == sorted(likes, reverse=True)


@pytest.mark.asyncio
async def test_sort_time_orders_by_created_at_asc(
    async_client: AsyncClient, post_with_mixed_likes: dict
):
    """sort=time 时根评论按 created_at ASC 排序。"""
    post_id = post_with_mixed_likes["post_id"]
    resp = await async_client.get(f"/api/forum/posts/{post_id}/replies?sort=time")
    timestamps = [r["created_at"] for r in resp.json()["replies"]]
    assert timestamps == sorted(timestamps)


@pytest.mark.asyncio
async def test_preview_children_ordered_by_time_asc_regardless_of_root_sort(
    async_client: AsyncClient, post_with_mixed_likes: dict
):
    """子回复 preview 始终按时间正序，无论根的 sort 模式。"""
    post_id = post_with_mixed_likes["post_id"]
    resp = await async_client.get(f"/api/forum/posts/{post_id}/replies?sort=hot")
    for root in resp.json()["replies"]:
        previews = root["preview_children"]
        if len(previews) >= 2:
            ts = [p["created_at"] for p in previews]
            assert ts == sorted(ts), "preview_children 不是按 created_at ASC"
```

`post_with_5_root_4_children` 和 `post_with_mixed_likes` fixture 在 `backend/tests/conftest.py` 中新建：

```python
# backend/tests/conftest.py 加：
@pytest.fixture
async def post_with_5_root_4_children(db_session, test_user):
    """生成 1 个帖子 + 5 个根评论 + 每根 4 个子回复（共 25 条 reply）"""
    from app import models
    from datetime import datetime, timezone
    post = models.ForumPost(title="t", content="x"*20, author_id=test_user.id)
    db_session.add(post)
    await db_session.commit()
    root_ids = []
    for i in range(5):
        root = models.ForumReply(
            post_id=post.id, author_id=test_user.id, content=f"root{i}", like_count=i,
        )
        db_session.add(root)
        await db_session.commit()
        root_ids.append(root.id)
        for j in range(4):
            child = models.ForumReply(
                post_id=post.id, author_id=test_user.id,
                content=f"child{i}-{j}", parent_reply_id=root.id, like_count=0,
            )
            db_session.add(child)
        await db_session.commit()
    return {"post_id": post.id, "root_ids": root_ids}


@pytest.fixture
async def post_with_mixed_likes(db_session, test_user):
    """4 个根评论，like_count 错乱：[3, 7, 1, 5]"""
    from app import models
    post = models.ForumPost(title="mixed", content="x"*20, author_id=test_user.id)
    db_session.add(post)
    await db_session.commit()
    likes = [3, 7, 1, 5]
    root_ids = []
    for i, lk in enumerate(likes):
        r = models.ForumReply(
            post_id=post.id, author_id=test_user.id,
            content=f"root{i}", like_count=lk,
        )
        db_session.add(r)
        await db_session.commit()
        root_ids.append(r.id)
        # 给每个根加 2 个子回复，时间分别为 t0, t1
        for j in range(2):
            c = models.ForumReply(
                post_id=post.id, author_id=test_user.id,
                content=f"c{i}-{j}", parent_reply_id=r.id,
            )
            db_session.add(c)
        await db_session.commit()
    return {"post_id": post.id, "root_ids": root_ids}
```

- [ ] **Step 2: 跑测试确认 fail**

```bash
cd backend && pytest tests/test_forum_replies_sort_and_pagination.py -v
```

预期：4 个测试 FAIL（API 还返回扁平全部树）。

- [ ] **Step 3: 重构 get_replies**

替换 `backend/app/routes/forum_replies_routes.py:42-187` 整个 `get_replies` 函数（保留签名和上面的 import + auth 块结构，只重写 query 部分）：

```python
from sqlalchemy import func as sa_func


@router.get("/posts/{post_id}/replies", response_model=schemas.ForumReplyListResponse)
async def get_replies(
    post_id: int,
    sort: str = Query("hot", regex="^(hot|time)$", description="排序方式：hot 按点赞 / time 按时间"),
    page: int = Query(1, ge=1, description="保留兼容性，当前实现不分页根评论"),
    page_size: int = Query(100, ge=1, le=200, description="根评论上限"),
    request: Request = None,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取帖子回复列表

    重构后只返根评论 + 每根 preview 前 3 条子回复 + total_children 计数。
    子回复分批通过 GET /api/forum/replies/{root_id}/children 拉取。
    """
    # 验证 post 可见性
    is_admin = False
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass

    post = await get_post_with_permissions(post_id, current_user, is_admin, db, current_admin)

    # 判定是否作者（决定是否能看 is_visible=False 的回复）
    is_author = False
    if current_user and post.author_id == current_user.id:
        is_author = True
    if current_admin and post.admin_author_id == current_admin.id:
        is_author = True

    # === 1. 查根评论 ===
    root_query = select(models.ForumReply).where(
        models.ForumReply.post_id == post_id,
        models.ForumReply.parent_reply_id.is_(None),
        models.ForumReply.is_deleted == False,
    )
    if not is_admin and not is_author:
        root_query = root_query.where(models.ForumReply.is_visible == True)

    if sort == "hot":
        root_query = root_query.order_by(
            models.ForumReply.like_count.desc(),
            models.ForumReply.created_at.desc(),
        )
    else:
        root_query = root_query.order_by(models.ForumReply.created_at.asc())

    # 总根评论数
    total_root_result = await db.execute(
        select(func.count()).select_from(root_query.subquery())
    )
    total_root = total_root_result.scalar() or 0

    root_query = root_query.limit(page_size).options(
        selectinload(models.ForumReply.author),
        selectinload(models.ForumReply.admin_author),
    )
    root_result = await db.execute(root_query)
    root_replies = root_result.scalars().all()
    root_ids = [r.id for r in root_replies]

    # === 2. 每根的前 3 条子回复（窗口函数）===
    preview_map: Dict[int, List[models.ForumReply]] = {}
    if root_ids:
        rn = sa_func.row_number().over(
            partition_by=models.ForumReply.parent_reply_id,
            order_by=models.ForumReply.created_at.asc(),
        ).label("rn")

        child_filters = [
            models.ForumReply.parent_reply_id.in_(root_ids),
            models.ForumReply.is_deleted == False,
        ]
        if not is_admin and not is_author:
            child_filters.append(models.ForumReply.is_visible == True)

        subq = (
            select(models.ForumReply.id, rn)
            .where(*child_filters)
            .subquery()
        )

        preview_query = (
            select(models.ForumReply)
            .join(subq, models.ForumReply.id == subq.c.id)
            .where(subq.c.rn <= 3)
            .options(
                selectinload(models.ForumReply.author),
                selectinload(models.ForumReply.admin_author),
                selectinload(models.ForumReply.parent_reply),
            )
            .order_by(models.ForumReply.parent_reply_id, models.ForumReply.created_at.asc())
        )
        preview_result = await db.execute(preview_query)
        for child in preview_result.scalars().all():
            preview_map.setdefault(child.parent_reply_id, []).append(child)

    # === 3. 每根的 total_children 计数 ===
    total_children_map: Dict[int, int] = {}
    if root_ids:
        count_filters = [
            models.ForumReply.parent_reply_id.in_(root_ids),
            models.ForumReply.is_deleted == False,
        ]
        if not is_admin and not is_author:
            count_filters.append(models.ForumReply.is_visible == True)

        count_result = await db.execute(
            select(
                models.ForumReply.parent_reply_id,
                func.count(models.ForumReply.id),
            )
            .where(*count_filters)
            .group_by(models.ForumReply.parent_reply_id)
        )
        for parent_id, count in count_result.all():
            total_children_map[parent_id] = count

    # === 4. 批量查询点赞状态 ===
    all_reply_ids = list(root_ids)
    for previews in preview_map.values():
        all_reply_ids.extend(p.id for p in previews)

    user_liked_replies: set[int] = set()
    if current_user and all_reply_ids:
        like_result = await db.execute(
            select(models.ForumLike.target_id)
            .where(
                models.ForumLike.target_type == "reply",
                models.ForumLike.target_id.in_(all_reply_ids),
                models.ForumLike.user_id == current_user.id,
            )
        )
        user_liked_replies = {row[0] for row in like_result.all()}

    # 预加载所有 author 勋章
    all_author_ids = list({r.author_id for r in root_replies if r.author_id})
    for previews in preview_map.values():
        all_author_ids.extend(p.author_id for p in previews if p.author_id)
    _badge_cache = await preload_badge_cache(db, list(set(all_author_ids)))

    # === 5. 构建输出 ===
    async def to_reply_out(reply: models.ForumReply) -> schemas.ForumReplyOut:
        parent_author = None
        if reply.parent_reply_id and getattr(reply, "parent_reply", None):
            parent_author = await get_reply_author_info(
                db, reply.parent_reply, request, _badge_cache=_badge_cache
            )
        return schemas.ForumReplyOut(
            id=reply.id,
            content=reply.content,
            author=await get_reply_author_info(db, reply, request, _badge_cache=_badge_cache),
            parent_reply_id=reply.parent_reply_id,
            parent_reply_author=parent_author,
            like_count=reply.like_count,
            is_liked=reply.id in user_liked_replies,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
        )

    out_replies: List[schemas.ForumRootReplyOut] = []
    for root in root_replies:
        previews = preview_map.get(root.id, [])
        preview_outs = [await to_reply_out(c) for c in previews]
        root_dict = (await to_reply_out(root)).model_dump()
        out_replies.append(
            schemas.ForumRootReplyOut(
                **root_dict,
                preview_children=preview_outs,
                total_children=total_children_map.get(root.id, 0),
            )
        )

    return schemas.ForumReplyListResponse(
        replies=out_replies,
        total=total_root,
        page=1,
        page_size=len(out_replies),
    )
```

- [ ] **Step 4: 跑测试 PASS**

```bash
cd backend && pytest tests/test_forum_replies_sort_and_pagination.py -v
```

预期：所有 PASS。

- [ ] **Step 5: 跑 forum 全套测试无回归**

```bash
cd backend && pytest tests/ -v -k forum
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/forum_replies_routes.py backend/tests/test_forum_replies_sort_and_pagination.py backend/tests/conftest.py
git commit -m "feat(forum): 重构 GET /posts/{id}/replies 为根评论 + preview + sort

只返根评论 + 每根前 3 条子回复 preview + total_children；
sort=hot 时根按 like_count DESC，sort=time 时按 created_at ASC；
子回复 preview 始终按 created_at ASC（保对话顺序）。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: 新端点 `GET /replies/{root_id}/children` 分批

**Files:**
- Add: `backend/app/routes/forum_replies_routes.py`（新 endpoint）

- [ ] **Step 1: 加测试**

`backend/tests/test_forum_replies_sort_and_pagination.py` 追加：

```python
@pytest.mark.asyncio
async def test_get_reply_children_pagination(
    async_client: AsyncClient, post_with_5_root_4_children: dict
):
    """`GET /replies/{root_id}/children?offset=3&limit=5` 返回第 4 条起的 1 条 + has_more=False。"""
    root_id = post_with_5_root_4_children["root_ids"][0]
    resp = await async_client.get(
        f"/api/forum/replies/{root_id}/children?offset=3&limit=5"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["replies"]) == 1  # 共 4 条，前 3 已 preview，offset=3 拿第 4
    assert data["has_more"] is False
    assert data["next_offset"] == 4


@pytest.mark.asyncio
async def test_get_reply_children_first_batch(
    async_client: AsyncClient, post_with_5_root_4_children: dict
):
    """offset=3&limit=2 应返回 1 条（剩余 1 条）+ has_more=False。"""
    root_id = post_with_5_root_4_children["root_ids"][0]
    resp = await async_client.get(
        f"/api/forum/replies/{root_id}/children?offset=3&limit=2"
    )
    data = resp.json()
    assert len(data["replies"]) == 1
    assert data["has_more"] is False


@pytest.mark.asyncio
async def test_get_reply_children_rejects_non_root(
    async_client: AsyncClient, post_with_5_root_4_children: dict
):
    """不是根回复时返回 404。"""
    # 先拿到一个子回复 id
    post_id = post_with_5_root_4_children["post_id"]
    list_resp = await async_client.get(f"/api/forum/posts/{post_id}/replies")
    child_id = list_resp.json()["replies"][0]["preview_children"][0]["id"]
    resp = await async_client.get(f"/api/forum/replies/{child_id}/children")
    assert resp.status_code == 404
```

- [ ] **Step 2: 跑测试确认 fail**

预期：3 个测试 FAIL，因为端点不存在（404）。

- [ ] **Step 3: 添加 endpoint**

在 `backend/app/routes/forum_replies_routes.py` 文件**底部**（其他 endpoint 之后）插入：

```python
@router.get(
    "/replies/{reply_id}/children",
    response_model=schemas.ForumReplyChildrenPage,
)
async def get_reply_children(
    reply_id: int,
    offset: int = Query(3, ge=0, description="跳过前 N 条已 preview 的，默认 3"),
    limit: int = Query(5, ge=1, le=20, description="本批拉取数，默认 5"),
    request: Request = None,
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取某根评论的子回复，按时间正序，offset/limit 分页

    用于详情页"展开剩余 N 条回复"按钮，按需分批拉。
    """
    # 1. 验证根回复存在且不是子回复
    root_result = await db.execute(
        select(models.ForumReply).where(
            models.ForumReply.id == reply_id,
            models.ForumReply.is_deleted == False,
        )
    )
    root = root_result.scalar_one_or_none()
    if not root or root.parent_reply_id is not None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="根评论不存在",
            headers={"X-Error-Code": "ROOT_REPLY_NOT_FOUND"},
        )

    # 2. 验证 post 可见性
    is_admin = False
    current_admin = None
    try:
        current_admin = await get_current_admin_async(request, db)
        is_admin = True
    except HTTPException:
        pass
    post = await get_post_with_permissions(root.post_id, current_user, is_admin, db, current_admin)

    is_author = False
    if current_user and post.author_id == current_user.id:
        is_author = True
    if current_admin and post.admin_author_id == current_admin.id:
        is_author = True

    # 3. 查 children：多拉一条用来判断 has_more
    children_query = select(models.ForumReply).where(
        models.ForumReply.parent_reply_id == reply_id,
        models.ForumReply.is_deleted == False,
    )
    if not is_admin and not is_author:
        children_query = children_query.where(models.ForumReply.is_visible == True)
    children_query = (
        children_query
        .order_by(models.ForumReply.created_at.asc())
        .offset(offset)
        .limit(limit + 1)
        .options(
            selectinload(models.ForumReply.author),
            selectinload(models.ForumReply.admin_author),
            selectinload(models.ForumReply.parent_reply),
        )
    )
    result = await db.execute(children_query)
    children = result.scalars().all()
    has_more = len(children) > limit
    children = children[:limit]

    # 4. 批量点赞 + badge
    child_ids = [c.id for c in children]
    user_liked_replies: set[int] = set()
    if current_user and child_ids:
        like_result = await db.execute(
            select(models.ForumLike.target_id)
            .where(
                models.ForumLike.target_type == "reply",
                models.ForumLike.target_id.in_(child_ids),
                models.ForumLike.user_id == current_user.id,
            )
        )
        user_liked_replies = {row[0] for row in like_result.all()}

    _author_ids = list({c.author_id for c in children if c.author_id})
    _badge_cache = await preload_badge_cache(db, _author_ids)

    out_children = []
    for c in children:
        parent_author = None
        if c.parent_reply_id and getattr(c, "parent_reply", None):
            parent_author = await get_reply_author_info(
                db, c.parent_reply, request, _badge_cache=_badge_cache
            )
        out_children.append(
            schemas.ForumReplyOut(
                id=c.id,
                content=c.content,
                author=await get_reply_author_info(db, c, request, _badge_cache=_badge_cache),
                parent_reply_id=c.parent_reply_id,
                parent_reply_author=parent_author,
                like_count=c.like_count,
                is_liked=c.id in user_liked_replies,
                created_at=c.created_at,
                updated_at=c.updated_at,
            )
        )

    return schemas.ForumReplyChildrenPage(
        replies=out_children,
        has_more=has_more,
        next_offset=offset + len(children),
    )
```

- [ ] **Step 4: 跑测试 PASS**

```bash
cd backend && pytest tests/test_forum_replies_sort_and_pagination.py -v
```

预期：所有 PASS（包括前面 4 个 + 这 3 个新加的 = 7 个）。

- [ ] **Step 5: 手动 curl 验证**

```bash
curl https://linktest.up.railway.app/api/forum/posts/{some_post_id}/replies?sort=hot | jq '.replies[0]'
curl https://linktest.up.railway.app/api/forum/replies/{root_id}/children?offset=3&limit=5 | jq
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/routes/forum_replies_routes.py backend/tests/test_forum_replies_sort_and_pagination.py
git commit -m "feat(forum): 加 GET /replies/{root_id}/children 分批端点

offset/limit 分页 + has_more + next_offset，用于详情页渐进展开。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

**🚦 Backend Part 2 完成检查点。Push 让 linktest 部署：**

```bash
git push origin main
```

---

### Task 12: Flutter ForumReply 模型 + ForumReplyChildrenPage

**Files:**
- Modify: `link2ur/lib/data/models/forum.dart:538`（ForumReply）+ 新增 ForumReplyChildrenPage

- [ ] **Step 1: 加 totalChildren + previewChildren 字段到 ForumReply**

`link2ur/lib/data/models/forum.dart:538-end of ForumReply class`，在构造函数和字段定义里加：

```dart
class ForumReply extends Equatable {
  const ForumReply({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.author,
    this.parentReplyId,
    this.parentReplyAuthor,
    this.likeCount = 0,
    this.isLiked = false,
    this.createdAt,
    this.updatedAt,
    this.previewChildren = const [],
    this.totalChildren = 0,
  });

  final int id;
  final int postId;
  final String content;
  final String authorId;
  final UserBrief author;
  final int? parentReplyId;
  final UserBrief? parentReplyAuthor;
  final int likeCount;
  final bool isLiked;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ForumReply> previewChildren;
  final int totalChildren;

  bool get isSubReply => parentReplyId != null;
  bool get isRoot => parentReplyId == null;
  int get hiddenChildrenCount =>
      totalChildren - previewChildren.length;
```

fromJson 加：

```dart
  factory ForumReply.fromJson(Map<String, dynamic> json) {
    return ForumReply(
      // ... 原有字段不变 ...
      previewChildren: (json['preview_children'] as List?)
              ?.map((e) => ForumReply.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalChildren: (json['total_children'] as int?) ?? 0,
    );
  }
```

copyWith 同步加这两个字段。

- [ ] **Step 2: 新增 ForumReplyChildrenPage class**

`link2ur/lib/data/models/forum.dart` 文件底部加：

```dart
/// `GET /api/forum/replies/{root_id}/children` 响应模型
class ForumReplyChildrenPage extends Equatable {
  const ForumReplyChildrenPage({
    required this.replies,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<ForumReply> replies;
  final bool hasMore;
  final int nextOffset;

  factory ForumReplyChildrenPage.fromJson(Map<String, dynamic> json) {
    return ForumReplyChildrenPage(
      replies: (json['replies'] as List)
          .map((e) => ForumReply.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool? ?? false,
      nextOffset: json['next_offset'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [replies, hasMore, nextOffset];
}
```

- [ ] **Step 3: flutter analyze**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/data/models/forum.dart
```

预期：0 error。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/models/forum.dart
git commit -m "feat(forum/flutter): ForumReply 加 previewChildren/totalChildren + ForumReplyChildrenPage

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: Flutter Repository — sort 参数 + getReplyChildren

**Files:**
- Modify: `link2ur/lib/data/repositories/forum_repository.dart`

- [ ] **Step 1: 改 getReplies 加 sort 参数**

打开 `link2ur/lib/data/repositories/forum_repository.dart`，找到 `getReplies` 方法：

```dart
// 原 (大致):
  Future<List<ForumReply>> getReplies(int postId, {int page = 1}) async {
    final resp = await _api.get('/api/forum/posts/$postId/replies',
        queryParameters: {'page': page});
    final list = (resp.data['replies'] as List)
        .map((e) => ForumReply.fromJson(e))
        .toList();
    return list;
  }

// 改为:
  Future<List<ForumReply>> getReplies(
    int postId, {
    String sort = 'hot',
    int pageSize = 100,
  }) async {
    final resp = await _api.get(
      '/api/forum/posts/$postId/replies',
      queryParameters: {'sort': sort, 'page_size': pageSize},
    );
    final list = (resp.data['replies'] as List)
        .map((e) => ForumReply.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
```

- [ ] **Step 2: 新增 getReplyChildren 方法**

`forum_repository.dart` 加新方法：

```dart
  /// 拉取某根评论的子回复分页
  /// [rootReplyId] 根评论 id
  /// [offset] 跳过前 N 条（默认 3，跳过已 preview）
  /// [limit] 本批拉取数（默认 5）
  Future<ForumReplyChildrenPage> getReplyChildren(
    int rootReplyId, {
    int offset = 3,
    int limit = 5,
  }) async {
    final resp = await _api.get(
      '/api/forum/replies/$rootReplyId/children',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    return ForumReplyChildrenPage.fromJson(
      resp.data as Map<String, dynamic>,
    );
  }
```

- [ ] **Step 3: flutter analyze**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/data/repositories/forum_repository.dart
```

预期：0 error。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/repositories/forum_repository.dart
git commit -m "feat(forum/flutter): repository 加 sort 参数 + getReplyChildren 方法

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Flutter ForumBloc — state + events 排序 + loadMore

**Files:**
- Modify: `link2ur/lib/features/forum/bloc/forum_bloc.dart`

- [ ] **Step 1: 在 ForumEvent 上加新事件**

找 `class ForumLoadReplies extends ForumEvent`（line 101），在它附近加：

```dart
class ForumLoadReplies extends ForumEvent {
  const ForumLoadReplies(this.postId, {this.sort = 'hot'});
  final int postId;
  final String sort;
  @override
  List<Object?> get props => [postId, sort];
}

class ForumReplySortChanged extends ForumEvent {
  const ForumReplySortChanged(this.postId, this.sort);
  final int postId;
  final String sort;
  @override
  List<Object?> get props => [postId, sort];
}

class ForumLoadMoreChildren extends ForumEvent {
  const ForumLoadMoreChildren(this.rootReplyId);
  final int rootReplyId;
  @override
  List<Object?> get props => [rootReplyId];
}
```

- [ ] **Step 2: 在 ForumState 上加字段**

找 `class ForumState extends Equatable`（line 226），加字段：

```dart
  final String replySort; // 'hot' | 'time'
  final Map<int, List<ForumReply>> loadedChildren; // rootReplyId -> 已加载的所有子回复
  final Map<int, bool> hasMoreChildren; // rootReplyId -> 是否还有更多
  final Map<int, int> nextChildOffset; // rootReplyId -> 下批 offset
  final Set<int> loadingChildrenRoots; // 正在 load 中的 rootReplyId 集合
```

构造函数 + copyWith 同步加。默认值：
- `replySort = 'hot'`
- 四个 Map / Set 默认 `const {}` / `const <int>{}`

- [ ] **Step 3: 加 event handler**

`forum_bloc.dart:410+` 在 `class ForumBloc` 里加 `on<...>` 注册：

```dart
    on<ForumReplySortChanged>(_onReplySortChanged);
    on<ForumLoadMoreChildren>(_onLoadMoreChildren);
```

实现：

```dart
  Future<void> _onReplySortChanged(
    ForumReplySortChanged event,
    Emitter<ForumState> emit,
  ) async {
    // 切换 sort 后重新拉根评论 + preview
    emit(state.copyWith(
      replySort: event.sort,
      loadedChildren: const {},
      hasMoreChildren: const {},
      nextChildOffset: const {},
    ));
    add(ForumLoadReplies(event.postId, sort: event.sort));
  }

  Future<void> _onLoadMoreChildren(
    ForumLoadMoreChildren event,
    Emitter<ForumState> emit,
  ) async {
    final rootId = event.rootReplyId;
    if (state.loadingChildrenRoots.contains(rootId)) return; // 防重复

    emit(state.copyWith(
      loadingChildrenRoots: {...state.loadingChildrenRoots, rootId},
    ));

    try {
      final offset = state.nextChildOffset[rootId] ?? 3;
      final page = await _repository.getReplyChildren(
        rootId,
        offset: offset,
        limit: 5,
      );
      final existing = state.loadedChildren[rootId] ?? const [];
      emit(state.copyWith(
        loadedChildren: {
          ...state.loadedChildren,
          rootId: [...existing, ...page.replies],
        },
        hasMoreChildren: {...state.hasMoreChildren, rootId: page.hasMore},
        nextChildOffset: {...state.nextChildOffset, rootId: page.nextOffset},
        loadingChildrenRoots:
            state.loadingChildrenRoots.where((id) => id != rootId).toSet(),
      ));
    } catch (e) {
      emit(state.copyWith(
        loadingChildrenRoots:
            state.loadingChildrenRoots.where((id) => id != rootId).toSet(),
        errorMessage: 'forum_load_children_failed',
      ));
    }
  }
```

- [ ] **Step 4: 改 _onLoadReplies 用新 sort 参数**

`forum_bloc.dart` 的 `_onLoadReplies`：

```dart
  Future<void> _onLoadReplies(
    ForumLoadReplies event,
    Emitter<ForumState> emit,
  ) async {
    emit(state.copyWith(status: ForumStatus.loading));
    try {
      final replies = await _repository.getReplies(
        event.postId,
        sort: event.sort,
      );
      emit(state.copyWith(
        status: ForumStatus.loaded,
        replies: replies,
        replySort: event.sort,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ForumStatus.error,
        errorMessage: 'forum_load_replies_failed',
      ));
    }
  }
```

- [ ] **Step 5: flutter analyze**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze lib/features/forum/bloc/forum_bloc.dart
```

预期：0 error。

- [ ] **Step 6: 写 BLoC test**

新建 `link2ur/test/features/forum/forum_bloc_reply_sort_test.dart`：

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/data/models/forum.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';
import 'package:link2ur/features/forum/bloc/forum_bloc.dart';

class MockForumRepository extends Mock implements ForumRepository {}

void main() {
  group('ForumBloc reply sort + load more', () {
    late MockForumRepository repo;

    setUp(() {
      repo = MockForumRepository();
    });

    blocTest<ForumBloc, ForumState>(
      'ForumReplySortChanged 触发清空 loadedChildren + 重拉根评论',
      build: () {
        when(() => repo.getReplies(1, sort: 'time'))
            .thenAnswer((_) async => []);
        return ForumBloc(forumRepository: repo)
          ..emit(ForumState.initial().copyWith(
            loadedChildren: {10: [/* fake */]},
          ));
      },
      act: (bloc) => bloc.add(const ForumReplySortChanged(1, 'time')),
      expect: () => [
        // 1. clear children + set sort
        isA<ForumState>().having((s) => s.replySort, 'sort', 'time'),
        // 2. loading
        isA<ForumState>().having((s) => s.status, 'status', ForumStatus.loading),
        // 3. loaded
        isA<ForumState>().having((s) => s.status, 'status', ForumStatus.loaded),
      ],
    );

    blocTest<ForumBloc, ForumState>(
      'ForumLoadMoreChildren 拼接 children + 更新 hasMore/offset',
      build: () {
        when(() => repo.getReplyChildren(10, offset: 3, limit: 5))
            .thenAnswer((_) async => ForumReplyChildrenPage(
                  replies: [/* fake reply */],
                  hasMore: false,
                  nextOffset: 4,
                ));
        return ForumBloc(forumRepository: repo);
      },
      act: (bloc) => bloc.add(const ForumLoadMoreChildren(10)),
      expect: () => [
        // 1. loadingChildrenRoots contains 10
        isA<ForumState>().having(
          (s) => s.loadingChildrenRoots.contains(10),
          'loading',
          true,
        ),
        // 2. loaded
        isA<ForumState>()
            .having((s) => s.hasMoreChildren[10], 'hasMore', false)
            .having((s) => s.nextChildOffset[10], 'nextOffset', 4),
      ],
    );
  });
}
```

- [ ] **Step 7: 跑 BLoC test**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test test/features/forum/forum_bloc_reply_sort_test.dart
```

预期：所有 PASS。

- [ ] **Step 8: Commit**

```bash
git add link2ur/lib/features/forum/bloc/forum_bloc.dart link2ur/test/features/forum/forum_bloc_reply_sort_test.dart
git commit -m "feat(forum/flutter): BLoC 加 replySort + loadedChildren + LoadMoreChildren

支持详情页排序切换 + 子回复分批加载。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Flutter 详情页 sort chip + 展开按钮 + @ 跳转自动展开

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

- [ ] **Step 1: 在评论标题行加排序 chip**

找评论标题渲染位置（grep `评论\(` 或 `commentsTitle` / 类似），在标题右侧加：

```dart
Row(
  children: [
    Text('${context.l10n.forumCommentsTitle} ${state.replies.length}'),
    const Spacer(),
    InkWell(
      onTap: () async {
        final newSort = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(context.l10n.forumSortByHot),
                trailing: state.replySort == 'hot' ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, 'hot'),
              ),
              ListTile(
                title: Text(context.l10n.forumSortByTime),
                trailing: state.replySort == 'time' ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, 'time'),
              ),
            ],
          ),
        );
        if (newSort != null && newSort != state.replySort) {
          context.read<ForumBloc>().add(
            ForumReplySortChanged(widget.postId, newSort),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderLight),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.replySort == 'hot'
                ? context.l10n.forumSortByHot
                : context.l10n.forumSortByTime),
            const Icon(Icons.expand_more, size: 14),
          ],
        ),
      ),
    ),
  ],
)
```

- [ ] **Step 2: 在每个根评论下渲染 preview_children + 展开按钮**

找单条 reply 渲染位置，把根评论 widget 改成：

```dart
Widget _buildRootReplyGroup(ForumReply root, ForumState state) {
  final loadedMore = state.loadedChildren[root.id] ?? const [];
  final displayChildren = [...root.previewChildren, ...loadedMore];
  final hiddenCount = root.totalChildren - displayChildren.length;
  final hasMore = state.hasMoreChildren[root.id] ?? (hiddenCount > 0);
  final isLoading = state.loadingChildrenRoots.contains(root.id);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildReplyWidget(root, isRoot: true),
      for (final child in displayChildren)
        Padding(
          padding: const EdgeInsets.only(left: 46, top: 6),
          child: _buildReplyWidget(child, isRoot: false),
        ),
      if (hasMore || hiddenCount > 0)
        Padding(
          padding: const EdgeInsets.only(left: 46, top: 4),
          child: InkWell(
            onTap: isLoading
                ? null
                : () => context.read<ForumBloc>().add(
                      ForumLoadMoreChildren(root.id),
                    ),
            child: Row(
              children: [
                Container(width: 18, height: 1, color: AppColors.primary.withOpacity(0.4)),
                const SizedBox(width: 6),
                if (isLoading)
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  Text(
                    '展开剩余 $hiddenCount 条回复',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
```

在 ListView 里用 `_buildRootReplyGroup(reply, state)` 替换原来的单 widget 渲染（仅对根评论；子回复不再独立渲染，因为已经在根组里）。

注意：`state.replies` 现在是根评论列表（因为后端只返根），不需要再手动过滤。

- [ ] **Step 3: @ 跳转兼容折叠**

找现有 `@xxx` onTap handler（约 line 593-609）：

```dart
// 原:
onTap: () {
  final target = state.replies.firstWhere(
    (r) => r.id == reply.parentReplyId,
    orElse: () => ... null,
  );
  if (target != null) _highlightStream.add(target.id);
},

// 改为:
onTap: () async {
  final targetId = reply.parentReplyId!;
  // 1. 在所有已渲染的 reply（根 + preview + loaded）里找
  bool found = false;
  for (final root in state.replies) {
    if (root.id == targetId) { found = true; break; }
    if (root.previewChildren.any((c) => c.id == targetId)) { found = true; break; }
    final loaded = state.loadedChildren[root.id] ?? const [];
    if (loaded.any((c) => c.id == targetId)) { found = true; break; }
  }

  if (!found) {
    // 2. 找 target 所属的 root（target 是某根的 child）
    // 通过 reply.parentReplyAuthor 不够；用 backend 已返回的 parent_reply_id 链路
    // 简化策略：找跟当前 reply 同一根的"展开剩余"button，触发 LoadMoreChildren 直到 hasMore=false
    // 实施时只 dispatch 一次（最多 5 条），如不在则放弃跳转（降级 spec 风险点 2）
    final ancestorRoot = _findAncestorRoot(reply, state);
    if (ancestorRoot != null && state.hasMoreChildren[ancestorRoot.id] == true) {
      context.read<ForumBloc>().add(ForumLoadMoreChildren(ancestorRoot.id));
      // 等待 state 更新
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
  _highlightStream.add(targetId);
},
```

`_findAncestorRoot(reply, state)`：

```dart
ForumReply? _findAncestorRoot(ForumReply reply, ForumState state) {
  // reply 自己是根
  if (reply.isRoot) return reply;
  // reply 是某根的 preview/loaded child
  for (final root in state.replies) {
    if (root.previewChildren.any((c) => c.id == reply.id)) return root;
    final loaded = state.loadedChildren[root.id] ?? const [];
    if (loaded.any((c) => c.id == reply.id)) return root;
  }
  return null;
}
```

- [ ] **Step 4: 加 l10n key**

`link2ur/lib/l10n/app_*.arb` 3 文件加：

```json
"forumSortByHot": "按热度",
"forumSortByTime": "按时间",
"forumExpandMoreReplies": "展开剩余 {count} 条回复",
"@forumExpandMoreReplies": {
  "placeholders": { "count": { "type": "int" } }
}
```

英文 / 繁体翻译对应。

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 5: flutter analyze**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

- [ ] **Step 6: 手动验证**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter run -d web-server
```

进入一个有多条评论的帖子，验证：
- ✅ 默认按热度排，根评论按点赞数从高到低
- ✅ 切到"按时间"，根评论按时间正序
- ✅ 每根评论只露前 3 条 child，第 4 条起折叠
- ✅ 点"展开剩余 N 条"加载 5 条新 child；再点继续加
- ✅ 全部加完按钮消失
- ✅ 点 @xxx mention：如果目标可见，800ms 黄色脉冲；如果在折叠区，自动加载后再脉冲

- [ ] **Step 7: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_post_detail_view.dart link2ur/lib/l10n/
git commit -m "feat(forum/flutter): 详情页加排序 chip + 展开按钮 + @ 跳转自动加载

排序 chip 切 hot/time → 重拉根评论；
每根默认展示 preview 3 条 + 展开剩余 N 条 → LoadMoreChildren；
@xxx 点击：目标在折叠区时自动展开再脉冲。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 16: Web frontend 详情页同步 Part 2

**Files:**
- Modify: `frontend/src/pages/ForumPostDetail.tsx`
- Modify: `frontend/src/api.ts`（forum reply 相关 helpers）

- [ ] **Step 1: 加 API helpers**

`frontend/src/api.ts` 在 forum 区域加：

```ts
export async function fetchForumReplies(
  postId: number,
  sort: 'hot' | 'time' = 'hot'
): Promise<ForumReplyListResponse> {
  const r = await api.get(`/api/forum/posts/${postId}/replies?sort=${sort}`);
  return r.data;
}

export async function fetchReplyChildren(
  rootReplyId: number,
  offset = 3,
  limit = 5
): Promise<{ replies: ForumReply[]; has_more: boolean; next_offset: number }> {
  const r = await api.get(
    `/api/forum/replies/${rootReplyId}/children?offset=${offset}&limit=${limit}`
  );
  return r.data;
}
```

更新 ForumReply type 加 `preview_children` + `total_children`。

- [ ] **Step 2: ForumPostDetail.tsx 改用新 API**

把原来一次拉所有回复改成：
- 顶上 `<Select>` 切 sort，onChange 重 fetch
- 渲染：根评论 + preview_children + "展开剩余 N 条"按钮
- 按钮点击 → fetchReplyChildren → setLocal state 拼接

简化伪代码：

```tsx
const [sort, setSort] = useState<'hot' | 'time'>('hot');
const [rootReplies, setRootReplies] = useState<ForumReply[]>([]);
const [loadedChildren, setLoadedChildren] = useState<Record<number, ForumReply[]>>({});
const [hasMoreMap, setHasMoreMap] = useState<Record<number, boolean>>({});
const [offsetMap, setOffsetMap] = useState<Record<number, number>>({});

useEffect(() => {
  fetchForumReplies(postId, sort).then((data) => {
    setRootReplies(data.replies);
    setLoadedChildren({});
    setHasMoreMap({});
    setOffsetMap({});
  });
}, [postId, sort]);

const expandMore = async (rootId: number) => {
  const offset = offsetMap[rootId] ?? 3;
  const page = await fetchReplyChildren(rootId, offset, 5);
  setLoadedChildren((m) => ({ ...m, [rootId]: [...(m[rootId] || []), ...page.replies] }));
  setHasMoreMap((m) => ({ ...m, [rootId]: page.has_more }));
  setOffsetMap((m) => ({ ...m, [rootId]: page.next_offset }));
};
```

每个根评论渲染：

```tsx
{rootReplies.map((root) => {
  const displayed = [...root.preview_children, ...(loadedChildren[root.id] || [])];
  const hidden = root.total_children - displayed.length;
  const hasMore = hasMoreMap[root.id] ?? hidden > 0;
  return (
    <div key={root.id}>
      <Reply reply={root} />
      {displayed.map((c) => <Reply key={c.id} reply={c} nested />)}
      {hasMore && (
        <button onClick={() => expandMore(root.id)}>展开剩余 {hidden} 条回复</button>
      )}
    </div>
  );
})}
```

- [ ] **Step 3: Build + 验证**

```bash
cd frontend && npm run build && npm run dev
```

打开 http://localhost:5173/forum/post/{id}，验证排序 + 展开按钮 + @ 跳转。

- [ ] **Step 4: Commit**

```bash
git add frontend/src/
git commit -m "feat(forum/web): 详情页评论 sort + 渐进展开同步

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## 完成后 Checklist

- [ ] **整体回归** - 跑完所有测试：

```bash
cd backend && pytest tests/ -v -k forum
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test
cd frontend && npm run build
```

- [ ] **Push 让 prod 部署**：

```bash
git push origin main
```

⚠️ Push 前确认 **prod DB 也已经运行 migration 234**（不只是 staging）：

```bash
psql "$PROD_DATABASE_URL" -c "\d forum_posts" | grep "category_id"
```

- [ ] **Linktest staging 烟雾验证**：
  - 进首页发帖入口，不选话题发布 → 成功
  - 进设计服务板块发帖 → 锁定话题，正常发布
  - 进社区流 → 看到上面两条都在
  - 进设计服务板块详情页 → 只看到第二条
  - 进任意有评论的帖详情页 → 默认按热度，切换按时间，展开剩余，点 @xxx 跳转

- [ ] **Prod 同样的烟雾验证**

完成。
