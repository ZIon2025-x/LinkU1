# 论坛回复扁平化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除 `forum_replies.reply_level` 3 层硬约束，三端对齐为扁平回复模型 + 可点击 @-mention 跳转。

**Architecture:** 后端去除 `reply_level` 列与 CheckConstraint、删除创建端点的层级校验、`ForumReplyOut` 移除 `reply_level` 与冗余嵌套 `replies` 字段。Flutter 视图本就扁平化渲染，仅去除模型字段并新增"@xxx"点击跳转 + 高亮脉冲。Web 把递归 `renderReply(level+1)` 改为单层 `replies.map`，并新增"@xxx"点击跳转 + CSS pulse 高亮。

**Tech Stack:** Python 3.11 + FastAPI + SQLAlchemy 2.0 async + Alembic-style numbered SQL migrations + PostgreSQL；Flutter 3.33+ + BLoC；React + Ant Design + TypeScript

**关联设计**：`docs/superpowers/specs/2026-04-26-forum-flat-replies-design.md`（提交 `bf5ee03f2`）

---

## 部署顺序总览

每端的 PUSH 顺序遵循"代码先（不再读 column）→ migration 后（drop column）"以避免运行时 500：

```
1. 写代码 + migration 文件 → commit & push to main
2. 等 Railway 自动部署到 linktest（运行新代码，column 仍存在，无害）
3. 在 linktest DB 跑 migration 219（drop column）
4. linktest smoke 测试
5. 在 prod DB 跑 migration 219
6. 手动触发 prod Railway 部署
7. prod smoke 测试
8. Web push（Vercel 自动部署）
9. Flutter 改动 commit（下一次发版统一带出）
```

---

## Phase 0: 前置准备

### Task 0.1: 处理 git status 中的不相关脏文件

**Files:**
- Audit only: `backend/app/forum_routes.py`, `backend/app/main.py`, `backend/app/routes/task_expert_deprecated_routes.py`

- [ ] **Step 1: 跑 git status**

```bash
git -C F:/python_work/LinkU status --short
```

预期看到：
```
 M backend/app/forum_routes.py
 M backend/app/main.py
?? backend/app/routes/task_expert_deprecated_routes.py
```

- [ ] **Step 2: 检查 forum_routes.py 的未提交改动**

```bash
git -C F:/python_work/LinkU diff backend/app/forum_routes.py | head -30
```

预期：`visible_forums` 函数把 logger.warning 降级为 logger.debug + 加 redis 缓存空结果。**与本工作无关**——是日志噪音治理。

- [ ] **Step 3: 询问用户是否提交这些不相关改动**

向用户报告：当前 working tree 有 3 个不相关脏文件。两种处理：
- (a) 用户先把它们处理掉再开始（推荐）
- (b) 我用 `git add` 精确添加只属于本工作的文件，避免污染

获得用户确认后再进入 Task 0.2。

### Task 0.2: 最终 reply_level grep 审计

**Files:** read-only audit

- [ ] **Step 1: 后端全仓 grep**

```bash
cd F:/python_work/LinkU
```

使用 Grep 工具（不要用 bash grep）：
- pattern: `reply_level`
- path: `backend/`
- output_mode: `content`

预期命中：
| 文件 | 行 | 内容片段 |
|---|---|---|
| `backend/app/models.py` | 2548 | `reply_level = Column(Integer, ...)` |
| `backend/app/models.py` | 2572 | `CheckConstraint("reply_level BETWEEN 1 AND 3", ...)` |
| `backend/app/schemas.py` | 3994 | `reply_level: int` |
| `backend/app/forum_routes.py` | 4740 | `reply_level=reply.reply_level,` (convert_reply 内) |
| `backend/app/forum_routes.py` | 4867 | `reply_level = 1` |
| `backend/app/forum_routes.py` | 4886 | `if parent_reply.reply_level >= 3:` |
| `backend/app/forum_routes.py` | 4893 | `reply_level = parent_reply.reply_level + 1` |
| `backend/app/forum_routes.py` | 4900 | `reply_level=reply_level,` (db_reply 创建) |
| `backend/app/forum_routes.py` | 5036 | `reply_level=db_reply.reply_level,` (create_reply return) |
| `backend/app/forum_routes.py` | 5136 | `reply_level=db_reply.reply_level,` (update_reply return) |
| `backend/app/routes/forum_my_routes.py` | 316 | `reply_level=reply.reply_level,` |

**如有任何未在上表中的命中**——记录下来并加进相应 task。

- [ ] **Step 2: Flutter 仓 grep**

使用 Grep 工具：
- pattern: `replyLevel|reply_level`
- path: `link2ur/lib/`

预期命中（仅 forum.dart）：
| 行 | 内容 |
|---|---|
| 547 | `this.replyLevel = 0,` |
| 561 | `final int replyLevel;` |
| 582 | `replyLevel: replyLevel,` |
| 604 | `replyLevel: json['reply_level'] as int? ?? 0,` |

- [ ] **Step 3: Web 仓 grep**

使用 Grep 工具：
- pattern: `reply_level|replyLevel`
- path: `frontend/src/`

预期命中：
| 文件 | 行 | 内容 |
|---|---|---|
| `frontend/src/api.ts` | (varies) | `reply_level?: number;` 类型字段 |
| `frontend/src/pages/ForumPostDetail.tsx` | (varies) | （可能引用，需确认） |

如有命中文件 row 数 ≠ 1（说明文件中有多处），都记录下来。

- [ ] **Step 4: Admin 仓 grep（兜底）**

使用 Grep 工具：
- pattern: `reply_level`
- path: `admin/src/`

预期：0 命中。如有命中，加进 task。

---

## Phase 1: 后端代码改造（不动 DB）

### Task 1.1: 创建 migration 219 SQL

**Files:**
- Create: `backend/migrations/219_drop_forum_reply_level.sql`

- [ ] **Step 1: 写入 migration**

```sql
-- 219_drop_forum_reply_level.sql
-- 删除 forum_replies.reply_level 列与 check_reply_level 约束
-- 关联设计文档: docs/superpowers/specs/2026-04-26-forum-flat-replies-design.md
-- 关联实施计划: docs/superpowers/plans/2026-04-26-forum-flat-replies.md

BEGIN;

-- 1) 删除 CheckConstraint
ALTER TABLE forum_replies DROP CONSTRAINT IF EXISTS check_reply_level;

-- 2) 删除 reply_level 列
ALTER TABLE forum_replies DROP COLUMN IF EXISTS reply_level;

COMMIT;
```

- [ ] **Step 2: 检查 SQL 语法**

```bash
ls F:/python_work/LinkU/backend/migrations/219_drop_forum_reply_level.sql
```

预期：文件存在。

不在此处 commit——本 task 与 Phase 1 其他后端代码改动一起提交。

### Task 1.2: models.py 删除 reply_level 列与约束

**Files:**
- Modify: `backend/app/models.py:2548, 2572`

- [ ] **Step 1: 删除 reply_level Column 定义**

使用 Edit 工具：

old_string:
```python
    parent_reply_id = Column(Integer, ForeignKey("forum_replies.id", ondelete="CASCADE"), nullable=True)
    reply_level = Column(Integer, default=1, server_default=text('1'))
    author_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
```

new_string:
```python
    parent_reply_id = Column(Integer, ForeignKey("forum_replies.id", ondelete="CASCADE"), nullable=True)
    author_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
```

- [ ] **Step 2: 删除 CheckConstraint**

使用 Edit 工具：

old_string:
```python
    __table_args__ = (
        CheckConstraint("reply_level BETWEEN 1 AND 3", name="check_reply_level"),
        CheckConstraint(
            "(author_id IS NOT NULL) OR (admin_author_id IS NOT NULL)",
            name="check_reply_has_author"
        ),
```

new_string:
```python
    __table_args__ = (
        CheckConstraint(
            "(author_id IS NOT NULL) OR (admin_author_id IS NOT NULL)",
            name="check_reply_has_author"
        ),
```

- [ ] **Step 3: 验证语法**

```bash
cd F:/python_work/LinkU/backend && python -c "from app import models; print(models.ForumReply.__table__.columns.keys())"
```

预期输出列名 list 中**不**含 `reply_level`，但仍含 `parent_reply_id`、`author_id` 等。

### Task 1.3: schemas.py 删除 reply_level 与 nested replies

**Files:**
- Modify: `backend/app/schemas.py:3987-4002`

- [ ] **Step 1: 编辑 ForumReplyOut**

使用 Edit 工具：

old_string:
```python
class ForumReplyOut(BaseModel):
    """回复输出"""
    id: int
    content: str
    author: UserInfo
    parent_reply_id: Optional[int] = None
    parent_reply_author: Optional[UserInfo] = None  # 被回复人，用于前端展示「回复 @xxx」
    reply_level: int
    like_count: int
    is_liked: Optional[bool] = False  # 当前用户是否已点赞（动态计算）
    created_at: datetime.datetime
    updated_at: datetime.datetime
    replies: List["ForumReplyOut"] = []  # 嵌套回复

    class Config:
        from_attributes = True
```

new_string:
```python
class ForumReplyOut(BaseModel):
    """回复输出 - 扁平化模型，所有回复同层级，parent_reply_id 用于"@xxx"语义"""
    id: int
    content: str
    author: UserInfo
    parent_reply_id: Optional[int] = None
    parent_reply_author: Optional[UserInfo] = None  # 被回复人，用于前端展示「回复 @xxx」
    like_count: int
    is_liked: Optional[bool] = False  # 当前用户是否已点赞（动态计算）
    created_at: datetime.datetime
    updated_at: datetime.datetime

    class Config:
        from_attributes = True
```

- [ ] **Step 2: 验证语法**

```bash
cd F:/python_work/LinkU/backend && python -c "from app import schemas; print(list(schemas.ForumReplyOut.model_fields.keys()))"
```

预期输出**不**含 `reply_level`、**不**含 `replies`。

### Task 1.4: forum_routes.py 简化创建端点

**Files:**
- Modify: `backend/app/forum_routes.py:4867-4903`

- [ ] **Step 1: 删除层级计算与上限检查**

使用 Edit 工具：

old_string:
```python
    # 如果是指定父回复，检查层级
    reply_level = 1
    if reply.parent_reply_id:
        parent_result = await db.execute(
            select(models.ForumReply).where(models.ForumReply.id == reply.parent_reply_id)
        )
        parent_reply = parent_result.scalar_one_or_none()
        
        if not parent_reply:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="父回复不存在"
            )
        
        if parent_reply.post_id != post_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="父回复不属于该帖子"
            )
        
        if parent_reply.reply_level >= 3:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="回复层级最多三层",
                headers={"X-Error-Code": "REPLY_LEVEL_LIMIT"}
            )
        
        reply_level = parent_reply.reply_level + 1
```

new_string:
```python
    # 校验父回复存在性 + 同帖归属（扁平化模型下不再有层级上限）
    if reply.parent_reply_id:
        parent_result = await db.execute(
            select(models.ForumReply).where(models.ForumReply.id == reply.parent_reply_id)
        )
        parent_reply = parent_result.scalar_one_or_none()

        if not parent_reply:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="父回复不存在"
            )

        if parent_reply.post_id != post_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="父回复不属于该帖子"
            )
```

- [ ] **Step 2: 删除 db_reply 创建中的 reply_level 字段**

使用 Edit 工具：

old_string:
```python
    db_reply = models.ForumReply(
        post_id=post_id,
        content=reply.content,
        parent_reply_id=reply.parent_reply_id,
        reply_level=reply_level,
        author_id=current_user.id if current_user else None,
        admin_author_id=admin_user.id if admin_user else None
    )
```

new_string:
```python
    db_reply = models.ForumReply(
        post_id=post_id,
        content=reply.content,
        parent_reply_id=reply.parent_reply_id,
        author_id=current_user.id if current_user else None,
        admin_author_id=admin_user.id if admin_user else None
    )
```

### Task 1.5: forum_routes.py 列表端点 (convert_reply)

**Files:**
- Modify: `backend/app/forum_routes.py:4734-4746`

- [ ] **Step 1: 删除 reply_level 与 replies 字段**

使用 Edit 工具：

old_string:
```python
        reply_out = schemas.ForumReplyOut(
            id=reply.id,
            content=reply.content,
            author=await get_reply_author_info(db, reply, request, _badge_cache=_badge_cache),
            parent_reply_id=reply.parent_reply_id,
            parent_reply_author=parent_author,
            reply_level=reply.reply_level,
            like_count=reply.like_count,
            is_liked=is_liked,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
            replies=[]
        )
        
        # 递归处理子回复
        for child_data in reply_data["children"]:
            child_reply = await convert_reply(child_data, liked_set)
            reply_out.replies.append(child_reply)
        
        return reply_out
```

new_string:
```python
        reply_out = schemas.ForumReplyOut(
            id=reply.id,
            content=reply.content,
            author=await get_reply_author_info(db, reply, request, _badge_cache=_badge_cache),
            parent_reply_id=reply.parent_reply_id,
            parent_reply_author=parent_author,
            like_count=reply.like_count,
            is_liked=is_liked,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
        )

        # 递归收集子回复，平铺加入 reply_list（扁平化模型）
        for child_data in reply_data["children"]:
            child_reply = await convert_reply(child_data, liked_set)
            reply_list.append(child_reply)

        return reply_out
```

**等等**——上面 new_string 的结尾改了行为：原本子回复嵌进 `reply_out.replies`，现在要平铺到外层 `reply_list`。但 `convert_reply` 内访问不到外层 `reply_list`。需要重构。

- [ ] **Step 2: 改用闭包累加器或返回 list 模式**

读 `forum_routes.py:4755-4765`：

```python
    reply_list = []
    for item in reply_tree:
        reply = await convert_reply(item, user_liked_replies)
        reply_list.append(reply)
```

改成 `convert_reply` 返回 `List[ForumReplyOut]`（自身 + 所有子孙的扁平列表）：

使用 Edit 工具替换上面 Step 1 中的 new_string：

```python
        reply_out = schemas.ForumReplyOut(
            id=reply.id,
            content=reply.content,
            author=await get_reply_author_info(db, reply, request, _badge_cache=_badge_cache),
            parent_reply_id=reply.parent_reply_id,
            parent_reply_author=parent_author,
            like_count=reply.like_count,
            is_liked=is_liked,
            created_at=reply.created_at,
            updated_at=reply.updated_at,
        )

        # 扁平化模型：返回 [self] + 所有子孙的扁平列表
        result = [reply_out]
        for child_data in reply_data["children"]:
            result.extend(await convert_reply(child_data, liked_set))
        return result
```

- [ ] **Step 3: 改 caller 适配新的返回类型**

使用 Edit 工具：

old_string:
```python
    reply_list = []
    for item in reply_tree:
        reply = await convert_reply(item, user_liked_replies)
        reply_list.append(reply)
```

new_string:
```python
    reply_list = []
    for item in reply_tree:
        reply_list.extend(await convert_reply(item, user_liked_replies))
```

- [ ] **Step 4: 更新 convert_reply 的 docstring**

使用 Edit 工具：

old_string:
```python
    async def convert_reply(reply_data, liked_set):
        """递归转换回复为输出格式"""
```

new_string:
```python
    async def convert_reply(reply_data, liked_set):
        """递归转换回复为扁平 ForumReplyOut 列表（self + 所有子孙）"""
```

### Task 1.6: forum_routes.py 创建/更新端点的返回结构

**Files:**
- Modify: `backend/app/forum_routes.py:5030-5042` (create_reply return)
- Modify: `backend/app/forum_routes.py:5131-5142` (update_reply return)

- [ ] **Step 1: 修复 create_reply 返回**

使用 Edit 工具：

old_string:
```python
    return schemas.ForumReplyOut(
        id=db_reply.id,
        content=db_reply.content,
        author=await get_reply_author_info(db, db_reply, request, _badge_cache=_badge_cache),
        parent_reply_id=db_reply.parent_reply_id,
        parent_reply_author=parent_reply_author,
        reply_level=db_reply.reply_level,
        like_count=db_reply.like_count,
        is_liked=False,
        created_at=db_reply.created_at,
        updated_at=db_reply.updated_at,
        replies=[]
    )
```

new_string:
```python
    return schemas.ForumReplyOut(
        id=db_reply.id,
        content=db_reply.content,
        author=await get_reply_author_info(db, db_reply, request, _badge_cache=_badge_cache),
        parent_reply_id=db_reply.parent_reply_id,
        parent_reply_author=parent_reply_author,
        like_count=db_reply.like_count,
        is_liked=False,
        created_at=db_reply.created_at,
        updated_at=db_reply.updated_at,
    )
```

- [ ] **Step 2: 修复 update_reply 返回**

使用 Edit 工具：

old_string:
```python
    return schemas.ForumReplyOut(
        id=db_reply.id,
        content=db_reply.content,
        author=await get_reply_author_info(db, db_reply, request, _badge_cache=_badge_cache),
        parent_reply_id=db_reply.parent_reply_id,
        reply_level=db_reply.reply_level,
        like_count=db_reply.like_count,
        is_liked=is_liked,
        created_at=db_reply.created_at,
        updated_at=db_reply.updated_at,
        replies=[]
    )
```

new_string:
```python
    return schemas.ForumReplyOut(
        id=db_reply.id,
        content=db_reply.content,
        author=await get_reply_author_info(db, db_reply, request, _badge_cache=_badge_cache),
        parent_reply_id=db_reply.parent_reply_id,
        like_count=db_reply.like_count,
        is_liked=is_liked,
        created_at=db_reply.created_at,
        updated_at=db_reply.updated_at,
    )
```

注意：update_reply 返回缺 `parent_reply_author`——这是 pre-existing 不一致，不在本次范围内修复。

### Task 1.7: routes/forum_my_routes.py 删除 reply_level 引用

**Files:**
- Modify: `backend/app/routes/forum_my_routes.py:316`

- [ ] **Step 1: 读 forum_my_routes.py 上下文**

使用 Read 工具读 `backend/app/routes/forum_my_routes.py` 第 300-330 行。确认 line 316 是 `ForumReplyOut(...)` 构造调用。

- [ ] **Step 2: 删除 reply_level 与 replies（如有）字段**

使用 Edit 工具，把那次构造中的 `reply_level=reply.reply_level,` 行**删除**；如果同时有 `replies=[]`，也一起删。

精确 old_string / new_string 取决于实际上下文（Step 1 读到什么再决定）——本步骤需要逐行对照，**不可机械替换**。

- [ ] **Step 3: 验证文件**

```bash
cd F:/python_work/LinkU/backend && python -c "from app.routes import forum_my_routes; print('ok')"
```

预期：`ok`，无 ImportError 或 SyntaxError。

### Task 1.8: 后端整体编译验证

- [ ] **Step 1: 整个 app 包 import 校验**

```bash
cd F:/python_work/LinkU/backend && python -c "from app import main; print('app import ok')"
```

预期：`app import ok`。任何 ImportError 或 NameError 必须在此处修复，**不可带病提交**。

- [ ] **Step 2: 全仓 reply_level 残留 grep**

使用 Grep 工具：
- pattern: `reply_level`
- path: `backend/app/`
- output_mode: `content`

预期：**0 命中**。如有命中，回到对应 task 修补。

### Task 1.9: 提交 Phase 1 后端 + migration 文件

- [ ] **Step 1: 检查待提交文件**

```bash
git -C F:/python_work/LinkU status --short
```

确认仅以下文件应进入本次 commit：
- `backend/migrations/219_drop_forum_reply_level.sql`（新增）
- `backend/app/models.py`
- `backend/app/schemas.py`
- `backend/app/forum_routes.py`
- `backend/app/routes/forum_my_routes.py`

**不可**包含 `backend/app/main.py` 或 `backend/app/routes/task_expert_deprecated_routes.py`（在 Task 0.1 中已确认这些是不相关脏文件）。

- [ ] **Step 2: 精确 git add**

```bash
git -C F:/python_work/LinkU add \
  backend/migrations/219_drop_forum_reply_level.sql \
  backend/app/models.py \
  backend/app/schemas.py \
  backend/app/forum_routes.py \
  backend/app/routes/forum_my_routes.py
```

**注意**：如 Task 0.1 中用户决定先 commit 那些不相关脏文件，则该步骤前先做。绝对不要在没有用户明确许可的情况下用 `git add -A` 或 `git add .`。

- [ ] **Step 3: 创建 commit**

```bash
git -C F:/python_work/LinkU commit -m "$(cat <<'EOF'
feat(forum): drop 3-level reply nesting cap, flatten model

Removes the reply_level BETWEEN 1 AND 3 hard constraint that's been
generating "回复层级最多三层" 403 errors when users try to reply to
deep-nested replies.

Backend:
- Migration 219: DROP CONSTRAINT check_reply_level + DROP COLUMN reply_level
- models.py: drop reply_level Column + CheckConstraint
- schemas.py: ForumReplyOut drops reply_level + nested replies fields
- forum_routes.py:
  - create_reply: drop level computation + REPLY_LEVEL_LIMIT 403,
    keep parent existence + same-post-id checks
  - convert_reply (list endpoint): now returns flat List[ForumReplyOut]
    aggregating self + descendants instead of nesting in .replies
  - update_reply / create_reply return: drop reply_level + replies=[]
- routes/forum_my_routes.py: drop reply_level field reference

API contract change: ForumReplyOut.replies (recursive) field removed.
Callers should treat the top-level ForumReplyListResponse.replies array
as the flat list of all replies. Old Flutter app's _flattenReplyTree
is idempotent on flat input (forum_repository.dart:266); old web
degrades gracefully to flat rendering during the Vercel/CF cache
window (~5-15 min). See spec §13 for backward compat analysis.

Migration timing per feedback_migration_before_deploy: code is pushed
first (no longer reads reply_level column), then migration is run on
each environment to safely DROP the column.

Spec: docs/superpowers/specs/2026-04-26-forum-flat-replies-design.md
Plan: docs/superpowers/plans/2026-04-26-forum-flat-replies.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: push to main**

```bash
git -C F:/python_work/LinkU push origin main
```

预期：push 成功。Railway 触发 linktest 自动部署。

---

## Phase 2: Linktest 验证

### Task 2.1: 等待 linktest 部署完成

- [ ] **Step 1: 等约 2-3 分钟（Railway 构建 + 部署）**

可以通过浏览器打开 Railway dashboard 看 deployment 状态，或者直接 curl 健康检查。

- [ ] **Step 2: linktest 健康检查**

```bash
curl -sS https://linktest.up.railway.app/health 2>&1 | head -10
```

预期：HTTP 200，返回 OK 类响应。

如响应失败或 500：
- 查 Railway logs
- 大概率是 ORM 跟代码版本不匹配的边界 bug，需要回头修

### Task 2.2: 在 linktest DB 跑 migration 219

- [ ] **Step 1: 通过 Railway CLI 或 dashboard 跑 migration**

用户的常规方式（参考你之前 migration 执行经验）：

选项 A — Railway CLI：
```bash
railway run --service postgres psql < F:/python_work/LinkU/backend/migrations/219_drop_forum_reply_level.sql
```

选项 B — Railway dashboard → DB → query editor 粘贴 SQL 内容直接执行

- [ ] **Step 2: 验证 column 已删除**

通过 psql 或 dashboard 执行：

```sql
SELECT column_name FROM information_schema.columns
WHERE table_name='forum_replies' AND column_name='reply_level';
```

预期：返回 0 行。

```sql
SELECT conname FROM pg_constraint WHERE conname='check_reply_level';
```

预期：返回 0 行。

### Task 2.3: linktest smoke test — 深度回复

- [ ] **Step 1: 准备测试数据**

通过浏览器或 Postman 登录 linktest 一个测试用户：`https://linktest.up.railway.app`

找一个现有的论坛帖子（或新建一个）。

- [ ] **Step 2: 创建一条 L1 回复**

POST `/api/forum/posts/{post_id}/replies`：
```json
{ "content": "L1 测试", "parent_reply_id": null }
```
记录返回的 `id`，称为 `L1_id`。

预期：HTTP 200，返回的 ForumReplyOut **不**含 `reply_level` 字段。

- [ ] **Step 3: 创建 L2、L3、L4、L5 回复（链式）**

L2: `{ "content": "L2", "parent_reply_id": L1_id }` → 取 `L2_id`
L3: `{ "content": "L3", "parent_reply_id": L2_id }` → 取 `L3_id`
L4: `{ "content": "L4", "parent_reply_id": L3_id }` → 取 `L4_id`
L5: `{ "content": "L5", "parent_reply_id": L4_id }` → 取 `L5_id`

**关键预期**：每一步都 HTTP 200。**L4 和 L5 是本次改动后才能成功的**——以前会返回 403 + `REPLY_LEVEL_LIMIT`。

- [ ] **Step 4: 列表读取验证**

GET `/api/forum/posts/{post_id}/replies`

预期：
- 返回 `replies` 数组包含全部 5 条回复（平铺）
- 每条回复**不**含 `reply_level` 字段
- 每条回复**不**含 `replies` 嵌套字段（顶层无）
- L2-L5 都有 `parent_reply_id` 与 `parent_reply_author`

- [ ] **Step 5: 错误路径验证**

- POST 用不存在的 `parent_reply_id`：预期 404
- POST 用其他帖子的 `parent_reply_id`：预期 400
- 这两个分支没改，应继续工作

如以上任何 step 失败，**停止部署到 prod**，回头修。

---

## Phase 3: Prod 部署

### Task 3.1: Prod DB 跑 migration 219

- [ ] **Step 1: pg_dump 备份**（可选但推荐）

```bash
railway run --service postgres-prod pg_dump --schema-only --table=forum_replies > /tmp/forum_replies_schema_backup_20260426.sql
```

- [ ] **Step 2: 跑 migration**

跟 Task 2.2 同方式（选项 A 或 B），**只是数据库切到 prod 的 postgres**。

- [ ] **Step 3: 验证 column 已删除**

跟 Task 2.2 Step 2 同 SQL，但在 prod DB 跑。

### Task 3.2: 触发 prod Railway 部署

- [ ] **Step 1: 通过 Railway dashboard 触发 prod service deploy**

参考 architecture_backend_staging_prod 的备忘：api.link2ur.com 不会跟 main 自动部署，需手动触发。

具体操作：Railway dashboard → prod backend service → Deployments → 选择 latest commit → Redeploy。

- [ ] **Step 2: 等部署完成（约 2-3 分钟）**

- [ ] **Step 3: prod 健康检查**

```bash
curl -sS https://api.link2ur.com/health 2>&1 | head -10
```

预期：HTTP 200。

### Task 3.3: prod smoke

- [ ] **Step 1: prod 上重复 Task 2.3 的关键 step**

不需要做完整 5 层链——做 L1 + L2 + L4（跳跃到 L4 验证 cap 已去）。每步预期 HTTP 200。

如失败，**立即回滚**：
- Railway → 选上一个稳定 deploy → Redeploy
- 列回填 reply_level：用 spec §6 的回滚 SQL 重建 column + constraint

---

## Phase 4: Web frontend 改造

### Task 4.1: api.ts 类型清理

**Files:**
- Modify: `frontend/src/api.ts`

- [ ] **Step 1: 找到 ForumReply 类型定义**

使用 Grep 工具：
- pattern: `reply_level\??`
- path: `frontend/src/api.ts`
- output_mode: `content`

记录命中的行号。

- [ ] **Step 2: 删除 reply_level 字段**

对每个命中行使用 Edit 工具删除该行。

- [ ] **Step 3: 检查 nested replies 字段**

使用 Grep 工具：
- pattern: `replies\??:\s*ForumReply`
- path: `frontend/src/api.ts`

如有命中，删除该字段（在扁平化模型下顶层 `replies` 数组就是全部回复，类型内不需要再嵌套）。

### Task 4.2: ForumPostDetail.tsx 移除递归渲染

**Files:**
- Modify: `frontend/src/pages/ForumPostDetail.tsx:987-991, 1339`

- [ ] **Step 1: 删除递归 renderReply 调用**

使用 Edit 工具：

old_string:
```tsx
        {reply.replies && reply.replies.length > 0 && (
          <div className={styles.nestedReplies}>
            {reply.replies.map((nestedReply) => renderReply(nestedReply, level + 1))}
          </div>
        )}
```

new_string:
```tsx
```

（即整段删除——含其上下文中的空行需保留一个空行）。

- [ ] **Step 2: 移除 renderReply 的 level 参数**

使用 Grep 工具找 `renderReply = (...)` 函数定义和所有调用：
- pattern: `renderReply\s*[=(]`
- path: `frontend/src/pages/ForumPostDetail.tsx`

定义处：把 `(reply: ForumReply, level: number = 0)` 改成 `(reply: ForumReply)`，函数体中 `level` 引用全部移除（缩进样式如 `style={{marginLeft: level * 20}}` 或类似——精确取决于实现，需要 Read 文件局部确认）。

调用处（line 1339）：`{replies.map((reply) => renderReply(reply))}` 应该已经没传 level，确认即可。

- [ ] **Step 3: 删除 styles.nestedReplies 引用**

使用 Grep 工具确认 `styles.nestedReplies` 在改完 Step 1 后是否还有其他引用：
- pattern: `nestedReplies`
- path: `frontend/src/`

如已无引用，可在 CSS module 中删除该 class（找到 `*.module.css` 或 `*.module.scss` 中对应的 `.nestedReplies` 块删除）。如果还有别处使用就跳过。

- [ ] **Step 4: 删除 line 660-664 updateReply helper 中的递归**

读 `ForumPostDetail.tsx:655-670` 上下文。预期看到类似：

```tsx
const updateReply = (reply: ForumReply): ForumReply => {
  if (reply.id === targetId) { return { ...reply, ...patch }; }
  if (reply.replies && reply.replies.length > 0) {
    return { ...reply, replies: reply.replies.map(updateReply) };
  }
  return reply;
};
```

改成：
```tsx
const updateReply = (reply: ForumReply): ForumReply => {
  if (reply.id === targetId) { return { ...reply, ...patch }; }
  return reply;
};
```

精确替换需要 Read 后逐行写 old/new。

### Task 4.3: 添加 @-mention 可点击 + 高亮

**Files:**
- Modify: `frontend/src/pages/ForumPostDetail.tsx`
- Modify: 对应的 CSS module

- [ ] **Step 1: 给每条 reply 容器加 id**

在 renderReply 中找到顶层 `<div>`（reply card 容器），加 `id={`reply-${reply.id}`}`。

- [ ] **Step 2: 在 reply header 渲染 @xxx 元素**

在 reply header 区域（用户名旁边）插入：

```tsx
{reply.parent_reply_author && (
  <span
    className={styles.replyMention}
    onClick={() => handleMentionClick(reply.parent_reply_id)}
    style={{ cursor: 'pointer', color: '#1890ff', marginLeft: 4 }}
  >
    @{reply.parent_reply_author.name}
  </span>
)}
```

- [ ] **Step 3: 实现 handleMentionClick**

在组件内（state hook 区域）：

```tsx
const handleMentionClick = (parentReplyId: number | undefined) => {
  if (!parentReplyId) return;
  const target = document.getElementById(`reply-${parentReplyId}`);
  if (target) {
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });
    target.classList.add(styles.highlightPulse);
    setTimeout(() => target.classList.remove(styles.highlightPulse), 800);
  } else {
    message.info(t('forum.replyTargetNotLoaded'));
  }
};
```

注意：`message` 是 antd 的全局 message API，需在文件顶部 `import { message } from 'antd';`。如已有则跳过。

- [ ] **Step 4: 加 .highlightPulse CSS**

在 ForumPostDetail 对应的 CSS module 加：

```css
.highlightPulse {
  animation: pulse 0.8s ease-out;
}

@keyframes pulse {
  0% { background-color: rgba(255, 235, 59, 0.4); }
  100% { background-color: transparent; }
}
```

- [ ] **Step 5: 加 i18n key（中英文）**

找到 i18n 翻译资源文件（typically `frontend/src/locales/*.json` 或 `i18n/`），加：
- `"forum.replyTargetNotLoaded": "原回复未加载，请滚动加载更多"` (zh)
- `"forum.replyTargetNotLoaded": "Original reply not loaded, please load more"` (en)

如有 zh-Hant 文件也对应加。**精确路径需要先用 Glob 找：**

```
pattern: frontend/src/**/zh*.json (or i18n.ts)
```

### Task 4.4: 本地验证 Web

- [ ] **Step 1: 启动 dev server**

```bash
cd F:/python_work/LinkU/frontend && npm start
```

需要等 `webpack compiled successfully`。如有 TypeScript 错误，根据报错修复（最常见：缺字段、类型不匹配）。

- [ ] **Step 2: 在浏览器打开论坛帖子页**

`http://localhost:3000/zh/community/forum/{post_id}`（具体 path 从 App.tsx 路由确认）。

- [ ] **Step 3: 视觉验证清单**

- [ ] 所有回复同层级渲染，无嵌套缩进
- [ ] 子回复（有 parent_reply_id）显示"@xxx"前缀
- [ ] 点击"@xxx"：平滑滚动到目标回复 + 200ms 黄色背景脉冲
- [ ] 控制台无 React 警告/报错

### Task 4.5: 提交 Web 改动 + push

- [ ] **Step 1: git status 确认仅 web 文件**

```bash
git -C F:/python_work/LinkU status --short
```

预期文件：
- `frontend/src/api.ts`
- `frontend/src/pages/ForumPostDetail.tsx`
- `frontend/src/pages/ForumPostDetail.module.{css,scss}`
- `frontend/src/locales/*.json` (or wherever i18n lives)

- [ ] **Step 2: 精确 git add**

```bash
git -C F:/python_work/LinkU add frontend/src/
```

- [ ] **Step 3: commit**

```bash
git -C F:/python_work/LinkU commit -m "$(cat <<'EOF'
feat(forum/web): flat reply rendering + clickable @-mention jump

Aligns web frontend with the new flat reply API contract:
- Replace recursive renderReply(level+1) with single-level map
- Drop reply_level + nested replies types from api.ts
- Drop styles.nestedReplies indent
- Simplify updateReply state helper (no longer recurses)

Add new @-mention UX:
- Each reply card gets id={`reply-${id}`} for jump targeting
- "@xxx" rendered next to author name when parent_reply_author exists
- Click handler: smooth scrollIntoView + 800ms highlightPulse
  background animation
- Toast fallback when parent reply is not in current page

Spec: docs/superpowers/specs/2026-04-26-forum-flat-replies-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: push to main**

```bash
git -C F:/python_work/LinkU push origin main
```

Vercel 自动触发 deploy，通常 1-2 分钟后线上生效。

### Task 4.6: 线上验证 web

- [ ] **Step 1: 等 Vercel deploy 完成**

打开 vercel.com dashboard → frontend project → wait for "Ready"。

- [ ] **Step 2: 访问 prod web**

打开 `https://link2ur.com/zh/community/forum/{post_id}` 或类似 path（从 vercel 分配的 production domain 进入）。

- [ ] **Step 3: 视觉验证 + @ 跳转**

跟 Task 4.4 Step 3 同清单，但在 prod 上做。

---

## Phase 5: Flutter 改造

### Task 5.1: forum.dart 删除 replyLevel

**Files:**
- Modify: `link2ur/lib/data/models/forum.dart:547, 561, 582, 604`

- [ ] **Step 1: 删除字段定义**

使用 Edit 工具：

old_string:
```dart
    this.parentReplyId,
    this.parentReplyAuthor,
    this.replyLevel = 0,
    this.likeCount = 0,
```

new_string:
```dart
    this.parentReplyId,
    this.parentReplyAuthor,
    this.likeCount = 0,
```

- [ ] **Step 2: 删除 final 字段声明**

使用 Edit 工具：

old_string:
```dart
  final int? parentReplyId;
  final UserBrief? parentReplyAuthor;
  final int replyLevel;
  final int likeCount;
```

new_string:
```dart
  final int? parentReplyId;
  final UserBrief? parentReplyAuthor;
  final int likeCount;
```

- [ ] **Step 3: 删除 copyWith 中的 replyLevel**

使用 Edit 工具：

old_string:
```dart
      parentReplyId: parentReplyId,
      parentReplyAuthor: parentReplyAuthor,
      replyLevel: replyLevel,
      likeCount: likeCount ?? this.likeCount,
```

new_string:
```dart
      parentReplyId: parentReplyId,
      parentReplyAuthor: parentReplyAuthor,
      likeCount: likeCount ?? this.likeCount,
```

- [ ] **Step 4: 删除 fromJson 中的 replyLevel**

使用 Edit 工具：

old_string:
```dart
      parentReplyAuthor: json['parent_reply_author'] != null
          ? UserBrief.fromJson(
              json['parent_reply_author'] as Map<String, dynamic>)
          : null,
      replyLevel: json['reply_level'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
```

new_string:
```dart
      parentReplyAuthor: json['parent_reply_author'] != null
          ? UserBrief.fromJson(
              json['parent_reply_author'] as Map<String, dynamic>)
          : null,
      likeCount: json['like_count'] as int? ?? 0,
```

- [ ] **Step 5: 验证 Flutter 编译**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd F:/python_work/LinkU/link2ur; flutter analyze lib/data/models/forum.dart lib/features/forum/
```

预期：0 个 error。warning 可接受（如 unused field）但要看一遍是否相关。

### Task 5.2: 添加 @ 跳转的 Stream 广播基础设施

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

- [ ] **Step 1: 在 State class 添加 highlight stream**

读 `forum_post_detail_view.dart:120-160`（`_State` 的 field 区段，找现有 `_replyKeys` 附近）。

加：

```dart
final _highlightStream = StreamController<int>.broadcast();
```

在 `dispose()` 中加：

```dart
_highlightStream.close();
```

`StreamController` 来自 `dart:async`，确保顶部已 import。

- [ ] **Step 2: 实现 jump-to-parent 方法**

在 State class 内加：

```dart
void _jumpToParent(int parentReplyId) {
  final key = _replyKeys[parentReplyId];
  final ctx = key?.currentContext;
  if (ctx == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.forumReplyTargetNotLoaded),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }
  Scrollable.ensureVisible(
    ctx,
    duration: const Duration(milliseconds: 300),
    alignment: 0.3,
    curve: Curves.easeInOut,
  );
  _highlightStream.add(parentReplyId);
}
```

- [ ] **Step 3: 添加 l10n key**

文件：`link2ur/lib/l10n/app_en.arb`、`app_zh.arb`、`app_zh_Hant.arb`

加：
- en: `"forumReplyTargetNotLoaded": "Original reply not loaded, please load more"`
- zh: `"forumReplyTargetNotLoaded": "原回复未加载，请加载更多"`
- zh_Hant: `"forumReplyTargetNotLoaded": "原回覆未載入，請載入更多"`

- [ ] **Step 4: 重新生成 l10n**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd F:/python_work/LinkU/link2ur; flutter gen-l10n
```

### Task 5.3: 在 _ReplyCard 加 @ 可点 + 监听 highlight

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart` (`_ReplyCard` widget)

- [ ] **Step 1: 给 _ReplyCard 加 onMentionTap + highlightStream 参数**

读 `_ReplyCard` 的构造（应在 forum_post_detail_view.dart 后段；用 Grep 找 `class _ReplyCard`）。

在它的 fields 加：
```dart
final void Function(int parentReplyId)? onMentionTap;
final Stream<int>? highlightStream;
```

构造函数 named param 中加这两项。

- [ ] **Step 2: 改 _ReplyCard 为 StatefulWidget（如本来是 Stateless）**

这一步是因为要做 200ms 高亮 AnimatedContainer，需要 setState 或 ValueNotifier。如已是 Stateful 则跳过。

如需改造：把 `class _ReplyCard extends StatelessWidget` → `extends StatefulWidget`，添加 `_State` 类，把原 `build` 移过去。

- [ ] **Step 3: 在 _State.initState 订阅 highlightStream**

```dart
StreamSubscription<int>? _highlightSub;
bool _highlight = false;

@override
void initState() {
  super.initState();
  _highlightSub = widget.highlightStream?.listen((id) {
    if (id == widget.reply.id && mounted) {
      setState(() => _highlight = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _highlight = false);
      });
    }
  });
}

@override
void dispose() {
  _highlightSub?.cancel();
  super.dispose();
}
```

- [ ] **Step 4: 包 AnimatedContainer 实现脉冲**

把 _ReplyCard 顶层 widget 包成：

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 800),
  color: _highlight
      ? Colors.yellow.withValues(alpha: 0.3)
      : Colors.transparent,
  child: /* 原 build 出的内容 */,
)
```

- [ ] **Step 5: 把"回复 @xxx"改成可点击**

读现有 `_ReplyCard` 的 build，找类似 `if (reply.parentReplyAuthor != null)` 的渲染段。把其中的 Text widget 包 GestureDetector：

```dart
GestureDetector(
  onTap: () {
    final pid = widget.reply.parentReplyId;
    if (pid != null) widget.onMentionTap?.call(pid);
  },
  child: Text(
    '@${widget.reply.parentReplyAuthor!.name}',
    style: TextStyle(
      color: Theme.of(context).primaryColor,
      decoration: TextDecoration.underline,
    ),
  ),
)
```

- [ ] **Step 6: 在调用 _ReplyCard 处传入新参数**

在 `forum_post_detail_view.dart:550-560` 的 `_ReplyCard(...)` 调用中加：

```dart
onMentionTap: _jumpToParent,
highlightStream: _highlightStream.stream,
```

### Task 5.4: 本地验证 Flutter

- [ ] **Step 1: flutter analyze**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd F:/python_work/LinkU/link2ur; flutter analyze
```

预期：0 个 error。

- [ ] **Step 2: flutter run（连接物理设备或模拟器）**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd F:/python_work/LinkU/link2ur; flutter run --dart-define=API_BASE_URL=https://linktest.up.railway.app
```

- [ ] **Step 3: 视觉清单**

- [ ] 论坛帖子详情页正常加载
- [ ] 所有回复扁平渲染
- [ ] 有 parent 的回复显示蓝色下划线 "@xxx"
- [ ] 点击"@xxx"：滚动到目标 + 200ms 黄色背景脉冲
- [ ] 创建一条 L4+回复（点深度回复的"回复"按钮）成功无 403
- [ ] 旧帖子（含原 reply_level=3 的数据）加载无 crash

### Task 5.5: 提交 Flutter 改动

- [ ] **Step 1: git status 确认范围**

```bash
git -C F:/python_work/LinkU status --short
```

预期：
- `link2ur/lib/data/models/forum.dart`
- `link2ur/lib/features/forum/views/forum_post_detail_view.dart`
- `link2ur/lib/l10n/app_*.arb`
- `link2ur/lib/l10n/*.dart` (gen-l10n 生成)

- [ ] **Step 2: git add 精确**

```bash
git -C F:/python_work/LinkU add link2ur/lib/
```

- [ ] **Step 3: commit**

```bash
git -C F:/python_work/LinkU commit -m "$(cat <<'EOF'
feat(forum/flutter): drop replyLevel + clickable @-mention jump

Aligns Flutter forum reply layer with the new flat API contract:
- forum.dart model drops replyLevel field (4 sites)
- _ReplyCard's "@xxx" prefix becomes a tappable GestureDetector
- _jumpToParent uses existing _replyKeys infrastructure to
  Scrollable.ensureVisible the target with smooth 300ms scroll
- Stream<int> broadcast triggers a 200ms AnimatedContainer pulse
  on the target card (yellow highlight fading to transparent)
- SnackBar fallback when target reply is in an unloaded page
- 3 ARB files get the new forumReplyTargetNotLoaded key

Old app behavior preserved: replyLevel was never used for view
decisions (isSubReply = parentReplyId != null drives all visual
differentiation), and _flattenReplyTree is idempotent on flat
input. See spec §13.1.

Spec: docs/superpowers/specs/2026-04-26-forum-flat-replies-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: push to main**

```bash
git -C F:/python_work/LinkU push origin main
```

Flutter 改动**不会自动发布到 app store**——它会跟下一次 Flutter 发版一起出。线上 iOS/Android 用户在新 Flutter 版本前继续看老体验（无 @ 跳转），但因为后端已改造，**老 app 用户的"深度回复 403"问题已经在 Phase 3 解决了**，不依赖 Flutter 这次发版。

---

## Phase 6: 收尾

### Task 6.1: 全仓最终 grep 审计

- [ ] **Step 1: backend**

使用 Grep 工具：
- pattern: `reply_level`
- path: `backend/`

预期：0 命中（除了在 spec 文档中的引用，那是历史叙述不算）。

如有命中（除文档），回到对应 task 修补。

- [ ] **Step 2: Flutter**

使用 Grep 工具：
- pattern: `replyLevel|reply_level`
- path: `link2ur/`

预期：除生成文件外 0 命中。

- [ ] **Step 3: Web**

使用 Grep 工具：
- pattern: `reply_level|replyLevel`
- path: `frontend/src/ admin/src/`

预期：0 命中。

### Task 6.2: 更新 memory

memory 中可加：

- 新建 `architecture_forum_replies_flat.md`：
  - name: `Forum replies are flat (no nesting)`
  - description: `2026-04-26 起 forum_replies 表无 reply_level 字段;parent_reply_id 仅作 @-target 用,API 返回平铺列表,前端用 parent_reply_author 渲染 "@xxx" 可点跳转`
  - type: `architecture`
  - body: 记录 commit hash + 设计/计划 spec 路径 + 关键 entry point (forum_routes.py 的 list endpoint convert_reply 函数)

- 更新 `MEMORY.md` 索引添加这一行

按 memory 写入流程（参见你的 auto memory 系统说明）。

### Task 6.3: schedule 提议

完工后向用户提议：

> "扁平化已 ship。要不要 /schedule 一个 2 周后的 agent 检查线上回复深度分布（看新功能上线后是否真的产生了深度链），并给出是否升级到 bucket 模型 (β) 的数据建议？"

如用户拒绝就跳过，不强推。

---

## 整体验收清单

完工时确认：

- [ ] linktest + prod 后端已 ship 新代码
- [ ] linktest + prod DB 的 forum_replies 表无 reply_level 列
- [ ] linktest + prod 上深度回复（L4+）创建成功
- [ ] Web 在 prod 上扁平渲染 + @ 跳转可用
- [ ] Flutter 本地构建通过 + @ 跳转可用（待下一次 release）
- [ ] 全仓 grep `reply_level` 仅命中文档/changelog
- [ ] memory 已更新

## 回滚策略

如 Phase 3 prod 出问题，按以下顺序：

1. **Railway 把 prod backend 回滚到上一个稳定 deploy**（恢复读 reply_level 的旧代码）
2. **prod DB 跑 spec §6 的回滚 SQL 重建 column + constraint**（递归 CTE 算 reply_level + 加回 CheckConstraint）

注意：步骤 1 必须先于 2，否则旧代码读不到 column 会 500。

如 Phase 4 web 出问题：Vercel 一键 rollback 到上一 deploy。

如 Phase 5 Flutter 出问题：本地代码 revert，下次发版前修复，已发版的旧 Flutter 不受影响。
