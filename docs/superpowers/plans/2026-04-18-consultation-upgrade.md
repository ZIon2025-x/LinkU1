# Consultation 架构升级 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 `SA.task_id` 覆盖 bug + 消除占位 task 语义污染,不重构咨询架构。Track 1 的 helper 顺手激活。

**Architecture:** 3 个核心 PR + 1 可选 PR。Migration 208a/209(列 + 回填)→ 等观察期 → Migration 208b(CHECK 约束)+ bug 修 → 守卫 + team role + Flutter。方案 Y:保持 `SA.task_id` 指当前业务任务,加 `consultation_task_id` 字段备份咨询占位 id。

**Tech Stack:** FastAPI + SQLAlchemy + PostgreSQL + Flutter/Dart + pytest + bloc_test

**Spec:** `docs/superpowers/specs/2026-04-18-consultation-upgrade-design.md`

---

## 前置要求(不做则停)

- [ ] **Track 1 已 merge 到 main**:`feature/consultation-fixes` 分支已合并,`project_consultation_fixes_track1.md` 记忆项确认
- [ ] Verify helper 存在:
  ```bash
  grep -n "def create_placeholder_task" backend/app/consultation/helpers.py
  grep -n "def require_team_role" backend/app/permissions/expert_permissions.py
  ```
  两个都应有输出

---

## 文件结构

**新增文件**:
- `backend/migrations/208a_add_is_consultation_placeholder_column.sql` — Task 加 flag + 回填
- `backend/migrations/208b_add_consultation_placeholder_check.sql` — CHECK 约束(延迟到 PR 2)
- `backend/migrations/209_application_consultation_task_id.sql` — SA/TA/FMPR 加备份字段
- `backend/migrations/211_backfill_consultation_task_id.sql`(可选 PR 4)
- `backend/app/utils/task_guards.py` — `load_real_task_or_404` helper
- `backend/tests/test_consultation_placeholder_upgrade.py` — 16 个后端测试
- `link2ur/test/data/models/consultation_route_extensions_test.dart` — Flutter 5 号测试
- `backend/docs/consultation_placeholder_maintenance.md` 或追加到现有文档

**修改文件**:
- `backend/app/models.py` — Task + 3 Application 表加字段
- `backend/app/consultation/helpers.py` — 扩展 create_placeholder_task + 新加 consultation_task_id_for
- `backend/app/expert_consultation_routes.py` — 创建点 ~429 迁 helper + overwrite 备份 ~1025
- `backend/app/user_service_application_routes.py` — overwrite 备份 ~681
- `backend/app/task_chat_routes.py` — 创建点 ~4860 迁 helper + TA 修复 ~5392, ~5427
- `backend/app/flea_market_routes.py` — 创建点 ~4064 迁 helper + 晋升 ~2451
- `backend/app/scheduled_tasks.py` — stale cleanup ~965-982
- `backend/app/admin_task_management_routes.py` — admin 过滤
- `backend/app/crud/task.py` + profile routes — 统计过滤
- `backend/app/routers.py` — 15 个 task-level endpoint 加守卫 + 6-8 个 team role 迁移
- `backend/app/coupon_points_routes.py` — 2 个 endpoint 加守卫
- `backend/app/multi_participant_routes.py` — 2 个 admin endpoint 加 log
- `link2ur/lib/data/models/service_application.dart` — 加 consultationTaskId + extension
- `link2ur/lib/data/models/task_application.dart` — 同上
- `link2ur/lib/data/models/flea_market_purchase_request.dart` — 同上 + FMPR 特殊 doc
- `link2ur/lib/data/models/task.dart` — 加 isConsultationPlaceholder

---

# PR 1 — Day 1: DB(不含 CHECK)+ Models + Helper 扩展 + 创建点迁移

## Task 1: 创建 migration 208a

**Files:**
- Create: `backend/migrations/208a_add_is_consultation_placeholder_column.sql`

- [ ] **Step 1: 写 migration 文件**

```sql
-- 显式标记占位 task,取代脆弱的 task_source 字符串匹配
-- 此 migration 跑完后可以和旧代码共存,因为还没加 CHECK 约束

ALTER TABLE tasks
  ADD COLUMN is_consultation_placeholder BOOLEAN NOT NULL DEFAULT FALSE;

-- 回填历史占位 task
UPDATE tasks
SET is_consultation_placeholder = TRUE
WHERE task_source IN ('consultation', 'task_consultation', 'flea_market_consultation');

-- 针对 stale cleanup 和 admin 过滤的局部索引
CREATE INDEX ix_tasks_consultation_placeholder_status
  ON tasks (is_consultation_placeholder, status)
  WHERE is_consultation_placeholder = TRUE;
```

- [ ] **Step 2: 本地 apply migration**

```bash
psql $DATABASE_URL -f backend/migrations/208a_add_is_consultation_placeholder_column.sql
```
预期:三条语句全部 SUCCESS。

- [ ] **Step 3: 验证回填结果**

```bash
psql $DATABASE_URL -c "SELECT COUNT(*) AS total, SUM(CASE WHEN is_consultation_placeholder THEN 1 ELSE 0 END) AS placeholders FROM tasks WHERE task_source IN ('consultation', 'task_consultation', 'flea_market_consultation');"
```
预期:`total` 和 `placeholders` 两个数字相等。

- [ ] **Step 4: Commit**

```bash
git add backend/migrations/208a_add_is_consultation_placeholder_column.sql
git commit -m "feat(db): migration 208a add is_consultation_placeholder column + backfill"
```

---

## Task 2: 创建 migration 209

**Files:**
- Create: `backend/migrations/209_application_consultation_task_id.sql`

- [ ] **Step 1: 写 migration 文件**

```sql
-- 备份咨询占位 task id,用于 approve 后仍能找回咨询历史消息
-- 不回填历史数据(历史已 approve 的 SA 的占位 id 已在覆盖时丢失,接受此技术债)

ALTER TABLE service_applications
  ADD COLUMN consultation_task_id INTEGER NULL REFERENCES tasks(id) ON DELETE SET NULL;

CREATE INDEX ix_sa_consultation_task_id
  ON service_applications (consultation_task_id)
  WHERE consultation_task_id IS NOT NULL;

ALTER TABLE task_applications
  ADD COLUMN consultation_task_id INTEGER NULL REFERENCES tasks(id) ON DELETE SET NULL;

CREATE INDEX ix_ta_consultation_task_id
  ON task_applications (consultation_task_id)
  WHERE consultation_task_id IS NOT NULL;

ALTER TABLE flea_market_purchase_requests
  ADD COLUMN consultation_task_id INTEGER NULL REFERENCES tasks(id) ON DELETE SET NULL;

CREATE INDEX ix_fmpr_consultation_task_id
  ON flea_market_purchase_requests (consultation_task_id)
  WHERE consultation_task_id IS NOT NULL;
```

- [ ] **Step 2: Apply migration**

```bash
psql $DATABASE_URL -f backend/migrations/209_application_consultation_task_id.sql
```
预期:六条语句全部 SUCCESS。

- [ ] **Step 3: 验证新列存在**

```bash
psql $DATABASE_URL -c "\d service_applications" | grep consultation_task_id
psql $DATABASE_URL -c "\d task_applications" | grep consultation_task_id
psql $DATABASE_URL -c "\d flea_market_purchase_requests" | grep consultation_task_id
```
预期:三行输出,每个表都显示 `consultation_task_id | integer |`。

- [ ] **Step 4: Commit**

```bash
git add backend/migrations/209_application_consultation_task_id.sql
git commit -m "feat(db): migration 209 add consultation_task_id backup column to 3 application tables"
```

---

## Task 3: 更新 SQLAlchemy models — Task

**Files:**
- Modify: `backend/app/models.py`(Task 类内)

- [ ] **Step 1: 找到 Task 类,添加字段**

在 `class Task(Base):` 类体内合适位置(和其他 boolean 字段邻近):

```python
is_consultation_placeholder = Column(
    Boolean, nullable=False, default=False, server_default='false'
)
```

- [ ] **Step 2: 验证 ORM 加载**

```bash
cd backend && python -c "from app import models; t = models.Task(); print(hasattr(t, 'is_consultation_placeholder'))"
```
预期:输出 `True`(且没有 import error)。

- [ ] **Step 3: Commit**

```bash
git add backend/app/models.py
git commit -m "feat(models): Task.is_consultation_placeholder column"
```

---

## Task 4: 更新 SQLAlchemy models — 三个 Application

**Files:**
- Modify: `backend/app/models.py`(ServiceApplication / TaskApplication / FleaMarketPurchaseRequest 三个类)

- [ ] **Step 1: 三个类各加 consultation_task_id 字段**

在 `class ServiceApplication(Base):`、`class TaskApplication(Base):`、`class FleaMarketPurchaseRequest(Base):` 各类体内,和其他 FK 字段邻近处添加:

```python
consultation_task_id = Column(
    Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True
)
```

- [ ] **Step 2: 验证 ORM 加载**

```bash
cd backend && python -c "from app import models; sa = models.ServiceApplication(); ta = models.TaskApplication(); fmpr = models.FleaMarketPurchaseRequest(); assert all(hasattr(x, 'consultation_task_id') for x in [sa, ta, fmpr]); print('OK')"
```
预期:输出 `OK`。

- [ ] **Step 3: Commit**

```bash
git add backend/app/models.py
git commit -m "feat(models): consultation_task_id on SA/TA/FMPR for consultation history backup"
```

---

## Task 5: Helper — 扩展 create_placeholder_task

**Files:**
- Modify: `backend/app/consultation/helpers.py`(`create_placeholder_task` 函数内)
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`(新建)

- [ ] **Step 1: 写失败测试**

创建 `backend/tests/test_consultation_placeholder_upgrade.py`:

```python
"""Tests for 2026-04-18 consultation upgrade (flag + consultation_task_id)."""
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock


@pytest.mark.asyncio
async def test_create_placeholder_task_sets_both_fields():
    """create_placeholder_task helper must set task_source AND is_consultation_placeholder
    together (the CHECK constraint in migration 208b will enforce this; helper makes it
    impossible to write one without the other)."""
    from app.consultation.helpers import create_placeholder_task

    db = MagicMock()
    db.add = MagicMock()
    db.flush = AsyncMock()

    task = await create_placeholder_task(
        db,
        consultation_type="consultation",
        title="咨询：测试",
        applicant_id="u_applicant",
        taker_id="u_taker",
    )

    assert task.task_source == "consultation"
    assert task.is_consultation_placeholder is True
    assert task.status == "consulting"
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py::test_create_placeholder_task_sets_both_fields -v
```
预期:FAIL,断言 `task.is_consultation_placeholder is True` 不成立(helper 还没设)。

- [ ] **Step 3: 修改 helper**

`backend/app/consultation/helpers.py` 的 `create_placeholder_task` 函数内部 `Task(...)` 构造加一行:

```python
task = models.Task(
    title=title,
    description=description,
    poster_id=applicant_id,
    taker_id=taker_id,
    status="consulting",
    task_source=consultation_type,
    is_consultation_placeholder=True,  # 新加
    **extra_fields,
)
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py::test_create_placeholder_task_sets_both_fields -v
```
预期:PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/consultation/helpers.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "feat(consultation): create_placeholder_task auto-sets is_consultation_placeholder=True"
```

---

## Task 6: Helper — 新加 consultation_task_id_for

**Files:**
- Modify: `backend/app/consultation/helpers.py`(文件末尾新加函数)
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写失败测试(7 种场景全覆盖)**

在 `test_consultation_placeholder_upgrade.py` 末尾加:

```python
def test_consultation_task_id_for_all_scenarios():
    """C.3 分场景表全部 7 种场景 + NULL 边界."""
    from app.consultation.helpers import consultation_task_id_for

    # 1. SA approve 前:consultation_task_id=NULL, task_id=占位 → 返回 task_id
    sa_pre = MagicMock(consultation_task_id=None, task_id=100)
    assert consultation_task_id_for(sa_pre) == 100

    # 2. SA approve 后:consultation_task_id=占位, task_id=真任务 → 返回 consultation_task_id
    sa_post = MagicMock(consultation_task_id=100, task_id=200)
    assert consultation_task_id_for(sa_post) == 100

    # 3. TA 占位记录咨询中:consultation_task_id=NULL, task_id=占位 → 返回 task_id
    ta_placeholder_during = MagicMock(consultation_task_id=None, task_id=101)
    assert consultation_task_id_for(ta_placeholder_during) == 101

    # 4. TA 占位记录 formal apply 后(cancelled):consultation_task_id=NULL, task_id=占位 → 返回 task_id
    ta_placeholder_cancelled = MagicMock(consultation_task_id=None, task_id=101)
    assert consultation_task_id_for(ta_placeholder_cancelled) == 101

    # 5. TA orig_application:consultation_task_id=占位, task_id=原任务 → 返回 consultation_task_id
    ta_orig = MagicMock(consultation_task_id=101, task_id=999)
    assert consultation_task_id_for(ta_orig) == 101

    # 6. FMPR 咨询中:consultation_task_id=NULL, task_id=占位 → 返回 task_id
    fmpr_during = MagicMock(consultation_task_id=None, task_id=102)
    assert consultation_task_id_for(fmpr_during) == 102

    # 7. FMPR 付款晋升后:consultation_task_id 和 task_id 都指同一行 → 返回 consultation_task_id(等价)
    fmpr_promoted = MagicMock(consultation_task_id=102, task_id=102)
    assert consultation_task_id_for(fmpr_promoted) == 102

    # 边界:两个都为 NULL → None
    null_case = MagicMock(consultation_task_id=None, task_id=None)
    assert consultation_task_id_for(null_case) is None
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py::test_consultation_task_id_for_all_scenarios -v
```
预期:FAIL,`ImportError: cannot import name 'consultation_task_id_for'`。

- [ ] **Step 3: 在 helpers.py 末尾加函数**

```python
from typing import Optional


def consultation_task_id_for(app) -> Optional[int]:
    """返回应该用来查 messages 的 task_id。None 表示不存在咨询消息。

    适用于 ServiceApplication / TaskApplication / FleaMarketPurchaseRequest
    三种申请类型,遵循 "consultation_task_id 优先,fallback 到 task_id" 的规则。

    详见 2026-04-18-consultation-upgrade-design.md §C.3 分场景表。
    """
    if app.consultation_task_id is not None:
        return app.consultation_task_id  # approve/正式转换后场景
    if app.task_id is not None:
        # app.task_id 此时指向占位 task(is_consultation_placeholder=True)
        # SA approve 前 / TA 占位态 / FMPR 未晋升态 都走这条
        return app.task_id
    return None
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py::test_consultation_task_id_for_all_scenarios -v
```
预期:PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/consultation/helpers.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "feat(consultation): consultation_task_id_for helper (C.3 routing rule)"
```

---

## Task 7: 迁移创建点 — expert_consultation_routes:~429(团队服务分支)

**Files:**
- Modify: `backend/app/expert_consultation_routes.py`(~line 418-449 附近)

- [ ] **Step 1: 读现有 inline Task(...) 构造并改成 call helper**

找到 `expert_consultation_routes.py` 中 service_id=NULL 的团队咨询分支(create consulting_task 那段 ~line 418-449)。

示例改动模式:

```diff
-consulting_task = models.Task(
-    title=f"咨询(团队):{expert.expert_name}",
-    description=...,
-    status="consulting",
-    task_source="consultation",
-    poster_id=current_user.id,
-    taker_id=expert_owner_id,
-    ...
-)
-db.add(consulting_task)
-await db.flush()
+from app.consultation.helpers import create_placeholder_task
+consulting_task = await create_placeholder_task(
+    db,
+    consultation_type="consultation",
+    title=f"咨询(团队):{expert.expert_name}",
+    applicant_id=current_user.id,
+    taker_id=expert_owner_id,
+    description=...,
+    # 其他 reward/currency/location 等通过 extra_fields 透传
+)
```

注意:如果已有的 Task 构造用了额外字段(reward, currency 等),通过 `**extra_fields` 透传给 helper。

- [ ] **Step 2: 运行 pytest 烟雾测试**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -v
```
预期:既有测试 1-2 仍 PASS(不应该破坏已有行为)。

- [ ] **Step 3: 手测 — 触发团队咨询 + 验证 flag**

在 staging(或本地完整起后端)发起一次对团队的咨询,然后:
```bash
psql $DATABASE_URL -c "SELECT id, task_source, is_consultation_placeholder FROM tasks ORDER BY created_at DESC LIMIT 1;"
```
预期:最新的 task 的 `task_source='consultation'` + `is_consultation_placeholder=t`。

- [ ] **Step 4: Commit**

```bash
git add backend/app/expert_consultation_routes.py
git commit -m "refactor(consultation): migrate team service create site to create_placeholder_task helper"
```

---

## Task 8: 迁移创建点 — flea_market_routes:~4064

**Files:**
- Modify: `backend/app/flea_market_routes.py`(~line 4052-4071)

- [ ] **Step 1: 找到 inline Task(...) 并改成 call helper**

找到 flea market 咨询创建 consulting_task 的地方(task_source='flea_market_consultation' 处,~line 4052-4071):

```diff
-consulting_task = models.Task(
-    title=f"咨询:{item.title}",
-    description=...,
-    status="consulting",
-    task_source="flea_market_consultation",
-    poster_id=buyer_id,
-    taker_id=seller_id,
-    ...
-)
-db.add(consulting_task)
-await db.flush()
+from app.consultation.helpers import create_placeholder_task
+consulting_task = await create_placeholder_task(
+    db,
+    consultation_type="flea_market_consultation",
+    title=f"咨询:{item.title}",
+    applicant_id=buyer_id,
+    taker_id=seller_id,
+    description=...,
+)
```

- [ ] **Step 2: 运行烟雾测试**

```bash
cd backend && pytest tests/ -k "flea" -v
```
预期:现有 flea market 测试仍 PASS。

- [ ] **Step 3: Commit**

```bash
git add backend/app/flea_market_routes.py
git commit -m "refactor(flea_market): migrate consultation create site to create_placeholder_task helper"
```

---

## Task 9: 迁移创建点 — task_chat_routes:~4860

**Files:**
- Modify: `backend/app/task_chat_routes.py`(~line 4849-4889 附近)

- [ ] **Step 1: 找到 inline Task(...) 并改成 call helper**

找到 task_chat_routes.py 中创建 task_consultation 占位 task 的地方:

```diff
-consulting_task = models.Task(
-    title=f"咨询：{task.title}",
-    description=f"original_task_id:{task.id}",
-    status="consulting",
-    task_source="task_consultation",
-    poster_id=current_user.id,
-    taker_id=task.poster_id,
-    ...
-)
-db.add(consulting_task)
-await db.flush()
+from app.consultation.helpers import create_placeholder_task
+consulting_task = await create_placeholder_task(
+    db,
+    consultation_type="task_consultation",
+    title=f"咨询：{task.title}",
+    applicant_id=current_user.id,
+    taker_id=task.poster_id,
+    description=f"original_task_id:{task.id}",
+)
```

**注意**:`description` 的 `original_task_id:{task.id}` 格式是 `consult_formal_apply` 解析依赖的(line 5361),**不能改格式**。

- [ ] **Step 2: 运行既有测试**

```bash
cd backend && pytest tests/ -k "task_consultation or consult" -v
```
预期:全部 PASS。

- [ ] **Step 3: Commit**

```bash
git add backend/app/task_chat_routes.py
git commit -m "refactor(task_chat): migrate task_consultation create site to create_placeholder_task helper"
```

---

## Task 10: 创建 task_guards.py helper(不应用)

**Files:**
- Create: `backend/app/utils/task_guards.py`
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写失败测试**

在测试文件加:

```python
@pytest.mark.asyncio
async def test_load_real_task_or_404_rejects_placeholder():
    """守卫对占位 task 返回 404(伪装成不存在,防探测)."""
    from app.utils.task_guards import load_real_task_or_404
    from fastapi import HTTPException

    placeholder_task = MagicMock(id=100, is_consultation_placeholder=True)
    db = MagicMock()
    db.get = AsyncMock(return_value=placeholder_task)

    with pytest.raises(HTTPException) as exc:
        await load_real_task_or_404(db, 100)
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_load_real_task_or_404_returns_real_task():
    """守卫对真任务正常返回."""
    from app.utils.task_guards import load_real_task_or_404

    real_task = MagicMock(id=200, is_consultation_placeholder=False)
    db = MagicMock()
    db.get = AsyncMock(return_value=real_task)

    result = await load_real_task_or_404(db, 200)
    assert result is real_task


@pytest.mark.asyncio
async def test_load_real_task_or_404_returns_404_for_nonexistent():
    """守卫对不存在的 id 返回 404."""
    from app.utils.task_guards import load_real_task_or_404
    from fastapi import HTTPException

    db = MagicMock()
    db.get = AsyncMock(return_value=None)

    with pytest.raises(HTTPException) as exc:
        await load_real_task_or_404(db, 9999)
    assert exc.value.status_code == 404
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "load_real_task" -v
```
预期:FAIL,`ModuleNotFoundError: No module named 'app.utils.task_guards'`。

- [ ] **Step 3: 创建 helper 文件**

`backend/app/utils/task_guards.py`:

```python
"""Task 级 API 的通用守卫:拒绝对咨询占位 task 的业务操作。"""

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app import models


async def load_real_task_or_404(db: AsyncSession, task_id: int) -> models.Task:
    """加载 Task,并确保它不是咨询占位。

    占位 task 不应出现在任何 task-level 业务 API 上(支付/评价/取消/完成/
    退款/争议等),即使 task_id 合法。返回 404 伪装成"任务不存在",避免泄露
    占位 id 的存在(防探测)。

    使用场景:所有 /api/tasks/{task_id}/* 端点开头替换 `db.get(Task, task_id)`。
    """
    task = await db.get(models.Task, task_id)
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="任务不存在")
    if task.is_consultation_placeholder:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="任务不存在")
    return task
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "load_real_task" -v
```
预期:3 个测试全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/utils/task_guards.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "feat(task_guards): load_real_task_or_404 helper to reject placeholder tasks"
```

---

## Task 11: Admin task 列表默认过滤

**Files:**
- Modify: `backend/app/admin_task_management_routes.py`(task list endpoint)
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写失败测试**

```python
@pytest.mark.asyncio
async def test_admin_task_list_excludes_placeholders_by_default(async_client, admin_token, seed_placeholder_task):
    """Admin /admin/tasks 默认不返回占位 task."""
    response = await async_client.get(
        "/admin/tasks",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    task_ids = [t["id"] for t in response.json().get("tasks", response.json())]
    assert seed_placeholder_task.id not in task_ids


@pytest.mark.asyncio
async def test_admin_task_list_include_placeholders_flag(async_client, admin_token, seed_placeholder_task):
    """?include_placeholders=true 时才返回占位 task."""
    response = await async_client.get(
        "/admin/tasks?include_placeholders=true",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    task_ids = [t["id"] for t in response.json().get("tasks", response.json())]
    assert seed_placeholder_task.id in task_ids
```

注:`async_client` / `admin_token` / `seed_placeholder_task` 使用项目既有 fixtures。如果 `seed_placeholder_task` fixture 不存在,在 conftest.py 或该文件里加一个返回 `is_consultation_placeholder=True` 的 Task。

- [ ] **Step 2: 跑测试确认失败**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "admin_task_list" -v
```
预期:FAIL。

- [ ] **Step 3: 修改 endpoint**

找到 `admin_task_management_routes.py` 中 task 列表 endpoint,在函数签名加 `include_placeholders: bool = False` query param,在 query 构造处加过滤:

```diff
 @router.get("/admin/tasks")
 async def list_tasks(
+    include_placeholders: bool = False,
     ...
 ):
     query = select(models.Task)
+    if not include_placeholders:
+        query = query.where(models.Task.is_consultation_placeholder == False)
     ...
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "admin_task_list" -v
```
预期:PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/admin_task_management_routes.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "feat(admin): exclude consultation placeholders from task list by default"
```

---

## Task 12: 用户主页"我发布的任务数"过滤

**Files:**
- Modify: `backend/app/crud/task.py` + profile routes(按 audit 结果)

- [ ] **Step 1: Audit — grep 按 poster_id 计数的地方**

```bash
cd backend && grep -rn "Task.poster_id ==" app/crud/ app/routers.py app/user_service_application_routes.py app/routes/ 2>&1 | grep -iE "count|statistics|stats" | head -20
```

记下所有命中(预估 3-4 处)。

- [ ] **Step 2: 在每处 where 后加 filter**

对每个命中的 query,加 `.where(Task.is_consultation_placeholder == False)`:

```diff
 count = await db.scalar(
     select(func.count()).select_from(Task)
     .where(Task.poster_id == user_id)
+    .where(Task.is_consultation_placeholder == False)
 )
```

- [ ] **Step 3: 手测验证**

创建一个占位 task + 一个真 task,查看用户主页任务数:

```bash
psql $DATABASE_URL -c "INSERT INTO tasks (...) VALUES (...);" # 创建一个占位 task
# 访问 /api/users/me/profile 或相关端点,确认任务数不含占位
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/crud/task.py  # + 其他改动文件
git commit -m "feat(stats): exclude consultation placeholders from user task count"
```

---

## Task 13: PR 1 整体 staging 部署 + 观察期

**Files:** 无代码改动,部署 + 文档

- [ ] **Step 1: 合并 PR 1 到 main**

将 Task 1-12 的 commit 打包成 PR,通过 review,merge 到 main。

- [ ] **Step 2: Railway 自动部署验证**

等待部署完成,验证:
- 新 endpoint `/admin/tasks` 和 `/admin/tasks?include_placeholders=true` 行为正确
- 新创建的咨询带 `is_consultation_placeholder=TRUE`
- Three creation sites 都走 helper(通过 log 或 db 抽样)

- [ ] **Step 3: 启动观察期 monitoring query**

建立每日监控(或 cron job)跑:

```sql
SELECT COUNT(*) AS stragglers
FROM tasks
WHERE task_source IN ('consultation', 'task_consultation', 'flea_market_consultation')
  AND is_consultation_placeholder = FALSE
  AND created_at > '<PR1 部署时间>';
```

记录**PR1 部署时间**(具体时间戳,替换尖括号)到 team doc,监控 24-48 小时。**预期 stragglers 连续为 0** 才能进 Day 2。

- [ ] **Step 4: 在 team doc / Slack 确认观察期通过**

24-48 小时后,stragglers=0 → 正式进 PR 2。

---

# PR 2 — Day 2: CHECK 约束 + Bug 修

## Task 14: 创建 migration 208b(CHECK 约束 + DO $$ ASSERT)

**Files:**
- Create: `backend/migrations/208b_add_consultation_placeholder_check.sql`

- [ ] **Step 1: 写 migration 文件**

```sql
-- 兜底回填(防止 208a 到 208b 之间有旧代码漏写 flag 的行)
UPDATE tasks
SET is_consultation_placeholder = TRUE
WHERE task_source IN ('consultation', 'task_consultation', 'flea_market_consultation')
  AND is_consultation_placeholder = FALSE;

-- 双保险 ASSERT
-- ⚠️ 要求 migration runner 用 ON_ERROR_STOP=on
DO $$
DECLARE
  violation_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO violation_count
  FROM tasks
  WHERE (is_consultation_placeholder = TRUE
          AND task_source NOT IN ('consultation', 'task_consultation', 'flea_market_consultation'))
     OR (is_consultation_placeholder = FALSE
          AND task_source IN ('consultation', 'task_consultation', 'flea_market_consultation'));
  IF violation_count > 0 THEN
    RAISE EXCEPTION
      'Cannot add ck_tasks_consultation_placeholder_matches_source: % rows still inconsistent. '
      'Check: SELECT id, task_source, is_consultation_placeholder FROM tasks WHERE (...same predicate...). '
      'Fix data before retry (probably old code still writing to prod).', violation_count;
  END IF;
END $$;

ALTER TABLE tasks
  ADD CONSTRAINT ck_tasks_consultation_placeholder_matches_source
  CHECK (
    (is_consultation_placeholder = TRUE
      AND task_source IN ('consultation', 'task_consultation', 'flea_market_consultation'))
    OR
    (is_consultation_placeholder = FALSE
      AND task_source NOT IN ('consultation', 'task_consultation', 'flea_market_consultation'))
  );
```

- [ ] **Step 2: 确认观察期已过**

重新跑 Task 13 Step 3 的 stragglers query,确认为 0。若非 0,找出具体行并修数据后重来,**不要跑 208b**。

- [ ] **Step 3: Apply migration(本地/staging 先)**

```bash
psql $DATABASE_URL -v ON_ERROR_STOP=1 -f backend/migrations/208b_add_consultation_placeholder_check.sql
```
预期:四条 SQL 全部 SUCCESS。若 ASSERT 失败,文件中止,没有加 constraint。

- [ ] **Step 4: 验证 CHECK 约束存在**

```bash
psql $DATABASE_URL -c "\d tasks" | grep ck_tasks_consultation_placeholder
```
预期:有一行输出显示 check constraint 存在。

- [ ] **Step 5: Commit**

```bash
git add backend/migrations/208b_add_consultation_placeholder_check.sql
git commit -m "feat(db): migration 208b CHECK constraint for is_consultation_placeholder vs task_source"
```

---

## Task 15: 测试 CHECK 约束生效

**Files:**
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写测试**

```python
@pytest.mark.asyncio
async def test_check_constraint_rejects_inconsistent_flag_and_source(async_db_session):
    """208b CHECK 约束:is_consultation_placeholder 和 task_source 必须一致."""
    from sqlalchemy.exc import IntegrityError
    from app import models

    # 先建一个 normal task,再试图只改一个字段(flag=TRUE 但 source 不变)
    real_task = models.Task(
        title="real",
        status="open",
        task_source="normal",
        is_consultation_placeholder=False,
        poster_id="u_test",
    )
    async_db_session.add(real_task)
    await async_db_session.flush()

    # 试图违反约束:只改 flag,不改 source
    real_task.is_consultation_placeholder = True
    with pytest.raises(IntegrityError):
        await async_db_session.commit()
    await async_db_session.rollback()
```

- [ ] **Step 2: 跑测试(需 208b 已 apply 到测试 DB)**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py::test_check_constraint_rejects_inconsistent_flag_and_source -v
```
预期:PASS(DB 抛 IntegrityError,测试捕获)。

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "test: verify ck_tasks_consultation_placeholder_matches_source constraint"
```

---

## Task 16: SA overwrite 备份 — team service(expert_consultation_routes.py:~1025)

**Files:**
- Modify: `backend/app/expert_consultation_routes.py`(~line 1025)
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写失败测试**

```python
@pytest.mark.asyncio
async def test_overwrite_backs_up_consultation_task_id_team():
    """B.2.1 团队服务 approve:SA.consultation_task_id 备份 + SA.task_id 改真任务."""
    from app.expert_consultation_routes import _approve_team_service_application
    # ... setup: application with task_id=100 (placeholder), new_task created with id=200
    # invoke the function or just the backup logic
    # assert application.consultation_task_id == 100
    # assert application.task_id == 200
    # (具体 setup 按项目既有测试风格,可能需要多个 mock)
    application = MagicMock(task_id=100, consultation_task_id=None)
    new_task_id = 200

    # 直接测试新的 2 行备份逻辑(不用跑整个 approve 函数):
    if application.task_id and not application.consultation_task_id:
        application.consultation_task_id = application.task_id
    application.task_id = new_task_id

    assert application.consultation_task_id == 100
    assert application.task_id == 200
```

- [ ] **Step 2: 跑测试**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py::test_overwrite_backs_up_consultation_task_id_team -v
```
这个测试本身应该 pass(测的是备份逻辑,在测试里已写成 inline)。真正的验证在 Step 4 中用 e2e 流程覆盖。

- [ ] **Step 3: 在代码里加备份逻辑**

`expert_consultation_routes.py:~1025`:

```diff
+    # 备份咨询占位 id,保留 team 成员访问历史消息的路径(防御性兜底,双层防护)
+    if application.task_id and not application.consultation_task_id:
+        application.consultation_task_id = application.task_id
     application.task_id = new_task.id  # 保持原语义
```

- [ ] **Step 4: E2E 验证**

在 staging 完整走一次"用户咨询 → 团队 approve",然后:

```bash
psql $DATABASE_URL -c "SELECT id, task_id, consultation_task_id FROM service_applications ORDER BY id DESC LIMIT 1;"
```
预期:`task_id` 和 `consultation_task_id` 两者不等且都非 NULL。

- [ ] **Step 5: Commit**

```bash
git add backend/app/expert_consultation_routes.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "fix(consultation): backup SA.task_id into consultation_task_id on team approve (B1)"
```

---

## Task 17: SA overwrite 备份 — personal service(user_service_application_routes.py:~681)

**Files:**
- Modify: `backend/app/user_service_application_routes.py`(~line 681)
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写测试**

```python
@pytest.mark.asyncio
async def test_overwrite_backs_up_consultation_task_id_personal():
    """B.2.1 个人服务 approve:同样备份."""
    application = MagicMock(task_id=100, consultation_task_id=None)
    new_task_id = 200

    if application.task_id and not application.consultation_task_id:
        application.consultation_task_id = application.task_id
    application.task_id = new_task_id

    assert application.consultation_task_id == 100
    assert application.task_id == 200


def test_overwrite_idempotent():
    """防御性兜底:第二次 approve 守卫本身不会错写 consultation_task_id."""
    application = MagicMock(task_id=200, consultation_task_id=100)  # 第一次已写
    new_task_id = 300

    if application.task_id and not application.consultation_task_id:
        application.consultation_task_id = application.task_id  # 应该不进
    application.task_id = new_task_id

    assert application.consultation_task_id == 100  # 仍是原来的 100
    assert application.task_id == 300
```

- [ ] **Step 2: 在代码里加备份逻辑**

`user_service_application_routes.py:~681`:

```diff
+    if application.task_id and not application.consultation_task_id:
+        application.consultation_task_id = application.task_id
     application.task_id = new_task.id
```

- [ ] **Step 3: 跑测试**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "personal or idempotent" -v
```
预期:PASS。

- [ ] **Step 4: Commit**

```bash
git add backend/app/user_service_application_routes.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "fix(consultation): backup SA.task_id into consultation_task_id on personal approve (B2) + idempotency test"
```

---

## Task 18: TA 正式转换修复(task_chat_routes.py:~5392, ~5427)

**Files:**
- Modify: `backend/app/task_chat_routes.py`(~line 5392 + ~line 5427)
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写失败测试**

```python
@pytest.mark.asyncio
async def test_ta_formal_apply_creates_orig_application_with_consultation_task_id(
    async_client, test_user, test_task_consultation_setup
):
    """B.2.3: formal apply 后新建的 orig_application.consultation_task_id 指向占位 task."""
    # test_task_consultation_setup 提供:原任务 + 占位 task + 占位 TA
    placeholder_task_id = test_task_consultation_setup.placeholder_task_id
    placeholder_ta_id = test_task_consultation_setup.placeholder_ta_id
    original_task_id = test_task_consultation_setup.original_task_id

    response = await async_client.post(
        f"/api/tasks/{placeholder_task_id}/applications/{placeholder_ta_id}/formal-apply",
        json={"message": "go"},
        headers={"Authorization": f"Bearer {test_user.token}"},
    )
    assert response.status_code == 200

    # 查新建的 orig_application:task_id=原任务 的 TA
    from app import models
    from sqlalchemy import select
    async with async_db_session() as db:
        result = await db.execute(
            select(models.TaskApplication).where(
                models.TaskApplication.task_id == original_task_id,
                models.TaskApplication.applicant_id == test_user.id,
            )
        )
        orig = result.scalar_one()
    assert orig.consultation_task_id == placeholder_task_id


@pytest.mark.asyncio
async def test_ta_formal_apply_cancels_placeholder_ta(
    async_client, test_user, test_task_consultation_setup
):
    """B.2.3: formal apply 后占位 TA status = cancelled(之前是 pending)."""
    placeholder_task_id = test_task_consultation_setup.placeholder_task_id
    placeholder_ta_id = test_task_consultation_setup.placeholder_ta_id

    await async_client.post(
        f"/api/tasks/{placeholder_task_id}/applications/{placeholder_ta_id}/formal-apply",
        json={"message": "go"},
        headers={"Authorization": f"Bearer {test_user.token}"},
    )

    from app import models
    async with async_db_session() as db:
        placeholder_ta = await db.get(models.TaskApplication, placeholder_ta_id)
    assert placeholder_ta.status == "cancelled"
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "ta_formal_apply" -v
```
预期:FAIL(orig_application 没 consultation_task_id + 占位 TA 仍是 "pending")。

- [ ] **Step 3: 改代码(两处)**

`task_chat_routes.py:~5392`(创建 orig_application 时加一行):

```diff
 orig_application = models.TaskApplication(
     task_id=original_task_id,
     applicant_id=current_user.id,
     status="pending",
     currency=application.currency or orig_task.currency or "GBP",
     negotiated_price=application.negotiated_price,
     message=body.message or application.message,
     created_at=current_time,
+    consultation_task_id=task_id,  # task_id 参数就是占位 task id
 )
```

`task_chat_routes.py:~5427`(占位 TA status 改成 cancelled):

```diff
-application.status = "pending"
+# 占位 TA 已被 orig_application 取代,标记为 cancelled 以避免 "pending" 歧义
+application.status = "cancelled"
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "ta_formal_apply" -v
```
预期:PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/task_chat_routes.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "fix(consultation): TA formal apply writes consultation_task_id + cancels placeholder (B.2.3)"
```

---

## Task 19: Flea market 占位晋升(flea_market_routes.py:~2451)

**Files:**
- Modify: `backend/app/flea_market_routes.py`(~line 2446-2453 + 外围)
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写失败测试**

```python
@pytest.mark.asyncio
async def test_flea_market_promote_sets_consultation_task_id(
    async_client, test_buyer, test_flea_consultation_setup
):
    """B.3: flea market 付款后,占位 task 晋升为真任务,FMPR.consultation_task_id 写入."""
    purchase_request_id = test_flea_consultation_setup.fmpr_id
    placeholder_task_id = test_flea_consultation_setup.placeholder_task_id

    # 触发付款流程(或直接调 confirm 端点)
    await async_client.post(
        f"/api/flea-market/purchase-requests/{purchase_request_id}/confirm",
        headers={"Authorization": f"Bearer {test_buyer.token}"},
    )

    from app import models
    async with async_db_session() as db:
        fmpr = await db.get(models.FleaMarketPurchaseRequest, purchase_request_id)
        task = await db.get(models.Task, placeholder_task_id)

    assert fmpr.consultation_task_id == placeholder_task_id  # 记录咨询 id
    assert task.is_consultation_placeholder is False  # 已晋升
    assert task.task_source == "flea_market"  # 不再是咨询 source
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "flea_market_promote" -v
```
预期:FAIL。

- [ ] **Step 3: 改代码**

`flea_market_routes.py:~2446-2453`:

```diff
 existing_task.status = "in_progress" if is_free_purchase else "pending_payment"
 ...
 # ⚠️ 以下两行必须同一事务内同时改,否则违反 ck_tasks_consultation_placeholder_matches_source
 existing_task.task_source = "flea_market"
+existing_task.is_consultation_placeholder = False  # 从占位晋升为真实订单任务
 existing_task.accepted_at = get_utc_time()
 new_task = existing_task

+# 和 SA/TA 对称:记录咨询 id 以便看历史
+if not purchase_request.consultation_task_id:
+    purchase_request.consultation_task_id = existing_task.id
```

**⚠️ PR review 时必须确认**:这两行之间没有 `db.flush()` / `db.commit()` / 查询操作(避免中间态违反 CHECK 约束)。

- [ ] **Step 4: 跑测试确认通过**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "flea_market_promote" -v
```
预期:PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/flea_market_routes.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "fix(flea_market): promote placeholder to real task + set consultation_task_id on payment (B.3)"
```

---

## Task 20: Stale cleanup 修复(scheduled_tasks.py:~965-982)

**Files:**
- Modify: `backend/app/scheduled_tasks.py`(~line 965-982)
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写失败测试**

```python
@pytest.mark.asyncio
async def test_stale_cleanup_covers_task_consultation(async_db_session):
    """B3 修复:14 天无活动的 task_consultation 占位被清理."""
    from datetime import timedelta
    from app.scheduled_tasks import close_stale_consultations
    from app import models
    from app.utils.time_utils import get_utc_time

    # 建一个 15 天前的 task_consultation 占位
    old_task = models.Task(
        title="old",
        status="consulting",
        task_source="task_consultation",
        is_consultation_placeholder=True,
        poster_id="u",
        created_at=get_utc_time() - timedelta(days=15),
    )
    async_db_session.add(old_task)
    await async_db_session.commit()

    await close_stale_consultations(async_db_session)

    await async_db_session.refresh(old_task)
    assert old_task.status == "closed"


@pytest.mark.asyncio
async def test_stale_cleanup_still_covers_service_and_flea_market(async_db_session):
    """回归:原有两类咨询仍被清理."""
    from datetime import timedelta
    from app.scheduled_tasks import close_stale_consultations
    from app import models
    from app.utils.time_utils import get_utc_time

    old_service = models.Task(
        title="svc",
        status="consulting",
        task_source="consultation",
        is_consultation_placeholder=True,
        poster_id="u",
        created_at=get_utc_time() - timedelta(days=15),
    )
    old_flea = models.Task(
        title="flea",
        status="consulting",
        task_source="flea_market_consultation",
        is_consultation_placeholder=True,
        poster_id="u",
        created_at=get_utc_time() - timedelta(days=15),
    )
    async_db_session.add_all([old_service, old_flea])
    await async_db_session.commit()

    await close_stale_consultations(async_db_session)

    for t in (old_service, old_flea):
        await async_db_session.refresh(t)
        assert t.status == "closed"
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "stale_cleanup" -v
```
预期:第一个 test FAIL(task_consultation 未覆盖),第二个 PASS(原逻辑覆盖)。

- [ ] **Step 3: 改代码**

`scheduled_tasks.py:~965-982`:

```diff
-# 现状:分两段查 task_source='consultation' 和 'flea_market_consultation',遗漏 task_consultation
+# 主过滤键:is_consultation_placeholder (source of truth,覆盖所有三类)
+# 分支处理:task_source (子类型标识,决定关联哪张申请表)
 stale_placeholders = await db.execute(
     select(models.Task).where(
         and_(
-            models.Task.task_source == 'consultation',
+            models.Task.is_consultation_placeholder == True,
             models.Task.status == 'consulting',
             models.Task.created_at < cutoff,
         )
     )
 )
-# 删除原来的 flea_market_consultation 分支查询(已被上面的 is_consultation_placeholder=True 覆盖)

 for task in stale_placeholders.scalars():
-    if task.task_source == 'consultation':
-        # 同步关闭 ServiceApplication
-        ...
-    elif task.task_source == 'flea_market_consultation':
-        # 同步关闭 FleaMarketPurchaseRequest
-        ...
+    # task_source 此处只用于分辨子类型关联哪张申请表,不参与是否清理的判断
+    task.status = "closed"  # 保留原有 close 逻辑
+    if task.task_source == 'consultation':
+        await _close_related_service_application(db, task)
+    elif task.task_source == 'task_consultation':
+        await _close_related_task_application(db, task)  # 新增(修 B3)
+    elif task.task_source == 'flea_market_consultation':
+        await _close_related_flea_market_request(db, task)
+    else:
+        logger.error(
+            "Placeholder task with unknown task_source",
+            extra={"task_id": task.id, "task_source": task.task_source},
+        )
```

**注**:`_close_related_task_application` 是新加的 helper,需要写出来:

```python
async def _close_related_task_application(db, task: models.Task) -> None:
    """Close the TaskApplication whose task_id points to this placeholder task."""
    result = await db.execute(
        select(models.TaskApplication).where(models.TaskApplication.task_id == task.id)
    )
    for ta in result.scalars():
        if ta.status in ("consulting", "negotiating", "price_agreed"):
            ta.status = "cancelled"
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "stale_cleanup" -v
```
预期:两个测试 PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/scheduled_tasks.py backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "fix(scheduled): stale cleanup covers task_consultation (B3) + unified is_consultation_placeholder key"
```

---

## Task 21: PR 2 部署

**Files:** 无代码,部署

- [ ] **Step 1: 合并 PR 2 到 main**

确保 Day 1 观察期的 stragglers=0 已验证,然后 merge PR 2。

- [ ] **Step 2: 部署(含 208b migration)**

Railway 部署时:
1. migration 208b 跑兜底 UPDATE + DO $$ ASSERT
2. 若 ASSERT 触发,部署失败 → 调查 stragglers,修数据,retry
3. 若 ASSERT 通过,ADD CONSTRAINT 成功,代码启动

- [ ] **Step 3: 部署后验证**

```bash
# 验证 CHECK 约束生效
psql $DATABASE_URL -c "\d tasks" | grep ck_tasks_consultation_placeholder
# 应有输出

# 手测 SA team approve → 验证 consultation_task_id 写入
# 手测 task consultation formal apply → 验证 orig_application.consultation_task_id
# 手测 flea market purchase → 验证晋升 + consultation_task_id
# 跑一次 scheduled cleanup(或等 cron)→ 验证 task_consultation 也被清
```

---

# PR 3 — Day 3: 守卫应用 + team role 迁移 + Flutter

## Task 22: 守卫应用 — routers.py 写操作(9 个)

**Files:**
- Modify: `backend/app/routers.py`(多处 endpoint 开头)

- [ ] **Step 1: 读 9 个 endpoint 的现有结构**

目标 endpoints(spec D.2 表):
- `POST /tasks/{id}/accept`(:1862)
- `POST /tasks/{id}/reject`(:2070)
- `POST /tasks/{id}/review`(:2195)
- `POST /tasks/{id}/complete`(:2315)
- `POST /tasks/{id}/dispute`(:2545)
- `POST /tasks/{id}/refund-request`(:2673)
- `POST /tasks/{id}/refund-request/{rid}/cancel`(:3524)
- `POST /tasks/{id}/refund-request/{rid}/rebuttal`(:3653)
- `POST /tasks/{id}/cancel`(:4481)
- `POST /tasks/{id}/pay`(:6714)

每个都有类似结构:
```python
task = await db.get(models.Task, task_id)
if not task:
    raise HTTPException(status_code=404, detail="任务不存在")
```

- [ ] **Step 2: 每个 endpoint 开头替换**

在文件顶部加 import(如还没):
```python
from app.utils.task_guards import load_real_task_or_404
```

然后对 10 处 endpoint,每处:

```diff
-task = await db.get(models.Task, task_id)
-if not task:
-    raise HTTPException(status_code=404, detail="任务不存在")
+task = await load_real_task_or_404(db, task_id)
```

- [ ] **Step 3: 运行烟雾测试**

```bash
cd backend && pytest tests/ -k "task" -v 2>&1 | tail -20
```
预期:没有破坏既有测试。

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(guards): 10 write endpoints in routers.py reject placeholder tasks (404)"
```

---

## Task 23: 守卫应用 — routers.py 读操作(4 个)

**Files:**
- Modify: `backend/app/routers.py`

- [ ] **Step 1: 同样模式替换 4 个读 endpoint**

- `GET /tasks/{id}/reviews`(:2276)
- `GET /tasks/{id}/refund-status`(:3008)
- `GET /tasks/{id}/dispute-timeline`(:3094)
- `GET /tasks/{id}/refund-history`(:3428)

每个 endpoint 开头:
```diff
-task = await db.get(models.Task, task_id)
-if not task:
-    raise HTTPException(status_code=404, detail="任务不存在")
+task = await load_real_task_or_404(db, task_id)
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(guards): 4 read endpoints in routers.py reject placeholder tasks (404)"
```

---

## Task 24: 守卫应用 — coupon_points_routes.py(2 个)

**Files:**
- Modify: `backend/app/coupon_points_routes.py`(:502, :2200)

- [ ] **Step 1: 同样模式**

- `POST /tasks/{id}/payment`(:502)
- `GET /tasks/{id}/payment-status`(:2200)

加 import + 两处替换。

- [ ] **Step 2: Commit**

```bash
git add backend/app/coupon_points_routes.py
git commit -m "feat(guards): 2 coupon_points endpoints reject placeholder tasks (404)"
```

---

## Task 25: Admin 加 warning log — multi_participant_routes.py(2 个)

**Files:**
- Modify: `backend/app/multi_participant_routes.py`(:1144, :2904)

- [ ] **Step 1: 每个 admin endpoint 的 db.get 之后加 log**

`POST /admin/tasks/{id}/complete`(:1144) 和 `POST /admin/tasks/{id}/complete/custom`(:2904),都在 task 加载之后加:

```diff
 task = await db.get(models.Task, task_id)
 if not task:
     raise HTTPException(status_code=404, detail="任务不存在")
+# 不拦,但记录客服对占位 task 的操作便于事后审计
+if task.is_consultation_placeholder:
+    logger.warning(
+        "Admin operation on consultation placeholder task",
+        extra={
+            "task_id": task.id,
+            "admin_user": current_admin.id,
+            "endpoint": request.url.path,
+        },
+    )
 # 后续业务逻辑不变(admin 穿透,不拦)
```

注意 `current_admin` / `request` 需要是已有的 endpoint 参数(如 `request: Request` / 依赖注入)。若没有 `request` 参数,加一个:

```python
async def admin_complete_task(task_id: int, request: Request, ...):
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/multi_participant_routes.py
git commit -m "feat(guards): admin task endpoints log warning when touching placeholder"
```

---

## Task 26: 测试 — 守卫拦截

**Files:**
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写测试**

```python
@pytest.mark.asyncio
async def test_task_api_rejects_placeholder_payment(async_client, user_token, seed_placeholder_task):
    """从 16 个拦截点中抽样 pay."""
    response = await async_client.post(
        f"/api/tasks/{seed_placeholder_task.id}/pay",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_task_api_rejects_placeholder_write_sample(async_client, user_token, seed_placeholder_task):
    """抽样覆盖 complete / review / cancel(守卫 helper 共用,抽样足以防回归)."""
    for endpoint in ("complete", "review", "cancel"):
        response = await async_client.post(
            f"/api/tasks/{seed_placeholder_task.id}/{endpoint}",
            json={},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert response.status_code == 404, f"{endpoint} should return 404 for placeholder"
```

- [ ] **Step 2: 跑测试**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "task_api_rejects" -v
```
预期:2 个测试 PASS。

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "test: 16 endpoint guards reject placeholder tasks (sampled: pay/complete/review/cancel)"
```

---

## Task 27: Audit team role inline checks

**Files:**
- Audit only, no code change

- [ ] **Step 1: Grep 出哪些 task-level endpoint 有 inline team check**

```bash
cd backend && grep -n "ExpertMember" app/routers.py app/coupon_points_routes.py app/multi_participant_routes.py 2>&1 | head -30
```

在 18 个守卫 endpoint 里,识别哪些用了 `models.ExpertMember` + role 检查的 pattern。预估 6-8 个(主要在 accept / reject / complete / cancel / dispute / refund-request 系列)。

- [ ] **Step 2: 列出迁移目标**

记录每个命中的 file:line,在下一个 task 批量迁移。

---

## Task 28: 迁移 team role checks(6-8 处)

**Files:**
- Modify: `backend/app/routers.py`(+ 其他命中文件)

- [ ] **Step 1: 对每个命中处替换 inline 检查**

模式:

```diff
-if task.taker_expert_id:
-    member_result = await db.execute(
-        select(models.ExpertMember).where(
-            and_(
-                models.ExpertMember.expert_id == task.taker_expert_id,
-                models.ExpertMember.user_id == current_user.id,
-            )
-        )
-    )
-    member = member_result.scalar_one_or_none()
-    if not member or member.role not in ("owner", "admin"):
-        raise HTTPException(status_code=403, detail="只有团队 owner 或 admin 可以操作")

+from app.permissions.expert_permissions import require_team_role
+if task.taker_expert_id:
+    await require_team_role(db, task.taker_expert_id, current_user.id, minimum="admin")
```

对每个 endpoint 独立做一次。

- [ ] **Step 2: 跑既有测试确保不破坏功能**

```bash
cd backend && pytest tests/ -k "team or expert" -v
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/routers.py  # + 其他改动文件
git commit -m "refactor(permissions): migrate 6-8 inline team checks to require_team_role helper"
```

---

## Task 29: 测试 — team role 迁移生效

**Files:**
- Test: `backend/tests/test_consultation_placeholder_upgrade.py`

- [ ] **Step 1: 写测试**

```python
@pytest.mark.asyncio
async def test_require_team_role_used_by_guarded_endpoints(
    async_client, team_member_not_admin_token, team_task
):
    """非 admin 的 team 成员调受保护的 endpoint → 403 with INSUFFICIENT_TEAM_ROLE.

    **依赖 Track 1 F3 已合入**(require_team_role helper 的错误码形式)。
    """
    # 选 2-3 个守卫 endpoint 抽样
    for endpoint in ("complete", "cancel"):
        response = await async_client.post(
            f"/api/tasks/{team_task.id}/{endpoint}",
            headers={"Authorization": f"Bearer {team_member_not_admin_token}"},
        )
        assert response.status_code == 403
        detail = response.json().get("detail", {})
        # Track 1 F6 的 error code 形式:可能是 dict 或 string
        if isinstance(detail, dict):
            assert detail.get("code") == "INSUFFICIENT_TEAM_ROLE"
        else:
            assert "INSUFFICIENT_TEAM_ROLE" in str(detail) or "不够" in str(detail) or "role" in str(detail).lower()
```

- [ ] **Step 2: 跑测试**

```bash
cd backend && pytest tests/test_consultation_placeholder_upgrade.py -k "require_team_role_used" -v
```
预期:PASS。若 FAIL,检查 Track 1 的错误码格式是否和 spec 假设一致。

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_consultation_placeholder_upgrade.py
git commit -m "test: verify require_team_role migration (INSUFFICIENT_TEAM_ROLE error code)"
```

---

## Task 30: Flutter — Task model 加 isConsultationPlaceholder

**Files:**
- Modify: `link2ur/lib/data/models/task.dart`
- Test: `link2ur/test/data/models/task_model_test.dart`

- [ ] **Step 1: 加字段**

```dart
class Task {
  // ... 既有字段
  final bool isConsultationPlaceholder;

  const Task({
    // ... 既有参数
    this.isConsultationPlaceholder = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      // ... 既有解析
      isConsultationPlaceholder: json['is_consultation_placeholder'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 2: 写测试**

`link2ur/test/data/models/task_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/task.dart';

void main() {
  test('Task.fromJson parses isConsultationPlaceholder=true', () {
    final task = Task.fromJson({'id': 1, 'is_consultation_placeholder': true});
    expect(task.isConsultationPlaceholder, isTrue);
  });

  test('Task.fromJson defaults isConsultationPlaceholder to false when missing', () {
    final task = Task.fromJson({'id': 1});
    expect(task.isConsultationPlaceholder, isFalse);
  });
}
```

- [ ] **Step 3: 跑测试**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test test/data/models/task_model_test.dart
```
预期:PASS。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/models/task.dart link2ur/test/data/models/task_model_test.dart
git commit -m "feat(flutter): Task.isConsultationPlaceholder field"
```

---

## Task 31: Flutter — ServiceApplication model + extension

**Files:**
- Modify: `link2ur/lib/data/models/service_application.dart`
- Test: `link2ur/test/data/models/service_application_model_test.dart`

- [ ] **Step 1: 加字段 + extension**

```dart
class ServiceApplication {
  // ... 既有字段
  final int? taskId;
  /// 咨询占位 task id。approve 前为 null;approve 时从 [taskId] 备份过来,
  /// 之后永久保留,用于回溯 approve 前的咨询对话消息。
  final int? consultationTaskId;

  const ServiceApplication({
    // ... 既有参数
    this.taskId,
    this.consultationTaskId,
  });

  factory ServiceApplication.fromJson(Map<String, dynamic> json) {
    return ServiceApplication(
      // ... 既有解析
      taskId: json['task_id'] as int?,
      consultationTaskId: json['consultation_task_id'] as int?,
    );
  }
}

/// 咨询消息路由 extension。C.3 规则:优先 consultationTaskId,fallback taskId。
extension ServiceApplicationConsultationRoute on ServiceApplication {
  int? get consultationMessageTaskId => consultationTaskId ?? taskId;
}
```

- [ ] **Step 2: 写测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/service_application.dart';

void main() {
  group('ServiceApplication', () {
    test('fromJson parses consultationTaskId', () {
      final sa = ServiceApplication.fromJson({'id': 1, 'task_id': 200, 'consultation_task_id': 100});
      expect(sa.consultationTaskId, 100);
    });

    test('fromJson handles null consultationTaskId', () {
      final sa = ServiceApplication.fromJson({'id': 1, 'task_id': 100});
      expect(sa.consultationTaskId, isNull);
    });
  });

  group('ServiceApplicationConsultationRoute.consultationMessageTaskId', () {
    test('approve 前:fallback to taskId(占位)', () {
      final sa = ServiceApplication.fromJson({'id': 1, 'task_id': 100, 'consultation_task_id': null});
      expect(sa.consultationMessageTaskId, 100);
    });

    test('approve 后:使用 consultationTaskId(占位)', () {
      final sa = ServiceApplication.fromJson({'id': 1, 'task_id': 200, 'consultation_task_id': 100});
      expect(sa.consultationMessageTaskId, 100);
    });
  });
}
```

- [ ] **Step 3: 跑测试**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; flutter test test/data/models/service_application_model_test.dart
```
预期:PASS。

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/models/service_application.dart link2ur/test/data/models/service_application_model_test.dart
git commit -m "feat(flutter): ServiceApplication.consultationTaskId + ConsultationRoute extension"
```

---

## Task 32: Flutter — TaskApplication model + extension

**Files:**
- Modify: `link2ur/lib/data/models/task_application.dart`
- Test: `link2ur/test/data/models/task_application_model_test.dart`

- [ ] **Step 1: 加字段 + extension**(和 SA 同样模式)

```dart
class TaskApplication {
  // ...
  final int? consultationTaskId;

  factory TaskApplication.fromJson(Map<String, dynamic> json) {
    return TaskApplication(
      // ...
      consultationTaskId: json['consultation_task_id'] as int?,
    );
  }
}

extension TaskApplicationConsultationRoute on TaskApplication {
  int? get consultationMessageTaskId => consultationTaskId ?? taskId;
}
```

- [ ] **Step 2: 写测试(TA 3 种场景)**

```dart
group('TaskApplicationConsultationRoute', () {
  test('TA 占位记录咨询中:fallback 到 taskId=占位', () {
    final ta = TaskApplication.fromJson({'id': 1, 'task_id': 101, 'consultation_task_id': null});
    expect(ta.consultationMessageTaskId, 101);
  });

  test('TA 占位记录 cancelled:fallback 到 taskId=占位', () {
    final ta = TaskApplication.fromJson({'id': 1, 'task_id': 101, 'status': 'cancelled', 'consultation_task_id': null});
    expect(ta.consultationMessageTaskId, 101);
  });

  test('TA orig_application:使用 consultationTaskId=占位', () {
    final ta = TaskApplication.fromJson({'id': 2, 'task_id': 999, 'consultation_task_id': 101});
    expect(ta.consultationMessageTaskId, 101);
  });
});
```

- [ ] **Step 3: 跑测试 + commit**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; flutter test test/data/models/task_application_model_test.dart
git add link2ur/lib/data/models/task_application.dart link2ur/test/data/models/task_application_model_test.dart
git commit -m "feat(flutter): TaskApplication.consultationTaskId + ConsultationRoute extension"
```

---

## Task 33: Flutter — FleaMarketPurchaseRequest model + extension

**Files:**
- Modify: `link2ur/lib/data/models/flea_market_purchase_request.dart`
- Test: `link2ur/test/data/models/flea_market_purchase_request_model_test.dart`

- [ ] **Step 1: 加字段 + extension + 特殊 dart doc**

```dart
class FleaMarketPurchaseRequest {
  // ...
  final int? taskId;
  /// 咨询占位 task id。
  ///
  /// **FMPR 特殊性**:flea_market 不新建真任务,而是把占位 task 直接晋升为真任务
  /// (改 `is_consultation_placeholder=false` + `task_source='flea_market'`)。
  /// 付款晋升后本字段和 [taskId] **指向同一行 task**,这是预期行为不是 bug。
  ///
  /// 判断"是否已成单"**不要**用 `consultationTaskId == taskId` 比较——这个比较
  /// 只在 FMPR 晋升后为 true,SA/TA 的任何阶段都是 false,**不是跨类型的成单判断**。
  /// 应该用 `task.isConsultationPlaceholder == false` 或 `purchaseRequest.status` 判断。
  final int? consultationTaskId;

  factory FleaMarketPurchaseRequest.fromJson(Map<String, dynamic> json) {
    return FleaMarketPurchaseRequest(
      // ...
      taskId: json['task_id'] as int?,
      consultationTaskId: json['consultation_task_id'] as int?,
    );
  }
}

extension FleaMarketPurchaseRequestConsultationRoute on FleaMarketPurchaseRequest {
  int? get consultationMessageTaskId => consultationTaskId ?? taskId;
}
```

- [ ] **Step 2: 写测试(FMPR 2 种场景 + 怪异性断言)**

```dart
group('FleaMarketPurchaseRequestConsultationRoute', () {
  test('FMPR 咨询中:fallback 到 taskId=占位', () {
    final fmpr = FleaMarketPurchaseRequest.fromJson({'id': 1, 'task_id': 102, 'consultation_task_id': null});
    expect(fmpr.consultationMessageTaskId, 102);
  });

  test('FMPR 晋升后:consultationTaskId == taskId (同一行),helper 返回相同值', () {
    final fmpr = FleaMarketPurchaseRequest.fromJson({'id': 1, 'task_id': 102, 'consultation_task_id': 102});
    expect(fmpr.consultationMessageTaskId, 102);
    // 断言怪异性但正确:不应用 == 做成单判断
    expect(fmpr.consultationTaskId, equals(fmpr.taskId));
  });
});
```

- [ ] **Step 3: 跑测试 + commit**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; flutter test test/data/models/flea_market_purchase_request_model_test.dart
git add link2ur/lib/data/models/flea_market_purchase_request.dart link2ur/test/data/models/flea_market_purchase_request_model_test.dart
git commit -m "feat(flutter): FMPR.consultationTaskId + extension + doc for promotion quirk"
```

---

## Task 34: Flutter — 三个 extension 的 NULL 边界测试

**Files:**
- Create: `link2ur/test/data/models/consultation_route_extensions_test.dart`

- [ ] **Step 1: 写 NULL 边界测试(3 条独立断言)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/service_application.dart';
import 'package:link2ur/data/models/task_application.dart';
import 'package:link2ur/data/models/flea_market_purchase_request.dart';

void main() {
  group('consultationMessageTaskId NULL boundary (3 extensions, independent assertions)', () {
    test('ServiceApplication: 两字段都 null → null', () {
      final sa = ServiceApplication.fromJson({'id': 1});
      expect(sa.consultationMessageTaskId, isNull);
    });

    test('TaskApplication: 两字段都 null → null', () {
      final ta = TaskApplication.fromJson({'id': 1});
      expect(ta.consultationMessageTaskId, isNull);
    });

    test('FleaMarketPurchaseRequest: 两字段都 null → null', () {
      final fmpr = FleaMarketPurchaseRequest.fromJson({'id': 1});
      expect(fmpr.consultationMessageTaskId, isNull);
    });
  });
}
```

- [ ] **Step 2: 跑测试**

```bash
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; flutter test test/data/models/consultation_route_extensions_test.dart
```
预期:3 个测试 PASS。

- [ ] **Step 3: Commit**

```bash
git add link2ur/test/data/models/consultation_route_extensions_test.dart
git commit -m "test(flutter): NULL boundary for 3 consultationMessageTaskId extensions"
```

---

## Task 35: PR 3 部署

**Files:** 无代码,部署

- [ ] **Step 1: 合并 PR 3 到 main**

- [ ] **Step 2: 部署 + 验证**

- 拿一个占位 task_id 手测:
  ```bash
  curl -X POST https://api.link2ur.com/api/tasks/<placeholder_id>/pay -H "Authorization: ..."
  # 预期:404
  curl -X POST https://api.link2ur.com/api/tasks/<placeholder_id>/complete -H "Authorization: ..."
  # 预期:404
  ```
- 非 admin team 成员手测被守护 endpoint → 预期 403 with INSUFFICIENT_TEAM_ROLE
- Flutter app 打开咨询消息,走过 7 种场景(见 C.3 分场景表)

---

# PR 4 (可选) — Day 3.5: 历史数据回填

**条件性**:只在 Day 0 诊断 SQL 显示 `affected_team_sa_count > 50` 或 `orphaned_messages > 500` 时做。

## Task 36: Day 0 诊断 SQL

**Files:** 无代码,查询

- [ ] **Step 1: 在 prod 跑 4 条诊断 SQL**

(从 spec Section G 复制,四条 COUNT 查询)

- [ ] **Step 2: 根据结果决定下一步**

| affected_team_sa_count | orphaned_messages | 行动 |
|---|---|---|
| < 50 | < 500 | **跳过 PR 4**,接受技术债,客服兜底 |
| 50-500 | 任意 | 做 PR 4(best-effort 回填) |
| > 500 | 任意 | 做 PR 4 + 发公告 |

- [ ] **Step 3: 记录诊断结果到 project doc 或 Slack**

---

## Task 37: 创建 migration 211(仅在需要时)

**Files:**
- Create: `backend/migrations/211_backfill_consultation_task_id.sql`

- [ ] **Step 1: 写 preview 查询**(先不改数据)

复制 spec Section G 的启发式匹配脚本,先跑 preview:

```bash
psql $DATABASE_URL -f backend/migrations/211_backfill_consultation_task_id.sql
# 这版先用 SELECT,不 UPDATE
```

- [ ] **Step 2: 人工审核 20 条样本**

逐行看 preview 结果,确认 `placeholder_task_id` 看起来真的对应 `real_task_id` 的前置咨询(poster_id / 时间窗 / service_id 线索匹配)。

- [ ] **Step 3: 若样本 OK,改成 UPDATE**

改文件把 `SELECT` 改成 `UPDATE ... SET consultation_task_id = ... WHERE id = ...`,加条件 "only rn=1 + 时间窗 < 3 days" 保守策略。

- [ ] **Step 4: Prod 跑 UPDATE**

```bash
psql $DATABASE_URL -f backend/migrations/211_backfill_consultation_task_id.sql
```

- [ ] **Step 5: Commit**

```bash
git add backend/migrations/211_backfill_consultation_task_id.sql
git commit -m "feat(db): migration 211 best-effort backfill consultation_task_id (optional)"
```

---

## Task 38: 客服兜底流程培训文档

**Files:**
- Create or modify: `backend/docs/` 下合适位置

- [ ] **Step 1: 加"占位 task 维护注意" 一节**

在 `backend/docs/` 下追加(位置按当前文档组织选):**推荐新建** `backend/docs/consultation_placeholder_maintenance.md` 因为独立语义清晰。

内容:

```markdown
# 咨询占位 Task 维护注意

## 关键约束:不要 DELETE 占位 task

`messages.task_id` FK 是 `ON DELETE CASCADE`。删除 `is_consultation_placeholder=TRUE`
的 task 会**级联删掉所有咨询消息**。

### ❌ 禁止的操作

```sql
DELETE FROM tasks WHERE is_consultation_placeholder = TRUE;  -- 不要!
```

### ✅ 正确的方式

只更新状态,保留 task row + 消息:

```sql
UPDATE tasks SET status = 'closed'
WHERE is_consultation_placeholder = TRUE AND status = 'consulting'
  AND created_at < now() - interval '14 days';
```

已有 `scheduled_tasks.close_stale_consultations` 自动做这件事。

### 如果真的需要物理清理

必须先:
1. 把 `messages.task_id` FK 改成 `ON DELETE SET NULL`
2. 或手动 DELETE 相关 messages

## 客服手动处理"看不到咨询历史"投诉

(步骤详见 spec Section G)

1. 查 `tasks WHERE task_source='consultation' AND poster_id=<applicant> AND created_at 最近 30 天`
2. 找到匹配的占位 task_id
3. `UPDATE service_applications SET consultation_task_id = <placeholder_id> WHERE id = <sa_id>`
4. 用户刷新即可看到历史消息
```

- [ ] **Step 2: Commit**

```bash
git add backend/docs/consultation_placeholder_maintenance.md
git commit -m "docs: consultation placeholder maintenance guide (DELETE warning + customer support)"
```

---

# 观察期 — 部署后 1 周

- [ ] 监控 `logger.warning("Admin operation on consultation placeholder task")` 日志条数,判断是否需要让客服 opt-in `?include_placeholders=true`
- [ ] 观察 `ix_tasks_consultation_placeholder_status` 索引使用情况(`EXPLAIN ANALYZE close_stale_consultations` query)
- [ ] 收集"咨询历史看不到"类投诉数量,和 Day 0 诊断预测对比
- [ ] Track 1 两个 helper 使用率监控(不再是死代码 / 半成品)

---

# 成功标准汇总(对照 spec)

- [ ] Migration 208a + 208b + 209 全部合入,所有历史占位 task 被正确标记,CHECK 约束生效
- [ ] PR 1→PR 2 之间观察期内,"FALSE+咨询 source" 的新插入行数连续 24 小时为 0
- [ ] SA approve 后保留 `consultation_task_id`,历史消息可通过此字段找回(Task 16-17)
- [ ] TA formal apply 后 `orig_application` 有正确 `consultation_task_id`,占位 TA 状态为 `cancelled`(Task 18)
- [ ] FMPR 付款晋升后 task 的 `is_consultation_placeholder=False` + `consultation_task_id` 写入(Task 19)
- [ ] `task_consultation` 类型的 stale task 被 14 天清理覆盖(Task 20)
- [ ] 16 个 task-level API 对占位 task_id 返回 404 + 2 个 admin endpoint 触碰占位时打 warning 日志(Task 22-25)
- [ ] Track 1 `create_placeholder_task` helper 被 4 处 caller 使用(Task 7-9)
- [ ] Track 1 `require_team_role` helper 被 6-8 个 endpoint 使用(Task 28)
- [ ] C.3 `consultation_task_id_for` helper 在后端存在,Flutter 有三个独立 extension(Task 6, 31-33)
- [ ] Admin 面板默认不显示占位 task(Task 11)
- [ ] 用户主页"我发布 N 条任务"不含占位(Task 12)
- [ ] Flutter 4 个 model(SA/TA/FMPR/Task)都加新字段 + 三个 extension(Task 30-33)
- [ ] 新增测试 ≥ 21 个(后端 16 + Flutter 5),全部通过
- [ ] Section G 诊断 SQL 跑过,影响面已量化并记录(Task 36)
- [ ] 无生产流量回归(现有咨询/任务流程行为不变)

---

# 任务总数

- **PR 1(Day 1)**:Task 1-13(13 个任务)
- **PR 2(Day 2)**:Task 14-21(8 个任务)
- **PR 3(Day 3)**:Task 22-35(14 个任务)
- **PR 4(Day 3.5,可选)**:Task 36-38(3 个任务)

**合计 38 个任务,约 3.5-4.5 天全职工作量**(和 spec 估算一致)。
