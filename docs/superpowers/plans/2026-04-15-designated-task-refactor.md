# Designated Task Request Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构"给指定用户发布任务请求"流程：取消创建任务时预生成的"伪造 TaskApplication"，用专用端点承载接受/拒绝/撤回动作；议价统一走现有咨询聊天；发布者获得"等待接受 + 撤回"UX。

**Architecture:** 后端新增 `backend/app/routes/designated_task_routes.py`（3 个端点：accept / reject / withdraw），`crud/task.py::create_task` 不再预创建 application，同时移除 `async_routers.apply_for_task` 对 `pending_acceptance` 的特殊分支。一次性数据清理脚本清除旧数据残留的伪造 application。Flutter 端 `TaskDetailBloc` 新增三事件，任务详情页按钮布局按"是否被指定 + 是否待报价"分支：定价 → 接受 / 拒绝 / 咨询；待报价 → 咨询 / 拒绝；发布者 → 状态条 + 撤回。现有"批准并支付"按钮保持不变（仍依赖 Application 存在），因为被指定用户"接受"后由新端点创建 `TaskApplication(status=pending)`。

**Tech Stack:** FastAPI + SQLAlchemy (async) + Alembic（后端）、Flutter BLoC + GoRouter（前端）、pytest（后端测试）、bloc_test + mocktail（前端测试）。

**前置条件：** 当前 `main` 分支已有未提交改动（`async_routers.py / task_chat_routes.py / schemas.py / l10n` 等），执行前必须先把这些改动 commit / stash，或基于 `main` 起一个干净 worktree。

---

## 文件结构概览

### 后端
- **修改** `backend/app/crud/task.py:177-234` — 删除伪造 `TaskApplication` 创建（保留 `task_direct_request` 通知 + 推送）
- **修改** `backend/app/async_routers.py:957-978` — 删除 `pending_acceptance` 特殊分支
- **新建** `backend/app/routes/designated_task_routes.py` — 3 个端点
- **修改** `backend/app/main.py` — 注册 `designated_task_router`
- **新建** `backend/migrations/201_cleanup_designated_fake_applications.sql` — 一次性清理数据
- **新建** `backend/tests/test_designated_task_routes.py` — 端点测试

### Flutter
- **修改** `link2ur/lib/core/constants/api_endpoints.dart` — 新增 3 个端点常量
- **修改** `link2ur/lib/data/repositories/task_repository.dart` — 新增 3 个方法
- **修改** `link2ur/lib/features/tasks/bloc/task_detail_event.dart` — 新增 3 个事件
- **修改** `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart` — 事件处理
- **修改** `link2ur/lib/features/tasks/views/task_detail_view.dart` — 按钮布局重构
- **修改** `link2ur/lib/l10n/app_{zh,zh_Hant,en}.arb` — 新增文案
- **新建** `link2ur/test/features/tasks/designated_task_flow_test.dart` — Bloc 测试

---

## Task 1 — 后端：删除伪造 application 创建

**Files:**
- Modify: `backend/app/crud/task.py:177-234`

- [ ] **Step 1：读当前实现并标记删除范围**

打开 `backend/app/crud/task.py`，确认第 177-234 行的 `designated_taker_id` 分支。保留 L179-182 的 task 字段设置 + L202-232 的通知/推送；删除 L188-201 的 `auto_application` 创建 + `db.commit()`。

- [ ] **Step 2：修改 crud/task.py**

用以下内容替换 L177-234：

```python
    designated_taker_id = getattr(task, "designated_taker_id", None)
    task_source = getattr(task, "task_source", "normal") or "normal"
    if designated_taker_id:
        db_task.taker_id = designated_taker_id
        db_task.status = "pending_acceptance"
        db_task.task_source = task_source

    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    if designated_taker_id:
        try:
            create_notification(
                db,
                user_id=designated_taker_id,
                type="task_direct_request",
                title="有用户向你发送了任务请求",
                title_en="You received a task request",
                content=f"「{task.title}」- {'待报价' if reward_to_be_quoted else f'£{task.reward}'}",
                content_en=f'"{task.title}" - {"Price to be quoted" if reward_to_be_quoted else f"£{task.reward}"}',
                related_id=str(db_task.id),
                related_type="task_id",
            )
            try:
                from app.push_notification_service import send_push_notification
                task_title = getattr(db_task, "title_zh", None) or getattr(db_task, "title_en", None) or db_task.title
                reward_text_zh = "（待报价）" if reward_to_be_quoted else f"（£{task.reward}）"
                reward_text_en = "(Price to be quoted)" if reward_to_be_quoted else f"(£{task.reward})"
                send_push_notification(
                    db,
                    user_id=designated_taker_id,
                    title=None,
                    body=None,
                    notification_type="task_direct_request",
                    data={"task_id": str(db_task.id), "type": "task_direct_request"},
                    template_vars={
                        "task_title": task_title,
                        "reward_text_zh": reward_text_zh,
                        "reward_text_en": reward_text_en,
                    },
                )
            except Exception as push_err:
                logger.warning(f"指定任务请求推送失败: {push_err}")
        except Exception as e:
            logger.warning(f"创建指定任务通知失败: {e}")
```

- [ ] **Step 3：跑现有 task crud 测试**

```bash
cd backend && pytest tests/ -k "task" -x -q
```

预期：全部通过。如果有断言"创建指定任务后应存在一条 application"的旧测试，**不要改断言**——把该测试标 `@pytest.mark.skip(reason="deprecated in designated-task-refactor plan T1")`，在 Task 6 统一回收。

- [ ] **Step 4：commit**

```bash
git add backend/app/crud/task.py
git commit -m "refactor(task): remove fake TaskApplication creation for designated tasks"
```

---

## Task 2 — 后端：移除 apply_for_task 的 pending_acceptance 分支

**Files:**
- Modify: `backend/app/async_routers.py:957-978`

- [ ] **Step 1：删除特殊分支**

打开 `backend/app/async_routers.py`，删除第 957-978 行整个 `if task.status == "pending_acceptance":` 分支。原逻辑是"允许被指定用户用 /tasks/{id}/apply 更新伪造 application 的 negotiated_price"——T1 已经去掉伪造 application，这里只保留纯粹的 open 状态申请。

- [ ] **Step 2：跑 apply 相关测试**

```bash
cd backend && pytest tests/ -k "apply" -x -q
```

预期：通过。任何断言"pending_acceptance 任务允许 apply"的测试同 T1 处理方式标 skip。

- [ ] **Step 3：commit**

```bash
git add backend/app/async_routers.py
git commit -m "refactor(task): remove pending_acceptance branch in apply_for_task"
```

---

## Task 3 — 后端：新建 designated_task_routes 文件骨架

**Files:**
- Create: `backend/app/routes/designated_task_routes.py`

- [ ] **Step 1：创建文件**

写入以下骨架（不含业务逻辑，确保能 import）：

```python
"""指定任务请求（accept / reject / withdraw）— 取代原先的伪造 TaskApplication 方案。"""
import json
import logging
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.crud.notification import create_notification
from app.database import get_async_db_dependency
from app.security_auth import get_current_user_secure_async_csrf
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

designated_task_router = APIRouter(tags=["designated_task"])
```

- [ ] **Step 2：注册到 main.py**

打开 `backend/app/main.py`，在已有 router 注册段落附近（搜索 `task_chat_router` 或 `consultation_router`）加一行：

```python
from app.routes.designated_task_routes import designated_task_router
app.include_router(designated_task_router)
```

- [ ] **Step 3：验证可启动**

```bash
cd backend && python -c "from app.main import app; print('ok')"
```

预期输出 `ok`。

- [ ] **Step 4：commit**

```bash
git add backend/app/routes/designated_task_routes.py backend/app/main.py
git commit -m "feat(task): scaffold designated_task_routes module"
```

---

## Task 4 — 后端：accept 端点（被指定用户接受定价任务）

**Files:**
- Modify: `backend/app/routes/designated_task_routes.py`
- Create: `backend/tests/test_designated_task_routes.py`

- [ ] **Step 1：写失败测试**

创建 `backend/tests/test_designated_task_routes.py`：

```python
"""Tests for designated task routes (accept / reject / withdraw)."""
import pytest
from httpx import AsyncClient

# 测试依赖现有 conftest 的 async_client / db_session / create_user / login_user fixtures
# 参考 backend/tests/conftest.py

pytestmark = pytest.mark.asyncio


async def test_accept_designated_fixed_price_task_creates_pending_application(
    async_client: AsyncClient, db_session, make_user, auth_headers, make_task
):
    poster = await make_user()
    taker = await make_user()
    task = await make_task(
        poster_id=poster.id,
        designated_taker_id=taker.id,
        reward=50,
        reward_to_be_quoted=False,
    )
    # 预期：T1 之后，创建任务不产生 TaskApplication
    apps_before = await db_session.execute(
        "SELECT COUNT(*) FROM task_applications WHERE task_id = :tid",
        {"tid": task.id},
    )
    assert apps_before.scalar() == 0

    resp = await async_client.post(
        f"/tasks/{task.id}/designated/accept",
        headers=await auth_headers(taker),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "pending"
    assert body["task_id"] == task.id

    apps_after = await db_session.execute(
        "SELECT status, applicant_id, negotiated_price FROM task_applications WHERE task_id = :tid",
        {"tid": task.id},
    )
    rows = apps_after.all()
    assert len(rows) == 1
    assert rows[0].status == "pending"
    assert str(rows[0].applicant_id) == str(taker.id)
    assert float(rows[0].negotiated_price) == 50.0


async def test_accept_designated_task_rejects_non_taker(
    async_client: AsyncClient, make_user, auth_headers, make_task
):
    poster = await make_user()
    taker = await make_user()
    intruder = await make_user()
    task = await make_task(
        poster_id=poster.id, designated_taker_id=taker.id, reward=50
    )
    resp = await async_client.post(
        f"/tasks/{task.id}/designated/accept",
        headers=await auth_headers(intruder),
    )
    assert resp.status_code == 403


async def test_accept_designated_task_rejects_quote_to_be_determined(
    async_client: AsyncClient, make_user, auth_headers, make_task
):
    poster = await make_user()
    taker = await make_user()
    task = await make_task(
        poster_id=poster.id,
        designated_taker_id=taker.id,
        reward_to_be_quoted=True,
    )
    resp = await async_client.post(
        f"/tasks/{task.id}/designated/accept",
        headers=await auth_headers(taker),
    )
    assert resp.status_code == 400
    assert "待报价" in resp.json()["detail"] or "quote" in resp.json()["detail"].lower()
```

- [ ] **Step 2：运行测试验证失败**

```bash
cd backend && pytest tests/test_designated_task_routes.py -x -v
```

预期：3 个测试全部 FAIL（端点未实现，404）。

- [ ] **Step 3：实现 accept 端点**

在 `backend/app/routes/designated_task_routes.py` 末尾追加：

```python
@designated_task_router.post("/tasks/{task_id}/designated/accept")
async def accept_designated_task(
    task_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """被指定用户接受任务（仅定价任务）。创建 TaskApplication(pending) 并通知发布者去批准并支付。"""
    task_q = await db.execute(select(models.Task).where(models.Task.id == task_id))
    task = task_q.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    if task.status != "pending_acceptance":
        raise HTTPException(status_code=400, detail="任务当前状态不允许此操作")
    if str(task.taker_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="你不是此任务的被指定用户")
    if getattr(task, "reward_to_be_quoted", False):
        raise HTTPException(status_code=400, detail="待报价任务请先通过咨询议价")

    existing_q = await db.execute(
        select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.applicant_id == current_user.id,
            )
        )
    )
    existing = existing_q.scalar_one_or_none()
    if existing and existing.status in ("pending", "approved", "price_agreed"):
        return {
            "task_id": task_id,
            "application_id": existing.id,
            "status": existing.status,
            "is_existing": True,
        }

    now = get_utc_time()
    app_row = models.TaskApplication(
        task_id=task_id,
        applicant_id=current_user.id,
        status="pending",
        negotiated_price=Decimal(str(task.reward)) if task.reward is not None else None,
        currency=task.currency or "GBP",
        message="接受指定任务",
        created_at=now,
    )
    db.add(app_row)
    await db.flush()

    try:
        create_notification(
            db,
            user_id=task.poster_id,
            type="designated_task_accepted",
            title="对方已接受任务",
            title_en="Designated user accepted the task",
            content=f"「{task.title}」对方已接受，请批准并支付以开始任务",
            content_en=f'"{task.title}" — the designated user accepted. Approve & pay to start.',
            related_id=str(task_id),
            related_type="task_id",
        )
    except Exception as e:
        logger.warning(f"designated_task_accepted 通知失败: {e}")

    await db.commit()
    await db.refresh(app_row)
    return {
        "task_id": task_id,
        "application_id": app_row.id,
        "status": app_row.status,
        "is_existing": False,
    }
```

- [ ] **Step 4：运行测试验证通过**

```bash
cd backend && pytest tests/test_designated_task_routes.py -x -v
```

预期：3 个测试全部 PASS。

- [ ] **Step 5：commit**

```bash
git add backend/app/routes/designated_task_routes.py backend/tests/test_designated_task_routes.py
git commit -m "feat(task): add POST /tasks/{id}/designated/accept endpoint"
```

---

## Task 5 — 后端：reject 端点（被指定用户拒绝）

**Files:**
- Modify: `backend/app/routes/designated_task_routes.py`
- Modify: `backend/tests/test_designated_task_routes.py`

- [ ] **Step 1：写失败测试**

追加到 `test_designated_task_routes.py`：

```python
async def test_reject_designated_task_reverts_to_open(
    async_client, db_session, make_user, auth_headers, make_task
):
    poster = await make_user()
    taker = await make_user()
    task = await make_task(
        poster_id=poster.id, designated_taker_id=taker.id, reward=50
    )
    resp = await async_client.post(
        f"/tasks/{task.id}/designated/reject",
        headers=await auth_headers(taker),
    )
    assert resp.status_code == 200

    row = (await db_session.execute(
        "SELECT status, taker_id FROM tasks WHERE id = :tid", {"tid": task.id}
    )).first()
    assert row.status == "open"
    assert row.taker_id is None


async def test_reject_designated_task_marks_consulting_application_rejected(
    async_client, db_session, make_user, auth_headers, make_task, make_application
):
    poster = await make_user()
    taker = await make_user()
    task = await make_task(
        poster_id=poster.id, designated_taker_id=taker.id, reward=50
    )
    app = await make_application(
        task_id=task.id, applicant_id=taker.id, status="consulting"
    )
    resp = await async_client.post(
        f"/tasks/{task.id}/designated/reject",
        headers=await auth_headers(taker),
    )
    assert resp.status_code == 200

    app_row = (await db_session.execute(
        "SELECT status FROM task_applications WHERE id = :aid", {"aid": app.id}
    )).first()
    assert app_row.status == "rejected"


async def test_reject_designated_task_rejects_non_taker(
    async_client, make_user, auth_headers, make_task
):
    poster = await make_user()
    taker = await make_user()
    intruder = await make_user()
    task = await make_task(
        poster_id=poster.id, designated_taker_id=taker.id
    )
    resp = await async_client.post(
        f"/tasks/{task.id}/designated/reject",
        headers=await auth_headers(intruder),
    )
    assert resp.status_code == 403
```

- [ ] **Step 2：运行测试验证失败**

```bash
cd backend && pytest tests/test_designated_task_routes.py::test_reject_designated_task_reverts_to_open -x -v
```

预期：FAIL（端点未实现）。

- [ ] **Step 3：实现 reject 端点**

追加到 `backend/app/routes/designated_task_routes.py`：

```python
@designated_task_router.post("/tasks/{task_id}/designated/reject")
async def reject_designated_task(
    task_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """被指定用户拒绝任务。task 回退为 open，taker_id 清空；该用户相关 application 标 rejected。"""
    task_q = await db.execute(select(models.Task).where(models.Task.id == task_id))
    task = task_q.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    if task.status != "pending_acceptance":
        raise HTTPException(status_code=400, detail="任务当前状态不允许此操作")
    if str(task.taker_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="你不是此任务的被指定用户")

    poster_id = task.poster_id
    task_title = task.title

    # 回退 task
    task.status = "open"
    task.taker_id = None

    # 把该用户在此任务上的 consulting/negotiating/pending application 标为 rejected
    apps_q = await db.execute(
        select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.applicant_id == current_user.id,
                models.TaskApplication.status.in_(
                    ["consulting", "negotiating", "price_agreed", "pending"]
                ),
            )
        )
    )
    for app_row in apps_q.scalars().all():
        app_row.status = "rejected"

    try:
        create_notification(
            db,
            user_id=poster_id,
            type="designated_task_rejected",
            title="对方已拒绝任务请求",
            title_en="Designated user declined the task",
            content=f"「{task_title}」对方已拒绝，任务已公开发布",
            content_en=f'"{task_title}" — declined. Task is now public.',
            related_id=str(task_id),
            related_type="task_id",
        )
    except Exception as e:
        logger.warning(f"designated_task_rejected 通知失败: {e}")

    await db.commit()
    return {"task_id": task_id, "status": "open"}
```

- [ ] **Step 4：运行测试验证通过**

```bash
cd backend && pytest tests/test_designated_task_routes.py -x -v
```

预期：全部通过（6 个测试）。

- [ ] **Step 5：commit**

```bash
git add backend/app/routes/designated_task_routes.py backend/tests/test_designated_task_routes.py
git commit -m "feat(task): add POST /tasks/{id}/designated/reject endpoint"
```

---

## Task 6 — 后端：withdraw 端点（发布者撤回）

**Files:**
- Modify: `backend/app/routes/designated_task_routes.py`
- Modify: `backend/tests/test_designated_task_routes.py`

- [ ] **Step 1：写失败测试**

追加：

```python
async def test_withdraw_designated_request_by_poster(
    async_client, db_session, make_user, auth_headers, make_task
):
    poster = await make_user()
    taker = await make_user()
    task = await make_task(
        poster_id=poster.id, designated_taker_id=taker.id, reward=50
    )
    resp = await async_client.post(
        f"/tasks/{task.id}/designated/withdraw",
        headers=await auth_headers(poster),
    )
    assert resp.status_code == 200

    row = (await db_session.execute(
        "SELECT status, taker_id FROM tasks WHERE id = :tid", {"tid": task.id}
    )).first()
    assert row.status == "open"
    assert row.taker_id is None


async def test_withdraw_cancels_all_related_applications(
    async_client, db_session, make_user, auth_headers, make_task, make_application
):
    poster = await make_user()
    taker = await make_user()
    task = await make_task(
        poster_id=poster.id, designated_taker_id=taker.id, reward=50
    )
    app = await make_application(
        task_id=task.id, applicant_id=taker.id, status="consulting"
    )
    resp = await async_client.post(
        f"/tasks/{task.id}/designated/withdraw",
        headers=await auth_headers(poster),
    )
    assert resp.status_code == 200
    app_row = (await db_session.execute(
        "SELECT status FROM task_applications WHERE id = :aid", {"aid": app.id}
    )).first()
    assert app_row.status == "cancelled"


async def test_withdraw_rejects_non_poster(
    async_client, make_user, auth_headers, make_task
):
    poster = await make_user()
    taker = await make_user()
    task = await make_task(poster_id=poster.id, designated_taker_id=taker.id)
    resp = await async_client.post(
        f"/tasks/{task.id}/designated/withdraw",
        headers=await auth_headers(taker),
    )
    assert resp.status_code == 403
```

- [ ] **Step 2：运行测试验证失败**

```bash
cd backend && pytest tests/test_designated_task_routes.py -x -v -k withdraw
```

预期：FAIL。

- [ ] **Step 3：实现 withdraw 端点**

追加到 `backend/app/routes/designated_task_routes.py`：

```python
@designated_task_router.post("/tasks/{task_id}/designated/withdraw")
async def withdraw_designated_request(
    task_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """发布者撤回指定任务请求。task 回退为 open，taker_id 清空；所有相关 application 标 cancelled。"""
    task_q = await db.execute(select(models.Task).where(models.Task.id == task_id))
    task = task_q.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    if task.status != "pending_acceptance":
        raise HTTPException(status_code=400, detail="任务当前状态不允许撤回")
    if str(task.poster_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="只有发布者可以撤回")

    original_taker_id = task.taker_id
    task_title = task.title

    task.status = "open"
    task.taker_id = None

    apps_q = await db.execute(
        select(models.TaskApplication).where(
            and_(
                models.TaskApplication.task_id == task_id,
                models.TaskApplication.status.in_(
                    ["consulting", "negotiating", "price_agreed", "pending"]
                ),
            )
        )
    )
    for app_row in apps_q.scalars().all():
        app_row.status = "cancelled"

    if original_taker_id:
        try:
            create_notification(
                db,
                user_id=original_taker_id,
                type="designated_task_withdrawn",
                title="对方已撤回任务请求",
                title_en="The task request was withdrawn",
                content=f"「{task_title}」发布者已撤回任务请求",
                content_en=f'"{task_title}" — the poster withdrew the request.',
                related_id=str(task_id),
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"designated_task_withdrawn 通知失败: {e}")

    await db.commit()
    return {"task_id": task_id, "status": "open"}
```

- [ ] **Step 4：全量跑 designated 测试**

```bash
cd backend && pytest tests/test_designated_task_routes.py -x -v
```

预期：9 个测试全部通过。

- [ ] **Step 5：commit**

```bash
git add backend/app/routes/designated_task_routes.py backend/tests/test_designated_task_routes.py
git commit -m "feat(task): add POST /tasks/{id}/designated/withdraw endpoint"
```

---

## Task 7 — 后端：数据清理 migration

**Files:**
- Create: `backend/migrations/201_cleanup_designated_fake_applications.sql`

> 约定：本仓库用编号 SQL 做迁移（见 memory `feedback_db_migration`），不走 Alembic 自动生成。查 `backend/migrations/` 下最新编号，递增 1（这里假定 201，执行时以实际最新为准）。

- [ ] **Step 1：确认最新 migration 编号**

```bash
ls backend/migrations/ | grep -E '^[0-9]+_' | sort -n | tail -5
```

记下最新编号（记作 N），本任务文件名 `{N+1}_cleanup_designated_fake_applications.sql`。

- [ ] **Step 2：写 SQL**

创建 `backend/migrations/{N+1}_cleanup_designated_fake_applications.sql`：

```sql
-- 清理 designated-task-refactor 前遗留的伪造 TaskApplication
-- 规则：task.status='pending_acceptance' 且 application.applicant_id=task.taker_id
--       且 application.message='来自用户资料页的任务请求' 且 status='pending'
-- 这些是 crud/task.py 老版本创建的伪造申请，重构后不再需要

BEGIN;

DELETE FROM task_applications
WHERE id IN (
  SELECT ta.id
  FROM task_applications ta
  JOIN tasks t ON ta.task_id = t.id
  WHERE t.status = 'pending_acceptance'
    AND ta.status = 'pending'
    AND ta.message = '来自用户资料页的任务请求'
    AND ta.applicant_id = t.taker_id
);

COMMIT;
```

- [ ] **Step 3：dry-run 查一下预期影响行数**

在 staging/dev 数据库执行：

```sql
SELECT COUNT(*) FROM task_applications ta
JOIN tasks t ON ta.task_id = t.id
WHERE t.status = 'pending_acceptance'
  AND ta.status = 'pending'
  AND ta.message = '来自用户资料页的任务请求'
  AND ta.applicant_id = t.taker_id;
```

记录数字。如果 >50，先人工抽查几条确认无误再跑正式 migration。

- [ ] **Step 4：commit**

```bash
git add backend/migrations/
git commit -m "chore(db): cleanup legacy fake designated-task applications"
```

---

## Task 8 — Flutter：API endpoints 常量 + Repository 方法

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`
- Modify: `link2ur/lib/data/repositories/task_repository.dart`

- [ ] **Step 1：添加端点常量**

在 `api_endpoints.dart` 里任务相关段落追加 3 行：

```dart
static String designatedTaskAccept(int taskId) => '/tasks/$taskId/designated/accept';
static String designatedTaskReject(int taskId) => '/tasks/$taskId/designated/reject';
static String designatedTaskWithdraw(int taskId) => '/tasks/$taskId/designated/withdraw';
```

- [ ] **Step 2：repository 新增 3 个方法**

在 `TaskRepository` 类里追加：

```dart
Future<Map<String, dynamic>> acceptDesignatedTask(int taskId) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.designatedTaskAccept(taskId),
  );
  if (!response.isSuccess || response.data == null) {
    throw Exception(response.message ?? 'designated_accept_failed');
  }
  return response.data!;
}

Future<Map<String, dynamic>> rejectDesignatedTask(int taskId) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.designatedTaskReject(taskId),
  );
  if (!response.isSuccess || response.data == null) {
    throw Exception(response.message ?? 'designated_reject_failed');
  }
  return response.data!;
}

Future<Map<String, dynamic>> withdrawDesignatedRequest(int taskId) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.designatedTaskWithdraw(taskId),
  );
  if (!response.isSuccess || response.data == null) {
    throw Exception(response.message ?? 'designated_withdraw_failed');
  }
  return response.data!;
}
```

- [ ] **Step 3：flutter analyze**

```bash
cd link2ur && $env:PATH="F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE="F:\DevCache\.pub-cache"; flutter analyze lib/data/repositories/task_repository.dart lib/core/constants/api_endpoints.dart
```

预期：No issues found.

- [ ] **Step 4：commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/task_repository.dart
git commit -m "feat(flutter): add designated task repository methods"
```

---

## Task 9 — Flutter：Bloc 事件 + 处理器

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_event.dart`
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

- [ ] **Step 1：写失败测试**

创建 `link2ur/test/features/tasks/designated_task_flow_test.dart`：

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/features/tasks/bloc/task_detail_bloc.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  group('Designated task flow', () {
    late _MockTaskRepository repo;

    setUp(() {
      repo = _MockTaskRepository();
    });

    blocTest<TaskDetailBloc, TaskDetailState>(
      'acceptDesignatedTask calls repository.acceptDesignatedTask',
      build: () {
        when(() => repo.acceptDesignatedTask(any()))
            .thenAnswer((_) async => {'application_id': 1, 'status': 'pending'});
        return TaskDetailBloc(taskRepository: repo, taskId: 42);
      },
      act: (bloc) => bloc.add(const TaskDetailAcceptDesignatedRequested()),
      verify: (_) => verify(() => repo.acceptDesignatedTask(42)).called(1),
    );

    blocTest<TaskDetailBloc, TaskDetailState>(
      'rejectDesignatedTask calls repository.rejectDesignatedTask',
      build: () {
        when(() => repo.rejectDesignatedTask(any()))
            .thenAnswer((_) async => {'status': 'open'});
        return TaskDetailBloc(taskRepository: repo, taskId: 42);
      },
      act: (bloc) => bloc.add(const TaskDetailRejectDesignatedRequested()),
      verify: (_) => verify(() => repo.rejectDesignatedTask(42)).called(1),
    );

    blocTest<TaskDetailBloc, TaskDetailState>(
      'withdrawDesignatedRequest calls repository.withdrawDesignatedRequest',
      build: () {
        when(() => repo.withdrawDesignatedRequest(any()))
            .thenAnswer((_) async => {'status': 'open'});
        return TaskDetailBloc(taskRepository: repo, taskId: 42);
      },
      act: (bloc) => bloc.add(const TaskDetailWithdrawDesignatedRequested()),
      verify: (_) => verify(() => repo.withdrawDesignatedRequest(42)).called(1),
    );
  });
}
```

- [ ] **Step 2：运行测试验证失败（事件类未定义）**

```bash
cd link2ur && $env:PATH="F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE="F:\DevCache\.pub-cache"; flutter test test/features/tasks/designated_task_flow_test.dart
```

预期：编译失败（`TaskDetailAcceptDesignatedRequested` 等未定义）。

- [ ] **Step 3：定义事件**

在 `task_detail_event.dart` 末尾追加：

```dart
class TaskDetailAcceptDesignatedRequested extends TaskDetailEvent {
  const TaskDetailAcceptDesignatedRequested();
  @override
  List<Object?> get props => [];
}

class TaskDetailRejectDesignatedRequested extends TaskDetailEvent {
  const TaskDetailRejectDesignatedRequested();
  @override
  List<Object?> get props => [];
}

class TaskDetailWithdrawDesignatedRequested extends TaskDetailEvent {
  const TaskDetailWithdrawDesignatedRequested();
  @override
  List<Object?> get props => [];
}
```

- [ ] **Step 4：在 Bloc 构造器中注册 3 个 handler**

在 `task_detail_bloc.dart` 构造器内（和其它 `on<...>` 在一起）加：

```dart
on<TaskDetailAcceptDesignatedRequested>(_onAcceptDesignated);
on<TaskDetailRejectDesignatedRequested>(_onRejectDesignated);
on<TaskDetailWithdrawDesignatedRequested>(_onWithdrawDesignated);
```

在类末尾追加方法：

```dart
Future<void> _onAcceptDesignated(
  TaskDetailAcceptDesignatedRequested event,
  Emitter<TaskDetailState> emit,
) async {
  if (_taskId == null) return;
  emit(state.copyWith(isActionLoading: true));
  try {
    await _taskRepository.acceptDesignatedTask(_taskId!);
    emit(state.copyWith(
      isActionLoading: false,
      actionMessage: 'designated_accepted',
    ));
    add(const TaskDetailLoadRequested());
  } catch (e) {
    emit(state.copyWith(
      isActionLoading: false,
      errorMessage: 'designated_accept_failed',
    ));
  }
}

Future<void> _onRejectDesignated(
  TaskDetailRejectDesignatedRequested event,
  Emitter<TaskDetailState> emit,
) async {
  if (_taskId == null) return;
  emit(state.copyWith(isActionLoading: true));
  try {
    await _taskRepository.rejectDesignatedTask(_taskId!);
    emit(state.copyWith(
      isActionLoading: false,
      actionMessage: 'designated_rejected',
    ));
    add(const TaskDetailLoadRequested());
  } catch (e) {
    emit(state.copyWith(
      isActionLoading: false,
      errorMessage: 'designated_reject_failed',
    ));
  }
}

Future<void> _onWithdrawDesignated(
  TaskDetailWithdrawDesignatedRequested event,
  Emitter<TaskDetailState> emit,
) async {
  if (_taskId == null) return;
  emit(state.copyWith(isActionLoading: true));
  try {
    await _taskRepository.withdrawDesignatedRequest(_taskId!);
    emit(state.copyWith(
      isActionLoading: false,
      actionMessage: 'designated_withdrawn',
    ));
    add(const TaskDetailLoadRequested());
  } catch (e) {
    emit(state.copyWith(
      isActionLoading: false,
      errorMessage: 'designated_withdraw_failed',
    ));
  }
}
```

- [ ] **Step 5：运行测试验证通过**

```bash
cd link2ur && flutter test test/features/tasks/designated_task_flow_test.dart
```

预期：3 个测试全部 PASS。

- [ ] **Step 6：commit**

```bash
git add link2ur/lib/features/tasks/bloc link2ur/test/features/tasks/designated_task_flow_test.dart
git commit -m "feat(flutter): add designated task bloc events + handlers"
```

---

## Task 10 — Flutter：l10n 文案

**Files:**
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`
- Modify: `link2ur/lib/l10n/app_en.arb`

- [ ] **Step 1：追加 key**

每个 arb 文件新增 6 个 key（保持现有格式）：

**app_zh.arb**
```json
"taskDetailDesignatedWaitingBanner": "等待对方接受任务请求",
"taskDetailDesignatedWithdraw": "撤回请求",
"taskDetailDesignatedWithdrawConfirmTitle": "撤回任务请求？",
"taskDetailDesignatedWithdrawConfirmMessage": "撤回后任务将公开发布，其他用户也可以申请。",
"taskDetailDesignatedAccept": "接受",
"taskDetailDesignatedConsult": "咨询"
```

**app_en.arb**
```json
"taskDetailDesignatedWaitingBanner": "Waiting for the designated user to respond",
"taskDetailDesignatedWithdraw": "Withdraw request",
"taskDetailDesignatedWithdrawConfirmTitle": "Withdraw task request?",
"taskDetailDesignatedWithdrawConfirmMessage": "After withdrawal the task becomes public and anyone can apply.",
"taskDetailDesignatedAccept": "Accept",
"taskDetailDesignatedConsult": "Consult"
```

**app_zh_Hant.arb**
```json
"taskDetailDesignatedWaitingBanner": "等待對方接受任務請求",
"taskDetailDesignatedWithdraw": "撤回請求",
"taskDetailDesignatedWithdrawConfirmTitle": "撤回任務請求？",
"taskDetailDesignatedWithdrawConfirmMessage": "撤回後任務將公開發佈，其他用戶也可以申請。",
"taskDetailDesignatedAccept": "接受",
"taskDetailDesignatedConsult": "諮詢"
```

- [ ] **Step 2：生成 localization 代码**

```bash
cd link2ur && $env:PATH="F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE="F:\DevCache\.pub-cache"; flutter gen-l10n
```

预期：无错误。

- [ ] **Step 3：commit**

```bash
git add link2ur/lib/l10n
git commit -m "i18n: add designated task action strings"
```

---

## Task 11 — Flutter：任务详情页按钮布局重构

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart:1026-1088`

- [ ] **Step 1：读当前实现范围**

打开 `task_detail_view.dart`，定位被指定用户 pending_acceptance 分支（L1026 `if (isTaker && task.status == AppConstants.taskStatusPendingAcceptance)` 起始到 L1089 结束）。

- [ ] **Step 2：替换被指定用户分支**

把 L1026-1089 的整个 `if (isTaker && task.status == ...)` 块替换为：

```dart
// 指定任务接单方 + 待接受 — 新版：定价=接受/拒绝/咨询；待报价=咨询/拒绝
if (isTaker && task.status == AppConstants.taskStatusPendingAcceptance) {
  final isQuoteTBD = task.rewardToBeQuoted;
  final consultBtn = Expanded(
    child: OutlinedButton(
      onPressed: () => _openConsultChat(context, task),
      child: Text(context.l10n.taskDetailDesignatedConsult),
    ),
  );
  final rejectBtn = Expanded(
    child: OutlinedButton(
      onPressed: () => _showDeclineDesignatedTaskConfirm(context),
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
      child: Text(context.l10n.taskDetailDeclineDesignated),
    ),
  );
  if (isQuoteTBD) {
    return Row(children: [rejectBtn, AppSpacing.hSm, consultBtn]);
  }
  final acceptBtn = Expanded(
    child: PrimaryButton(
      text: context.l10n.taskDetailDesignatedAccept,
      onPressed: () {
        context.read<TaskDetailBloc>().add(
          const TaskDetailAcceptDesignatedRequested(),
        );
      },
    ),
  );
  return Row(children: [rejectBtn, AppSpacing.hSm, consultBtn, AppSpacing.hSm, acceptBtn]);
}
```

- [ ] **Step 3：修改 `_showDeclineDesignatedTaskConfirm` 内部调用**

找到同文件里 `_showDeclineDesignatedTaskConfirm` 方法，把它里面原先 `TaskDetailCancelApplicationRequested()` 调用替换为：

```dart
context.read<TaskDetailBloc>().add(const TaskDetailRejectDesignatedRequested());
```

- [ ] **Step 4：新增 `_openConsultChat` helper**

在同文件里添加：

```dart
void _openConsultChat(BuildContext context, Task task) async {
  final bloc = context.read<TaskDetailBloc>();
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final app = await bloc.startConsultation();
    if (app == null) return;
    router.push('/tasks/${task.id}/applications/${app['application_id']}/chat');
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(context.localizeError('designated_consult_failed')),
    ));
  }
}
```

注意：`bloc.startConsultation()` 如果 TaskDetailBloc 还没有，则需要补一个薄方法调用 `task_chat_routes.py` 的 `POST /tasks/{id}/consult`。如果项目已有现成入口（搜索 `consult` 或 `/consult`），优先复用，不要重复实现。

- [ ] **Step 5：flutter analyze**

```bash
cd link2ur && flutter analyze lib/features/tasks/views/task_detail_view.dart
```

预期：No issues found. 如果有警告是"unused_element 旧的 `_showQuoteDesignatedPriceSheet` / `_showCounterOfferSheet`"，记下，在 Task 13 清理。

- [ ] **Step 6：commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat(flutter): rewire designated taker buttons (accept/reject/consult)"
```

---

## Task 12 — Flutter：发布者状态条 + 撤回按钮

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart:971-990`

- [ ] **Step 1：修改发布者分支**

把 L971-990 的发布者 `pending_acceptance` 分支替换为：

```dart
// 发布者 + pending_acceptance
if (isPoster && task.status == AppConstants.taskStatusPendingAcceptance) {
  final designatedApp = state.applications.cast<TaskApplication?>().firstWhere(
    (a) => a!.applicantId == task.takerId && (a.isPending || a.status == 'price_agreed'),
    orElse: () => null,
  );
  if (designatedApp != null) {
    // 对方已接受或议价达成 → 批准并支付（保留原有行为）
    return PrimaryButton(
      text: context.l10n.taskDetailApproveAndPay,
      icon: Icons.credit_card,
      onPressed: () {
        context.read<TaskDetailBloc>().add(
          TaskDetailAcceptApplicant(designatedApp.id),
        );
      },
    );
  }
  // 未接受 → 等待状态条 + 撤回按钮
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: AppColors.primary, size: 18),
            AppSpacing.hSm,
            Expanded(
              child: Text(
                context.l10n.taskDetailDesignatedWaitingBanner,
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      AppSpacing.vSm,
      OutlinedButton(
        onPressed: () => _showWithdrawDesignatedConfirm(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          minimumSize: const Size.fromHeight(44),
        ),
        child: Text(context.l10n.taskDetailDesignatedWithdraw),
      ),
    ],
  );
}
```

- [ ] **Step 2：新增 `_showWithdrawDesignatedConfirm`**

在同文件追加：

```dart
void _showWithdrawDesignatedConfirm(BuildContext context) {
  final bloc = context.read<TaskDetailBloc>();
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(context.l10n.taskDetailDesignatedWithdrawConfirmTitle),
      content: Text(context.l10n.taskDetailDesignatedWithdrawConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogCtx);
            bloc.add(const TaskDetailWithdrawDesignatedRequested());
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(context.l10n.taskDetailDesignatedWithdraw),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3：flutter analyze + 启动 app 冒烟**

```bash
cd link2ur && flutter analyze lib/features/tasks/views/task_detail_view.dart
```

手动冒烟测试：
1. 用户 A 给 B 发布定价指定任务 → A 打开任务 → 看到"等待接受"+"撤回"
2. B 打开任务 → 看到"拒绝 / 咨询 / 接受"
3. B 点接受 → A 刷新看到"批准并支付"
4. B 点咨询 → 进入聊天
5. B 点拒绝 → 任务回退到 open，A 收到通知
6. 重复 1，A 点撤回 → 任务回 open，B 收到通知
7. 重复 1，但任务为"待报价" → B 只看到"拒绝 / 咨询"（无"接受"）

- [ ] **Step 4：commit**

```bash
git add link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "feat(flutter): add poster waiting banner + withdraw button"
```

---

## Task 13 — 清理死代码

**Files:**
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart`
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart`

被 T2 + T11 绕过后，以下元素可能已成为死代码（但"反报价/议价"路径可能还被 `TaskDetailRespondCounterOfferRequested`（议价通知落地页）使用——**先用 grep 验证，不要盲删**）：

- `_showQuoteDesignatedPriceSheet`（T11 中被替换掉的"提交报价"）
- `_showCounterOfferSheet`（三按钮里的"反报价"）
- `TaskDetailQuoteDesignatedPriceRequested` 事件
- Bloc `_onQuoteDesignatedPrice` 方法

- [ ] **Step 1：grep 验证死代码**

```bash
grep -rn "_showQuoteDesignatedPriceSheet\|_showCounterOfferSheet\|TaskDetailQuoteDesignatedPriceRequested\|_onQuoteDesignatedPrice" link2ur/lib link2ur/test
```

只有声明点没有其它 caller → 安全删除。**如果还有调用方（比如议价通知落地页依然用）**，保留不动，跳到 Step 3。

- [ ] **Step 2：删除死代码**

按 grep 结果删除对应 method / event / handler。连带删除只用于这些的 import。

- [ ] **Step 3：flutter analyze + 全量测试**

```bash
cd link2ur && flutter analyze && flutter test
```

预期：No issues found + 所有测试通过。

- [ ] **Step 4：后端回收 Step 3 中标 skip 的测试**

检查 T1/T2 里标过 `@pytest.mark.skip(reason="deprecated in designated-task-refactor plan T1")` 的测试。判断：

- 如果测试断言的是"伪造 application 创建"本身 → 删除该测试
- 如果测试断言的是"apply_for_task 在 pending_acceptance 下更新 app" → 删除该测试
- 如果是其它附带断言 → 改断言为新行为

- [ ] **Step 5：commit**

```bash
git add -u
git commit -m "chore: remove dead code from designated task refactor"
```

---

## Task 14 — 集成冒烟 + 跨层验证

**Files:** —

- [ ] **Step 1：执行 full-stack-consistency-check**

按项目根 `CLAUDE.md` 引用的 `~/.claude/skills/full-stack-consistency-check/SKILL.md` 清单逐项验证：DB → Backend Model → Pydantic Schema → API Route → Frontend Endpoint → Repository → Model.fromJson → BLoC → UI。

重点核对：

1. **没有 pydantic schema 变动**（端点用 inline dict 返回，无需新 schema）
2. **前后端端点字符串完全一致**：`/tasks/{id}/designated/accept|reject|withdraw`
3. **通知 type 字符串**：`designated_task_accepted / designated_task_rejected / designated_task_withdrawn / task_direct_request` 在 Flutter 端 `notification_list_view.dart` 跳转逻辑里被识别（`type.startsWith('task_')` 或 `type.startsWith('designated_')`——**如果前缀规则不覆盖，补一条 case**）。

- [ ] **Step 2：后端全量测试**

```bash
cd backend && pytest -x -q
```

预期：全绿。

- [ ] **Step 3：Flutter 全量测试 + analyze**

```bash
cd link2ur && flutter analyze && flutter test
```

预期：No issues found + 全绿。

- [ ] **Step 4：人工端到端场景（staging）**

部署到 staging 后跑 T12 Step 3 的 7 个场景。全部通过。

- [ ] **Step 5：最终 commit（如果 Step 1 补了通知跳转 case）**

```bash
git add -u
git commit -m "chore: wire designated task notification routing"
```

---

## 自检清单

- [x] **需求覆盖**
  - 删除伪造 application → T1
  - 新增 3 个端点（accept/reject/withdraw） → T3-T6
  - 移除 apply_for_task 特殊分支 → T2
  - 数据清理 → T7
  - Flutter 按钮重构（定价 + 待报价两套） → T11
  - 发布者等待条 + 撤回 → T12
  - Bloc 事件 → T9
  - l10n → T10
  - 死代码清理 → T13
  - 全链路验证 → T14

- [x] **无 placeholder**：每步给了具体代码、命令、预期输出

- [x] **类型一致性**：`TaskDetailAcceptDesignatedRequested` / `TaskDetailRejectDesignatedRequested` / `TaskDetailWithdrawDesignatedRequested` 事件名 T9 定义、T11/T12 使用，一致；repository 方法名 `acceptDesignatedTask / rejectDesignatedTask / withdrawDesignatedRequest` T8 定义、T9 使用，一致；端点字符串 T3-T6 + T8 + T14 Step 1 三处完全一致。

- [ ] **待人工确认**：
  - Task 11 Step 4 中的 `_openConsultChat` 需要 `TaskDetailBloc.startConsultation()`——实施时先查是否已存在咨询入口的现有方法，如果有复用，如果没有需要补一个小 action。执行时如发现需新增，在 T11 内插入一个小步。
  - Task 13 Step 4 中关于测试回收的判断需要实施者看实际测试内容决定。
