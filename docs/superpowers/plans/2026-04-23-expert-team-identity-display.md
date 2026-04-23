# Expert Team Identity Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让服务、活动、论坛帖子的列表/详情在后端统一输出 `display_name / display_avatar / owner_type / owner_id` 四个新字段，Flutter 端新建 `PublisherIdentity` 组件替换各页面的硬编码作者渲染，实现"团队内容展示团队身份、个人内容展示个人身份、点击正确分流路由"。

**Architecture:** 后端抽取 `app/services/display_identity.py` async helper，由各路由在返回响应前调用并追加新字段（additive，不删旧字段）；Flutter 三个 model 加新字段（fallback 兼容旧响应），新建 `PublisherIdentity` stateless widget，各 view 替换 author 区域。

**Tech Stack:** FastAPI + SQLAlchemy async, Pydantic v2, Flutter/Dart BLoC, GoRouter

---

## File Map

| 文件 | 操作 | 说明 |
|---|---|---|
| `backend/app/services/display_identity.py` | **新建** | async helper：单条 + 批量 resolve |
| `backend/app/schemas.py` | **修改** | 4 个 schema 加 4 个新字段 |
| `backend/app/service_public_routes.py` | **修改** | detail endpoint 追加 display_* 字段 |
| `backend/app/expert_service_routes.py` | **修改** | list endpoint 批量 resolve + 追加字段 |
| `backend/app/multi_participant_routes.py` | **修改** | activity detail（sync）内联追加 |
| `backend/app/expert_activity_routes.py` | **修改** | activity list（async）批量 resolve |
| `backend/app/forum_routes.py` | **修改** | post list + detail endpoint 追加字段 |
| `backend/app/follow_feed_routes.py` | **修改** | 迁入共享 helper，行为不变 |
| `link2ur/lib/data/models/task_expert.dart` | **修改** | TaskExpertService 加 4 个 Optional 字段 |
| `link2ur/lib/data/models/activity.dart` | **修改** | Activity 加 displayName / displayAvatar |
| `link2ur/lib/data/models/forum.dart` | **修改** | ForumPost 加 4 个 Optional 字段 |
| `link2ur/lib/l10n/app_en.arb` | **修改** | 加 `expertTeamLabel` / `unknownUser` |
| `link2ur/lib/l10n/app_zh.arb` | **修改** | 同上（中文） |
| `link2ur/lib/l10n/app_zh_Hant.arb` | **修改** | 同上（繁体） |
| `link2ur/lib/core/widgets/publisher_identity.dart` | **新建** | PublisherIdentity widget |
| `link2ur/lib/features/task_expert/views/service_detail_view.dart` | **修改** | AppBar owner 区换用 PublisherIdentity |
| `link2ur/lib/features/task_expert/views/task_expert_list_view.dart` | **修改** | _ExpertCard owner 区换用 PublisherIdentity |
| `link2ur/lib/features/task_expert/views/task_expert_detail_view.dart` | **修改** | _ServiceCard owner 区换用 PublisherIdentity |
| `link2ur/lib/features/activity/views/activity_detail_view.dart` | **修改** | _PosterInfoRow 换用 PublisherIdentity |
| `link2ur/lib/features/forum/views/forum_post_list_view.dart` | **修改** | _PostCard author 区换用 PublisherIdentity |
| `link2ur/lib/features/forum/views/forum_post_detail_view.dart` | **修改** | 帖子头部 author 区换用 PublisherIdentity |
| `link2ur/lib/features/discover/views/discover_view.dart` | **修改** | Feed 卡片 owner 区换用 PublisherIdentity |

---

## Task 1: 创建 display_identity.py async helper

**Files:**
- Create: `backend/app/services/__init__.py`（若不存在）
- Create: `backend/app/services/display_identity.py`

- [ ] **Step 1: 确认 Expert 模型字段名**

```bash
grep -n "class Expert\b" backend/app/models_expert.py | head -3
grep -n "^\s*name\s*=\s*Column\|^\s*avatar\s*=\s*Column\|^\s*id\s*=\s*Column" backend/app/models_expert.py | head -10
```

期望输出：找到 `id`、`name`、`avatar` 三列及其类型（id 应为 String(8) 或类似形式）。

- [ ] **Step 2: 确认 Expert.id 类型与 Activity.owner_id 对应方式**

```bash
grep -n "owner_id\|expert_id" backend/app/models.py | grep -i "Column\|ForeignKey" | head -10
```

期望：判断 Activity.owner_id 是整数 FK 还是字符串。若 Expert.id 是 String(8)，在 helper 里需要 `str(owner_id)` 转换。

- [ ] **Step 3: 创建 `backend/app/services/__init__.py`**（若不存在）

```bash
ls backend/app/services/ 2>/dev/null || mkdir backend/app/services && touch backend/app/services/__init__.py
```

- [ ] **Step 4: 写 `backend/app/services/display_identity.py`**

```python
"""Helpers for resolving publisher display identity (name + avatar)."""
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select


async def resolve_async(
    db: AsyncSession,
    owner_type: str,
    owner_id: int,
) -> tuple[str, Optional[str]]:
    """Return (display_name, display_avatar). Falls back to ('', None) if not found."""
    from app.models_expert import Expert
    from app.models import User  # adjust import if User is elsewhere

    if owner_type == "expert":
        result = await db.execute(
            select(Expert).where(Expert.id == str(owner_id))
        )
        team = result.scalar_one_or_none()
        return (team.name or "" if team else "", team.avatar if team else None)
    else:
        result = await db.execute(
            select(User).where(User.id == owner_id)
        )
        user = result.scalar_one_or_none()
        return (user.name or "" if user else "", user.avatar if user else None)


async def batch_resolve_async(
    db: AsyncSession,
    identities: list[tuple[str, int]],  # [(owner_type, owner_id), ...]
) -> dict[tuple[str, int], tuple[str, Optional[str]]]:
    """Batch resolve to avoid N+1 on list endpoints."""
    from app.models_expert import Expert
    from app.models import User

    expert_ids = list({oid for otype, oid in identities if otype == "expert"})
    user_ids = list({oid for otype, oid in identities if otype == "user"})

    experts: dict[int, tuple[str, Optional[str]]] = {}
    users: dict[int, tuple[str, Optional[str]]] = {}

    if expert_ids:
        rows = (await db.execute(
            select(Expert.id, Expert.name, Expert.avatar)
            .where(Expert.id.in_([str(i) for i in expert_ids]))
        )).all()
        experts = {int(r.id): (r.name or "", r.avatar) for r in rows}

    if user_ids:
        rows = (await db.execute(
            select(User.id, User.name, User.avatar)
            .where(User.id.in_(user_ids))
        )).all()
        users = {r.id: (r.name or "", r.avatar) for r in rows}

    out: dict[tuple[str, int], tuple[str, Optional[str]]] = {}
    for otype, oid in identities:
        if otype == "expert":
            out[(otype, oid)] = experts.get(oid, ("", None))
        else:
            out[(otype, oid)] = users.get(oid, ("", None))
    return out
```

> **注意**：若 Expert.id 是纯整数类型，去掉 `str()` 转换；若 User 在 `app.models_expert` 里，调整 import。

- [ ] **Step 5: 验证 import 路径无误**

```bash
cd backend && python -c "from app.services.display_identity import resolve_async, batch_resolve_async; print('OK')"
```

期望输出：`OK`（无报错）。

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/
git commit -m "feat: add display_identity async helper for owner name/avatar resolution"
```

---

## Task 2: 更新 4 个 Pydantic schemas

**Files:**
- Modify: `backend/app/schemas.py`

- [ ] **Step 1: 找到 4 个 schema 的位置**

```bash
grep -n "class TaskExpertServiceOut\|class ActivityOut\|class ForumPostOut\|class ForumPostListItem" backend/app/schemas.py
```

期望：输出 4 行行号。记录每个 class 的行号。

- [ ] **Step 2: 在 `TaskExpertServiceOut` 末尾追加字段**

打开 `backend/app/schemas.py`，在 `TaskExpertServiceOut` 的最后一个字段之后添加：

```python
    # Display identity fields (added for expert team identity display)
    display_name: str = ""
    display_avatar: Optional[str] = None
    owner_type: str = "user"
    owner_id: int = 0
```

> `TaskExpertServiceOut` 已有 `owner_name`/`owner_avatar`/`owner_rating`，这是**新增**字段，不替换旧字段。

- [ ] **Step 3: 在 `ActivityOut` 末尾追加字段**

`ActivityOut` 已有 `owner_type` 和 `owner_id`（不重复添加），只追加：

```python
    # Display identity fields
    display_name: str = ""
    display_avatar: Optional[str] = None
```

- [ ] **Step 4: 在 `ForumPostOut` 末尾追加字段**

```python
    # Display identity fields (synthesized from expert_id)
    owner_type: str = "user"
    owner_id: int = 0
    display_name: str = ""
    display_avatar: Optional[str] = None
```

- [ ] **Step 5: 在 `ForumPostListItem` 末尾追加同样字段**

```python
    # Display identity fields (synthesized from expert_id)
    owner_type: str = "user"
    owner_id: int = 0
    display_name: str = ""
    display_avatar: Optional[str] = None
```

- [ ] **Step 6: 验证 schema 可正常导入**

```bash
cd backend && python -c "from app.schemas import TaskExpertServiceOut, ActivityOut, ForumPostOut, ForumPostListItem; print('OK')"
```

期望：`OK`

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat: add display_name/display_avatar/owner_type/owner_id to service, activity, forum schemas"
```

---

## Task 3: 修补 service 端点

**Files:**
- Modify: `backend/app/service_public_routes.py`（detail）
- Modify: `backend/app/expert_service_routes.py`（list）

- [ ] **Step 1: 找 service detail 中已有的 owner 解析代码位置**

```bash
grep -n "owner_type\|owner_name\|display_name\|service_out" backend/app/service_public_routes.py | head -20
```

期望：看到已有的 `service_out.owner_name = ...` 赋值块（约在 209-224 行）。

- [ ] **Step 2: 在 service detail endpoint 的 owner 解析块之后追加 display 字段**

找到 `service_public_routes.py` 中如下代码块（已有代码）：

```python
    if service.owner_type == "user" and service.owner_id:
        owner = await async_crud.async_user_crud.get_user_by_id(db, service.owner_id)
        if owner:
            service_out.owner_name = owner.name
            service_out.owner_avatar = owner.avatar
            service_out.owner_rating = owner.avg_rating
    elif service.owner_type == "expert" and service.owner_id:
        expert_obj = await db.get(Expert, service.owner_id)
        if expert_obj:
            service_out.owner_name = expert_obj.name
            service_out.owner_avatar = expert_obj.avatar
            service_out.owner_rating = float(expert_obj.rating) if expert_obj.rating else 0.0
```

在该块 **之后**（`return service_out` 之前）追加：

```python
    # Populate display identity fields
    service_out.owner_type = service.owner_type or "user"
    service_out.owner_id = service.owner_id or 0
    service_out.display_name = service_out.owner_name or ""
    service_out.display_avatar = service_out.owner_avatar
```

- [ ] **Step 3: 找 service list 端点**

```bash
grep -n "@router\|async def\|def " backend/app/expert_service_routes.py | head -30
```

找到返回 `TaskExpertServiceOut` list 的端点（通常是 `GET /{expert_id}/services` 或 `GET /`）。

- [ ] **Step 4: 在 service list 端点中批量 resolve display identity**

在 list 端点内，**在构建 response list 之前**，插入批量 resolve：

```python
    from app.services.display_identity import batch_resolve_async

    # Collect identities for batch lookup
    identities = [
        (s.owner_type or "user", s.owner_id or 0)
        for s in services  # 替换 services 为实际的服务对象列表变量名
    ]
    identity_map = await batch_resolve_async(db, identities)
```

然后在构建每个 `TaskExpertServiceOut` 对象时（或在遍历时）追加：

```python
        svc_out.owner_type = svc.owner_type or "user"
        svc_out.owner_id = svc.owner_id or 0
        svc_out.display_name, svc_out.display_avatar = identity_map.get(
            (svc.owner_type or "user", svc.owner_id or 0), ("", None)
        )
```

- [ ] **Step 5: 本地测试 service 端点**

```bash
cd backend && python -c "import app.service_public_routes; import app.expert_service_routes; print('import OK')"
```

期望：`import OK`

- [ ] **Step 6: Commit**

```bash
git add backend/app/service_public_routes.py backend/app/expert_service_routes.py
git commit -m "feat: add display identity fields to service list/detail endpoints"
```

---

## Task 4: 修补 activity 端点

**Files:**
- Modify: `backend/app/multi_participant_routes.py`（activity detail，sync）
- Modify: `backend/app/expert_activity_routes.py`（activity list，async）

- [ ] **Step 1: 找 activity detail 端点中返回 ActivityOut 的位置**

```bash
grep -n "ActivityOut\|owner_type\|return\|activity_out\b" backend/app/multi_participant_routes.py | head -30
```

找到构建并 return `ActivityOut` 响应对象的位置（约 1483-1604 行）。

- [ ] **Step 2: 在 activity detail（sync）中内联追加 display 字段**

找到 `activity` 对象（从 DB 加载的 ORM 对象）和 `activity_out`（响应对象），在 `return` 之前添加（sync 版本，直接用已加载的 ORM 关系或追加查询）：

```python
    # Populate display identity fields (sync inline — no async helper available here)
    from app import models as _m
    _owner_type = getattr(activity, "owner_type", "user") or "user"
    _owner_id = getattr(activity, "owner_id", 0) or 0
    if _owner_type == "expert":
        from app.models_expert import Expert as _Expert
        _team = db.get(_Expert, str(_owner_id))
        _display_name = _team.name if _team else ""
        _display_avatar = _team.avatar if _team else None
    else:
        _user = db.get(_m.User, _owner_id)
        _display_name = _user.name if _user else ""
        _display_avatar = _user.avatar if _user else None
    activity_out.display_name = _display_name
    activity_out.display_avatar = _display_avatar
```

> 若 `activity_out` 是 dict 而非 Pydantic 对象，改为 `activity_out["display_name"] = _display_name` 等。若 `ActivityOut` 已通过 `owner_type`/`owner_id` 渠道构造，直接读取即可不再查 DB，只需赋值 `display_name`。

- [ ] **Step 3: 找 expert_activity_routes.py 的 list 端点**

```bash
grep -n "@router\|async def " backend/app/expert_activity_routes.py | head -20
```

- [ ] **Step 4: 在 activity list（async）端点批量 resolve display identity**

在 list 端点构建响应 list 之前插入：

```python
    from app.services.display_identity import batch_resolve_async
    identities = [
        (a.owner_type or "user", a.owner_id or 0)
        for a in activities  # 替换为实际变量名
    ]
    identity_map = await batch_resolve_async(db, identities)
```

在遍历构建每个 `ActivityOut` 时追加：

```python
        act_out.display_name, act_out.display_avatar = identity_map.get(
            (act.owner_type or "user", act.owner_id or 0), ("", None)
        )
```

- [ ] **Step 5: 检查是否还有其他 activity list 端点（如公开列表）**

```bash
grep -rn "response_model.*ActivityOut\|ActivityOut" backend/app/ | grep -v "schemas.py\|#" | head -20
```

若发现其他返回 `ActivityOut` list 的端点，对每个端点重复 Step 4 的批量 resolve 模式。

- [ ] **Step 6: 验证 import**

```bash
cd backend && python -c "import app.multi_participant_routes; import app.expert_activity_routes; print('OK')"
```

- [ ] **Step 7: Commit**

```bash
git add backend/app/multi_participant_routes.py backend/app/expert_activity_routes.py
git commit -m "feat: add display identity fields to activity list/detail endpoints"
```

---

## Task 5: 修补 forum 端点

**Files:**
- Modify: `backend/app/forum_routes.py`

- [ ] **Step 1: 找 forum post list 端点的行号和结构**

```bash
grep -n "async def get_posts\b" backend/app/forum_routes.py
```

然后读取该函数前 80 行，观察它如何构建响应（dict 列表还是 ForumPostOut 对象）。

- [ ] **Step 2: 在 post list 端点中批量 resolve display identity**

论坛帖没有原生 `owner_type`/`owner_id`，需从 `expert_id` 合成。在 list 端点**构建响应之前**插入：

```python
    from app.services.display_identity import batch_resolve_async

    # Synthesize owner_type/owner_id for each post
    def _post_identity(post) -> tuple[str, int]:
        if getattr(post, "expert_id", None):
            return ("expert", int(post.expert_id))
        return ("user", post.author_id or 0)  # adjust field name if needed

    identities = [_post_identity(p) for p in posts]  # replace `posts` with actual var
    identity_map = await batch_resolve_async(db, identities)
```

在构建每个 `ForumPostListItem` 时追加：

```python
        _otype, _oid = _post_identity(post)
        post_out["owner_type"] = _otype          # or post_out.owner_type = _otype
        post_out["owner_id"] = _oid
        post_out["display_name"], post_out["display_avatar"] = identity_map.get(
            (_otype, _oid), ("", None)
        )
```

> 若响应是 Pydantic 对象用 `post_out.owner_type = ...`；若是 dict 用 `post_out["owner_type"] = ...`。

- [ ] **Step 3: 找 forum post detail 端点并追加字段**

```bash
grep -n "async def get_post\b" backend/app/forum_routes.py
```

读取该函数，在 `return` 之前追加（单条，用 `resolve_async`）：

```python
    from app.services.display_identity import resolve_async

    _expert_id = getattr(post, "expert_id", None)
    _otype = "expert" if _expert_id else "user"
    _oid = int(_expert_id) if _expert_id else (post.author_id or 0)
    _display_name, _display_avatar = await resolve_async(db, _otype, _oid)

    # Attach to response
    post_out.owner_type = _otype
    post_out.owner_id = _oid
    post_out.display_name = _display_name
    post_out.display_avatar = _display_avatar
```

- [ ] **Step 4: 验证 import**

```bash
cd backend && python -c "import app.forum_routes; print('OK')"
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/forum_routes.py
git commit -m "feat: add display identity fields to forum post list/detail endpoints"
```

---

## Task 6: 重构 follow_feed_routes 使用共享 helper

**Files:**
- Modify: `backend/app/follow_feed_routes.py`

- [ ] **Step 1: 找现有内联身份解析逻辑位置**

```bash
grep -n "is_team\|display_name\|display_avatar\|expert_name\|expert_avatar" backend/app/follow_feed_routes.py | head -30
```

期望：看到多处类似 `is_team = row.owner_type == "expert"` + `display_name = row.expert_name if is_team else row.user_name` 的模式。

- [ ] **Step 2: 理解现有 batch JOIN 结构**

`follow_feed_routes.py` 用 JOIN 在单次查询里同时拉取 user 和 expert 信息，与 `batch_resolve_async` 的方式不同（JOIN vs 额外查询）。现有方式性能更优，**不替换查询逻辑**，只抽取身份选择逻辑为辅助函数。

在文件顶部（import 区域后）添加：

```python
def _pick_identity(
    owner_type: str,
    expert_name: str | None,
    expert_avatar: str | None,
    user_name: str | None,
    user_avatar: str | None,
) -> tuple[str, str | None]:
    """Shared identity selector for feed rows that already JOIN both User and Expert."""
    if owner_type == "expert":
        return (expert_name or "", expert_avatar)
    return (user_name or "", user_avatar)
```

- [ ] **Step 3: 替换 `_fetch_followed_services` 中的内联逻辑**

找到类似：
```python
is_team = row.owner_type == "expert"
display_name = (row.expert_name if is_team else row.user_name) or "匿名用户"
display_avatar = row.expert_avatar if is_team else row.user_avatar
```
替换为：
```python
display_name, display_avatar = _pick_identity(
    row.owner_type or "user",
    row.expert_name, row.expert_avatar,
    row.user_name, row.user_avatar,
)
display_name = display_name or "匿名用户"
```

- [ ] **Step 4: 对 `_fetch_followed_activities` 重复相同替换**

- [ ] **Step 5: 对 `_fetch_followed_forum_posts` 重复相同替换**（使用 `is_team_post` / `post_expert_id` 分支）

- [ ] **Step 6: 验证 import**

```bash
cd backend && python -c "import app.follow_feed_routes; print('OK')"
```

- [ ] **Step 7: Commit**

```bash
git add backend/app/follow_feed_routes.py
git commit -m "refactor: extract identity selector helper in follow_feed_routes, behavior unchanged"
```

---

## Task 7: 更新 3 个 Dart 模型

**Files:**
- Modify: `link2ur/lib/data/models/task_expert.dart`
- Modify: `link2ur/lib/data/models/activity.dart`
- Modify: `link2ur/lib/data/models/forum.dart`

- [ ] **Step 1: 在 `TaskExpertService` 类中添加 3 个新字段**

找到 `TaskExpertService` 类字段声明区（`ownerName`/`ownerAvatar` 附近），追加：

```dart
  final String? displayName;
  final String? displayAvatar;
  final String? ownerType;
```

在 constructor 添加对应参数：
```dart
  this.displayName,
  this.displayAvatar,
  this.ownerType,
```

在 `fromJson` 中追加解析（放在 `ownerName` 解析之后）：
```dart
  displayName: json['display_name'] as String?,
  displayAvatar: json['display_avatar'] as String?,
  ownerType: json['owner_type'] as String?,
```

在 `copyWith` 中追加（若该类有 copyWith）：
```dart
  displayName: displayName ?? this.displayName,
  displayAvatar: displayAvatar ?? this.displayAvatar,
  ownerType: ownerType ?? this.ownerType,
```

在 `toJson` 中追加（若有）：
```dart
  if (displayName != null) 'display_name': displayName,
  if (displayAvatar != null) 'display_avatar': displayAvatar,
  if (ownerType != null) 'owner_type': ownerType,
```

在 `props` list 中追加（Equatable）：
```dart
  displayName, displayAvatar, ownerType,
```

- [ ] **Step 2: 在 `Activity` 类中添加 2 个新字段**

`Activity` 已有 `ownerType`/`ownerId`，只追加：

```dart
  final String? displayName;
  final String? displayAvatar;
```

constructor / fromJson / copyWith / toJson / props 处理同 Step 1 模式。

fromJson:
```dart
  displayName: json['display_name'] as String?,
  displayAvatar: json['display_avatar'] as String?,
```

- [ ] **Step 3: 在 `ForumPost` 类中添加 4 个新字段**

```dart
  final String? ownerType;
  final int? ownerId;
  final String? displayName;
  final String? displayAvatar;
```

fromJson:
```dart
  ownerType: json['owner_type'] as String?,
  ownerId: json['owner_id'] as int?,
  displayName: json['display_name'] as String?,
  displayAvatar: json['display_avatar'] as String?,
```

constructor / copyWith / toJson / props 处理同 Step 1。

- [ ] **Step 4: flutter analyze（models 层）**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; Set-Location link2ur; flutter analyze lib/data/models/
```

期望：0 errors，warnings 不增加。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/data/models/task_expert.dart link2ur/lib/data/models/activity.dart link2ur/lib/data/models/forum.dart
git commit -m "feat: add display identity fields to TaskExpertService, Activity, ForumPost models"
```

---

## Task 8: 添加 l10n 字符串 + 创建 PublisherIdentity widget

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`
- Create: `link2ur/lib/core/widgets/publisher_identity.dart`

- [ ] **Step 1: 在 3 个 ARB 文件中追加 2 个新 key**

`app_en.arb`（在末尾 `}` 之前）：
```json
  "expertTeamLabel": "Expert Team",
  "@expertTeamLabel": { "description": "Badge label for expert team publisher" },
  "unknownUser": "Unknown User",
  "@unknownUser": { "description": "Fallback name when publisher name is empty" }
```

`app_zh.arb`：
```json
  "expertTeamLabel": "达人团队",
  "@expertTeamLabel": { "description": "Badge label for expert team publisher" },
  "unknownUser": "未知用户",
  "@unknownUser": { "description": "Fallback name when publisher name is empty" }
```

`app_zh_Hant.arb`：
```json
  "expertTeamLabel": "達人團隊",
  "@expertTeamLabel": { "description": "Badge label for expert team publisher" },
  "unknownUser": "未知用戶",
  "@unknownUser": { "description": "Fallback name when publisher name is empty" }
```

- [ ] **Step 2: 生成 l10n 文件**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; Set-Location link2ur; flutter gen-l10n
```

期望：生成成功，无错误。

- [ ] **Step 3: 创建 `publisher_identity.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:link2ur/core/design/app_colors.dart';
import 'package:link2ur/core/design/app_typography.dart';
import 'package:link2ur/core/design/app_spacing.dart';
import 'package:link2ur/core/router/go_router_extensions.dart';
import 'package:link2ur/core/widgets/avatar_view.dart';
import 'package:link2ur/l10n/app_localizations.dart';

/// Renders a publisher (user or expert team) with avatar, name, and optional badge.
/// Clicking navigates to the correct profile/team page.
class PublisherIdentity extends StatelessWidget {
  const PublisherIdentity({
    super.key,
    required this.ownerType,
    required this.ownerId,
    required this.displayName,
    this.displayAvatar,
    this.showBadge = true,
    this.avatarSize = 32,
    this.nameStyle,
  });

  /// 'user' or 'expert'
  final String ownerType;
  final int ownerId;
  final String displayName;
  final String? displayAvatar;

  /// When true and ownerType == 'expert', shows a small "达人团队" badge.
  final bool showBadge;
  final double avatarSize;
  final TextStyle? nameStyle;

  bool get _isExpert => ownerType == 'expert';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = displayName.isEmpty ? l10n.unknownUser : displayName;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isExpert) {
          context.goToTaskExpertDetail(ownerId.toString());
        } else {
          context.goToUserProfile(ownerId.toString());
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarView(
            imageUrl: displayAvatar,
            name: name,
            size: avatarSize,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: nameStyle ?? AppTypography.captionBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showBadge && _isExpert)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.expertTeamLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

> **验证**：`AvatarView` 存在于 `lib/core/widgets/avatar_view.dart`（通过 Grep 确认）；`AppSpacing.xs` 是否存在（若不存在改为 `const SizedBox(width: 6)`）；`AppLocalizations` import 路径按实际生成路径调整（可能是 `generated/l10n/` 下）。

- [ ] **Step 4: flutter analyze（新 widget）**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; Set-Location link2ur; flutter analyze lib/core/widgets/publisher_identity.dart
```

期望：0 errors。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/core/widgets/publisher_identity.dart
git commit -m "feat: add PublisherIdentity widget and l10n strings for expert team badge"
```

---

## Task 9: 更新 service 视图

**Files:**
- Modify: `link2ur/lib/features/task_expert/views/service_detail_view.dart`
- Modify: `link2ur/lib/features/task_expert/views/task_expert_list_view.dart`
- Modify: `link2ur/lib/features/task_expert/views/task_expert_detail_view.dart`

- [ ] **Step 1: 在 service_detail_view.dart 替换 AppBar owner 区**

找到约第 100-119 行（`service.ownerAvatar` 和 `onTap: service.userId != null ? () => context.goToUserProfile(service.userId!) : null`）。

用 `PublisherIdentity` 替换整个 `GestureDetector` + `CircleAvatar` 块：

```dart
import 'package:link2ur/core/widgets/publisher_identity.dart';

// 替换原有 GestureDetector/CircleAvatar 块为：
PublisherIdentity(
  ownerType: service.ownerType ?? 'user',
  ownerId: int.tryParse(service.userId ?? '0') ?? 0,
  displayName: service.displayName ?? service.ownerName ?? '',
  displayAvatar: service.displayAvatar ?? service.ownerAvatar,
  avatarSize: 16,
  showBadge: false,  // AppBar 空间有限，badge 放 detail body 里
),
```

> `ownerId`：若 service 已有 `owner_id` int 字段（确认 model），改用 `service.ownerId`；否则用 `int.tryParse(service.userId ?? '0') ?? 0`。

- [ ] **Step 2: 检查 task_expert_list_view.dart 的 _ExpertCard**

```bash
grep -n "ownerName\|owner_name\|ownerAvatar\|userId\|goToUserProfile" link2ur/lib/features/task_expert/views/task_expert_list_view.dart | head -20
```

若 `_ExpertCard` 显示了 owner 信息（avatar + name），用 `PublisherIdentity` 替换。若只显示 expert team 信息（不是 service owner），跳过此文件。

- [ ] **Step 3: 检查 task_expert_detail_view.dart 的 _ServiceCard**

```bash
grep -n "ownerName\|ownerAvatar\|userId\|goToUserProfile" link2ur/lib/features/task_expert/views/task_expert_detail_view.dart | head -20
```

同 Step 2 逻辑：若有 owner 渲染，用 `PublisherIdentity` 替换。

- [ ] **Step 4: flutter analyze（service views）**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; Set-Location link2ur; flutter analyze lib/features/task_expert/
```

期望：0 errors。

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/task_expert/
git commit -m "feat: replace service owner display with PublisherIdentity widget"
```

---

## Task 10: 更新 activity 视图

**Files:**
- Modify: `link2ur/lib/features/activity/views/activity_detail_view.dart`

- [ ] **Step 1: 读取 _PosterInfoRow 现有实现**

```bash
grep -n "_PosterInfoRow\|class _PosterInfoRow" link2ur/lib/features/activity/views/activity_detail_view.dart
```

读取该 class 全部内容（约 1877-1920 行）。

- [ ] **Step 2: 替换 _PosterInfoRow 内部渲染**

`_PosterInfoRow` 当前逻辑：加载 `expert` 对象（来自 bloc state），用 `expert?.displayNameWith(context.l10n)`，点击 `context.safePush('/task-experts/$id')`。

替换为使用 `PublisherIdentity`（利用 model 上的新字段，不再需要 bloc 里的额外 expert 对象）：

```dart
import 'package:link2ur/core/widgets/publisher_identity.dart';

// 在 _PosterInfoRow.build() 中：
final ownerType = activity.ownerType ?? 'user';
final ownerId = activity.ownerId ?? 0;
final displayName = activity.displayName ?? '';
final displayAvatar = activity.displayAvatar;

return Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  child: PublisherIdentity(
    ownerType: ownerType,
    ownerId: ownerId,
    displayName: displayName,
    displayAvatar: displayAvatar,
    avatarSize: 32,
    showBadge: true,
  ),
);
```

> 若旧 `_PosterInfoRow` 依赖 `expert` from bloc state（`context.read<ActivityBloc>().state.expert`），且新字段 fallback 足够，可去掉该 bloc 依赖。若 `expert` 还被页面其他地方使用，保留 bloc 依赖，只替换 _PosterInfoRow 内部 UI。

- [ ] **Step 3: 检查 activity list 卡片是否有 owner 显示**

```bash
grep -rn "ownerName\|owner_name\|ownerAvatar\|Activity\b.*owner" link2ur/lib/features/activity/views/ | grep -v "_detail" | head -20
```

若 activity list 卡片有 owner 渲染，对每处用 `PublisherIdentity` 替换。

- [ ] **Step 4: flutter analyze（activity views）**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; Set-Location link2ur; flutter analyze lib/features/activity/
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/activity/
git commit -m "feat: replace activity poster display with PublisherIdentity widget"
```

---

## Task 11: 更新 forum 视图

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_post_list_view.dart`
- Modify: `link2ur/lib/features/forum/views/forum_post_detail_view.dart`

- [ ] **Step 1: 替换 forum_post_list_view.dart 的 author 区**

找到约第 328-345 行（`post.author!.avatar`、`post.author!.name`）。

用 `PublisherIdentity` 替换：

```dart
import 'package:link2ur/core/widgets/publisher_identity.dart';

// 替换原有 AvatarView + Text author 块为：
PublisherIdentity(
  ownerType: post.ownerType ?? 'user',
  ownerId: post.ownerId ?? (int.tryParse(post.authorId) ?? 0),
  displayName: post.displayName ?? post.author?.name ?? '',
  displayAvatar: post.displayAvatar ?? post.author?.avatar,
  avatarSize: 20,
  showBadge: false,  // list 卡片空间有限
),
```

> `post.authorId` 可能是 String，用 `int.tryParse` 处理；确认 `ForumPost.ownerId` 字段名（Task 7 中加的是 `ownerId`）。

- [ ] **Step 2: 替换 forum_post_detail_view.dart 的帖子头部 author 区**

找到约第 177-223 行（`post.author?.avatar`、`post.author?.name`、`context.goToUserProfile`）。

用 `PublisherIdentity` 替换：

```dart
PublisherIdentity(
  ownerType: post.ownerType ?? 'user',
  ownerId: post.ownerId ?? (int.tryParse(post.authorId) ?? 0),
  displayName: post.displayName ?? post.author?.name ?? '',
  displayAvatar: post.displayAvatar ?? post.author?.avatar,
  avatarSize: 32,
  showBadge: true,
),
```

> **只替换帖子作者区**（非回复者区）。回复者仍显示个人身份（回复是用户行为，不受本 spec 影响）。

- [ ] **Step 3: flutter analyze（forum views）**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; Set-Location link2ur; flutter analyze lib/features/forum/
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/forum/
git commit -m "feat: replace forum post author display with PublisherIdentity widget"
```

---

## Task 12: 更新 discover/feed 视图 + 全量 analyze

**Files:**
- Modify: `link2ur/lib/features/discover/views/discover_view.dart`

- [ ] **Step 1: 检查 discover_view.dart 中需要替换的 owner 渲染位置**

```bash
grep -n "ownerName\|owner_name\|ownerAvatar\|display_name\|ownerType\|PublisherIdentity" link2ur/lib/features/discover/views/discover_view.dart | head -20
```

Discover feed 卡片（非 expert 卡片本身，是 Feed 里转发的服务/活动/帖子卡片）。若 Feed 卡片里有 author/owner 渲染（有 `ownerName`/`ownerAvatar` 相关字段），用 `PublisherIdentity` 替换。

- [ ] **Step 2: 替换 feed 卡片中的 owner 渲染（若存在）**

```dart
PublisherIdentity(
  ownerType: item.ownerType ?? 'user',
  ownerId: item.ownerId ?? 0,
  displayName: item.displayName ?? item.ownerName ?? '',
  displayAvatar: item.displayAvatar ?? item.ownerAvatar,
  avatarSize: 24,
  showBadge: false,
),
```

- [ ] **Step 3: 全量 flutter analyze**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; Set-Location link2ur; flutter analyze
```

期望：0 errors，无新 warnings（与修改前基准对比）。

- [ ] **Step 4: 兼容性验证（旧响应 fallback）**

在 `service_detail_view.dart` 中临时把 `service.displayName` 改为 `null`，确认 `PublisherIdentity` fallback 到 `service.ownerName`：
- `displayName: service.displayName ?? service.ownerName ?? ''` — 若 `displayName` 为 null，显示 `ownerName`
- 逻辑正确后恢复原代码。

- [ ] **Step 5: 旧后端响应模拟验证**

在 `ForumPost.fromJson` 中临时注释掉 `displayName`/`displayAvatar` 解析行，运行 app 到论坛列表页，确认不崩（fallback 到 `post.author?.name`）。验证完毕后恢复注释。

- [ ] **Step 6: Final commit**

```bash
git add link2ur/lib/features/discover/
git commit -m "feat: replace discover feed owner display with PublisherIdentity widget"
```

---

## 验证清单（实施完成后）

参照 spec §验证路径，在模拟器/设备上手动检查：

- [ ] 达人团队发布的服务列表卡片 → 显示团队名 + 团队头像
- [ ] 达人团队服务详情页头 → 显示团队名 + 团队头像 + "达人团队"徽章
- [ ] 达人团队发布的活动列表卡片 → 显示团队身份
- [ ] 活动详情页作者栏 → 团队身份 + badge
- [ ] 达人团队发布的论坛帖子列表 → 显示团队名
- [ ] 论坛帖子详情页头部 → 团队身份 + badge（回复者不变）
- [ ] Feed 卡片 → 团队内容显示团队身份
- [ ] 个人用户发布的相同内容 → 显示个人头像 + 名字，无 badge
- [ ] 点击团队 publisher → 跳转 `/task-experts/{team_id}`
- [ ] 点击个人 publisher → 跳转 `/user/{user_id}`（或 profile 页）
- [ ] `flutter analyze` 0 errors

---

## 风险提示

1. **Expert.id 类型**：models_expert.py 中 Expert.id 为 String(8)，但 Activity.owner_id 在 schema 中为 int。Task 1 Step 2 **必须确认**是否需要 `str()` 转换，否则 batch query 会返回空结果。

2. **N+1**：list 端点必须用 `batch_resolve_async`，不要在 for 循环里调 `resolve_async`。

3. **forum_routes.py 体积大**：文件 312KB，编辑时注意不要破坏附近代码；建议用精确的 Edit 工具（old_string/new_string）而非整文件重写。

4. **ForumPost.authorId 类型**：Dart model 中 `authorId` 可能是 String（确认 forum.dart），`int.tryParse` 是必要的。
