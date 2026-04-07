# 达人团队作为任务接单方 —— 实施计划 v2

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"达人任务的接单方"从自然人升级为达人团队,客户付款通过 Stripe Manual Transfer 直达团队 Stripe Connect 账户。**复用现有 `payment_transfer_service.py` 全部基础设施**,只扩展支持团队 destination。

**Architecture:** 加 `tasks.taker_expert_id` 列承载经济主体;`taker_id` 仍填团队 owner(Y 方案);**扩展现有 `payment_transfers` 表加 6 列**(不新建审计表);**修改现有 `payment_transfer_service.execute_transfer`** 在 `taker_expert_id` 非空时把 destination 切到 `experts.stripe_account_id`;Stripe Onboarding 端点 `POST /api/experts/{id}/stripe-connect` **已存在**,只需补 `account.updated` webhook handler。

**Tech Stack:** FastAPI + SQLAlchemy(async + sync) + Stripe Connect (Express type) + PostgreSQL + pytest + pytest-asyncio

**Spec Reference:** `docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md` (v2)
**Discovery Reference:** `docs/superpowers/plans/2026-04-07-expert-team-discovery.md`

**v2 Plan vs v1:**
- Phase 0 (Discovery) 已完成 ✅
- Phase 1.3: 改为 ALTER `payment_transfers` 加 6 列(原 v1 是 CREATE 新表)
- Phase 3: 删掉 Stripe Onboarding 端点创建任务(已存在),只剩 webhook 改动
- Phase 4.4: 简化(D1 确认已是 manual transfer)
- Phase 6: 280 行新 Celery 任务 → ~50 行扩展现有 `execute_transfer`
- Phase 7: 改为在现有 webhook handler / refund_service 里 hook 进去

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `backend/migrations/176_add_tasks_taker_expert_id.sql` | 加 taker_expert_id 列 |
| Create | `backend/migrations/177_add_activities_owner_polymorphic.sql` | 多态所有权 |
| Create | `backend/migrations/178_extend_payment_transfers_for_team_taker.sql` | **ALTER 现有表加 6 列** |
| Create | `backend/migrations/179_add_tasks_payment_completed_at.sql` | 90 天时效检查需要 |
| Create | `backend/migrations/180_backfill_tasks_taker_expert.sql` | 在飞任务回填 |
| Modify | `backend/app/models.py` | Task/Activity/PaymentTransfer 字段扩展 |
| Create | `backend/app/services/expert_task_resolver.py` | resolve_task_taker_from_service/activity helper |
| Modify | `backend/app/payment_transfer_service.py` | execute_transfer 加 taker_expert_id 分支(核心改动) |
| Create | `backend/app/expert_activity_routes.py` | POST /api/experts/{id}/activities |
| Create | `backend/app/expert_earnings_routes.py` | 团队任务列表 / earnings summary / transfer 历史 |
| Create | `backend/app/serializers/task_taker_display.py` | build_taker_display() |
| Modify | `backend/app/expert_service_routes.py:106-133` | Stripe + GBP 门槛 |
| Modify | `backend/app/task_expert_routes.py:3090-3130` | 咨询任务 → 调 helper |
| Modify | `backend/app/task_expert_routes.py:3820-3860` | 正式服务任务 → 调 helper |
| Modify | `backend/app/multi_participant_routes.py` | 活动报名 → 调 helper |
| Modify | `backend/app/routers.py` (~6536) | account.updated webhook 分支 |
| Modify | `backend/app/routers.py` (7620) | charge.dispute.created handler 追加团队反向 |
| Modify | `backend/app/refund_service.py` (131) | 反向时填新字段 stripe_reversal_id/reversed_at/reversed_reason |
| Modify | `backend/app/celery_tasks.py` | 加 60 天 Transfer 时效预警 daily task |
| Modify | `backend/app/expert_routes.py` (1250) | (可选)放宽 status 端点 required_roles |
| Modify | `backend/app/expert_routes.py:833` | ownership transfer 同步未完成任务 taker_id |
| Create | `backend/tests/test_expert_task_resolver.py` | helper 单元测试 |
| Create | `backend/tests/test_payment_transfer_team_extension.py` | execute_transfer 团队分支测试 |
| Create | `backend/tests/test_expert_publish_endpoints.py` | 服务/活动发布门槛 |
| Create | `backend/tests/test_team_dispute_reversal.py` | dispute 反向 hook |
| Create | `backend/tests/test_expert_earnings_routes.py` | 三个查询端点 |
| Create | `backend/tests/test_taker_display_serializer.py` | serializer |
| Create | `backend/tests/test_e2e_team_task_money_flow.py` | 端到端冒烟 |

---

# Phase 0: Discovery ✅ 已完成

见 `docs/superpowers/plans/2026-04-07-expert-team-discovery.md`。所有 15 项 grep 已完成,§4.4 决策走 **A 路径**(已是 manual transfer)。

---

# Phase 1: Schema Migrations + ORM Models

### Task 1.1: Migration 176 — tasks 加 taker_expert_id

**Files:**
- Create: `backend/migrations/176_add_tasks_taker_expert_id.sql`

- [ ] **Step 1:** 创建文件:

```sql
-- ===========================================
-- 迁移 176: tasks 加 taker_expert_id 列
-- spec §1.1
-- ===========================================
BEGIN;

ALTER TABLE tasks
  ADD COLUMN taker_expert_id VARCHAR(8) NULL
    REFERENCES experts(id) ON DELETE RESTRICT;

CREATE INDEX ix_tasks_taker_expert
  ON tasks(taker_expert_id)
  WHERE taker_expert_id IS NOT NULL;

COMMENT ON COLUMN tasks.taker_id IS
  '任务接单自然人。团队接单时填团队 owner 的 user_id 作为"团队代表"。';
COMMENT ON COLUMN tasks.taker_expert_id IS
  '团队接单时的经济主体。非 NULL 时钱转到 experts.stripe_account_id。';

COMMIT;
```

- [ ] **Step 2:** 跑迁移 + 验证字段:

```bash
psql $DATABASE_URL -f backend/migrations/176_add_tasks_taker_expert_id.sql
psql $DATABASE_URL -c "\d tasks" | grep taker_expert_id
```

预期: 看到 `taker_expert_id | character varying(8)`

- [ ] **Step 3:** Commit

```bash
git add backend/migrations/176_add_tasks_taker_expert_id.sql
git commit -m "feat(db): add tasks.taker_expert_id for team-as-taker"
```

### Task 1.2: Migration 177 — activities 多态所有权

**Files:**
- Create: `backend/migrations/177_add_activities_owner_polymorphic.sql`

- [ ] **Step 1:**

```sql
BEGIN;

ALTER TABLE activities
  ADD COLUMN owner_type VARCHAR(20) NOT NULL DEFAULT 'user'
    CHECK (owner_type IN ('user', 'expert')),
  ADD COLUMN owner_id VARCHAR(8) NULL;

UPDATE activities SET owner_id = expert_id WHERE owner_id IS NULL;

ALTER TABLE activities ALTER COLUMN owner_id SET NOT NULL;

CREATE INDEX ix_activities_owner ON activities(owner_type, owner_id);

COMMENT ON COLUMN activities.owner_type IS '所有权: user=个人, expert=达人团队';
COMMENT ON COLUMN activities.owner_id IS 'user 时指 users.id; expert 时指 experts.id';
COMMENT ON COLUMN activities.expert_id IS '[legacy] 原 user_id 字段,团队活动时填 owner.user_id';

COMMIT;
```

- [ ] **Step 2:** 跑迁移 + 验证 NULL count = 0:

```bash
psql $DATABASE_URL -f backend/migrations/177_add_activities_owner_polymorphic.sql
psql $DATABASE_URL -c "SELECT COUNT(*) FROM activities WHERE owner_id IS NULL;"
```

- [ ] **Step 3:** Commit

```bash
git add backend/migrations/177_add_activities_owner_polymorphic.sql
git commit -m "feat(db): add activities polymorphic ownership"
```

### Task 1.3: Migration 178 — 扩展 payment_transfers(v2 核心改动)

**Files:**
- Create: `backend/migrations/178_extend_payment_transfers_for_team_taker.sql`

- [ ] **Step 1:**

```sql
-- ===========================================
-- 迁移 178: 扩展 payment_transfers 支持团队接单
-- spec §1.3 (v2)
-- ===========================================
BEGIN;

-- 1. 加新字段
ALTER TABLE payment_transfers
  ADD COLUMN taker_expert_id VARCHAR(8) NULL
    REFERENCES experts(id) ON DELETE RESTRICT,
  ADD COLUMN idempotency_key VARCHAR(64) NULL,
  ADD COLUMN stripe_charge_id VARCHAR(255) NULL,
  ADD COLUMN stripe_reversal_id VARCHAR(255) NULL,
  ADD COLUMN reversed_at TIMESTAMPTZ NULL,
  ADD COLUMN reversed_reason TEXT NULL;

-- 2. 回填现有行的 idempotency_key
UPDATE payment_transfers
SET idempotency_key = 'legacy_' || id::text
WHERE idempotency_key IS NULL;

-- 3. 加约束
ALTER TABLE payment_transfers
  ALTER COLUMN idempotency_key SET NOT NULL,
  ADD CONSTRAINT uq_payment_transfers_idempotency UNIQUE (idempotency_key);

-- 4. 索引
CREATE INDEX ix_pt_taker_expert
  ON payment_transfers(taker_expert_id)
  WHERE taker_expert_id IS NOT NULL;

CREATE INDEX ix_pt_charge
  ON payment_transfers(stripe_charge_id)
  WHERE stripe_charge_id IS NOT NULL;

-- 5. status 取值约束
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_payment_transfers_status'
  ) THEN
    ALTER TABLE payment_transfers
      ADD CONSTRAINT chk_payment_transfers_status
      CHECK (status IN ('pending','succeeded','failed','retrying','reversed'));
  END IF;
END $$;

COMMENT ON COLUMN payment_transfers.taker_expert_id IS
  '团队接单时填团队 ID。非 NULL 时 destination 是 experts.stripe_account_id。';
COMMENT ON COLUMN payment_transfers.idempotency_key IS
  '幂等键。新行: task_{task_id}_transfer。老行: legacy_{id}。';

COMMIT;
```

- [ ] **Step 2:** 跑迁移:

```bash
psql $DATABASE_URL -f backend/migrations/178_extend_payment_transfers_for_team_taker.sql
psql $DATABASE_URL -c "\d payment_transfers" | grep -E "taker_expert|idempotency|stripe_reversal|reversed_"
```

预期: 看到 6 个新字段

- [ ] **Step 3:** 验证现有行 idempotency_key 都填了:

```bash
psql $DATABASE_URL -c "SELECT COUNT(*) FROM payment_transfers WHERE idempotency_key IS NULL;"
```

预期: 0

- [ ] **Step 4:** Commit

```bash
git add backend/migrations/178_extend_payment_transfers_for_team_taker.sql
git commit -m "feat(db): extend payment_transfers for team taker (v2)"
```

### Task 1.4: Migration 179 — tasks 加 payment_completed_at

**Files:**
- Create: `backend/migrations/179_add_tasks_payment_completed_at.sql`

- [ ] **Step 1:**

```sql
BEGIN;

ALTER TABLE tasks ADD COLUMN payment_completed_at TIMESTAMPTZ NULL;

CREATE INDEX ix_tasks_payment_completed_at
  ON tasks(payment_completed_at)
  WHERE payment_completed_at IS NOT NULL;

COMMENT ON COLUMN tasks.payment_completed_at IS
  '客户付款 Stripe charge 成功的时间。用于 Stripe Transfer 90 天时效检查 (spec §3.4a)。';

COMMIT;
```

- [ ] **Step 2:** 跑 + 验证

- [ ] **Step 3:** Commit

### Task 1.5: SQLAlchemy 模型扩展(Task + Activity + PaymentTransfer)

**Files:**
- Modify: `backend/app/models.py`

- [ ] **Step 1:** 在 Task 类(grep `class Task(Base)` 定位)的 `taker_id` 后面加:

```python
taker_expert_id = Column(String(8), ForeignKey("experts.id", ondelete="RESTRICT"), nullable=True)
payment_completed_at = Column(DateTime(timezone=True), nullable=True)
```

- [ ] **Step 2:** 在 Activity 类(grep `class Activity(Base)` 定位)字段定义里加:

```python
owner_type = Column(String(20), nullable=False, server_default='user')
owner_id = Column(String(8), nullable=False)
```

- [ ] **Step 3:** 在 PaymentTransfer 类(`models.py:3248`)字段定义里追加 6 个字段:

```python
taker_expert_id = Column(String(8), ForeignKey("experts.id", ondelete="RESTRICT"), nullable=True)
idempotency_key = Column(String(64), nullable=False, unique=True)
stripe_charge_id = Column(String(255), nullable=True)
stripe_reversal_id = Column(String(255), nullable=True)
reversed_at = Column(DateTime(timezone=True), nullable=True)
reversed_reason = Column(Text, nullable=True)
```

- [ ] **Step 4:** Verify import 不报错:

```bash
cd backend && python -c "from app.models import Task, Activity, PaymentTransfer; print(Task.taker_expert_id, Activity.owner_type, PaymentTransfer.idempotency_key)"
```

- [ ] **Step 5:** Commit

```bash
git add backend/app/models.py
git commit -m "feat(models): extend Task/Activity/PaymentTransfer for team taker"
```

---

# Phase 2: Helper Functions

### Task 2.1: 写 resolve_task_taker_from_service 测试

**Files:**
- Create: `backend/tests/test_expert_task_resolver.py`

- [ ] **Step 1:**

```python
"""单元测试 expert_task_resolver. spec §4.2"""
import pytest
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException


@pytest.fixture
def mock_db():
    db = MagicMock()
    db.get = AsyncMock()
    db.execute = AsyncMock()
    return db


@pytest.fixture
def fake_service():
    s = MagicMock()
    s.owner_type = 'expert'
    s.owner_id = 'e_test01'
    s.currency = 'GBP'
    return s


@pytest.fixture
def fake_expert():
    e = MagicMock()
    e.id = 'e_test01'
    e.stripe_onboarding_complete = True
    return e


@pytest.fixture
def fake_owner_member():
    m = MagicMock()
    m.user_id = 'u_owner01'
    m.role = 'owner'
    m.status = 'active'
    return m


@pytest.mark.asyncio
async def test_resolve_service_team_happy_path(mock_db, fake_service, fake_expert, fake_owner_member):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = fake_owner_member
    mock_db.execute.return_value = result_obj

    taker_id, taker_expert_id = await resolve_task_taker_from_service(mock_db, fake_service)
    assert taker_id == 'u_owner01'
    assert taker_expert_id == 'e_test01'


@pytest.mark.asyncio
async def test_resolve_service_user_personal(mock_db):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    s = MagicMock()
    s.owner_type = 'user'
    s.owner_id = 'u_personal01'
    taker_id, taker_expert_id = await resolve_task_taker_from_service(mock_db, s)
    assert taker_id == 'u_personal01'
    assert taker_expert_id is None


@pytest.mark.asyncio
async def test_resolve_service_team_no_stripe(mock_db, fake_service, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    fake_expert.stripe_onboarding_complete = False
    mock_db.get.return_value = fake_expert
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, fake_service)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_stripe_not_ready'


@pytest.mark.asyncio
async def test_resolve_service_team_non_gbp(mock_db, fake_service, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    fake_service.currency = 'USD'
    mock_db.get.return_value = fake_expert
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, fake_service)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_currency_unsupported'


@pytest.mark.asyncio
async def test_resolve_service_team_no_owner(mock_db, fake_service, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = result_obj
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, fake_service)
    assert exc.value.status_code == 500
    assert exc.value.detail['error_code'] == 'expert_owner_missing'


@pytest.mark.asyncio
async def test_resolve_service_unknown_owner_type(mock_db):
    from app.services.expert_task_resolver import resolve_task_taker_from_service
    s = MagicMock()
    s.owner_type = 'alien'
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, s)
    assert exc.value.status_code == 500
```

- [ ] **Step 2:** 跑测试 confirm fail:

```bash
cd backend && pytest tests/test_expert_task_resolver.py -v
```

预期: 6 个 fail (ImportError)

- [ ] **Step 3:** Commit

### Task 2.2: 实现 resolve_task_taker_from_service

**Files:**
- Create: `backend/app/services/__init__.py`(若不存在)
- Create: `backend/app/services/expert_task_resolver.py`

- [ ] **Step 1:**

```bash
test -d backend/app/services || mkdir -p backend/app/services && touch backend/app/services/__init__.py
```

- [ ] **Step 2:** 创建 resolver 文件:

```python
"""
Resolve (taker_id, taker_expert_id) from expert_service or activity.
spec §4.2 §4.3a
"""
from typing import Optional, Tuple
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException

from app import models
from app.models_expert import Expert, ExpertMember


async def resolve_task_taker_from_service(
    db: AsyncSession,
    service: "models.TaskExpertService",
) -> Tuple[str, Optional[str]]:
    """
    返回 (taker_id, taker_expert_id):
      - owner_type='expert': (team_owner.user_id, expert.id)
      - owner_type='user':   (service.owner_id, None)
    """
    if service.owner_type == 'expert':
        expert = await db.get(Expert, service.owner_id)
        if not expert:
            raise HTTPException(status_code=404, detail="Expert team not found")
        if not expert.stripe_onboarding_complete:
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_stripe_not_ready",
                "message": "This service is temporarily unavailable",
            })
        if (service.currency or 'GBP').upper() != 'GBP':
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_currency_unsupported",
                "message": "Team services only support GBP currently",
            })

        result = await db.execute(
            select(ExpertMember).where(
                ExpertMember.expert_id == expert.id,
                ExpertMember.role == 'owner',
                ExpertMember.status == 'active',
            ).limit(1)
        )
        owner = result.scalar_one_or_none()
        if not owner:
            raise HTTPException(status_code=500, detail={
                "error_code": "expert_owner_missing",
                "message": "Team has no active owner",
            })
        return (owner.user_id, expert.id)

    elif service.owner_type == 'user':
        return (service.owner_id, None)

    else:
        raise HTTPException(
            status_code=500,
            detail=f"Unknown service owner_type: {service.owner_type}"
        )
```

- [ ] **Step 3:** 跑测试:

```bash
cd backend && pytest tests/test_expert_task_resolver.py -v
```

预期: 6 PASS

- [ ] **Step 4:** Commit

```bash
git add backend/app/services/__init__.py backend/app/services/expert_task_resolver.py
git commit -m "feat(resolver): resolve_task_taker_from_service helper"
```

### Task 2.3: 写并实现 resolve_task_taker_from_activity

**Files:**
- Modify: `backend/tests/test_expert_task_resolver.py`
- Modify: `backend/app/services/expert_task_resolver.py`

- [ ] **Step 1:** 测试追加(在文件末尾):

```python
@pytest.fixture
def fake_activity():
    a = MagicMock()
    a.owner_type = 'expert'
    a.owner_id = 'e_test01'
    a.currency = 'GBP'
    a.expert_id = 'u_legacy01'
    return a


@pytest.mark.asyncio
async def test_resolve_activity_team_happy_path(mock_db, fake_activity, fake_expert, fake_owner_member):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = fake_owner_member
    mock_db.execute.return_value = result_obj
    taker_id, taker_expert_id = await resolve_task_taker_from_activity(mock_db, fake_activity)
    assert taker_id == 'u_owner01'
    assert taker_expert_id == 'e_test01'


@pytest.mark.asyncio
async def test_resolve_activity_user_legacy(mock_db):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    a = MagicMock()
    a.owner_type = 'user'
    a.expert_id = 'u_legacy01'
    taker_id, taker_expert_id = await resolve_task_taker_from_activity(mock_db, a)
    assert taker_id == 'u_legacy01'
    assert taker_expert_id is None


@pytest.mark.asyncio
async def test_resolve_activity_team_non_gbp(mock_db, fake_activity, fake_expert):
    from app.services.expert_task_resolver import resolve_task_taker_from_activity
    fake_activity.currency = 'EUR'
    mock_db.get.return_value = fake_expert
    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_activity(mock_db, fake_activity)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_currency_unsupported'
```

- [ ] **Step 2:** Implementation 追加到 `expert_task_resolver.py`:

```python
async def resolve_task_taker_from_activity(
    db: AsyncSession,
    activity: "models.Activity",
) -> Tuple[str, Optional[str]]:
    if activity.owner_type == 'expert':
        expert = await db.get(Expert, activity.owner_id)
        if not expert:
            raise HTTPException(status_code=404, detail="Expert team not found")
        if not expert.stripe_onboarding_complete:
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_stripe_not_ready",
                "message": "Team is temporarily unable to accept sign-ups",
            })
        if (activity.currency or 'GBP').upper() != 'GBP':
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_currency_unsupported",
                "message": "Team activities only support GBP currently",
            })

        result = await db.execute(
            select(ExpertMember).where(
                ExpertMember.expert_id == expert.id,
                ExpertMember.role == 'owner',
                ExpertMember.status == 'active',
            ).limit(1)
        )
        owner = result.scalar_one_or_none()
        if not owner:
            raise HTTPException(status_code=500, detail={
                "error_code": "expert_owner_missing",
                "message": "Team has no active owner",
            })
        return (owner.user_id, expert.id)

    elif activity.owner_type == 'user':
        return (activity.expert_id, None)

    else:
        raise HTTPException(
            status_code=500,
            detail=f"Unknown activity owner_type: {activity.owner_type}"
        )
```

- [ ] **Step 3:** 跑全部 resolver 测试:

```bash
cd backend && pytest tests/test_expert_task_resolver.py -v
```

预期: 9 PASS

- [ ] **Step 4:** Commit

```bash
git add backend/app/services/expert_task_resolver.py backend/tests/test_expert_task_resolver.py
git commit -m "feat(resolver): add resolve_task_taker_from_activity"
```

---

# Phase 3: Stripe Webhook 扩展

> **v2 大幅简化:** Stripe Onboarding 端点 (`POST /api/experts/{id}/stripe-connect`, `GET /api/experts/{id}/stripe-connect/status`) **已存在**于 `expert_routes.py:1176-1291`。本 phase 只加 webhook + 一个可选的权限放宽。

### Task 3.1: account.updated webhook 测试

**Files:**
- Create: `backend/tests/test_stripe_webhook_handlers_team.py`

- [ ] **Step 1:**

```python
"""测试 webhook account.updated 对达人团队的处理. spec §2.4"""
import json
import pytest
from unittest.mock import patch, MagicMock


def _build_event(event_type, obj_data):
    return {
        'id': 'evt_test01',
        'type': event_type,
        'data': {'object': obj_data},
    }


def test_account_updated_charges_disabled_suspends_team_services(
    client, db_session, test_expert_with_stripe, test_active_team_service
):
    """charges_enabled 从 True 变 False:挂起所有 active 团队服务."""
    test_expert_with_stripe.stripe_onboarding_complete = True
    test_active_team_service.status = 'active'
    db_session.commit()

    payload_dict = _build_event('account.updated', {
        'id': test_expert_with_stripe.stripe_account_id,
        'charges_enabled': False,
    })
    payload = json.dumps(payload_dict)

    with patch('stripe.Webhook.construct_event') as mock_verify:
        mock_event = MagicMock()
        mock_event.type = 'account.updated'
        mock_event.data.object.id = test_expert_with_stripe.stripe_account_id
        mock_event.data.object.charges_enabled = False
        mock_verify.return_value = mock_event
        client.post('/api/stripe/webhook', data=payload, headers={'Stripe-Signature': 'fake'})

    db_session.refresh(test_expert_with_stripe)
    db_session.refresh(test_active_team_service)
    assert test_expert_with_stripe.stripe_onboarding_complete is False
    assert test_active_team_service.status == 'inactive'


def test_account_updated_charges_enabled_unfreezes(
    client, db_session, test_expert_with_stripe
):
    """charges_enabled 从 False 变 True:复原 stripe_onboarding_complete."""
    test_expert_with_stripe.stripe_onboarding_complete = False
    db_session.commit()

    payload_dict = _build_event('account.updated', {
        'id': test_expert_with_stripe.stripe_account_id,
        'charges_enabled': True,
    })
    payload = json.dumps(payload_dict)

    with patch('stripe.Webhook.construct_event') as mock_verify:
        mock_event = MagicMock()
        mock_event.type = 'account.updated'
        mock_event.data.object.id = test_expert_with_stripe.stripe_account_id
        mock_event.data.object.charges_enabled = True
        mock_verify.return_value = mock_event
        client.post('/api/stripe/webhook', data=payload, headers={'Stripe-Signature': 'fake'})

    db_session.refresh(test_expert_with_stripe)
    assert test_expert_with_stripe.stripe_onboarding_complete is True


def test_account_updated_unrelated_account_ignored(client, db_session):
    """非团队账户的 account.updated:静默无视."""
    payload_dict = _build_event('account.updated', {
        'id': 'acct_random',
        'charges_enabled': True,
    })
    payload = json.dumps(payload_dict)

    with patch('stripe.Webhook.construct_event') as mock_verify:
        mock_event = MagicMock()
        mock_event.type = 'account.updated'
        mock_event.data.object.id = 'acct_random'
        mock_event.data.object.charges_enabled = True
        mock_verify.return_value = mock_event
        resp = client.post('/api/stripe/webhook', data=payload, headers={'Stripe-Signature': 'fake'})

    assert resp.status_code == 200
```

- [ ] **Step 2:** 跑测试 fail。

- [ ] **Step 3:** Commit

### Task 3.2: 实现 account.updated webhook handler

**Files:**
- Modify: `backend/app/routers.py`(在 `routers.py:6536` 附近的 webhook handler 函数里加分支)

- [ ] **Step 1:** 找到现有 webhook handler(grep `event.type == "charge.dispute.created"` 定位上下文,在 `event_type` 系列 elif 链里加一个分支):

```python
elif event_type == 'account.updated':
    from app.models_expert import Expert
    from sqlalchemy import update as sql_update
    acct = event_data
    acct_id = acct.get('id') if isinstance(acct, dict) else acct.id
    charges_enabled = acct.get('charges_enabled') if isinstance(acct, dict) else acct.charges_enabled

    expert = db.query(Expert).filter(Expert.stripe_account_id == acct_id).first()
    if not expert:
        # 不是团队账户,无视
        pass
    else:
        new_status = bool(charges_enabled)
        if expert.stripe_onboarding_complete != new_status:
            expert.stripe_onboarding_complete = new_status
            if not new_status:
                # 断开时挂起所有 active 团队服务
                db.query(models.TaskExpertService).filter(
                    models.TaskExpertService.owner_type == 'expert',
                    models.TaskExpertService.owner_id == expert.id,
                    models.TaskExpertService.status == 'active'
                ).update({'status': 'inactive'}, synchronize_session=False)
            db.commit()
            logger.info(f"Expert {expert.id} stripe_onboarding_complete updated to {new_status}")
```

- [ ] **Step 2:** 跑测试 PASS。

- [ ] **Step 3:** **手动**在 Stripe Dashboard → Developers → Webhooks 给现有 endpoint 订阅:
  - `account.updated`(Connected accounts)
  - 确认勾选 "Listen to events on Connected accounts"

- [ ] **Step 4:** Commit

```bash
git add backend/app/routers.py backend/tests/test_stripe_webhook_handlers_team.py
git commit -m "feat(webhook): handle account.updated to sync expert stripe state"
```

### Task 3.3:(可选)放宽 stripe-connect/status required_roles

**Files:**
- Modify: `backend/app/expert_routes.py:1259`

- [ ] **Step 1:** 找到 `_get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])` 在 status 端点里(line 1259),改为:

```python
await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin", "member"])
```

让普通成员也能在达人管理页面看到 Stripe 状态。

- [ ] **Step 2:** 写一个简单测试 confirm member 也能 200。

- [ ] **Step 3:** Commit

---

# Phase 4: 老 task_expert_routes.py 内部重写

### Task 4.1: 服务发布端点加 Stripe + GBP 门槛

**Files:**
- Modify: `backend/app/expert_service_routes.py:106-133`

- [ ] **Step 1:** 找到 `POST /api/experts/{expert_id}/services` handler。在已有的 `_get_member_or_403` 之后加:

```python
expert = await db.get(Expert, expert_id)
if not expert:
    raise HTTPException(404, "Expert team not found")
if not expert.stripe_onboarding_complete:
    raise HTTPException(status_code=409, detail={
        "error_code": "expert_stripe_not_ready",
        "message": "Team must complete Stripe onboarding before publishing services",
    })

if (body.currency or 'GBP').upper() != 'GBP':
    raise HTTPException(status_code=422, detail={
        "error_code": "expert_currency_unsupported",
        "message": "Team services only support GBP currently",
    })
```

确认 `Expert` 已 import,如果没有则加 `from app.models_expert import Expert`。

- [ ] **Step 2:** 写测试 `backend/tests/test_expert_publish_endpoints.py`:

```python
def test_publish_service_blocked_no_stripe(client, db_session, test_expert_no_stripe, team_owner_user):
    test_expert_no_stripe.stripe_onboarding_complete = False
    db_session.commit()
    resp = client.post(
        f"/api/experts/{test_expert_no_stripe.id}/services",
        json={'service_name': 'Test', 'base_price': 100, 'currency': 'GBP', 'category': 'test'},
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert resp.status_code == 409
    assert resp.json()['detail']['error_code'] == 'expert_stripe_not_ready'


def test_publish_service_blocked_non_gbp(client, db_session, test_expert_with_stripe, team_owner_user):
    resp = client.post(
        f"/api/experts/{test_expert_with_stripe.id}/services",
        json={'service_name': 'Test', 'base_price': 100, 'currency': 'USD', 'category': 'test'},
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert resp.status_code == 422
    assert resp.json()['detail']['error_code'] == 'expert_currency_unsupported'


def test_publish_service_succeeds_when_ready(client, db_session, test_expert_with_stripe, team_owner_user):
    resp = client.post(
        f"/api/experts/{test_expert_with_stripe.id}/services",
        json={'service_name': 'Test', 'base_price': 100, 'currency': 'GBP', 'category': 'test'},
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert resp.status_code in (200, 201)
```

- [ ] **Step 3:** 跑测试 PASS。

- [ ] **Step 4:** Commit

```bash
git add backend/app/expert_service_routes.py backend/tests/test_expert_publish_endpoints.py
git commit -m "feat(expert): gate service publish on Stripe + GBP"
```

### Task 4.2: 咨询任务创建调 helper

**Files:**
- Modify: `backend/app/task_expert_routes.py:3090-3130`

- [ ] **Step 1:** 找到咨询任务创建处(grep `task_source.*consultation` 或 `咨询:` 定位)。在 `new_task = models.Task(...)` 之前加:

```python
from app.services.expert_task_resolver import resolve_task_taker_from_service
taker_id_value, taker_expert_id_value = await resolve_task_taker_from_service(db, service)
```

然后修改 Task 创建,把 `taker_id=service.owner_user_id` 改成:

```python
taker_id=taker_id_value,
taker_expert_id=taker_expert_id_value,
```

- [ ] **Step 2:** 写测试 `backend/tests/test_consultation_creation.py`:

```python
def test_consultation_team_service_sets_taker_expert_id(
    client, db_session, test_team_service, customer_user, test_expert_with_stripe
):
    resp = client.post(
        '/api/expert-services/consult',
        json={'service_id': test_team_service.id},
        headers={'Authorization': f'Bearer {customer_user.token}'},
    )
    assert resp.status_code == 200
    task_id = resp.json()['task_id']
    task = db_session.query(models.Task).get(task_id)
    assert task.taker_expert_id == test_expert_with_stripe.id
    assert task.taker_id is not None  # = team owner user_id
```

- [ ] **Step 3:** PASS + Commit

### Task 4.3: 正式服务任务创建调 helper

**Files:**
- Modify: `backend/app/task_expert_routes.py:3820-3860`

- [ ] **Step 1:** 找到正式服务任务创建处(grep `taker_id=application.expert_id`)。在创建 Task 之前加 service 加载 + helper 调用:

```python
service = await db.get(models.TaskExpertService, application.service_id)
if not service:
    raise HTTPException(404, "Service not found")

from app.services.expert_task_resolver import resolve_task_taker_from_service
taker_id_value, taker_expert_id_value = await resolve_task_taker_from_service(db, service)
```

把原来的 `taker_id=application.expert_id` 改为:

```python
taker_id=taker_id_value,
taker_expert_id=taker_expert_id_value,
```

- [ ] **Step 2:** 写测试 - 类似 4.2 但走正式路径。

- [ ] **Step 3:** PASS + Commit

### Task 4.4: ~~Payment Intent 改造~~(v2 跳过)

> **v2:** D1 confirmed 个人服务已经是 manual transfer (`task_expert_routes.py:3878-3902` 没有 `transfer_data`)。**无需改动**。Payment Intent 创建逻辑保留现状。Phase 6 的 execute_transfer 改造会自动让团队任务也走 manual transfer。

跳过本 task。

---

# Phase 5: 活动路径

### Task 5.1: 新建团队活动发布端点

**Files:**
- Create: `backend/app/expert_activity_routes.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1:** 创建文件:

```python
"""团队活动发布端点。spec §2.2 (E1)"""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.database import get_async_db_dependency
from app import models
from app.models_expert import Expert, ExpertMember
from app.expert_routes import _get_member_or_403
from app.secure_auth import get_current_user_secure_async_csrf

router = APIRouter(prefix="/api/experts", tags=["expert-activities"])


class TeamActivityCreate(BaseModel):
    title: str
    description: Optional[str] = None
    location: str
    task_type: str
    reward_type: str = 'cash'
    original_price_per_participant: float
    discount_percentage: float = 0
    discounted_price_per_participant: Optional[float] = None
    currency: str = 'GBP'
    points_reward: int = 0
    max_participants: int
    min_participants: int = 1
    deadline: str
    activity_end_date: Optional[str] = None
    images: Optional[list] = None


@router.post("/{expert_id}/activities")
async def create_team_activity(
    expert_id: str,
    body: TeamActivityCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    expert = await db.get(Expert, expert_id)
    if not expert:
        raise HTTPException(404, "Expert team not found")

    await _get_member_or_403(db, expert_id, current_user.id, required_roles=['owner', 'admin'])

    if not expert.stripe_onboarding_complete:
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team must complete Stripe onboarding before publishing activities",
        })

    if (body.currency or 'GBP').upper() != 'GBP':
        raise HTTPException(status_code=422, detail={
            "error_code": "expert_currency_unsupported",
            "message": "Team activities only support GBP currently",
        })

    result = await db.execute(
        select(ExpertMember).where(
            ExpertMember.expert_id == expert.id,
            ExpertMember.role == 'owner',
            ExpertMember.status == 'active',
        ).limit(1)
    )
    owner = result.scalar_one_or_none()
    if not owner:
        raise HTTPException(500, "Team has no active owner")

    activity = models.Activity(
        title=body.title,
        description=body.description,
        location=body.location,
        task_type=body.task_type,
        reward_type=body.reward_type,
        original_price_per_participant=body.original_price_per_participant,
        discount_percentage=body.discount_percentage,
        discounted_price_per_participant=body.discounted_price_per_participant,
        currency=body.currency,
        points_reward=body.points_reward,
        max_participants=body.max_participants,
        min_participants=body.min_participants,
        deadline=body.deadline,
        activity_end_date=body.activity_end_date,
        images=body.images,
        expert_id=owner.user_id,
        owner_type='expert',
        owner_id=expert.id,
        status='open',
        is_public=True,
    )
    db.add(activity)
    await db.commit()
    await db.refresh(activity)

    return {"id": activity.id, "owner_type": "expert", "owner_id": expert.id}
```

- [ ] **Step 2:** 在 `main.py` 注册:

```python
from app.expert_activity_routes import router as expert_activity_router
app.include_router(expert_activity_router)
```

- [ ] **Step 3:** 写测试 `backend/tests/test_team_activity_publish.py`(类似 publish_endpoints,3 个测试)。

- [ ] **Step 4:** PASS + Commit

### Task 5.2: 活动报名 → Task 创建调 helper

**Files:**
- Modify: `backend/app/multi_participant_routes.py:236-599`

- [ ] **Step 1:** 找到所有活动报名生成 Task 的代码点(grep `parent_activity_id` 在该文件的赋值,可能 2-3 处:单人活动、time-slot 活动)。在每处 Task 创建前加:

```python
from app.services.expert_task_resolver import resolve_task_taker_from_activity
taker_id_value, taker_expert_id_value = await resolve_task_taker_from_activity(db, activity)
```

把原来的 `taker_id=activity.expert_id` 改为:

```python
taker_id=taker_id_value,
taker_expert_id=taker_expert_id_value,
```

- [ ] **Step 2:** 在活动报名端点开头(在解析活动后)加 Stripe 门槛:

```python
if activity.owner_type == 'expert':
    expert_check = await db.get(Expert, activity.owner_id)
    if expert_check and not expert_check.stripe_onboarding_complete:
        raise HTTPException(409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team is temporarily unable to accept new sign-ups",
        })
```

- [ ] **Step 3:** 写集成测试。

- [ ] **Step 4:** PASS + Commit

---

# Phase 6: Money Flow —— 扩展 payment_transfer_service

> **v2 核心改动:** 不新建 Celery 任务。直接修改 `payment_transfer_service.py` 的 `create_transfer_record` 和 `execute_transfer`,在 `taker_expert_id` 非空时把 destination 切到团队。

### Task 6.1: 写 execute_transfer 团队分支测试

**Files:**
- Create: `backend/tests/test_payment_transfer_team_extension.py`

- [ ] **Step 1:**

```python
"""测试 payment_transfer_service.execute_transfer 对团队任务的处理. spec §3.2"""
import pytest
from decimal import Decimal
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
import stripe


def test_execute_transfer_team_uses_expert_stripe_account(
    db_session, test_team_task_completed, test_expert_with_stripe
):
    """团队任务的 destination 应该是 experts.stripe_account_id."""
    from app.payment_transfer_service import create_transfer_record, execute_transfer

    record = create_transfer_record(
        db=db_session,
        task_id=test_team_task_completed.id,
        taker_id=test_team_task_completed.taker_id,  # = owner.user_id
        poster_id=test_team_task_completed.poster_id,
        amount=Decimal('100.00'),
        currency='GBP',
        taker_expert_id=test_expert_with_stripe.id,
        commit=True,
    )

    with patch('stripe.Transfer.create') as mock_create:
        mock_create.return_value = MagicMock(id='tr_team_test01')
        success, transfer_id, err = execute_transfer(db_session, record, taker_stripe_account_id=None)
        assert success
        assert transfer_id == 'tr_team_test01'
        # 验证 destination 是团队的,不是 user 的
        kwargs = mock_create.call_args.kwargs
        assert kwargs['destination'] == test_expert_with_stripe.stripe_account_id


def test_execute_transfer_individual_unchanged(
    db_session, test_individual_task_completed, test_individual_user_with_stripe
):
    """个人任务依然走 taker_stripe_account_id 参数(不动)."""
    from app.payment_transfer_service import create_transfer_record, execute_transfer

    record = create_transfer_record(
        db=db_session,
        task_id=test_individual_task_completed.id,
        taker_id=test_individual_task_completed.taker_id,
        poster_id=test_individual_task_completed.poster_id,
        amount=Decimal('50.00'),
        currency='GBP',
        commit=True,
    )

    with patch('stripe.Transfer.create') as mock_create:
        mock_create.return_value = MagicMock(id='tr_indiv_test01')
        success, _, _ = execute_transfer(
            db_session, record,
            taker_stripe_account_id=test_individual_user_with_stripe.stripe_account_id
        )
        assert success
        kwargs = mock_create.call_args.kwargs
        assert kwargs['destination'] == test_individual_user_with_stripe.stripe_account_id


def test_execute_transfer_team_no_stripe_account_fails(db_session, test_team_task_completed):
    """团队没有 stripe_account_id → failed."""
    from app.payment_transfer_service import create_transfer_record, execute_transfer
    from app.models_expert import Expert

    expert = db_session.query(Expert).get(test_team_task_completed.taker_expert_id)
    expert.stripe_account_id = None
    db_session.commit()

    record = create_transfer_record(
        db=db_session,
        task_id=test_team_task_completed.id,
        taker_id=test_team_task_completed.taker_id,
        poster_id=test_team_task_completed.poster_id,
        amount=Decimal('100.00'),
        currency='GBP',
        taker_expert_id=expert.id,
        commit=True,
    )

    success, transfer_id, err = execute_transfer(db_session, record, None)
    assert not success
    assert 'Stripe' in (err or '')


def test_execute_transfer_window_expired(db_session, test_team_task_old_payment):
    """超过 89 天的任务直接 failed,不调 Stripe."""
    from app.payment_transfer_service import create_transfer_record, execute_transfer

    test_team_task_old_payment.payment_completed_at = datetime.utcnow() - timedelta(days=95)
    db_session.commit()

    record = create_transfer_record(
        db=db_session,
        task_id=test_team_task_old_payment.id,
        taker_id=test_team_task_old_payment.taker_id,
        poster_id=test_team_task_old_payment.poster_id,
        amount=Decimal('100.00'),
        currency='GBP',
        taker_expert_id=test_team_task_old_payment.taker_expert_id,
        commit=True,
    )

    with patch('stripe.Transfer.create') as mock_create:
        success, _, err = execute_transfer(db_session, record, None)
        assert not success
        assert 'window_expired' in (err or '') or 'window' in (err or '')
        mock_create.assert_not_called()


def test_execute_transfer_team_non_gbp_fails(db_session, test_team_task_completed):
    """非 GBP 团队任务 → failed."""
    from app.payment_transfer_service import create_transfer_record, execute_transfer

    record = create_transfer_record(
        db=db_session,
        task_id=test_team_task_completed.id,
        taker_id=test_team_task_completed.taker_id,
        poster_id=test_team_task_completed.poster_id,
        amount=Decimal('100.00'),
        currency='USD',
        taker_expert_id=test_team_task_completed.taker_expert_id,
        commit=True,
    )

    with patch('stripe.Transfer.create') as mock_create:
        success, _, err = execute_transfer(db_session, record, None)
        assert not success
        assert 'currency' in (err or '').lower()
        mock_create.assert_not_called()


def test_create_transfer_record_idempotency_key(db_session, test_team_task_completed):
    """创建的 transfer record idempotency_key 是 task_{id}_transfer."""
    from app.payment_transfer_service import create_transfer_record

    record = create_transfer_record(
        db=db_session,
        task_id=test_team_task_completed.id,
        taker_id=test_team_task_completed.taker_id,
        poster_id=test_team_task_completed.poster_id,
        amount=Decimal('100.00'),
        currency='GBP',
        taker_expert_id=test_team_task_completed.taker_expert_id,
        commit=True,
    )

    assert record.idempotency_key == f"task_{test_team_task_completed.id}_transfer"
```

- [ ] **Step 2:** 跑测试 fail。

- [ ] **Step 3:** Commit

### Task 6.2: 扩展 create_transfer_record + execute_transfer

**Files:**
- Modify: `backend/app/payment_transfer_service.py`

- [ ] **Step 1:** 修改 `create_transfer_record` 签名(line 48-105):

```python
def create_transfer_record(
    db: Session,
    task_id: int,
    taker_id: str,
    poster_id: str,
    amount: Decimal,
    currency: str = "GBP",
    taker_expert_id: Optional[str] = None,   # ★ 新增
    metadata: Optional[Dict[str, Any]] = None,
    commit: bool = True
) -> models.PaymentTransfer:
    # 现有幂等检查保留
    existing = db.query(models.PaymentTransfer).filter(
        and_(
            models.PaymentTransfer.task_id == task_id,
            models.PaymentTransfer.taker_id == taker_id,
            models.PaymentTransfer.status.in_(["pending", "retrying", "succeeded"])
        )
    ).first()
    if existing:
        logger.info(f"转账记录已存在: task_id={task_id}, taker_id={taker_id}")
        return existing

    transfer_record = models.PaymentTransfer(
        task_id=task_id,
        taker_id=taker_id,
        poster_id=poster_id,
        amount=amount,
        currency=currency,
        status="pending",
        retry_count=0,
        max_retries=len(RETRY_DELAYS),
        taker_expert_id=taker_expert_id,                          # ★ 新增
        idempotency_key=f"task_{task_id}_transfer",                # ★ 新增
        extra_metadata=metadata or {},
    )
    db.add(transfer_record)

    if commit:
        from app.transaction_utils import safe_commit
        if not safe_commit(db, f"创建转账记录 task_id={task_id}"):
            raise Exception("创建转账记录失败")
    else:
        db.flush()
    db.refresh(transfer_record)
    logger.info(f"✅ 创建转账记录: task_id={task_id}, transfer_record_id={transfer_record.id}, taker_expert_id={taker_expert_id}")
    return transfer_record
```

- [ ] **Step 2:** 修改 `execute_transfer`(line 108+):在 `task` 加载之后,加新的分支逻辑。具体步骤:

1. 改签名 `taker_stripe_account_id` 改成 `Optional[str] = None`
2. 在 `task = db.query(models.Task)...` 之后加:

```python
# ★ v2: 团队任务的 destination 是 experts.stripe_account_id
destination_account = None
if transfer_record.taker_expert_id:
    from app.models_expert import Expert
    expert = db.query(Expert).filter(Expert.id == transfer_record.taker_expert_id).first()
    if not expert or not expert.stripe_account_id:
        transfer_record.status = 'failed'
        transfer_record.last_error = 'Team has no Stripe Connect account'
        db.commit()
        return False, None, 'Team has no Stripe Connect account'
    if not expert.stripe_onboarding_complete:
        transfer_record.status = 'failed'
        transfer_record.last_error = 'Team Stripe onboarding not complete'
        db.commit()
        return False, None, 'Team Stripe onboarding not complete'
    # 币种检查
    if (transfer_record.currency or 'GBP').upper() != 'GBP':
        transfer_record.status = 'failed'
        transfer_record.last_error = 'currency_unsupported for team task'
        db.commit()
        return False, None, 'currency_unsupported for team task'
    destination_account = expert.stripe_account_id
else:
    destination_account = taker_stripe_account_id

# ★ v2: 90 天 Transfer 时效检查 (§3.4a)
if task.payment_completed_at:
    from datetime import datetime as _dt, timedelta as _td
    age = _dt.utcnow() - task.payment_completed_at.replace(tzinfo=None)
    if age > _td(days=89):
        transfer_record.status = 'failed'
        transfer_record.last_error = f'stripe_transfer_window_expired ({age.days}d)'
        db.commit()
        return False, None, f'stripe_transfer_window_expired ({age.days}d)'
```

3. 在调 `stripe.Transfer.create(...)` 的地方,把 `destination=taker_stripe_account_id` 改成 `destination=destination_account`,并加 `idempotency_key=transfer_record.idempotency_key`。

4. 在 Stripe Account validate 那段(`stripe_client.Account.retrieve(taker_stripe_account_id)`),把 `taker_stripe_account_id` 改成 `destination_account`。

- [ ] **Step 3:** 跑测试:

```bash
cd backend && pytest tests/test_payment_transfer_team_extension.py -v
```

预期: 6 PASS

- [ ] **Step 4:** Commit

```bash
git add backend/app/payment_transfer_service.py backend/tests/test_payment_transfer_team_extension.py
git commit -m "feat(transfer): extend execute_transfer for team taker (v2)"
```

### Task 6.3: 验证任务完成端点调 create_transfer_record 时传 taker_expert_id

**Files:**
- Modify: `backend/app/routers.py:3920` 附近(客户手动确认完成)
- Modify: `backend/app/scheduled_tasks.py:267, 1012, 1133`(自动确认)

- [ ] **Step 1:** 找到每处 `create_transfer_record` 调用,确保新增了 `taker_expert_id=task.taker_expert_id` 参数:

```python
transfer_record = create_transfer_record(
    db=db,
    task_id=task.id,
    taker_id=task.taker_id,
    poster_id=task.poster_id,
    amount=transfer_amount,
    currency=task.currency or 'GBP',
    taker_expert_id=task.taker_expert_id,  # ★ 新增
    metadata={...},
)
```

- [ ] **Step 2:** 写集成测试 `backend/tests/test_team_task_completion_flow.py`:

```python
def test_team_task_confirm_creates_correct_transfer_record(
    client, db_session, test_team_task_in_progress, customer_user
):
    with patch('stripe.Transfer.create') as mock_create:
        mock_create.return_value = MagicMock(id='tr_e2e_team')
        client.post(
            f'/api/tasks/{test_team_task_in_progress.id}/confirm',
            headers={'Authorization': f'Bearer {customer_user.token}'},
        )
        record = db_session.query(models.PaymentTransfer).filter_by(
            task_id=test_team_task_in_progress.id
        ).first()
        assert record is not None
        assert record.taker_expert_id == test_team_task_in_progress.taker_expert_id
        assert record.idempotency_key == f"task_{test_team_task_in_progress.id}_transfer"
```

- [ ] **Step 3:** PASS + Commit

### Task 6.4: 60 天 Transfer 时效预警 Celery beat

**Files:**
- Modify: `backend/app/celery_tasks.py`(在文件末尾追加)
- Modify: Celery beat schedule(grep `beat_schedule` 或 `celerybeat`)

- [ ] **Step 1:** 在 `celery_tasks.py` 末尾追加:

```python
@shared_task(name='expert_transfer.warn_long_running')
def warn_long_running_team_tasks():
    """每天扫一次,通知 owner 接近 90 天 Transfer 时效的 in-flight 团队任务. spec §3.4a"""
    from datetime import datetime, timedelta
    from sqlalchemy import select
    from app.database import SessionLocal
    from app import models, crud

    db = SessionLocal()
    try:
        threshold = datetime.utcnow() - timedelta(days=60)
        tasks = db.query(models.Task).filter(
            models.Task.taker_expert_id.is_not(None),
            models.Task.status.in_(['in_progress', 'disputed']),
            models.Task.payment_completed_at < threshold,
        ).all()
        for t in tasks:
            crud.create_notification(
                db, str(t.taker_id),
                "expert_transfer_window_warning", "款项接近时效",
                f"任务 #{t.id} 已超过 60 天未完成,请尽快完成,否则款项无法 Transfer",
                related_id=str(t.id),
                auto_commit=False
            )
        db.commit()
        logger.info(f"warn_long_running_team_tasks: notified {len(tasks)} tasks")
    finally:
        db.close()
```

- [ ] **Step 2:** 在 Celery beat 配置(grep `beat_schedule`)加:

```python
'expert-transfer-warn-daily': {
    'task': 'expert_transfer.warn_long_running',
    'schedule': crontab(hour=9, minute=0),
},
```

- [ ] **Step 3:** Commit

### Task 6.5: 通知系统验证

**Files:** 无需改动

- [ ] **Step 1:** Verify现有 transfer 失败时已经通过 `crud.create_notification` 发通知给 `taker_id`。grep `create_notification` in `payment_transfer_service.py`:

```bash
grep -n "create_notification\|notify" backend/app/payment_transfer_service.py
```

- [ ] **Step 2:** 如果存在,confirm taker_id 在团队任务时已经是 owner.user_id(因为 Y 方案),通知会自然到达 owner。**无需修改**。

如果不存在,补一段简单的失败通知。

- [ ] **Step 3:** 如有补丁则 commit;否则跳过。

---

# Phase 7: Refund / Dispute / Reversal

### Task 7.1: 写 dispute 反向 hook 测试

**Files:**
- Create: `backend/tests/test_team_dispute_reversal.py`

- [ ] **Step 1:**

```python
"""测试 charge.dispute.created 对团队任务的额外反向处理. spec §3.5"""
import json
from unittest.mock import patch, MagicMock


def test_dispute_team_task_reverses_transfer(
    client, db_session, test_team_task_with_succeeded_transfer
):
    """团队任务 dispute → 自动反向 transfer."""
    pt = test_team_task_with_succeeded_transfer

    payload = json.dumps({
        'id': 'evt_dispute01',
        'type': 'charge.dispute.created',
        'data': {'object': {
            'charge': pt.stripe_charge_id,
            'metadata': {'task_id': str(pt.task_id)},
            'reason': 'fraudulent',
            'amount': int(pt.amount * 100),
        }}
    })

    with patch('stripe.Webhook.construct_event') as mock_verify, \
         patch('stripe.Transfer.create_reversal') as mock_reverse:
        mock_event = MagicMock()
        mock_event.type = 'charge.dispute.created'
        mock_event.data.object = MagicMock()
        mock_event.data.object.charge = pt.stripe_charge_id
        mock_event.data.object.metadata = {'task_id': str(pt.task_id)}
        mock_verify.return_value = mock_event
        mock_reverse.return_value = MagicMock(id='trr_test01')

        client.post('/api/stripe/webhook', data=payload, headers={'Stripe-Signature': 'fake'})

    db_session.refresh(pt)
    assert pt.status == 'reversed'
    assert pt.stripe_reversal_id == 'trr_test01'
    assert pt.reversed_reason == 'dispute'


def test_dispute_individual_task_no_team_reversal(
    client, db_session, test_individual_task_with_succeeded_transfer
):
    """个人任务 dispute → 现有冻结流程不变,不触发新反向."""
    pt = test_individual_task_with_succeeded_transfer

    payload = json.dumps({
        'id': 'evt_dispute02',
        'type': 'charge.dispute.created',
        'data': {'object': {
            'charge': pt.stripe_charge_id or 'ch_test',
            'metadata': {'task_id': str(pt.task_id)},
        }}
    })

    with patch('stripe.Webhook.construct_event') as mock_verify, \
         patch('stripe.Transfer.create_reversal') as mock_reverse:
        mock_event = MagicMock()
        mock_event.type = 'charge.dispute.created'
        mock_event.data.object = MagicMock()
        mock_event.data.object.charge = pt.stripe_charge_id or 'ch_test'
        mock_event.data.object.metadata = {'task_id': str(pt.task_id)}
        mock_verify.return_value = mock_event

        client.post('/api/stripe/webhook', data=payload, headers={'Stripe-Signature': 'fake'})

    db_session.refresh(pt)
    assert pt.status != 'reversed'  # 不变
```

- [ ] **Step 2:** 跑测试 fail (新代码还没写)。

- [ ] **Step 3:** Commit

### Task 7.2: 在现有 dispute handler 追加团队反向逻辑

**Files:**
- Modify: `backend/app/routers.py:7620` 附近(`charge.dispute.created` 现有分支末尾)

- [ ] **Step 1:** 在现有 `elif event_type == "charge.dispute.created":` 分支末尾(冻结/通知逻辑之后)追加:

```python
        # ★ v2: 团队任务自动反向 transfer
        if task and getattr(task, 'taker_expert_id', None):
            pt = db.query(models.PaymentTransfer).filter(
                models.PaymentTransfer.task_id == task_id,
                models.PaymentTransfer.status == 'succeeded'
            ).first()
            if pt and pt.transfer_id:
                try:
                    reversal = stripe.Transfer.create_reversal(
                        pt.transfer_id,
                        amount=int(pt.amount * 100),
                        metadata={'task_id': str(task_id), 'reason': 'dispute'},
                    )
                    pt.stripe_reversal_id = reversal.id
                    pt.status = 'reversed'
                    pt.reversed_at = get_utc_time()
                    pt.reversed_reason = 'dispute'
                    db.commit()
                    crud.create_notification(
                        db, str(pt.taker_id),
                        "expert_transfer_reversed", "款项已反向",
                        f"任务 #{task_id} 的 £{pt.amount} 因争议被反向",
                        related_id=str(task_id), auto_commit=False
                    )
                    logger.warning(f"Team transfer reversed for task {task_id}: trr={reversal.id}")
                except stripe.error.StripeError as e:
                    logger.error(f"Failed to reverse team transfer for task {task_id}: {e}")
```

- [ ] **Step 2:** 跑测试 PASS。

- [ ] **Step 3:** **手动**在 Stripe Dashboard 确认 `charge.dispute.created` 事件已订阅(应该已订阅,line 7620 已存在)。

- [ ] **Step 4:** Commit

```bash
git add backend/app/routers.py backend/tests/test_team_dispute_reversal.py
git commit -m "feat(webhook): auto-reverse team transfer on dispute"
```

### Task 7.3: refund_service.py 反向时填新字段

**Files:**
- Modify: `backend/app/refund_service.py:131-145`

- [ ] **Step 1:** 在现有 `reversal = stripe.Transfer.create_reversal(...)` 成功后追加 3 个字段写入:

```python
reversal = stripe.Transfer.create_reversal(
    original_transfer.transfer_id,
    amount=refund_amount_pence,
    metadata={...}
)
refund_transfer_id = reversal.id

# ★ v2: 填新审计字段
original_transfer.stripe_reversal_id = reversal.id
original_transfer.status = 'reversed'
original_transfer.reversed_at = get_utc_time()
original_transfer.reversed_reason = 'refund'
db.commit()

logger.info(f"✅ 创建反向转账成功: reversal_id={reversal.id}")
```

- [ ] **Step 2:** 写测试 - 触发管理员退款 → 验证 reversed_at/reversed_reason 被填。

- [ ] **Step 3:** PASS + Commit

---

# Phase 8: Dashboard Query Endpoints + Serializer

### Task 8.1: 写 build_taker_display 测试 + 实现

**Files:**
- Create: `backend/tests/test_taker_display_serializer.py`
- Create: `backend/app/serializers/__init__.py`
- Create: `backend/app/serializers/task_taker_display.py`

- [ ] **Step 1:** 创建 serializers 包:

```bash
test -d backend/app/serializers || mkdir -p backend/app/serializers && touch backend/app/serializers/__init__.py
```

- [ ] **Step 2:** 测试:

```python
"""测试 build_taker_display. spec §4.6"""
import pytest
from unittest.mock import AsyncMock, MagicMock


@pytest.fixture
def mock_db():
    db = MagicMock()
    db.get = AsyncMock()
    return db


@pytest.mark.asyncio
async def test_taker_display_team_task(mock_db):
    from app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = 'u_owner01'
    task.taker_expert_id = 'e_test01'

    expert = MagicMock()
    expert.id = 'e_test01'
    expert.name = '星光摄影团队'
    expert.avatar = 'https://.../logo.png'
    mock_db.get.return_value = expert

    result = await build_taker_display(task, mock_db)
    assert result['type'] == 'expert'
    assert result['entity_id'] == 'e_test01'
    assert result['name'] == '星光摄影团队'


@pytest.mark.asyncio
async def test_taker_display_individual_task(mock_db):
    from app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = 'u_indiv01'
    task.taker_expert_id = None

    user = MagicMock()
    user.id = 'u_indiv01'
    user.name = '李四'
    user.avatar = 'https://.../u.png'
    mock_db.get.return_value = user

    result = await build_taker_display(task, mock_db)
    assert result['type'] == 'user'
    assert result['name'] == '李四'


@pytest.mark.asyncio
async def test_taker_display_unclaimed_task(mock_db):
    from app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = None
    task.taker_expert_id = None
    result = await build_taker_display(task, mock_db)
    assert result is None
```

- [ ] **Step 3:** 实现:

```python
"""统一 taker 展示信息序列化。spec §4.6 (U2 方案)"""
from typing import Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from app import models
from app.models_expert import Expert


async def build_taker_display(
    task: "models.Task",
    db: AsyncSession,
) -> Optional[Dict[str, Any]]:
    if task.taker_expert_id:
        expert = await db.get(Expert, task.taker_expert_id)
        if expert:
            return {
                "type": "expert",
                "entity_id": expert.id,
                "name": expert.name,
                "avatar": expert.avatar,
            }

    if task.taker_id:
        user = await db.get(models.User, task.taker_id)
        if user:
            return {
                "type": "user",
                "entity_id": user.id,
                "name": user.name,
                "avatar": getattr(user, 'avatar', None),
            }

    return None
```

- [ ] **Step 4:** 跑测试 PASS + Commit

### Task 8.2: 在主要 Task 响应端点接入 taker_display

**Files:**
- Modify: 主要 Task 详情/列表 API(grep `taker_id` in router files)

- [ ] **Step 1:** 找到至少一个 task detail 端点,在 response dict 构建处加:

```python
from app.serializers.task_taker_display import build_taker_display
task_dict['taker_display'] = await build_taker_display(task, db)
```

(其他端点的接入可以在 follow-up 做,本 plan 只确保**关键端点**接入)

- [ ] **Step 2:** 写一个集成测试覆盖该端点。

- [ ] **Step 3:** Commit

### Task 8.3: 创建 expert_earnings_routes.py + 团队任务列表

**Files:**
- Create: `backend/app/expert_earnings_routes.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1:** 创建文件:

```python
"""达人管理页面查询端点。spec §5"""
from typing import Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_async_db_dependency
from app import models
from app.models_expert import Expert
from app.expert_routes import _get_member_or_403
from app.secure_auth import get_current_user_secure_async_csrf

router = APIRouter(prefix="/api/experts", tags=["expert-earnings"])


@router.get("/{expert_id}/tasks")
async def list_team_tasks(
    expert_id: str,
    status: Optional[str] = None,
    task_source: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=['owner', 'admin', 'member'])

    conditions = [models.Task.taker_expert_id == expert_id]
    if status:
        conditions.append(models.Task.status.in_([s.strip() for s in status.split(',')]))
    if task_source:
        conditions.append(models.Task.task_source == task_source)
    if start_date:
        conditions.append(models.Task.created_at >= start_date)
    if end_date:
        conditions.append(models.Task.created_at <= end_date)

    count_q = select(func.count()).select_from(models.Task).where(and_(*conditions))
    total = (await db.execute(count_q)).scalar_one()

    q = (
        select(models.Task, models.PaymentTransfer)
        .join(models.PaymentTransfer, models.PaymentTransfer.task_id == models.Task.id, isouter=True)
        .where(and_(*conditions))
        .order_by(models.Task.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    rows = (await db.execute(q)).all()

    items = []
    for task, pt in rows:
        poster = await db.get(models.User, task.poster_id)
        items.append({
            "id": task.id,
            "title": task.title,
            "status": task.status,
            "task_source": task.task_source,
            "poster": {
                "id": poster.id, "name": poster.name, "avatar": getattr(poster, 'avatar', None),
            } if poster else None,
            "gross_amount": str(task.agreed_reward or task.reward or 0),
            "currency": task.currency or 'GBP',
            "transfer": {
                "status": pt.status,
                "net_amount": str(pt.amount),
                "stripe_transfer_id": pt.transfer_id,
                "error_message": pt.last_error,
            } if pt else None,
            "created_at": task.created_at.isoformat() if task.created_at else None,
            "completed_at": task.completed_at.isoformat() if task.completed_at else None,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}
```

- [ ] **Step 2:** 注册 router in `main.py`。

- [ ] **Step 3:** 写测试。PASS + Commit。

### Task 8.4: earnings/summary 端点

**Files:**
- Modify: `backend/app/expert_earnings_routes.py`

- [ ] **Step 1:** 追加:

```python
@router.get("/{expert_id}/earnings/summary")
async def earnings_summary(
    expert_id: str,
    period: str = Query('all_time', regex='^(all_time|this_month|last_30d|last_90d)$'),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=['owner', 'admin', 'member'])

    from datetime import timedelta
    now = datetime.utcnow()
    if period == 'this_month':
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    elif period == 'last_30d':
        start = now - timedelta(days=30)
    elif period == 'last_90d':
        start = now - timedelta(days=90)
    else:
        start = None

    pt_conditions = [models.PaymentTransfer.taker_expert_id == expert_id]
    if start:
        pt_conditions.append(models.PaymentTransfer.created_at >= start)

    q = (
        select(
            func.coalesce(func.sum(models.Task.agreed_reward), 0).label('total_gross'),
            func.coalesce(func.sum(
                models.PaymentTransfer.amount
            ).filter(models.PaymentTransfer.status == 'succeeded'), 0).label('total_net'),
            func.count(models.PaymentTransfer.id).filter(models.PaymentTransfer.status == 'succeeded').label('succeeded_count'),
            func.count(models.PaymentTransfer.id).filter(models.PaymentTransfer.status.in_(['pending','retrying'])).label('pending_count'),
            func.count(models.PaymentTransfer.id).filter(models.PaymentTransfer.status == 'failed').label('failed_count'),
            func.coalesce(func.sum(
                models.PaymentTransfer.amount
            ).filter(models.PaymentTransfer.status == 'reversed'), 0).label('total_reversed'),
        )
        .select_from(models.Task)
        .join(models.PaymentTransfer, models.PaymentTransfer.task_id == models.Task.id, isouter=True)
        .where(models.Task.taker_expert_id == expert_id)
    )

    row = (await db.execute(q)).one()
    total_gross = row.total_gross or 0
    total_net = row.total_net or 0
    total_fee = total_gross - total_net

    return {
        "period": period,
        "currency": "GBP",
        "total_gross": str(total_gross),
        "total_net": str(total_net),
        "total_fee": str(total_fee),
        "total_reversed": str(row.total_reversed or 0),
        "pending_count": row.pending_count,
        "failed_count": row.failed_count,
        "succeeded_count": row.succeeded_count,
        "note": "Actual balance is held in your team's Stripe account. Check the Stripe Dashboard for real-time balance.",
    }
```

- [ ] **Step 2:** 测试 + Commit

### Task 8.5: earnings/transfers 历史端点

**Files:**
- Modify: `backend/app/expert_earnings_routes.py`

- [ ] **Step 1:**

```python
@router.get("/{expert_id}/earnings/transfers")
async def transfer_history(
    expert_id: str,
    status: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=['owner', 'admin', 'member'])

    conditions = [models.PaymentTransfer.taker_expert_id == expert_id]
    if status:
        conditions.append(models.PaymentTransfer.status.in_(status.split(',')))
    if start_date:
        conditions.append(models.PaymentTransfer.created_at >= start_date)
    if end_date:
        conditions.append(models.PaymentTransfer.created_at <= end_date)

    total_q = select(func.count()).select_from(models.PaymentTransfer).where(and_(*conditions))
    total = (await db.execute(total_q)).scalar_one()

    q = (
        select(models.PaymentTransfer)
        .where(and_(*conditions))
        .order_by(models.PaymentTransfer.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    rows = (await db.execute(q)).scalars().all()

    items = []
    for r in rows:
        task = await db.get(models.Task, r.task_id)
        items.append({
            "id": r.id,
            "task": {"id": r.task_id, "title": task.title if task else None},
            "amount": str(r.amount),
            "currency": r.currency,
            "status": r.status,
            "stripe_transfer_id": r.transfer_id,
            "stripe_reversal_id": r.stripe_reversal_id,
            "created_at": r.created_at.isoformat(),
            "retry_count": r.retry_count,
            "error_message": r.last_error,
            "reversed_at": r.reversed_at.isoformat() if r.reversed_at else None,
            "reversed_reason": r.reversed_reason,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}
```

- [ ] **Step 2:** 测试 + Commit

---

# Phase 9: 历史数据回填

### Task 9.1: 跑预审 SQL,记录冲突

- [ ] **Step 1:**

```bash
psql $DATABASE_URL -c "
SELECT t.id, t.taker_id, array_agg(em.expert_id) AS candidate_experts
FROM tasks t
JOIN expert_members em ON em.user_id = t.taker_id
WHERE t.status IN ('pending','pending_payment','in_progress','disputed')
  AND t.taker_expert_id IS NULL
  AND (t.expert_service_id IS NOT NULL OR t.parent_activity_id IS NOT NULL)
  AND COALESCE(t.currency, 'GBP') = 'GBP'
  AND em.status = 'active'
GROUP BY t.id, t.taker_id
HAVING COUNT(DISTINCT em.expert_id) > 1;
"
```

- [ ] **Step 2:** 把结果填到 discovery 文档新段落 `## §9.1 回填预审结果`,如果有冲突任务,人工决策。

- [ ] **Step 3:** Commit

### Task 9.2: Migration 180 — 回填脚本

**Files:**
- Create: `backend/migrations/180_backfill_tasks_taker_expert.sql`

- [ ] **Step 1:**

```sql
BEGIN;

WITH candidate AS (
  SELECT DISTINCT ON (t.id)
    t.id AS task_id,
    em.expert_id
  FROM tasks t
  JOIN expert_members em ON em.user_id = t.taker_id
  JOIN experts e ON e.id = em.expert_id
  WHERE t.status IN ('pending','pending_payment','in_progress','disputed')
    AND t.taker_expert_id IS NULL
    AND (t.expert_service_id IS NOT NULL OR t.parent_activity_id IS NOT NULL)
    AND COALESCE(t.currency, 'GBP') = 'GBP'
    AND em.role IN ('owner','admin')
    AND em.status = 'active'
    AND e.status = 'active'
  ORDER BY t.id,
           CASE em.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
           em.joined_at ASC
)
UPDATE tasks t
SET taker_expert_id = c.expert_id
FROM candidate c
WHERE t.id = c.task_id;

DO $$
DECLARE
  total_inflight INT;
  backfilled INT;
BEGIN
  SELECT COUNT(*) INTO total_inflight
  FROM tasks
  WHERE status IN ('pending','pending_payment','in_progress','disputed')
    AND (expert_service_id IS NOT NULL OR parent_activity_id IS NOT NULL)
    AND COALESCE(currency, 'GBP') = 'GBP';

  SELECT COUNT(*) INTO backfilled
  FROM tasks
  WHERE taker_expert_id IS NOT NULL
    AND status IN ('pending','pending_payment','in_progress','disputed');

  RAISE NOTICE 'In-flight expert tasks: %', total_inflight;
  RAISE NOTICE 'Backfilled: %', backfilled;
  RAISE NOTICE 'Remaining individual-model: %', total_inflight - backfilled;
END $$;

COMMIT;
```

- [ ] **Step 2:** 跑迁移,记录 NOTICE 输出。

- [ ] **Step 3:** Commit

### Task 9.3: ownership transfer 同步未完成任务 taker_id

**Files:**
- Modify: `backend/app/expert_routes.py:833`

- [ ] **Step 1:** 在 `transfer_ownership` 函数 commit 之前追加:

```python
from sqlalchemy import update as sql_update
await db.execute(
    sql_update(models.Task)
    .where(
        models.Task.taker_expert_id == expert.id,
        models.Task.status.in_(['pending','pending_payment','in_progress','disputed'])
    )
    .values(taker_id=new_owner_user_id)
)
```

(`new_owner_user_id` 是 transfer_ownership 已有的变量名,具体看代码)

- [ ] **Step 2:** 写测试。

- [ ] **Step 3:** Commit

---

# Phase 10: E2E + Sanity Checks

### Task 10.1: E2E 冒烟测试 — 团队任务全流程

**Files:**
- Create: `backend/tests/test_e2e_team_task_money_flow.py`

- [ ] **Step 1:**

```python
"""端到端: 发布服务 → 下单 → 付款 → 完成 → Transfer 成功. spec §9.2"""
from datetime import datetime
from unittest.mock import patch, MagicMock


def test_e2e_team_service_money_flow(
    client, db_session, test_expert_with_stripe, team_owner_user, customer_user
):
    # 1. 团队 owner 发布服务
    publish_resp = client.post(
        f"/api/experts/{test_expert_with_stripe.id}/services",
        json={'service_name': 'E2E', 'base_price': 100, 'currency': 'GBP', 'category': 'test'},
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert publish_resp.status_code in (200, 201)
    service_id = publish_resp.json()['id']

    # 2. 客户咨询 → 创建 Task
    consult_resp = client.post(
        '/api/expert-services/consult',
        json={'service_id': service_id},
        headers={'Authorization': f'Bearer {customer_user.token}'},
    )
    assert consult_resp.status_code == 200
    task_id = consult_resp.json()['task_id']
    task = db_session.query(models.Task).get(task_id)
    assert task.taker_expert_id == test_expert_with_stripe.id

    # 3. 模拟付款 + 进入 in_progress
    task.status = 'in_progress'
    task.payment_completed_at = datetime.utcnow()
    task.is_paid = 1
    db_session.commit()

    # 4. 客户确认完成
    with patch('stripe.Transfer.create') as mock_transfer:
        mock_transfer.return_value = MagicMock(id='tr_e2e_team_test')
        complete_resp = client.post(
            f'/api/tasks/{task_id}/confirm',
            headers={'Authorization': f'Bearer {customer_user.token}'},
        )
        assert complete_resp.status_code == 200

    # 5. 验证 PaymentTransfer 行
    pt = db_session.query(models.PaymentTransfer).filter_by(task_id=task_id).first()
    assert pt is not None
    assert pt.taker_expert_id == test_expert_with_stripe.id
    assert pt.status == 'succeeded'
    assert pt.transfer_id == 'tr_e2e_team_test'
    # destination 验证
    kwargs = mock_transfer.call_args.kwargs
    assert kwargs['destination'] == test_expert_with_stripe.stripe_account_id
```

- [ ] **Step 2:** PASS + Commit

### Task 10.2: 跑全部新测试 + 回归

- [ ] **Step 1:** 跑所有新测试:

```bash
cd backend && pytest tests/test_expert_task_resolver.py tests/test_payment_transfer_team_extension.py tests/test_expert_publish_endpoints.py tests/test_stripe_webhook_handlers_team.py tests/test_team_activity_publish.py tests/test_taker_display_serializer.py tests/test_team_dispute_reversal.py tests/test_e2e_team_task_money_flow.py -v
```

预期: ALL PASS

- [ ] **Step 2:** Sanity check:

```bash
psql $DATABASE_URL -c "
SELECT
  owner_type,
  COUNT(*) AS n,
  COUNT(*) FILTER (WHERE owner_id IS NULL) AS n_null_owner,
  COUNT(*) FILTER (WHERE owner_type='expert' AND NOT EXISTS (
    SELECT 1 FROM experts e WHERE e.id = owner_id
  )) AS n_orphan_expert
FROM task_expert_services
GROUP BY owner_type;
"
```

- [ ] **Step 3:** 跑全量回归:

```bash
cd backend && pytest -x -q
```

- [ ] **Step 4:** Commit

### Task 10.3: 更新 spec 状态 + runbook

**Files:**
- Modify: `docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md`(顶部)
- Create: `docs/runbooks/expert-team-stripe-transfers.md`

- [ ] **Step 1:** spec 顶部 `**状态:** Draft v2` → `**状态:** Implemented (<日期>)`

- [ ] **Step 2:** runbook 写运维操作:
  - 失败 transfer 的手工处理
  - 90 天时效任务的应急流程
  - dispute 反向失败的人工介入
  - Stripe Dashboard 上的对账场景

- [ ] **Step 3:** Commit

### Task 10.4: 上线 checklist

参考 spec §6.6,逐项确认:
- [ ] §6.3 sanity check 通过
- [ ] §9.1 预审已处理冲突
- [ ] 所有 migration 在 staging 跑通
- [ ] 所有新测试 PASS
- [ ] Stripe Dashboard `account.updated` + `charge.dispute.created` (Connected accounts) 已订阅
- [ ] E2E 冒烟通过
- [ ] 负测试(未 onboard 团队发布)→ 409
- [ ] 在 staging 模拟一笔团队任务全流程,人工 verify

全部勾完 → plan 完成。

---

# 完成

整个 plan 共 **10 个 Phase, ~38 个 task**(v1 是 50 个,v2 减少 12 个 task,主要因为 Stripe Onboarding 端点已存在 + Celery task 改为扩展现有 service)。

实际新增/修改文件统计(估算):
- 5 个 SQL migration
- ~150 行 helper(`expert_task_resolver.py`)
- ~80 行扩展(`payment_transfer_service.py`)
- ~150 行新端点(`expert_activity_routes.py` + `expert_earnings_routes.py`)
- ~50 行 webhook handler 追加
- ~30 行 refund_service.py 改动
- ~50 行 task_expert_routes.py 改动
- ~100 行 multi_participant_routes.py 改动
- ~60 行 serializer
- ~600 行测试

**总实施代码 ~1300 行,测试 ~600 行。比 v1 估算的 1500+500 减少约 30%,反映了"扩展而非新建"的真实工作量。**
