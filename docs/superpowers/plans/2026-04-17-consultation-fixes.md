# Consultation Fixes (Track 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实施咨询功能 Track 1 的 7 项代码级修复,不动 DB schema。

**Architecture:** 新建 `backend/app/permissions/` 和 `backend/app/consultation/` 两个包,集中权限检查与咨询公共业务逻辑;Flutter 侧抽 `ConsultationActionsBase` 基类共用对话框;后端错误用现有 `raise_http_error_with_code` 机制补充 12 个咨询 error code,Flutter 对应扩展 `error_localizer.dart`。

**Tech Stack:** FastAPI + SQLAlchemy + Redis + Celery(后端)、Flutter + BLoC(前端)、pytest + bloc_test(测试)

**Spec:** `docs/superpowers/specs/2026-04-17-consultation-fixes-design.md`

---

## 文件结构

### 新建文件

- `backend/app/permissions/__init__.py`
- `backend/app/permissions/expert_permissions.py` — `get_team_role` / `require_team_role` + request-scoped cache
- `backend/app/consultation/__init__.py`
- `backend/app/consultation/helpers.py` — `create_placeholder_task` / `close_consultation_task` / `resolve_taker_from_service` / `check_consultation_idempotency`
- `backend/app/consultation/notifications.py` — 咨询通知双语模板
- `backend/app/consultation/error_codes.py` — 12 个错误码常量
- `backend/tests/test_expert_permissions.py`
- `backend/tests/test_consultation_helpers.py`
- `backend/tests/test_consultation_notifications.py`
- `backend/tests/test_stale_consultation_cleanup.py`
- `backend/tests/test_consultation_error_codes.py`
- `link2ur/test/features/task_expert/consultation_error_code_test.dart`

### 修改文件

- `backend/app/celery_tasks.py:1729` — lock_ttl 调整
- `backend/app/scheduled_tasks.py:912-992` — `close_stale_consultations` 读配置
- `backend/app/config.py` — 新增 `CONSULTATION_STALE_DAYS`
- `backend/app/expert_consultation_routes.py` — 路由改用 helpers + permissions + error codes
- `backend/app/task_chat_routes.py` — 咨询相关路径改用 helpers + permissions + error codes
- `backend/app/flea_market_routes.py` — 咨询相关路径改用 helpers + error codes
- `backend/app/main.py` — 请求中间件 reset permissions cache
- `link2ur/lib/features/tasks/views/consultation/consultation_base.dart` — 基类加共用对话框
- `link2ur/lib/features/tasks/views/consultation/service_consultation_actions.dart` — 去重
- `link2ur/lib/features/tasks/views/consultation/task_consultation_actions.dart` — 去重
- `link2ur/lib/features/tasks/views/consultation/flea_market_consultation_actions.dart` — 去重
- `link2ur/lib/data/repositories/task_expert_repository.dart` — `TaskExpertException` 加 `errorCode`
- `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart` — state 加 `errorCode`,events 处理传递
- `link2ur/lib/core/utils/error_localizer.dart` — 扩展 switch
- `link2ur/lib/l10n/app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb` — 13 条新 key

---

## Task 1: F1 — 修复 Celery 锁 TTL

**目的:** `close_stale_consultations_task` 的 lock_ttl 从 3600(等于调度间隔)降到 1200(< 间隔,避免并发)。

**Files:**
- Modify: `backend/app/celery_tasks.py:1724-1744`

### Step 1.1: 修改 lock_ttl

- [ ] 打开 `backend/app/celery_tasks.py`,把第 1729 行:

```python
if not get_redis_distributed_lock(lock_key, lock_ttl=3600):
```

改为:

```python
# lock_ttl 必须小于调度间隔 (interval_seconds=3600, task_scheduler.py:648),
# 否则长时间运行会让下一次调度获取到已释放的锁从而并发执行。
# 实测 close_stale_consultations 最长 <5min,设 1200s (20min) 充裕。
if not get_redis_distributed_lock(lock_key, lock_ttl=1200):
```

### Step 1.2: 提交

- [ ] Run:

```bash
git add backend/app/celery_tasks.py
git commit -m "fix(celery): prevent concurrent close_stale_consultations via lock TTL < interval"
```

---

## Task 2: F3 + F7 — 团队权限 helper + request-scoped 缓存

**目的:** 统一三处不一致的 `ExpertMember` 权限查询;缓存单次请求内的角色查询结果避免 N+1。

**Files:**
- Create: `backend/app/permissions/__init__.py`
- Create: `backend/app/permissions/expert_permissions.py`
- Create: `backend/tests/test_expert_permissions.py`
- Modify: `backend/app/main.py`(中间件 reset cache)

### Step 2.1: 写失败测试

- [ ] 创建 `backend/tests/test_expert_permissions.py`:

```python
"""
团队权限 helper 测试
"""
import pytest
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException

from app.permissions.expert_permissions import (
    get_team_role,
    require_team_role,
    reset_role_cache,
)


@pytest.fixture(autouse=True)
def _reset():
    reset_role_cache()
    yield
    reset_role_cache()


class _StubDB:
    """最小 mock:根据 fixture 数据返回 ExpertMember 记录"""
    def __init__(self, members: dict[tuple[str, int], str]):
        # members: {(expert_id, user_id): role}
        self._members = members
        self.query_count = 0

    async def execute(self, stmt):  # pragma: no cover - 简化实现
        self.query_count += 1
        # 由具体测试覆盖(参见下方 monkeypatch)
        raise NotImplementedError


@pytest.mark.asyncio
async def test_get_team_role_returns_owner(monkeypatch):
    async def fake_query(db, expert_id, user_id):
        return "owner"
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    role = await get_team_role(None, "exp-1", 42)
    assert role == "owner"


@pytest.mark.asyncio
async def test_get_team_role_returns_none_for_non_member(monkeypatch):
    async def fake_query(db, expert_id, user_id):
        return None
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    assert await get_team_role(None, "exp-1", 999) is None


@pytest.mark.asyncio
async def test_get_team_role_caches_within_request(monkeypatch):
    calls = {"n": 0}

    async def fake_query(db, expert_id, user_id):
        calls["n"] += 1
        return "admin"

    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    await get_team_role(None, "exp-1", 42)
    await get_team_role(None, "exp-1", 42)
    await get_team_role(None, "exp-1", 42)
    assert calls["n"] == 1  # 只查一次,后续命中缓存


@pytest.mark.asyncio
async def test_get_team_role_cache_resets_between_requests(monkeypatch):
    calls = {"n": 0}

    async def fake_query(db, expert_id, user_id):
        calls["n"] += 1
        return "member"

    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    await get_team_role(None, "exp-1", 42)
    reset_role_cache()
    await get_team_role(None, "exp-1", 42)
    assert calls["n"] == 2


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "role,minimum,should_pass",
    [
        ("owner", "owner", True),
        ("admin", "owner", False),
        ("member", "owner", False),
        ("owner", "admin", True),
        ("admin", "admin", True),
        ("member", "admin", False),
        ("owner", "member", True),
        ("admin", "member", True),
        ("member", "member", True),
        (None, "member", False),
    ],
)
async def test_require_team_role_matrix(monkeypatch, role, minimum, should_pass):
    async def fake_query(db, expert_id, user_id):
        return role
    monkeypatch.setattr(
        "app.permissions.expert_permissions._query_team_role", fake_query
    )
    if should_pass:
        got = await require_team_role(None, "exp-1", 42, minimum=minimum)
        assert got == role
    else:
        with pytest.raises(HTTPException) as exc:
            await require_team_role(None, "exp-1", 42, minimum=minimum)
        assert exc.value.status_code == 403
        assert isinstance(exc.value.detail, dict)
        expected_code = (
            "NOT_TEAM_MEMBER" if role is None else "INSUFFICIENT_TEAM_ROLE"
        )
        assert exc.value.detail.get("error_code") == expected_code
```

### Step 2.2: 运行测试验证失败

- [ ] Run:

```bash
cd backend && pytest tests/test_expert_permissions.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'app.permissions'`

### Step 2.3: 创建 permissions 包和实现

- [ ] 创建 `backend/app/permissions/__init__.py`:

```python
"""权限检查统一模块"""
from app.permissions.expert_permissions import (  # noqa: F401
    get_team_role,
    require_team_role,
    reset_role_cache,
    TeamRole,
)
```

- [ ] 创建 `backend/app/permissions/expert_permissions.py`:

```python
"""
团队(Expert)权限检查 helper + request-scoped 缓存。

Usage:
    role = await get_team_role(db, expert_id, user.id)
    # 或
    role = await require_team_role(db, expert_id, user.id, minimum="admin")
"""
from contextvars import ContextVar
from typing import Literal, Optional

from fastapi import HTTPException
from sqlalchemy import select

from app import models

TeamRole = Literal["owner", "admin", "member"]

_ROLE_HIERARCHY: dict[TeamRole, int] = {"member": 1, "admin": 2, "owner": 3}

# per-request cache: key = (expert_id, user_id), value = role or None
_role_cache: ContextVar[Optional[dict[tuple[str, int], Optional[TeamRole]]]] = (
    ContextVar("_expert_role_cache", default=None)
)


def reset_role_cache() -> None:
    """中间件在每个请求开始时调用,避免跨请求泄露。"""
    _role_cache.set({})


def _cache() -> dict[tuple[str, int], Optional[TeamRole]]:
    c = _role_cache.get()
    if c is None:
        c = {}
        _role_cache.set(c)
    return c


async def _query_team_role(db, expert_id: str, user_id: int) -> Optional[TeamRole]:
    """
    实际 DB 查询(不走缓存)。
    查 ExpertMember 表,对于 owner 也通过 ExpertMember.role='owner' 行识别。
    """
    stmt = select(models.ExpertMember).where(
        models.ExpertMember.expert_id == expert_id,
        models.ExpertMember.user_id == user_id,
        models.ExpertMember.status == "active",
    )
    result = await db.execute(stmt)
    member = result.scalar_one_or_none()
    if member is None:
        return None
    role = (member.role or "").lower()
    if role not in ("owner", "admin", "member"):
        return "member"
    return role  # type: ignore[return-value]


async def get_team_role(db, expert_id: str, user_id: int) -> Optional[TeamRole]:
    """返回当前用户在团队内的角色;非成员返回 None。结果在请求上下文内缓存。"""
    cache = _cache()
    key = (expert_id, user_id)
    if key in cache:
        return cache[key]
    role = await _query_team_role(db, expert_id, user_id)
    cache[key] = role
    return role


async def require_team_role(
    db,
    expert_id: str,
    user_id: int,
    *,
    minimum: TeamRole,
) -> TeamRole:
    """
    不满足最低角色抛 403。
    - minimum='owner' 仅 owner 通过
    - minimum='admin' owner + admin 通过
    - minimum='member' 所有活跃成员通过
    """
    role = await get_team_role(db, expert_id, user_id)
    if role is None:
        raise HTTPException(
            status_code=403,
            detail={
                "error_code": "NOT_TEAM_MEMBER",
                "message": "您不是该团队成员",
            },
        )
    if _ROLE_HIERARCHY[role] < _ROLE_HIERARCHY[minimum]:
        raise HTTPException(
            status_code=403,
            detail={
                "error_code": "INSUFFICIENT_TEAM_ROLE",
                "message": f"该操作需要 {minimum} 及以上角色",
            },
        )
    return role
```

### Step 2.4: 在中间件 reset cache

- [ ] 打开 `backend/app/main.py`,在现有中间件链上追加 reset。搜索 `@app.middleware("http")` 定位第一个中间件位置,在其前添加:

```python
from app.permissions import reset_role_cache


@app.middleware("http")
async def _reset_permission_cache_middleware(request, call_next):
    reset_role_cache()
    return await call_next(request)
```

放在其他中间件**之前**(越靠外越早 reset)。

### Step 2.5: 运行测试验证通过

- [ ] Run:

```bash
cd backend && pytest tests/test_expert_permissions.py -v
```

Expected: 所有 test PASS(14 个用例)

### Step 2.6: 提交

- [ ] Run:

```bash
git add backend/app/permissions/ backend/app/main.py backend/tests/test_expert_permissions.py
git commit -m "feat(permissions): unified team role helper with request-scoped cache"
```

---

## Task 3: F4a — 后端 consultation helpers 模块

**目的:** 把"创建占位 task / 关闭咨询 / 解析 taker / 幂等性检查"公共逻辑从三个路由文件抽取到 `consultation/helpers.py`。

**Files:**
- Create: `backend/app/consultation/__init__.py`
- Create: `backend/app/consultation/helpers.py`
- Create: `backend/tests/test_consultation_helpers.py`

### Step 3.1: 写失败测试

- [ ] 创建 `backend/tests/test_consultation_helpers.py`:

```python
"""
consultation.helpers 单元测试。
不依赖真实 DB,使用内存对象模拟 SQLAlchemy 行为。
"""
from datetime import datetime, timedelta
import pytest
from unittest.mock import AsyncMock, MagicMock

from app.consultation.helpers import (
    check_consultation_idempotency,
    close_consultation_task,
)


@pytest.mark.asyncio
async def test_check_consultation_idempotency_returns_existing(monkeypatch):
    existing = MagicMock(id=123, status="consulting")

    async def fake_execute(stmt):
        r = MagicMock()
        r.scalar_one_or_none = MagicMock(return_value=existing)
        return r

    db = MagicMock()
    db.execute = fake_execute
    got = await check_consultation_idempotency(
        db, applicant_id=42, subject_id=7, subject_type="service"
    )
    assert got is existing


@pytest.mark.asyncio
async def test_check_consultation_idempotency_returns_none_when_absent():
    async def fake_execute(stmt):
        r = MagicMock()
        r.scalar_one_or_none = MagicMock(return_value=None)
        return r

    db = MagicMock()
    db.execute = fake_execute
    got = await check_consultation_idempotency(
        db, applicant_id=42, subject_id=7, subject_type="service"
    )
    assert got is None


@pytest.mark.asyncio
async def test_close_consultation_task_sets_status_closed():
    app_row = MagicMock()
    app_row.task_id = 55

    task_row = MagicMock(id=55, status="consulting")

    async def fake_get(model, pk):
        return task_row

    db = MagicMock()
    db.get = fake_get
    db.add = MagicMock()
    db.flush = AsyncMock()

    await close_consultation_task(db, app_row, reason="转为正式订单")
    assert task_row.status == "closed"
```

### Step 3.2: 运行测试验证失败

- [ ] Run:

```bash
cd backend && pytest tests/test_consultation_helpers.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'app.consultation'`

### Step 3.3: 实现 helpers 模块

- [ ] 创建 `backend/app/consultation/__init__.py`:

```python
"""咨询功能公共业务逻辑"""
```

- [ ] 读 `backend/app/expert_consultation_routes.py:27-53`,把 `_close_consultation_task` 的函数体复制出来作为 `close_consultation_task` 的实现基础。读 `expert_consultation_routes.py:240-261`(check existing) 了解幂等性查询。

- [ ] 创建 `backend/app/consultation/helpers.py`:

```python
"""
咨询公共业务逻辑

三种咨询类型(service / task / flea_market)共用的操作:
- 创建占位 Task
- 关闭咨询占位 Task + 同步应用状态
- 解析服务/团队的 taker_id
- 幂等性检查
"""
from datetime import datetime, timezone
from typing import Literal, Optional

from sqlalchemy import select

from app import models

_ACTIVE_CONSULTATION_STATUSES = (
    "consulting",
    "negotiating",
    "price_agreed",
    "pending",
)

SubjectType = Literal["service", "task", "flea_market_item"]


async def check_consultation_idempotency(
    db,
    *,
    applicant_id: int,
    subject_id,
    subject_type: SubjectType,
) -> Optional[models.ServiceApplication]:
    """
    查询用户对同一主体是否已有进行中咨询。
    返回已存在的 ServiceApplication(或其他申请模型),供路由返回而不是重复创建。
    本 helper 只处理 service 主体;task/flea_market 由各自路由内保留原查询逻辑。
    """
    if subject_type != "service":
        # task / flea_market 的幂等性查询字段不同,本次不合并(Track 2 统一表后再处理)
        return None
    stmt = select(models.ServiceApplication).where(
        models.ServiceApplication.applicant_id == applicant_id,
        models.ServiceApplication.service_id == subject_id,
        models.ServiceApplication.status.in_(_ACTIVE_CONSULTATION_STATUSES),
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def close_consultation_task(
    db,
    application,
    *,
    reason: str,
) -> None:
    """
    关闭咨询占位 task(status → 'closed')并记录原因到 application.
    调用方:approve/reject/close_consultation 时触发。
    """
    if not getattr(application, "task_id", None):
        return
    task = await db.get(models.Task, application.task_id)
    if task is None:
        return
    if task.status in ("consulting", "negotiating", "price_agreed"):
        task.status = "closed"
        # 记录关闭原因到 description 尾注(非 breaking)
        existing_desc = (task.description or "").rstrip()
        suffix = f"\n[closed:{datetime.now(timezone.utc).isoformat()}] {reason}"
        task.description = (existing_desc + suffix)[:2000]  # 防止溢出
        db.add(task)
        await db.flush()


async def resolve_taker_from_service(db, service):
    """
    解析服务对应的 taker:
    - 个人服务 (owner_type='user'): (user_id, None)
    - 团队服务 (owner_type='expert'): (team_owner.user_id, expert_id)
    返回 (taker_id: int, taker_expert_id: Optional[str])
    """
    if service.owner_type == "expert":
        stmt = select(models.ExpertMember).where(
            models.ExpertMember.expert_id == service.owner_id,
            models.ExpertMember.role == "owner",
            models.ExpertMember.status == "active",
        )
        result = await db.execute(stmt)
        owner = result.scalar_one_or_none()
        if owner is None:
            raise ValueError(f"Team {service.owner_id} has no active owner")
        return owner.user_id, service.owner_id
    return service.owner_id, None


async def create_placeholder_task(
    db,
    *,
    consultation_type: Literal["consultation", "task_consultation", "flea_market_consultation"],
    title: str,
    applicant_id: int,
    taker_id: Optional[int],
    service_id: Optional[int] = None,
    description: str = "",
) -> models.Task:
    """
    创建咨询占位 Task(status='consulting')。
    返回持久化后的 Task 对象(已 flush,有 id)。
    """
    task = models.Task(
        title=title,
        description=description,
        poster_id=applicant_id,
        taker_id=taker_id,
        status="consulting",
        task_source=consultation_type,
        service_id=service_id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(task)
    await db.flush()
    return task
```

### Step 3.4: 运行测试验证通过

- [ ] Run:

```bash
cd backend && pytest tests/test_consultation_helpers.py -v
```

Expected: 所有 3 个 test PASS

### Step 3.5: 在路由中使用 helpers

- [ ] 打开 `backend/app/expert_consultation_routes.py:27-53`,删除本地 `_close_consultation_task` 函数。搜索所有 `_close_consultation_task(` 调用点,改为:

```python
from app.consultation.helpers import close_consultation_task
# ...
await close_consultation_task(db, application, reason="...")
```

- [ ] `expert_consultation_routes.py:244-261` 的幂等性检查段改为:

```python
from app.consultation.helpers import check_consultation_idempotency
existing = await check_consultation_idempotency(
    db, applicant_id=current_user.id, subject_id=service_id, subject_type="service"
)
if existing:
    return existing
```

- [ ] `expert_consultation_routes.py:281-300` 创建占位 Task 段改为:

```python
from app.consultation.helpers import create_placeholder_task, resolve_taker_from_service
taker_id, _ = await resolve_taker_from_service(db, service)
task = await create_placeholder_task(
    db,
    consultation_type="consultation",
    title=f"咨询: {service.service_name}",
    applicant_id=current_user.id,
    taker_id=taker_id,
    service_id=service.id,
    description="",
)
```

同样对 `task_chat_routes.py` 的 task_consultation 流程、`flea_market_routes.py` 的 flea_market_consultation 流程做类似替换(保留它们各自的 description/幂等性逻辑)。

### Step 3.6: 跑现有咨询集成测试确保无回归

- [ ] Run:

```bash
cd backend && pytest tests/test_team_service_application_approve.py -v
```

Expected: 原 5 个测试 PASS

### Step 3.7: 提交

- [ ] Run:

```bash
git add backend/app/consultation/ backend/app/expert_consultation_routes.py backend/app/task_chat_routes.py backend/app/flea_market_routes.py backend/tests/test_consultation_helpers.py
git commit -m "refactor(consultation): extract shared helpers to app.consultation"
```

---

## Task 4: F5 — 咨询通知双语模板

**目的:** 集中管理咨询通知的 zh/en 文案,修正现有英文里的全角引号,对齐项目既有双语模式。

**Files:**
- Create: `backend/app/consultation/notifications.py`
- Create: `backend/tests/test_consultation_notifications.py`

### Step 4.1: 写失败测试

- [ ] 创建 `backend/tests/test_consultation_notifications.py`:

```python
"""咨询通知模板测试"""
from app.consultation.notifications import (
    consultation_submitted,
    consultation_negotiated,
    consultation_quoted,
    consultation_formally_applied,
    consultation_approved,
    consultation_rejected,
    consultation_closed,
    consultation_stale_auto_closed,
)


def test_submitted_uses_correct_quotes():
    msg = consultation_submitted(applicant_name="Alice", service_name="翻译")
    assert "Alice" in msg["content_zh"]
    assert "翻译" in msg["content_zh"]
    # 英文文案应使用标准英文双引号,不用中文全角
    assert "「" not in msg["content_en"]
    assert "」" not in msg["content_en"]
    assert "Alice" in msg["content_en"]


def test_negotiated_includes_price():
    msg = consultation_negotiated(
        applicant_name="Bob", service_name="S", price=100
    )
    assert "100" in msg["content_zh"]
    assert "100" in msg["content_en"]


def test_approved_has_both_locales():
    msg = consultation_approved(service_name="翻译", price=500)
    assert msg["content_zh"]
    assert msg["content_en"]


def test_all_templates_return_dict_with_zh_en_keys():
    samples = [
        consultation_submitted(applicant_name="x", service_name="y"),
        consultation_negotiated(applicant_name="x", service_name="y", price=1),
        consultation_quoted(expert_name="x", service_name="y", price=1),
        consultation_formally_applied(applicant_name="x", service_name="y"),
        consultation_approved(service_name="y", price=1),
        consultation_rejected(service_name="y"),
        consultation_closed(),
        consultation_stale_auto_closed(days=14),
    ]
    for m in samples:
        assert set(m.keys()) == {"content_zh", "content_en"}
        assert isinstance(m["content_zh"], str) and m["content_zh"]
        assert isinstance(m["content_en"], str) and m["content_en"]
```

### Step 4.2: 运行测试验证失败

- [ ] Run:

```bash
cd backend && pytest tests/test_consultation_notifications.py -v
```

Expected: FAIL — `ImportError: cannot import name 'consultation_submitted'`

### Step 4.3: 实现模板

- [ ] 创建 `backend/app/consultation/notifications.py`:

```python
"""
咨询通知双语模板。

所有咨询相关的系统消息文案在此集中,供路由/scheduled tasks 调用。
返回 dict,字段与 messages 表 content_zh / content_en 对齐。
"""
from typing import TypedDict


class Bilingual(TypedDict):
    content_zh: str
    content_en: str


def consultation_submitted(*, applicant_name: str, service_name: str) -> Bilingual:
    return {
        "content_zh": f"用户「{applicant_name}」对服务「{service_name}」发起了新咨询",
        "content_en": f'"{applicant_name}" started a new consultation for "{service_name}"',
    }


def consultation_negotiated(
    *, applicant_name: str, service_name: str, price: int
) -> Bilingual:
    return {
        "content_zh": f"用户「{applicant_name}」对服务「{service_name}」议价,出价 {price}",
        "content_en": f'"{applicant_name}" negotiated price {price} for "{service_name}"',
    }


def consultation_quoted(
    *, expert_name: str, service_name: str, price: int
) -> Bilingual:
    return {
        "content_zh": f"专家「{expert_name}」对服务「{service_name}」给出报价 {price}",
        "content_en": f'Expert "{expert_name}" quoted {price} for "{service_name}"',
    }


def consultation_formally_applied(
    *, applicant_name: str, service_name: str
) -> Bilingual:
    return {
        "content_zh": f"用户「{applicant_name}」正式申请服务「{service_name}」",
        "content_en": f'"{applicant_name}" submitted a formal application for "{service_name}"',
    }


def consultation_approved(*, service_name: str, price: int) -> Bilingual:
    return {
        "content_zh": f"咨询已批准,服务「{service_name}」成交价 {price},请完成支付",
        "content_en": f'Consultation approved. Service "{service_name}" agreed at {price}. Please complete payment.',
    }


def consultation_rejected(*, service_name: str) -> Bilingual:
    return {
        "content_zh": f"咨询被拒绝,服务「{service_name}」",
        "content_en": f'Consultation for "{service_name}" was rejected.',
    }


def consultation_closed() -> Bilingual:
    return {
        "content_zh": "咨询已关闭",
        "content_en": "Consultation closed.",
    }


def consultation_stale_auto_closed(*, days: int) -> Bilingual:
    return {
        "content_zh": f"咨询已自动关闭({days} 天未活跃)",
        "content_en": f"Consultation auto-closed after {days} days of inactivity.",
    }
```

### Step 4.4: 运行测试验证通过

- [ ] Run:

```bash
cd backend && pytest tests/test_consultation_notifications.py -v
```

Expected: 4 个 test PASS

### Step 4.5: 替换硬编码文案

- [ ] 搜索 `expert_consultation_routes.py` 里所有硬编码的 `content_zh = f"..."` 和 `content_en = f"..."`(参考 `expert_consultation_routes.py:81-87` 及其他通知创建点),替换为调用对应模板函数:

```python
from app.consultation.notifications import consultation_submitted
msg = consultation_submitted(
    applicant_name=current_user.name, service_name=service.service_name
)
# 插入 messages 时: content_zh=msg["content_zh"], content_en=msg["content_en"]
```

对 `task_chat_routes.py` 与 `scheduled_tasks.py`(stale 自动关闭通知)同样替换。

### Step 4.6: 提交

- [ ] Run:

```bash
git add backend/app/consultation/notifications.py backend/tests/test_consultation_notifications.py backend/app/expert_consultation_routes.py backend/app/task_chat_routes.py backend/app/scheduled_tasks.py
git commit -m "refactor(consultation): centralize bilingual notification templates"
```

---

## Task 5: F2 — stale cleanup 可配置阈值 + 测试

**目的:** 14 天阈值改为可配置(环境变量),补充测试覆盖。

**Files:**
- Modify: `backend/app/config.py`
- Modify: `backend/app/scheduled_tasks.py:912-992`
- Create: `backend/tests/test_stale_consultation_cleanup.py`

### Step 5.1: 添加配置项

- [ ] 打开 `backend/app/config.py`,找到 `class Config:` 末尾,添加:

```python
    # 咨询不活跃自动关闭阈值(天)。staging/prod 可通过环境变量覆盖。
    CONSULTATION_STALE_DAYS: int = int(os.getenv("CONSULTATION_STALE_DAYS", "14"))
```

### Step 5.2: scheduled_tasks 读配置

- [ ] 打开 `backend/app/scheduled_tasks.py`,搜索函数 `close_stale_consultations`(约 912 行),把函数签名改为:

```python
def close_stale_consultations(db, stale_days: int | None = None):
    from app.config import Config
    days = stale_days if stale_days is not None else Config.CONSULTATION_STALE_DAYS
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    # ... 保留原函数体其余部分,将原硬编码 14 替换为 days
```

### Step 5.3: 写失败测试

- [ ] 创建 `backend/tests/test_stale_consultation_cleanup.py`:

```python
"""
stale consultation cleanup 集成测试。
使用真实 SQLAlchemy Session(测试用 SQLite)和时间注入。
"""
from datetime import datetime, timedelta, timezone
import pytest

from app import models
from app.scheduled_tasks import close_stale_consultations


@pytest.fixture
def session(test_db_session):
    """复用项目既有的 test_db_session fixture"""
    return test_db_session


def _make_consultation_task(
    session, *, created_ago_days: int, task_source="consultation"
):
    task = models.Task(
        title="咨询占位",
        description="",
        poster_id=1,
        taker_id=2,
        status="consulting",
        task_source=task_source,
        created_at=datetime.now(timezone.utc) - timedelta(days=created_ago_days),
    )
    session.add(task)
    session.flush()
    sa = models.ServiceApplication(
        service_id=None,
        applicant_id=1,
        status="consulting",
        task_id=task.id,
    )
    session.add(sa)
    session.flush()
    return task, sa


def test_closes_task_older_than_default_threshold(session):
    task, sa = _make_consultation_task(session, created_ago_days=20)
    close_stale_consultations(session)
    session.refresh(task)
    session.refresh(sa)
    assert task.status == "closed"
    assert sa.status == "cancelled"


def test_keeps_task_within_threshold(session):
    task, sa = _make_consultation_task(session, created_ago_days=5)
    close_stale_consultations(session)
    session.refresh(task)
    session.refresh(sa)
    assert task.status == "consulting"
    assert sa.status == "consulting"


def test_custom_threshold_override(session):
    task, sa = _make_consultation_task(session, created_ago_days=5)
    close_stale_consultations(session, stale_days=3)
    session.refresh(task)
    assert task.status == "closed"


def test_ignores_non_consultation_tasks(session):
    task = models.Task(
        title="普通任务",
        description="",
        poster_id=1,
        taker_id=2,
        status="consulting",
        task_source="expert_service",  # 不是咨询来源
        created_at=datetime.now(timezone.utc) - timedelta(days=30),
    )
    session.add(task)
    session.flush()
    close_stale_consultations(session)
    session.refresh(task)
    assert task.status == "consulting"  # 不动


def test_closes_flea_market_consultation(session):
    task, _ = _make_consultation_task(
        session, created_ago_days=20, task_source="flea_market_consultation"
    )
    close_stale_consultations(session)
    session.refresh(task)
    assert task.status == "closed"
```

### Step 5.4: 运行测试

- [ ] Run:

```bash
cd backend && pytest tests/test_stale_consultation_cleanup.py -v
```

Expected: 所有 test PASS(若 fixture `test_db_session` 不存在,先检查 `backend/tests/conftest.py` 是否已提供;没有则需添加,如下)

### Step 5.5: 补 conftest 若缺失

- [ ] 若 `backend/tests/conftest.py` 不存在或未提供 `test_db_session` fixture,追加:

```python
# backend/tests/conftest.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models import Base


@pytest.fixture
def test_db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()
```

(若项目 models 默认用 async,此处需适配 `sqlalchemy.ext.asyncio` 版本;以现有项目 conftest 为准。)

### Step 5.6: 提交

- [ ] Run:

```bash
git add backend/app/config.py backend/app/scheduled_tasks.py backend/tests/test_stale_consultation_cleanup.py backend/tests/conftest.py
git commit -m "feat(scheduled): configurable consultation stale threshold + tests"
```

---

## Task 6: F6a — 后端咨询错误码

**目的:** 为 12 个咨询错误场景添加稳定 `error_code`,替换路由中裸 `HTTPException(..., detail="字符串")`。

**Files:**
- Create: `backend/app/consultation/error_codes.py`
- Modify: `backend/app/expert_consultation_routes.py`、`task_chat_routes.py`、`flea_market_routes.py`
- Create: `backend/tests/test_consultation_error_codes.py`

### Step 6.1: 定义错误码常量

- [ ] 创建 `backend/app/consultation/error_codes.py`:

```python
"""咨询相关错误码常量。供路由统一使用,客户端据此做 l10n。"""

CONSULTATION_ALREADY_EXISTS = "CONSULTATION_ALREADY_EXISTS"
CONSULTATION_NOT_FOUND = "CONSULTATION_NOT_FOUND"
CONSULTATION_CLOSED = "CONSULTATION_CLOSED"
SERVICE_NOT_FOUND = "SERVICE_NOT_FOUND"
SERVICE_INACTIVE = "SERVICE_INACTIVE"
EXPERT_TEAM_NOT_FOUND = "EXPERT_TEAM_NOT_FOUND"
EXPERT_TEAM_INACTIVE = "EXPERT_TEAM_INACTIVE"
CANNOT_CONSULT_SELF = "CANNOT_CONSULT_SELF"
NOT_SERVICE_OWNER = "NOT_SERVICE_OWNER"
NOT_TEAM_MEMBER = "NOT_TEAM_MEMBER"
INSUFFICIENT_TEAM_ROLE = "INSUFFICIENT_TEAM_ROLE"
INVALID_STATUS_TRANSITION = "INVALID_STATUS_TRANSITION"
PRICE_OUT_OF_RANGE = "PRICE_OUT_OF_RANGE"
```

### Step 6.2: 写失败测试

- [ ] 创建 `backend/tests/test_consultation_error_codes.py`:

```python
"""
咨询错误码集成测试 — 验证每个错误场景返回正确的 error_code。
使用 FastAPI TestClient + mock 用户。
"""
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    from app.main import app
    return TestClient(app)


def _assert_error_code(response, status: int, code: str):
    assert response.status_code == status
    body = response.json()
    # error_handlers 会把 detail.error_code 解包到顶层
    assert body.get("error_code") == code, body


def test_service_not_found_returns_code(client, auth_headers):
    r = client.post("/api/services/999999/consult", headers=auth_headers)
    _assert_error_code(r, 404, "SERVICE_NOT_FOUND")


def test_consultation_already_exists_returns_code(client, auth_headers, seed_consulting_application):
    service_id = seed_consulting_application.service_id
    r = client.post(f"/api/services/{service_id}/consult", headers=auth_headers)
    _assert_error_code(r, 400, "CONSULTATION_ALREADY_EXISTS")


def test_cannot_consult_self_returns_code(client, auth_headers, seed_owned_service):
    r = client.post(f"/api/services/{seed_owned_service.id}/consult", headers=auth_headers)
    _assert_error_code(r, 400, "CANNOT_CONSULT_SELF")


def test_service_inactive_returns_code(client, auth_headers, seed_inactive_service):
    r = client.post(f"/api/services/{seed_inactive_service.id}/consult", headers=auth_headers)
    _assert_error_code(r, 400, "SERVICE_INACTIVE")


def test_expert_team_not_found_returns_code(client, auth_headers):
    r = client.post("/api/experts/nonexistent-team-id/consult", headers=auth_headers)
    _assert_error_code(r, 404, "EXPERT_TEAM_NOT_FOUND")


def test_expert_team_inactive_returns_code(client, auth_headers, seed_inactive_team):
    r = client.post(f"/api/experts/{seed_inactive_team.id}/consult", headers=auth_headers)
    _assert_error_code(r, 400, "EXPERT_TEAM_INACTIVE")


def test_consultation_not_found_returns_code(client, auth_headers):
    r = client.post("/api/applications/99999999/negotiate", json={"proposed_price": 100}, headers=auth_headers)
    _assert_error_code(r, 404, "CONSULTATION_NOT_FOUND")


def test_consultation_closed_returns_code(client, auth_headers, seed_closed_consultation):
    r = client.post(f"/api/applications/{seed_closed_consultation.id}/negotiate", json={"proposed_price": 100}, headers=auth_headers)
    _assert_error_code(r, 400, "CONSULTATION_CLOSED")


def test_not_service_owner_returns_code(client, auth_headers, seed_other_user_service, seed_consulting_application_for_other):
    r = client.post(f"/api/applications/{seed_consulting_application_for_other.id}/approve", headers=auth_headers)
    _assert_error_code(r, 403, "NOT_SERVICE_OWNER")


def test_not_team_member_returns_code(client, auth_headers, seed_consulting_application_for_other_team):
    r = client.post(f"/api/applications/{seed_consulting_application_for_other_team.id}/approve", headers=auth_headers)
    _assert_error_code(r, 403, "NOT_TEAM_MEMBER")


def test_insufficient_team_role_returns_code(client, member_headers, seed_team_consulting_application):
    # member_headers 是普通成员(非 owner/admin),approve 需要 admin 以上
    r = client.post(f"/api/applications/{seed_team_consulting_application.id}/approve", headers=member_headers)
    _assert_error_code(r, 403, "INSUFFICIENT_TEAM_ROLE")


def test_invalid_status_transition_returns_code(client, auth_headers, seed_rejected_application):
    r = client.post(f"/api/applications/{seed_rejected_application.id}/approve", headers=auth_headers)
    _assert_error_code(r, 400, "INVALID_STATUS_TRANSITION")


def test_price_out_of_range_returns_code(client, auth_headers, seed_consulting_application):
    r = client.post(
        f"/api/applications/{seed_consulting_application.id}/negotiate",
        json={"proposed_price": 999999999},  # 超出服务允许范围
        headers=auth_headers,
    )
    _assert_error_code(r, 400, "PRICE_OUT_OF_RANGE")
```

**fixtures 指引(按需添加到 `backend/tests/conftest.py`):**

- `auth_headers` / `member_headers` — JWT 构造 helper(项目既有)
- `seed_consulting_application` — 用户已有 consulting 状态的 ServiceApplication
- `seed_owned_service` — auth_headers 用户自己所有的服务
- `seed_inactive_service` — is_active=False 的服务
- `seed_inactive_team` — status != "active" 的 Expert
- `seed_closed_consultation` — status="cancelled" 的 ServiceApplication
- `seed_other_user_service` + `seed_consulting_application_for_other` — 属于别人的服务 + 咨询
- `seed_consulting_application_for_other_team` — 属于别人团队的咨询
- `seed_team_consulting_application` — member_headers 所在团队的咨询
- `seed_rejected_application` — status="rejected" 的 ServiceApplication

如果某 fixture 太复杂难造,可在该 test 中用 `monkeypatch` 直接 mock DB 查询返回对应状态,只要最终断言 `error_code` 正确即可。

### Step 6.3: 路由内替换

- [ ] 打开 `backend/app/expert_consultation_routes.py`,搜索 `HTTPException(`,对每个咨询场景改用错误码。举例:

原(大约第 236 行附近):
```python
raise HTTPException(status_code=404, detail="服务不存在")
```

改为:
```python
from app.consultation import error_codes
from app.error_handlers import raise_http_error_with_code
raise_http_error_with_code(
    message="服务不存在", status_code=404, error_code=error_codes.SERVICE_NOT_FOUND
)
```

对所有 12 个场景做对应替换:

| 场景 | 文件搜索词 | error_code |
|---|---|---|
| 服务不存在 | `"服务不存在"` | `SERVICE_NOT_FOUND` |
| 服务下架 | `"服务已下架"` 或 `is_active` 校验 | `SERVICE_INACTIVE` |
| 团队不存在 | `"团队不存在"` | `EXPERT_TEAM_NOT_FOUND` |
| 团队非 active | `"团队未激活"` 等 | `EXPERT_TEAM_INACTIVE` |
| 咨询自己 | `"不能对自己"` | `CANNOT_CONSULT_SELF` |
| 已有咨询 | 幂等检查分支现返回 existing,若有报错分支 | `CONSULTATION_ALREADY_EXISTS` |
| 非服务 owner | `"不是服务所有者"` | `NOT_SERVICE_OWNER` |
| 咨询不存在 | `"申请不存在"` 等 | `CONSULTATION_NOT_FOUND` |
| 咨询已关闭 | `"已关闭"` 等 | `CONSULTATION_CLOSED` |
| 状态非法 | status 校验 | `INVALID_STATUS_TRANSITION` |
| 价格越界 | 价格范围校验 | `PRICE_OUT_OF_RANGE` |

`NOT_TEAM_MEMBER` / `INSUFFICIENT_TEAM_ROLE` 已由 Task 2 的 `require_team_role` 抛出,无需再改。

### Step 6.4: 运行测试

- [ ] Run:

```bash
cd backend && pytest tests/test_consultation_error_codes.py -v
```

Expected: 所有 12 个 test PASS

### Step 6.5: 提交

- [ ] Run:

```bash
git add backend/app/consultation/error_codes.py backend/app/expert_consultation_routes.py backend/app/task_chat_routes.py backend/app/flea_market_routes.py backend/tests/test_consultation_error_codes.py
git commit -m "feat(consultation): standardize error codes for 12 consultation scenarios"
```

---

## Task 7: F4b — Flutter ConsultationActions 基类去重

**目的:** 三个 `*_consultation_actions.dart` 子类中重复的对话框(议价/报价/反驳/正式申请/批准确认)下沉到基类。

**Files:**
- Modify: `link2ur/lib/features/tasks/views/consultation/consultation_base.dart`
- Modify: `link2ur/lib/features/tasks/views/consultation/service_consultation_actions.dart`
- Modify: `link2ur/lib/features/tasks/views/consultation/task_consultation_actions.dart`
- Modify: `link2ur/lib/features/tasks/views/consultation/flea_market_consultation_actions.dart`

### Step 7.1: 读当前三个子类,找出完全重复的对话框方法

- [ ] 打开三个子类文件,对比 `_showNegotiateDialog` / `_showQuoteDialog` / `_showCounterOfferDialog` / `_showFormalApplyDialog` / `_showApproveConfirmation` 五个方法的实现。除了最后调用的 repository 方法之外,UI 代码应完全一致。

### Step 7.2: 基类引入 abstract 回调 + 共享对话框

- [ ] 修改 `consultation_base.dart` `ConsultationActions` 抽象类,新增:

```dart
// 抽象回调,由子类实现具体 repository 调用
Future<void> onNegotiate(BuildContext context, int applicationId, double price);
Future<void> onQuote(BuildContext context, int applicationId, double price);
Future<void> onCounterOffer(BuildContext context, int applicationId, double price);
Future<void> onFormalApply(BuildContext context, int applicationId);
Future<void> onApprove(BuildContext context, int applicationId);

// 共享对话框 - 非 abstract,所有子类直接复用
Future<void> showNegotiateDialog(BuildContext context, int applicationId) async {
  final controller = TextEditingController();
  final result = await showDialog<double>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.negotiatePrice),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: dialogContext.l10n.proposedPrice),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final v = double.tryParse(controller.text.trim());
            if (v != null && v > 0) Navigator.pop(dialogContext, v);
          },
          child: Text(dialogContext.l10n.submit),
        ),
      ],
    ),
  );
  if (result != null && context.mounted) {
    await onNegotiate(context, applicationId, result);
  }
}

// showQuoteDialog / showCounterOfferDialog / showFormalApplyDialog /
// showApproveConfirmation 同理,把三个子类中重复代码原样搬上来,
// 最后一行改为调 onXxx 抽象方法。
```

(完整代码较长,每个对话框十几到三十行,按三个子类中任何一份原代码搬迁即可。)

### Step 7.3: 子类瘦身

- [ ] 打开 `service_consultation_actions.dart`,删除 5 个 `_show*Dialog` 实现;只保留 `on*` 覆盖:

```dart
@override
Future<void> onNegotiate(BuildContext context, int applicationId, double price) async {
  context.read<TaskExpertBloc>().add(
    TaskExpertNegotiatePrice(applicationId, proposedPrice: price),
  );
}

@override
Future<void> onQuote(BuildContext context, int applicationId, double price) async {
  context.read<TaskExpertBloc>().add(
    TaskExpertQuotePrice(applicationId, quotedPrice: price),
  );
}

// ...onCounterOffer / onFormalApply / onApprove 类似
```

原先调用 `_showNegotiateDialog(...)` 的地方(按钮 `onPressed`)改成调 `showNegotiateDialog(...)`(基类方法)。

- [ ] 对 `task_consultation_actions.dart` 和 `flea_market_consultation_actions.dart` 重复此过程。

### Step 7.4: 跑 flutter analyze

- [ ] Run(先设置环境):

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
cd link2ur
flutter analyze lib/features/tasks/views/consultation/
```

Expected: 无 error/warning

### Step 7.5: 跑 widget test

- [ ] Run:

```powershell
flutter test test/features/tasks/consultation/
```

Expected: 既有测试 PASS(本 Task 无新测试,依赖 Task 8 的 bloc 测试间接覆盖)

### Step 7.6: 提交

- [ ] Run:

```bash
cd ..
git add link2ur/lib/features/tasks/views/consultation/
git commit -m "refactor(flutter): share consultation dialog UI across 3 subclasses"
```

---

## Task 8: F6b — Flutter TaskExpertException.errorCode + BLoC state

**目的:** BLoC state 上新增 `errorCode` 字段,让 UI 可按错误码显示不同本地化文案。

**Files:**
- Modify: `link2ur/lib/data/repositories/task_expert_repository.dart`
- Modify: `link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart`
- Modify: `link2ur/lib/features/task_expert/bloc/task_expert_state.dart`(若存在单独 state 文件,否则同 bloc 文件)

### Step 8.1: 写失败测试

- [ ] 创建 `link2ur/test/features/task_expert/consultation_error_code_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// 按项目实际 import 路径调整
import 'package:link2ur/features/task_expert/bloc/task_expert_bloc.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';

class _MockRepo extends Mock implements TaskExpertRepository {}

void main() {
  group('TaskExpertBloc consultation errorCode plumbing', () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
    });

    blocTest<TaskExpertBloc, TaskExpertState>(
      'populates errorCode when repo throws with code',
      build: () {
        when(() => repo.createConsultation(any())).thenThrow(
          TaskExpertException('服务已下架', errorCode: 'SERVICE_INACTIVE'),
        );
        return TaskExpertBloc(repository: repo);
      },
      act: (bloc) => bloc.add(TaskExpertStartConsultation(42)),
      expect: () => [
        isA<TaskExpertState>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<TaskExpertState>()
            .having((s) => s.errorCode, 'errorCode', 'SERVICE_INACTIVE')
            .having((s) => s.errorMessage, 'errorMessage', contains('服务已下架')),
      ],
    );

    blocTest<TaskExpertState, TaskExpertState>(
      'leaves errorCode null for generic Exception',
      build: () {
        when(() => repo.createConsultation(any())).thenThrow(Exception('oops'));
        return TaskExpertBloc(repository: repo);
      },
      act: (bloc) => bloc.add(TaskExpertStartConsultation(42)),
      expect: () => [
        isA<TaskExpertState>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<TaskExpertState>().having((s) => s.errorCode, 'errorCode', null),
      ],
    );
  });
}
```

### Step 8.2: 运行测试验证失败

- [ ] Run:

```powershell
flutter test test/features/task_expert/consultation_error_code_test.dart
```

Expected: FAIL — `TaskExpertException` 不接受 `errorCode` 参数;`TaskExpertState` 无 `errorCode` 字段

### Step 8.3: 扩展 TaskExpertException

- [ ] 打开 `link2ur/lib/data/repositories/task_expert_repository.dart`,找到 `TaskExpertException` 定义,改为:

```dart
class TaskExpertException implements Exception {
  TaskExpertException(this.message, {this.errorCode});
  final String message;
  final String? errorCode;

  @override
  String toString() => 'TaskExpertException: $message';
}
```

- [ ] 修改 repository 错误抛出位置,把 `ApiResponse.errorCode` 透传:

```dart
// 原:
throw TaskExpertException(response.message ?? 'default');
// 改为:
throw TaskExpertException(
  response.message ?? 'default',
  errorCode: response.errorCode,
);
```

需要在 `createConsultation` / `negotiatePrice` / `quotePrice` / `respondToNegotiation` / `formalApply` / `closeConsultation` / `createTaskConsultation` / `createFleaMarketConsultation` / `approveApplication` / `rejectApplication` 等所有咨询相关方法中做此改动。

### Step 8.4: 扩展 TaskExpertState

- [ ] 打开 `task_expert_bloc.dart`(state 是 `part of` 同文件),找到 `TaskExpertState` 类,添加 `errorCode` 字段:

```dart
class TaskExpertState extends Equatable {
  const TaskExpertState({
    // ... 原有字段
    this.errorCode,
  });

  // ... 原有字段
  final String? errorCode;

  TaskExpertState copyWith({
    // ... 原有参数
    String? errorCode,
    bool clearErrorCode = false,  // sentinel:允许显式清空
  }) {
    return TaskExpertState(
      // ... 原有透传
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
    );
  }

  @override
  List<Object?> get props => [
    // ... 原有 props
    errorCode,
  ];
}
```

### Step 8.5: BLoC 处理函数传递 errorCode

- [ ] 打开所有 `_on*Consultation*` / `_onStartConsultation` / `_onNegotiate*` / `_onCloseConsultation` / `_onApprove*` 处理函数,把 catch 分支改为:

```dart
on TaskExpertException catch (e) {
  emit(state.copyWith(
    isSubmitting: false,
    errorMessage: e.message,
    errorCode: e.errorCode,
    actionMessage: 'consultation_failed',
  ));
}
```

成功分支要 reset errorCode:

```dart
emit(state.copyWith(
  isSubmitting: false,
  consultationData: data,
  clearErrorCode: true,  // 成功时清掉旧错误码
  actionMessage: 'consultation_started',
));
```

### Step 8.6: 运行测试验证通过

- [ ] Run:

```powershell
flutter test test/features/task_expert/consultation_error_code_test.dart
```

Expected: 两个 test PASS

### Step 8.7: 提交

- [ ] Run:

```bash
git add link2ur/lib/data/repositories/task_expert_repository.dart link2ur/lib/features/task_expert/bloc/task_expert_bloc.dart link2ur/test/features/task_expert/consultation_error_code_test.dart
git commit -m "feat(flutter): plumb consultation errorCode through repo -> bloc -> state"
```

---

## Task 9: F6c — l10n ARB 条目 + error_localizer 扩展

**目的:** 13 个新 l10n key(12 错误码 + 1 fallback)× 3 locale + `error_localizer.dart` switch 扩展。

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`
- Modify: `link2ur/lib/core/utils/error_localizer.dart`

### Step 9.1: 添加 ARB key — en

- [ ] 打开 `link2ur/lib/l10n/app_en.arb`,在文件末尾 `}` 前追加:

```json
,
"consultationErrorAlreadyExists": "You already have an ongoing consultation for this item",
"@consultationErrorAlreadyExists": {},
"consultationErrorNotFound": "Consultation not found",
"@consultationErrorNotFound": {},
"consultationErrorClosed": "This consultation has been closed",
"@consultationErrorClosed": {},
"consultationErrorServiceNotFound": "Service not found",
"@consultationErrorServiceNotFound": {},
"consultationErrorServiceInactive": "This service is no longer available",
"@consultationErrorServiceInactive": {},
"consultationErrorTeamNotFound": "Expert team not found",
"@consultationErrorTeamNotFound": {},
"consultationErrorTeamInactive": "This expert team is not active",
"@consultationErrorTeamInactive": {},
"consultationErrorCannotConsultSelf": "You cannot consult your own service",
"@consultationErrorCannotConsultSelf": {},
"consultationErrorNotServiceOwner": "You are not the owner of this service",
"@consultationErrorNotServiceOwner": {},
"consultationErrorNotTeamMember": "You are not a member of this team",
"@consultationErrorNotTeamMember": {},
"consultationErrorInsufficientTeamRole": "Your team role does not permit this action",
"@consultationErrorInsufficientTeamRole": {},
"consultationErrorInvalidStatusTransition": "This action is not allowed in the current consultation state",
"@consultationErrorInvalidStatusTransition": {},
"consultationErrorPriceOutOfRange": "Price is outside the allowed range",
"@consultationErrorPriceOutOfRange": {},
"consultationErrorGeneric": "Consultation action failed. Please try again."
"@consultationErrorGeneric": {}
```

### Step 9.2: 添加 ARB key — zh

- [ ] 打开 `link2ur/lib/l10n/app_zh.arb`,按相同顺序添加:

```json
,
"consultationErrorAlreadyExists": "您已有进行中的咨询申请",
"@consultationErrorAlreadyExists": {},
"consultationErrorNotFound": "咨询申请不存在",
"@consultationErrorNotFound": {},
"consultationErrorClosed": "该咨询已关闭",
"@consultationErrorClosed": {},
"consultationErrorServiceNotFound": "服务不存在",
"@consultationErrorServiceNotFound": {},
"consultationErrorServiceInactive": "该服务已下架",
"@consultationErrorServiceInactive": {},
"consultationErrorTeamNotFound": "专家团队不存在",
"@consultationErrorTeamNotFound": {},
"consultationErrorTeamInactive": "该专家团队未激活",
"@consultationErrorTeamInactive": {},
"consultationErrorCannotConsultSelf": "不能对自己发起咨询",
"@consultationErrorCannotConsultSelf": {},
"consultationErrorNotServiceOwner": "您不是该服务的所有者",
"@consultationErrorNotServiceOwner": {},
"consultationErrorNotTeamMember": "您不是该团队成员",
"@consultationErrorNotTeamMember": {},
"consultationErrorInsufficientTeamRole": "您的团队角色不足以执行该操作",
"@consultationErrorInsufficientTeamRole": {},
"consultationErrorInvalidStatusTransition": "当前咨询状态不允许该操作",
"@consultationErrorInvalidStatusTransition": {},
"consultationErrorPriceOutOfRange": "价格超出允许范围",
"@consultationErrorPriceOutOfRange": {},
"consultationErrorGeneric": "咨询操作失败,请稍后重试"
"@consultationErrorGeneric": {}
```

### Step 9.3: 添加 ARB key — zh_Hant

- [ ] 打开 `link2ur/lib/l10n/app_zh_Hant.arb`,添加:

```json
,
"consultationErrorAlreadyExists": "您已有進行中的諮詢申請",
"@consultationErrorAlreadyExists": {},
"consultationErrorNotFound": "諮詢申請不存在",
"@consultationErrorNotFound": {},
"consultationErrorClosed": "該諮詢已關閉",
"@consultationErrorClosed": {},
"consultationErrorServiceNotFound": "服務不存在",
"@consultationErrorServiceNotFound": {},
"consultationErrorServiceInactive": "該服務已下架",
"@consultationErrorServiceInactive": {},
"consultationErrorTeamNotFound": "專家團隊不存在",
"@consultationErrorTeamNotFound": {},
"consultationErrorTeamInactive": "該專家團隊未啟用",
"@consultationErrorTeamInactive": {},
"consultationErrorCannotConsultSelf": "不能對自己發起諮詢",
"@consultationErrorCannotConsultSelf": {},
"consultationErrorNotServiceOwner": "您不是該服務的所有者",
"@consultationErrorNotServiceOwner": {},
"consultationErrorNotTeamMember": "您不是該團隊成員",
"@consultationErrorNotTeamMember": {},
"consultationErrorInsufficientTeamRole": "您的團隊角色不足以執行該操作",
"@consultationErrorInsufficientTeamRole": {},
"consultationErrorInvalidStatusTransition": "當前諮詢狀態不允許該操作",
"@consultationErrorInvalidStatusTransition": {},
"consultationErrorPriceOutOfRange": "價格超出允許範圍",
"@consultationErrorPriceOutOfRange": {},
"consultationErrorGeneric": "諮詢操作失敗,請稍後再試"
"@consultationErrorGeneric": {}
```

### Step 9.4: 生成 l10n 代码

- [ ] Run:

```powershell
cd link2ur
flutter gen-l10n
```

Expected: 无 error,生成文件包含新 getter

### Step 9.5: 扩展 error_localizer.dart

- [ ] 打开 `link2ur/lib/core/utils/error_localizer.dart`,新增静态方法专用于 error code(code 来自 BLoC state.errorCode,不是 errorMessage):

```dart
/// 专门处理 backend 返回的 error_code → l10n,供咨询流程使用
static String localizeErrorCode(BuildContext context, String? errorCode) {
  if (errorCode == null || errorCode.isEmpty) {
    return context.l10n.errorUnknownGeneric;
  }
  switch (errorCode) {
    case 'CONSULTATION_ALREADY_EXISTS':
      return context.l10n.consultationErrorAlreadyExists;
    case 'CONSULTATION_NOT_FOUND':
      return context.l10n.consultationErrorNotFound;
    case 'CONSULTATION_CLOSED':
      return context.l10n.consultationErrorClosed;
    case 'SERVICE_NOT_FOUND':
      return context.l10n.consultationErrorServiceNotFound;
    case 'SERVICE_INACTIVE':
      return context.l10n.consultationErrorServiceInactive;
    case 'EXPERT_TEAM_NOT_FOUND':
      return context.l10n.consultationErrorTeamNotFound;
    case 'EXPERT_TEAM_INACTIVE':
      return context.l10n.consultationErrorTeamInactive;
    case 'CANNOT_CONSULT_SELF':
      return context.l10n.consultationErrorCannotConsultSelf;
    case 'NOT_SERVICE_OWNER':
      return context.l10n.consultationErrorNotServiceOwner;
    case 'NOT_TEAM_MEMBER':
      return context.l10n.consultationErrorNotTeamMember;
    case 'INSUFFICIENT_TEAM_ROLE':
      return context.l10n.consultationErrorInsufficientTeamRole;
    case 'INVALID_STATUS_TRANSITION':
      return context.l10n.consultationErrorInvalidStatusTransition;
    case 'PRICE_OUT_OF_RANGE':
      return context.l10n.consultationErrorPriceOutOfRange;
    default:
      return context.l10n.consultationErrorGeneric;
  }
}
```

并在 `ErrorLocalizerExtension` 上追加:

```dart
String localizeErrorCode(String? code) =>
    ErrorLocalizer.localizeErrorCode(this, code);
```

### Step 9.6: UI 调用点升级

- [ ] 在咨询相关 UI(`service_consultation_actions.dart` 等按钮 onPressed 后的错误 SnackBar),从:

```dart
SnackBar(content: Text(context.localizeError(state.errorMessage)))
```

改为优先读 errorCode:

```dart
SnackBar(
  content: Text(
    state.errorCode != null
        ? context.localizeErrorCode(state.errorCode)
        : context.localizeError(state.errorMessage),
  ),
)
```

### Step 9.7: 跑完整测试 + analyze

- [ ] Run:

```powershell
cd link2ur
flutter analyze
flutter test test/
```

Expected: analyze 无 error;所有测试 PASS

### Step 9.8: 提交

- [ ] Run:

```bash
cd ..
git add link2ur/lib/l10n/ link2ur/lib/core/utils/error_localizer.dart link2ur/lib/features/tasks/views/consultation/
git commit -m "feat(flutter): l10n entries for 13 consultation error codes"
```

---

## Task 10: 集成验证 + 文档更新

### Step 10.1: 后端全量测试

- [ ] Run:

```bash
cd backend && pytest tests/ -v --tb=short
```

Expected: 全绿。若既有测试失败,修复而不是跳过。

### Step 10.2: Flutter 全量测试

- [ ] Run:

```powershell
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze
flutter test test/
```

Expected: 0 error,全测试 PASS。

### Step 10.3: 更新 memory

- [ ] 在 `C:\Users\Ryan\.claude\projects\F--python-work-LinkU\memory\MEMORY.md` 的 "Tech Debt" 节下添加一行:

```markdown
- [Consultation fixes Track 1 完成](project_consultation_fixes_track1.md) — 2026-04-17,代码层修复,F1-F7 合入
```

并写对应 file `project_consultation_fixes_track1.md`:

```markdown
---
name: Consultation fixes Track 1 completed
description: 2026-04-17 完成 Track 1 的 7 项咨询修复;Track 2(conversation-first 重构)仍待立项
type: project
---

2026-04-17 合入 Track 1 七项修复:Celery 锁 TTL、stale cleanup 可配置阈值、团队权限 helper、咨询 helpers 模块、通知双语模板、12 个错误码、ExpertMember request-scoped 缓存、Flutter 对话框基类 + errorCode 端到端 l10n。

**Why:** 咨询功能代码审查发现 10 项问题,按复杂度分两 Track。Track 1 纯代码重构,Track 2 (tasks 表 task-first → conversation-first 重构)单独立项。

**How to apply:** 后续修改咨询相关路由/BLoC 时,走 `app/permissions/` + `app/consultation/` + `error_codes.py`;新增咨询错误场景加常量 + l10n 条目两处,不要裸 `HTTPException`。
```

### Step 10.4: 最终提交

- [ ] Run:

```bash
git status
# 确认无未提交改动
git log --oneline -10
# 确认 Task 1-9 共 9 个 commit
```

Expected: `git status` clean。

---

## Success Criteria

- [ ] 9 个 commit 合入 main,每个对应 1 个 Task
- [ ] backend pytest 全绿,新增测试 ≥ 25 个
- [ ] Flutter flutter test 全绿,analyze 无 error
- [ ] `expert_consultation_routes.py` + `task_chat_routes.py`(咨询部分) + `flea_market_routes.py`(咨询部分)总行数下降 ≥ 15%
- [ ] 至少 5 个咨询错误场景在 Flutter 端显示正确本地化文案(对应 3 locale)
- [ ] `close_stale_consultations_task` 在 staging 运行 24h 无并发告警
