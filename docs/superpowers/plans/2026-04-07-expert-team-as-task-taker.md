# 达人团队作为任务接单方 —— 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"达人任务的接单方"从自然人升级为达人团队,客户付款通过 Stripe Manual Transfer 直达团队 Stripe Connect 账户。平台不持有团队钱包,团队内部分账由团队自理。

**Architecture:** 加 `tasks.taker_expert_id` 列承载经济主体;`taker_id` 仍填团队 owner 作为"代表"(Y 方案,老代码免改);任务完成时 Celery 异步调 `stripe.Transfer.create` 到 `experts.stripe_account_id`,所有 transfer 写入 `expert_stripe_transfers` 审计表(幂等 + 重试 + 反向)。新建 helper `resolve_task_taker_from_*()` 集中"service/activity → (taker_id, taker_expert_id)" 的解析逻辑。

**Tech Stack:** FastAPI + SQLAlchemy(async) + Celery(sync session in worker) + Stripe Connect + PostgreSQL + pytest + pytest-asyncio

**Spec Reference:** `docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `backend/migrations/176_add_tasks_taker_expert_id.sql` | tasks 加 taker_expert_id 列 + 索引 |
| Create | `backend/migrations/177_add_activities_owner_polymorphic.sql` | activities 加 owner_type/owner_id 多态列 |
| Create | `backend/migrations/178_create_expert_stripe_transfers.sql` | 新建审计表 |
| Create | `backend/migrations/179_backfill_tasks_taker_expert.sql` | 在飞任务回填(Phase 9 才跑) |
| Modify | `backend/app/models.py` | Task 加 taker_expert_id 字段;Activity 加多态字段 |
| Modify | `backend/app/models_expert.py` | 新增 ExpertStripeTransfer ORM 类 |
| Create | `backend/app/services/expert_task_resolver.py` | resolve_task_taker_from_service / _activity 两个 helper |
| Create | `backend/app/tasks/expert_transfer.py` | Celery 任务 enqueue_expert_transfer + helpers |
| Create | `backend/app/expert_stripe_routes.py` | Stripe Onboarding / status 端点 |
| Create | `backend/app/expert_activity_routes.py` | POST /api/experts/{id}/activities |
| Create | `backend/app/expert_earnings_routes.py` | 团队收入 / Transfer 历史 / 任务列表查询 |
| Create | `backend/app/serializers/task_taker_display.py` | build_taker_display() helper |
| Modify | `backend/app/expert_service_routes.py:106-133` | 加 Stripe + GBP 门槛 |
| Modify | `backend/app/task_expert_routes.py:3090-3130` | 咨询任务创建 → 调 helper |
| Modify | `backend/app/task_expert_routes.py:3820-3860` | 正式服务任务创建 → 调 helper |
| Modify | `backend/app/task_expert_routes.py:3870-3899` | Payment Intent 改造(A/B 分支) |
| Modify | `backend/app/multi_participant_routes.py:236-599` | 活动报名 → Task 时调 helper |
| Modify | `backend/app/multi_participant_routes.py` | 活动报名加 Stripe 门槛检查 |
| Modify | `backend/app/routers.py` (webhook 区域) | account.updated + charge.dispute.created 分支 |
| Modify | `backend/app/expert_routes.py` (ownership transfer) | 同步未完成任务 taker_id |
| Modify | 任务完成端点(Phase 0 grep 定位) | 加 taker_expert_id 分叉 |
| Create | `backend/tests/test_expert_task_resolver.py` | helper 单元测试 |
| Create | `backend/tests/test_expert_transfer_celery.py` | Celery task 测试(mock Stripe) |
| Create | `backend/tests/test_expert_publish_endpoints.py` | 发布服务/活动端点测试 |
| Create | `backend/tests/test_expert_stripe_routes.py` | Onboarding 端点测试 |
| Create | `backend/tests/test_expert_earnings_routes.py` | Dashboard 查询端点测试 |
| Create | `backend/tests/test_taker_display_serializer.py` | serializer 测试 |
| Create | `backend/tests/test_e2e_team_task_money_flow.py` | 端到端冒烟 |

---

# Phase 0: Discovery(必做的代码探索)

**目标:** 解决 spec §8 的 15 项 grep 待定项,把伪代码具体化。所有发现写入下面这个 discovery 文档,作为后续 phase 的输入。

### Task 0.1: 创建 discovery 报告文件

**Files:**
- Create: `docs/superpowers/plans/2026-04-07-expert-team-discovery.md`

- [ ] **Step 1:** 创建文件,模板如下:

```markdown
# Expert Team As Taker — Discovery Report

> 配套 plan: 2026-04-07-expert-team-as-task-taker.md
> 此文档记录 Phase 0 的所有 grep 结果,后续 Phase 引用本文档具体定位。

## D1. 个人服务当前资金流模式
- 文件: <path:line>
- 当前是 destination charge 还是 manual transfer?
- 走哪条:_____

## D2. 任务完成端点位置
- 文件:行 (可能多处):
  - <path:line> — <说明>
  - <path:line> — <说明>

## D3. _compute_application_fee 函数
- 文件: <path:line>
- 签名: `def _compute_application_fee(<params>) -> <return>`

## D4. tasks.payment_charge_id 字段
- 字段名: <name>
- 文件: <path:line>

## D5. ExpertStripeTransfer ORM 模型放哪
- 决定: <models.py | models_expert.py | new file>

## D6. Webhook handler 位置
- 文件: <path:line>
- 验签函数名: <name>

## D7. ownership transfer 端点
- 文件: <path:line>
- 函数名: <name>

## D8. Stripe Account type
- 现有个人 Stripe Connect 创建代码: <path:line or "not found">
- 决定: <standard | express | custom>

## D9. 个人 wallet_accounts.balance credit 路径
- 是否存在: <yes/no>
- 文件: <path:line>
- §4.4 走 A 还是 B 回退?

## D10. refund 端点位置
- 文件: <path:line>

## D11. Celery sync session factory
- 现有 Celery 任务文件: <path>
- 用 sync 还是 async session? <答案>

## D12. tasks.payment_completed_at 字段
- 字段名: <name 或 "not found, need to add">

## D13. Webhook signing secret 环境变量
- 名字: <env var name>

## D14. 积分发放函数
- 函数名: <name>
- 文件: <path:line>

## D15. _get_member_or_403 helper
- 文件: <path:line>
- 签名: <full signature>
```

- [ ] **Step 2:** Commit

```bash
git add docs/superpowers/plans/2026-04-07-expert-team-discovery.md
git commit -m "docs: discovery report scaffold for expert-team plan"
```

### Task 0.2: D1 — 个人服务当前资金流

- [ ] **Step 1:** Grep Payment Intent 创建代码

```bash
grep -n "PaymentIntent.create" backend/app/task_expert_routes.py
```

- [ ] **Step 2:** Read 找到的位置 ±20 行,看是否设了 `transfer_data` 或 `application_fee_amount`。

- [ ] **Step 3:** 把结果填入 discovery D1 段。结论一定是"manual transfer"或"destination charge"二选一。

- [ ] **Step 4:** Commit

```bash
git add docs/superpowers/plans/2026-04-07-expert-team-discovery.md
git commit -m "docs(discovery): D1 individual service payment flow"
```

### Task 0.3: D2 — 任务完成端点

- [ ] **Step 1:**

```bash
grep -rn "status.*completed\|status.*=.*'completed'\|task.status = " backend/app/ --include="*.py" | grep -v test
```

- [ ] **Step 2:** 阅读每个候选位置,找出所有真正会把 task.status 转为 'completed' 的代码路径。常见入口:
  - 客户确认完成
  - 系统自动完成(如果有)
  - 管理员手工完成

- [ ] **Step 3:** 把所有定位填入 discovery D2 段,每条带文件:行 + 说明。

- [ ] **Step 4:** Commit

### Task 0.4: D3-D7 批量 grep

- [ ] **Step 1:** 一次性把这几个 grep 跑了:

```bash
# D3
grep -rn "_compute_application_fee\|application_fee\|platform_fee\|compute_fee" backend/app/ --include="*.py" | grep -v test | head -20

# D4
grep -n "payment_charge_id\|charge_id\|stripe_charge" backend/app/models.py

# D6
grep -n "stripe.Webhook\|webhook_secret\|construct_event" backend/app/routers.py

# D7
grep -n "transfer_ownership\|ownership_transfer\|change_owner" backend/app/expert_routes.py
```

- [ ] **Step 2:** 把每条结果填入 discovery D3/D4/D6/D7 段。

- [ ] **Step 3:** D5 是设计决策,无需 grep。**默认决定:** 放在 `backend/app/models_expert.py`(和 `Expert` 模型在一起,逻辑相关)。如果文件已经太大可以放新文件。把决定填入 discovery D5 段。

- [ ] **Step 4:** Commit

### Task 0.5: D8-D11 批量 grep

- [ ] **Step 1:**

```bash
# D8
grep -rn "Account.create\|stripe.Account\|connect_account" backend/app/ --include="*.py" | grep -v test

# D9
grep -n "wallet_accounts\|wallet_service\|credit_balance\|wallet_account.balance" backend/app/task_expert_routes.py
grep -rn "WalletAccount\|update.*balance" backend/app/wallet_routes.py backend/app/wallet_service.py 2>/dev/null

# D10
grep -rn "refund\|Refund\|stripe.Refund" backend/app/ --include="*.py" | grep -v test | head -20

# D11
ls backend/app/tasks/ 2>/dev/null
grep -rn "@shared_task\|@celery_app.task" backend/app/ --include="*.py" | head -10
```

- [ ] **Step 2:** 把结果填入 discovery D8-D11 段。**对 D9 的结论尤其重要** —— 它决定 §4.4 走 A 还是 B 回退,影响 Phase 4 的范围。

- [ ] **Step 3:** Commit

### Task 0.6: D12-D15 批量 grep

- [ ] **Step 1:**

```bash
# D12
grep -n "payment_completed_at\|paid_at\|payment_intent_succeeded" backend/app/models.py

# D13
grep -rn "STRIPE_WEBHOOK\|webhook_secret" backend/app/ --include="*.py" backend/.env.example 2>/dev/null

# D14
grep -rn "points_balance\|credit_points\|add_points\|points_reward" backend/app/ --include="*.py" | grep -v test | head -20

# D15
grep -n "_get_member_or_403\|get_member_or_403" backend/app/expert_routes.py backend/app/expert_service_routes.py
```

- [ ] **Step 2:** 把结果填入 discovery D12-D15 段。

- [ ] **Step 3:** **重要:** 如果 D12 的 `payment_completed_at` 字段不存在,在 discovery 文档里加一行 "Phase 1 需要新增此列",Phase 1.4 会处理。

- [ ] **Step 4:** Commit

```bash
git add docs/superpowers/plans/2026-04-07-expert-team-discovery.md
git commit -m "docs(discovery): D12-D15 grep results"
```

### Task 0.7: 决定 §4.4 走 A 还是 B

- [ ] **Step 1:** 根据 D1 + D9 的结果做决策:
  - 如果 D1 = "manual transfer" → 走 §4.4 **A**(已经对齐,Phase 4 只需要让团队任务复用 manual transfer)
  - 如果 D1 = "destination charge" 且 D9 wallet credit 路径**存在** → 走 §4.4 **A**(把个人路径也迁过去,补丁很小)
  - 如果 D1 = "destination charge" 且 D9 wallet credit 路径**不存在** → 走 §4.4 **B 回退**(团队走 manual,个人保持 destination charge,代码加 if-else 分叉)

- [ ] **Step 2:** 在 discovery 文档底部加一段 "## §4.4 决策":

```markdown
## §4.4 决策

基于 D1 + D9 的结果,Phase 4 走 [A | B] 路径:
- 选择: <A | B>
- 理由: <一句话>
- 影响: <Phase 4 的 task 数量是否需要调整>
```

- [ ] **Step 3:** Commit

```bash
git add docs/superpowers/plans/2026-04-07-expert-team-discovery.md
git commit -m "docs(discovery): §4.4 A/B branch decision"
```

---

# Phase 1: Schema Migrations + ORM Models

### Task 1.1: Migration 176 — tasks 加 taker_expert_id

**Files:**
- Create: `backend/migrations/176_add_tasks_taker_expert_id.sql`

- [ ] **Step 1:** 创建文件:

```sql
-- ===========================================
-- 迁移 176: tasks 加 taker_expert_id 列(团队接单经济主体)
-- spec: docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md §1.1
-- ===========================================

BEGIN;

ALTER TABLE tasks
  ADD COLUMN taker_expert_id VARCHAR(8) NULL
    REFERENCES experts(id) ON DELETE RESTRICT;

CREATE INDEX ix_tasks_taker_expert
  ON tasks(taker_expert_id)
  WHERE taker_expert_id IS NOT NULL;

COMMENT ON COLUMN tasks.taker_id IS
  '任务接单自然人。团队接单时填团队 owner 的 user_id 作为"团队代表",真正的经济主体看 taker_expert_id。';
COMMENT ON COLUMN tasks.taker_expert_id IS
  '团队接单时的经济主体。非 NULL 时钱转到 experts.stripe_account_id,个人路径不走 wallet_accounts。';

COMMIT;
```

- [ ] **Step 2:** 在 staging 数据库跑迁移(本地或 staging,取决于团队习惯):

```bash
psql $DATABASE_URL -f backend/migrations/176_add_tasks_taker_expert_id.sql
```

预期输出: `BEGIN`, `ALTER TABLE`, `CREATE INDEX`, `COMMENT`, `COMMIT`

- [ ] **Step 3:** 验证字段创建成功:

```bash
psql $DATABASE_URL -c "\d tasks" | grep taker_expert_id
```

预期: `taker_expert_id | character varying(8) | | |`

- [ ] **Step 4:** Commit

```bash
git add backend/migrations/176_add_tasks_taker_expert_id.sql
git commit -m "feat(db): add tasks.taker_expert_id column for team-as-taker"
```

### Task 1.2: Migration 177 — activities 加多态所有权

**Files:**
- Create: `backend/migrations/177_add_activities_owner_polymorphic.sql`

- [ ] **Step 1:** 创建文件:

```sql
-- ===========================================
-- 迁移 177: activities 加 owner_type/owner_id 多态列
-- spec §1.2
-- ===========================================

BEGIN;

ALTER TABLE activities
  ADD COLUMN owner_type VARCHAR(20) NOT NULL DEFAULT 'user'
    CHECK (owner_type IN ('user', 'expert')),
  ADD COLUMN owner_id VARCHAR(8) NULL;

-- 回填:现有活动全部是个人拥有
UPDATE activities SET owner_id = expert_id WHERE owner_id IS NULL;

ALTER TABLE activities ALTER COLUMN owner_id SET NOT NULL;

CREATE INDEX ix_activities_owner ON activities(owner_type, owner_id);

COMMENT ON COLUMN activities.owner_type IS
  '所有权类型: user=个人用户, expert=达人团队';
COMMENT ON COLUMN activities.owner_id IS
  'owner_type=user 时指向 users.id; owner_type=expert 时指向 experts.id';
COMMENT ON COLUMN activities.expert_id IS
  '[legacy] 原个人 owner 字段,保留以避免全代码库 grep 风险。团队活动时填 team owner 的 user_id 作为代表。';

COMMIT;
```

- [ ] **Step 2:** 跑迁移:

```bash
psql $DATABASE_URL -f backend/migrations/177_add_activities_owner_polymorphic.sql
```

- [ ] **Step 3:** 验证回填零 NULL:

```bash
psql $DATABASE_URL -c "SELECT COUNT(*) FROM activities WHERE owner_id IS NULL;"
```

预期: `0`

- [ ] **Step 4:** Commit

```bash
git add backend/migrations/177_add_activities_owner_polymorphic.sql
git commit -m "feat(db): add activities polymorphic ownership columns"
```

### Task 1.3: Migration 178 — expert_stripe_transfers 审计表

**Files:**
- Create: `backend/migrations/178_create_expert_stripe_transfers.sql`

- [ ] **Step 1:** 创建文件:

```sql
-- ===========================================
-- 迁移 178: expert_stripe_transfers 审计表
-- spec §1.3
-- ===========================================

BEGIN;

CREATE TABLE expert_stripe_transfers (
    id                   BIGSERIAL PRIMARY KEY,
    task_id              INTEGER NOT NULL REFERENCES tasks(id) ON DELETE RESTRICT,
    expert_id            VARCHAR(8) NOT NULL REFERENCES experts(id) ON DELETE RESTRICT,
    amount               DECIMAL(12,2) NOT NULL,
    currency             VARCHAR(3) NOT NULL DEFAULT 'GBP',
    stripe_transfer_id   VARCHAR(255) NULL,
    stripe_reversal_id   VARCHAR(255) NULL,
    stripe_charge_id     VARCHAR(255) NULL,
    status               VARCHAR(20) NOT NULL,
    idempotency_key      VARCHAR(64) NOT NULL,
    error_message        TEXT NULL,
    error_code           VARCHAR(100) NULL,
    attempt_count        INTEGER NOT NULL DEFAULT 0,
    last_attempt_at      TIMESTAMPTZ NULL,
    reversed_at          TIMESTAMPTZ NULL,
    reversed_reason      TEXT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_est_task UNIQUE (task_id),
    CONSTRAINT uq_est_idempotency UNIQUE (idempotency_key),
    CONSTRAINT chk_est_status CHECK (status IN ('pending','succeeded','failed','reversed'))
);

CREATE INDEX ix_est_expert
  ON expert_stripe_transfers(expert_id, created_at DESC);

CREATE INDEX ix_est_status
  ON expert_stripe_transfers(status)
  WHERE status IN ('pending', 'failed');

CREATE INDEX ix_est_charge
  ON expert_stripe_transfers(stripe_charge_id)
  WHERE stripe_charge_id IS NOT NULL;

COMMIT;
```

- [ ] **Step 2:** 跑迁移:

```bash
psql $DATABASE_URL -f backend/migrations/178_create_expert_stripe_transfers.sql
```

- [ ] **Step 3:** 验证表 + 约束:

```bash
psql $DATABASE_URL -c "\d expert_stripe_transfers"
```

确认看到 4 个 UNIQUE/CHECK 约束 + 3 个索引。

- [ ] **Step 4:** Commit

### Task 1.4: 如果 D12 缺 payment_completed_at,补一个 migration

**条件任务:** 仅当 Discovery D12 显示 `tasks.payment_completed_at` 不存在时执行。

- [ ] **Step 1:** 创建 `backend/migrations/178a_add_tasks_payment_completed_at.sql`:

```sql
BEGIN;

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS payment_completed_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS ix_tasks_payment_completed_at
  ON tasks(payment_completed_at)
  WHERE payment_completed_at IS NOT NULL;

COMMENT ON COLUMN tasks.payment_completed_at IS
  '客户付款 Stripe charge 成功的时间。用于 Stripe Transfer 90 天时效检查(spec §3.4a)。';

COMMIT;
```

- [ ] **Step 2:** 跑迁移并验证

- [ ] **Step 3:** 在 discovery D12 段更新结论:"已通过 178a 新增"

- [ ] **Step 4:** Commit

### Task 1.5: SQLAlchemy 模型 — Task 加 taker_expert_id

**Files:**
- Modify: `backend/app/models.py`

- [ ] **Step 1:** 在 Task 类(grep `class Task(Base)` 定位)的字段定义里,在 `taker_id` 后面加一行:

```python
taker_expert_id = Column(String(8), ForeignKey("experts.id", ondelete="RESTRICT"), nullable=True)
```

- [ ] **Step 2:** 如果 Task 类有 `__repr__` 或 serializer 方法,顺带加一行(可选)。

- [ ] **Step 3:** 启动 Python REPL 验证 import 不报错:

```bash
python -c "from backend.app.models import Task; print(Task.taker_expert_id)"
```

预期: 输出 `Task.taker_expert_id` 列对象。

- [ ] **Step 4:** Commit

```bash
git add backend/app/models.py
git commit -m "feat(models): add Task.taker_expert_id field"
```

### Task 1.6: SQLAlchemy 模型 — Activity 加多态字段

**Files:**
- Modify: `backend/app/models.py`(Activity 类附近,grep `class Activity(Base)` 定位)

- [ ] **Step 1:** 在 Activity 类字段定义里加:

```python
owner_type = Column(String(20), nullable=False, server_default='user')
owner_id = Column(String(8), nullable=False)
```

注意:这俩字段 **没有** FK 约束(因为 owner_id 是多态的,不能指向单一表)。CHECK 约束已经在 SQL 层做了。

- [ ] **Step 2:** Verify:

```bash
python -c "from backend.app.models import Activity; print(Activity.owner_type, Activity.owner_id)"
```

- [ ] **Step 3:** Commit

### Task 1.7: SQLAlchemy 模型 — ExpertStripeTransfer

**Files:**
- Modify: `backend/app/models_expert.py`(根据 D5 决定的位置,默认放这里)

- [ ] **Step 1:** 在文件末尾加新类:

```python
class ExpertStripeTransfer(Base):
    """达人团队 Stripe Transfer 审计流水。spec §1.3"""
    __tablename__ = "expert_stripe_transfers"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="RESTRICT"), nullable=False)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="RESTRICT"), nullable=False)
    amount = Column(DECIMAL(12, 2), nullable=False)
    currency = Column(String(3), nullable=False, default='GBP')
    stripe_transfer_id = Column(String(255), nullable=True)
    stripe_reversal_id = Column(String(255), nullable=True)
    stripe_charge_id = Column(String(255), nullable=True)
    status = Column(String(20), nullable=False)
    idempotency_key = Column(String(64), nullable=False, unique=True)
    error_message = Column(Text, nullable=True)
    error_code = Column(String(100), nullable=True)
    attempt_count = Column(Integer, nullable=False, default=0)
    last_attempt_at = Column(DateTime(timezone=True), nullable=True)
    reversed_at = Column(DateTime(timezone=True), nullable=True)
    reversed_reason = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=get_utc_time, onupdate=get_utc_time, server_default=func.now())

    __table_args__ = (
        UniqueConstraint('task_id', name='uq_est_task'),
        UniqueConstraint('idempotency_key', name='uq_est_idempotency'),
        CheckConstraint(
            "status IN ('pending','succeeded','failed','reversed')",
            name='chk_est_status'
        ),
    )
```

- [ ] **Step 2:** 确认所有 import 在文件顶部存在(`Column`, `BigInteger`, `Integer`, `String`, `DECIMAL`, `Text`, `DateTime`, `ForeignKey`, `UniqueConstraint`, `CheckConstraint`, `get_utc_time`, `func`, `Base`)。

- [ ] **Step 3:** Verify import:

```bash
python -c "from backend.app.models_expert import ExpertStripeTransfer; print(ExpertStripeTransfer.__tablename__)"
```

预期: `expert_stripe_transfers`

- [ ] **Step 4:** Commit

```bash
git add backend/app/models_expert.py
git commit -m "feat(models): add ExpertStripeTransfer ORM model"
```

---

# Phase 2: Helper Functions

### Task 2.1: 写 resolve_task_taker_from_service 测试

**Files:**
- Create: `backend/tests/test_expert_task_resolver.py`

- [ ] **Step 1:** 创建文件:

```python
"""单元测试 expert_task_resolver helper. spec §4.2 / §4.3a"""
import pytest
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException

# import 路径在实现完成后填,先用占位
# from backend.app.services.expert_task_resolver import (
#     resolve_task_taker_from_service,
#     resolve_task_taker_from_activity,
# )


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
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_service
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = fake_owner_member
    mock_db.execute.return_value = result_obj

    taker_id, taker_expert_id = await resolve_task_taker_from_service(mock_db, fake_service)
    assert taker_id == 'u_owner01'
    assert taker_expert_id == 'e_test01'


@pytest.mark.asyncio
async def test_resolve_service_user_personal(mock_db):
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_service
    s = MagicMock()
    s.owner_type = 'user'
    s.owner_id = 'u_personal01'

    taker_id, taker_expert_id = await resolve_task_taker_from_service(mock_db, s)
    assert taker_id == 'u_personal01'
    assert taker_expert_id is None


@pytest.mark.asyncio
async def test_resolve_service_team_no_stripe(mock_db, fake_service, fake_expert):
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_service
    fake_expert.stripe_onboarding_complete = False
    mock_db.get.return_value = fake_expert

    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, fake_service)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_stripe_not_ready'


@pytest.mark.asyncio
async def test_resolve_service_team_non_gbp(mock_db, fake_service, fake_expert):
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_service
    fake_service.currency = 'USD'
    mock_db.get.return_value = fake_expert

    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, fake_service)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_currency_unsupported'


@pytest.mark.asyncio
async def test_resolve_service_team_no_owner(mock_db, fake_service, fake_expert):
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_service
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
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_service
    s = MagicMock()
    s.owner_type = 'alien'

    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_service(mock_db, s)
    assert exc.value.status_code == 500
```

- [ ] **Step 2:** 跑测试,确认全部 fail:

```bash
cd backend && pytest tests/test_expert_task_resolver.py -v
```

预期: `ImportError` 或 6 个 fail (helper 还没写)

- [ ] **Step 3:** Commit

```bash
git add backend/tests/test_expert_task_resolver.py
git commit -m "test(resolver): failing tests for resolve_task_taker_from_service"
```

### Task 2.2: 实现 resolve_task_taker_from_service

**Files:**
- Create: `backend/app/services/__init__.py`(若不存在)
- Create: `backend/app/services/expert_task_resolver.py`

- [ ] **Step 1:** 确认 services 包存在:

```bash
test -d backend/app/services || mkdir -p backend/app/services && touch backend/app/services/__init__.py
```

- [ ] **Step 2:** 创建 `backend/app/services/expert_task_resolver.py`:

```python
"""
Helper to resolve (taker_id, taker_expert_id) from expert_service or activity.

spec: docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md §4.2 §4.3a

团队接单(owner_type='expert')→ (team_owner.user_id, expert.id)
个人接单(owner_type='user')   → (owner_user_id, None)

团队路径会校验 Stripe onboarding 状态 + 币种 (GBP only)。
"""
from typing import Optional, Tuple
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException

from backend.app import models
from backend.app.models_expert import Expert, ExpertMember


async def resolve_task_taker_from_service(
    db: AsyncSession,
    service: "models.TaskExpertService",
) -> Tuple[str, Optional[str]]:
    """
    Resolve (taker_id, taker_expert_id) from a TaskExpertService row.

    Returns:
        (taker_id, taker_expert_id):
        - owner_type='expert': (team_owner.user_id, expert.id)
        - owner_type='user':   (service.owner_id, None)

    Raises:
        HTTPException 404 if expert team not found
        HTTPException 409 if team not stripe-onboarded or non-GBP
        HTTPException 500 if team has no active owner / unknown owner_type
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
        # 币种检查 §1.4
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

预期: 6 个 PASS

- [ ] **Step 4:** Commit

```bash
git add backend/app/services/__init__.py backend/app/services/expert_task_resolver.py
git commit -m "feat(resolver): implement resolve_task_taker_from_service"
```

### Task 2.3: 写 resolve_task_taker_from_activity 测试

**Files:**
- Modify: `backend/tests/test_expert_task_resolver.py`

- [ ] **Step 1:** 在文件末尾追加:

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
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_activity
    mock_db.get.return_value = fake_expert
    result_obj = MagicMock()
    result_obj.scalar_one_or_none.return_value = fake_owner_member
    mock_db.execute.return_value = result_obj

    taker_id, taker_expert_id = await resolve_task_taker_from_activity(mock_db, fake_activity)
    assert taker_id == 'u_owner01'
    assert taker_expert_id == 'e_test01'


@pytest.mark.asyncio
async def test_resolve_activity_user_legacy(mock_db):
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_activity
    a = MagicMock()
    a.owner_type = 'user'
    a.expert_id = 'u_legacy01'

    taker_id, taker_expert_id = await resolve_task_taker_from_activity(mock_db, a)
    assert taker_id == 'u_legacy01'
    assert taker_expert_id is None


@pytest.mark.asyncio
async def test_resolve_activity_team_non_gbp(mock_db, fake_activity, fake_expert):
    from backend.app.services.expert_task_resolver import resolve_task_taker_from_activity
    fake_activity.currency = 'EUR'
    mock_db.get.return_value = fake_expert

    with pytest.raises(HTTPException) as exc:
        await resolve_task_taker_from_activity(mock_db, fake_activity)
    assert exc.value.status_code == 409
    assert exc.value.detail['error_code'] == 'expert_currency_unsupported'
```

- [ ] **Step 2:** 跑测试:

```bash
cd backend && pytest tests/test_expert_task_resolver.py::test_resolve_activity_team_happy_path -v
```

预期: ImportError(`resolve_task_taker_from_activity` 不存在)

- [ ] **Step 3:** Commit

### Task 2.4: 实现 resolve_task_taker_from_activity

**Files:**
- Modify: `backend/app/services/expert_task_resolver.py`

- [ ] **Step 1:** 在文件末尾追加:

```python
async def resolve_task_taker_from_activity(
    db: AsyncSession,
    activity: "models.Activity",
) -> Tuple[str, Optional[str]]:
    """
    Resolve (taker_id, taker_expert_id) from an Activity row.

    Returns:
        (taker_id, taker_expert_id):
        - owner_type='expert': (team_owner.user_id, expert.id)
        - owner_type='user':   (activity.expert_id, None)  # legacy 个人活动

    Raises: same as resolve_task_taker_from_service.
    """
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

- [ ] **Step 2:** 跑全部 resolver 测试:

```bash
cd backend && pytest tests/test_expert_task_resolver.py -v
```

预期: 9 个 PASS(6 + 3)

- [ ] **Step 3:** Commit

```bash
git add backend/app/services/expert_task_resolver.py backend/tests/test_expert_task_resolver.py
git commit -m "feat(resolver): add resolve_task_taker_from_activity helper"
```

---

# Phase 3: Stripe Onboarding Endpoints + Webhook

### Task 3.1: 写 Stripe Onboarding 端点契约测试

**Files:**
- Create: `backend/tests/test_expert_stripe_routes.py`

- [ ] **Step 1:** 创建测试(用 FastAPI TestClient + mock Stripe):

```python
"""测试 Stripe Onboarding 端点. spec §2.3"""
import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

# 这些 fixture 需要在你的 conftest.py 里有对应的实现
# - client: TestClient with auth middleware bypass
# - db_session: rollback per test
# - team_owner_user: a logged-in team owner
# - test_expert: an Expert row with stripe_account_id=None


def test_post_onboarding_creates_account_link(client, test_expert, team_owner_user):
    with patch('stripe.Account.create') as mock_acc, \
         patch('stripe.AccountLink.create') as mock_link:
        mock_acc.return_value = MagicMock(id='acct_test01')
        mock_link.return_value = MagicMock(url='https://stripe.test/onboard', expires_at=1234567890)

        resp = client.post(
            f"/api/experts/{test_expert.id}/stripe/onboarding",
            headers={'Authorization': f'Bearer {team_owner_user.token}'}
        )

    assert resp.status_code == 200
    body = resp.json()
    assert body['url'] == 'https://stripe.test/onboard'
    assert body['expires_at'] == 1234567890
    mock_acc.assert_called_once()
    mock_link.assert_called_once()


def test_post_onboarding_reuses_existing_account(client, test_expert_with_stripe, team_owner_user):
    """已经创建过 Stripe 账户,只生成新的 AccountLink。"""
    with patch('stripe.Account.create') as mock_acc, \
         patch('stripe.AccountLink.create') as mock_link:
        mock_link.return_value = MagicMock(url='https://stripe.test/onboard2', expires_at=1234567899)

        resp = client.post(
            f"/api/experts/{test_expert_with_stripe.id}/stripe/onboarding",
            headers={'Authorization': f'Bearer {team_owner_user.token}'}
        )

    assert resp.status_code == 200
    mock_acc.assert_not_called()
    mock_link.assert_called_once()


def test_post_onboarding_member_forbidden(client, test_expert, regular_member_user):
    """普通 member 不能触发 Onboarding。"""
    resp = client.post(
        f"/api/experts/{test_expert.id}/stripe/onboarding",
        headers={'Authorization': f'Bearer {regular_member_user.token}'}
    )
    assert resp.status_code == 403


def test_get_status_returns_current_state(client, test_expert_with_stripe, team_owner_user):
    with patch('stripe.Account.retrieve') as mock_retrieve:
        mock_retrieve.return_value = MagicMock(
            charges_enabled=True,
            requirements=MagicMock(currently_due=[], past_due=[], _previous_attributes={}),
        )

        resp = client.get(
            f"/api/experts/{test_expert_with_stripe.id}/stripe/status",
            headers={'Authorization': f'Bearer {team_owner_user.token}'}
        )

    assert resp.status_code == 200
    body = resp.json()
    assert body['charges_enabled'] is True


def test_get_status_member_allowed(client, test_expert_with_stripe, regular_member_user):
    """status 端点所有 active 成员可查。"""
    with patch('stripe.Account.retrieve') as mock_retrieve:
        mock_retrieve.return_value = MagicMock(
            charges_enabled=True,
            requirements=MagicMock(currently_due=[], past_due=[], _previous_attributes={}),
        )

        resp = client.get(
            f"/api/experts/{test_expert_with_stripe.id}/stripe/status",
            headers={'Authorization': f'Bearer {regular_member_user.token}'}
        )

    assert resp.status_code == 200
```

- [ ] **Step 2:** 跑测试,确认 fail(模块不存在):

```bash
cd backend && pytest tests/test_expert_stripe_routes.py -v
```

- [ ] **Step 3:** Commit

```bash
git add backend/tests/test_expert_stripe_routes.py
git commit -m "test(stripe): failing tests for expert Stripe onboarding endpoints"
```

### Task 3.2: 实现 expert_stripe_routes.py

**Files:**
- Create: `backend/app/expert_stripe_routes.py`
- Modify: `backend/app/main.py`(注册 router)

- [ ] **Step 1:** 创建 `backend/app/expert_stripe_routes.py`:

```python
"""
Stripe Connect onboarding 端点 for expert teams.
spec §2.3
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
import stripe

from backend.app.database import get_db
from backend.app.models_expert import Expert
from backend.app.expert_routes import _get_member_or_403  # 复用现有 RBAC helper
from backend.app.secure_auth import get_current_user_secure_async_csrf

router = APIRouter(prefix="/api/experts", tags=["expert-stripe"])


# Stripe Account 类型 — 见 discovery D8。默认 'standard',如果 D8 决定了别的就改这里。
STRIPE_ACCOUNT_TYPE = "standard"


@router.post("/{expert_id}/stripe/onboarding")
async def start_stripe_onboarding(
    expert_id: str,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    """启动 Stripe Connect onboarding。返回 AccountLink URL。仅 owner/admin。"""
    expert = await db.get(Expert, expert_id)
    if not expert:
        raise HTTPException(404, "Expert team not found")

    await _get_member_or_403(db, expert_id, current_user.id, roles=['owner', 'admin'])

    # 第一次:创建 Stripe Account
    if not expert.stripe_account_id:
        account = stripe.Account.create(
            type=STRIPE_ACCOUNT_TYPE,
            country=expert.stripe_connect_country or 'GB',
            email=current_user.email,
            metadata={'expert_id': expert.id},
        )
        expert.stripe_account_id = account.id
        await db.commit()

    # 生成 AccountLink (用户跳转去填表)
    link = stripe.AccountLink.create(
        account=expert.stripe_account_id,
        type='account_onboarding',
        refresh_url=f"https://link2ur.com/expert/{expert_id}/stripe/refresh",
        return_url=f"https://link2ur.com/expert/{expert_id}/stripe/return",
    )

    return {"url": link.url, "expires_at": link.expires_at}


@router.get("/{expert_id}/stripe/status")
async def get_stripe_status(
    expert_id: str,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    """查 Stripe Connect 状态。所有 active 成员可查。"""
    expert = await db.get(Expert, expert_id)
    if not expert:
        raise HTTPException(404, "Expert team not found")

    await _get_member_or_403(db, expert_id, current_user.id, roles=['owner', 'admin', 'member'])

    if not expert.stripe_account_id:
        return {
            "onboarding_complete": False,
            "charges_enabled": False,
            "requirements": None,
            "stripe_account_id": None,
        }

    account = stripe.Account.retrieve(expert.stripe_account_id)
    requirements = {}
    if hasattr(account, 'requirements') and account.requirements:
        requirements = {
            'currently_due': list(account.requirements.currently_due or []),
            'past_due': list(account.requirements.past_due or []),
        }

    return {
        "onboarding_complete": expert.stripe_onboarding_complete,
        "charges_enabled": bool(account.charges_enabled),
        "requirements": requirements,
        "stripe_account_id": expert.stripe_account_id,
    }
```

- [ ] **Step 2:** 在 `main.py`(grep `app.include_router`)注册:

```python
from backend.app.expert_stripe_routes import router as expert_stripe_router
app.include_router(expert_stripe_router)
```

- [ ] **Step 3:** 跑测试:

```bash
cd backend && pytest tests/test_expert_stripe_routes.py -v
```

预期: 5 个 PASS(假设 fixture 都到位)

- [ ] **Step 4:** Commit

```bash
git add backend/app/expert_stripe_routes.py backend/app/main.py
git commit -m "feat(stripe): expert team Stripe Connect onboarding endpoints"
```

### Task 3.3: 写 Webhook account.updated 分支测试

**Files:**
- Create or Modify: `backend/tests/test_stripe_webhook_handlers.py`

- [ ] **Step 1:** 创建测试:

```python
"""测试 webhook account.updated handler. spec §2.4"""
import json
import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient


def _build_event(event_type, obj_data):
    return {
        'id': 'evt_test01',
        'type': event_type,
        'data': {'object': obj_data},
    }


def test_account_updated_charges_enabled_unchanged(client, db_session, test_expert_with_stripe):
    """已经 onboarding_complete 的团队,charges_enabled=True 事件:不变更。"""
    test_expert_with_stripe.stripe_onboarding_complete = True
    db_session.commit()

    payload = json.dumps(_build_event('account.updated', {
        'id': test_expert_with_stripe.stripe_account_id,
        'charges_enabled': True,
    }))

    with patch('stripe.Webhook.construct_event') as mock_verify:
        mock_verify.return_value = json.loads(payload)
        resp = client.post('/api/stripe/webhook', data=payload, headers={'Stripe-Signature': 'fake'})

    assert resp.status_code == 200
    db_session.refresh(test_expert_with_stripe)
    assert test_expert_with_stripe.stripe_onboarding_complete is True


def test_account_updated_disables_charges_suspends_services(
    client, db_session, test_expert_with_stripe, test_active_team_service
):
    """charges_enabled 从 True 变 False:挂起所有 active 团队服务。"""
    test_expert_with_stripe.stripe_onboarding_complete = True
    test_active_team_service.status = 'active'
    db_session.commit()

    payload = json.dumps(_build_event('account.updated', {
        'id': test_expert_with_stripe.stripe_account_id,
        'charges_enabled': False,
    }))

    with patch('stripe.Webhook.construct_event') as mock_verify:
        mock_verify.return_value = json.loads(payload)
        client.post('/api/stripe/webhook', data=payload, headers={'Stripe-Signature': 'fake'})

    db_session.refresh(test_expert_with_stripe)
    db_session.refresh(test_active_team_service)
    assert test_expert_with_stripe.stripe_onboarding_complete is False
    assert test_active_team_service.status == 'inactive'
```

- [ ] **Step 2:** 跑测试,确认 fail。

- [ ] **Step 3:** Commit

### Task 3.4: 实现 account.updated webhook 分支

**Files:**
- Modify: `backend/app/routers.py`(根据 D6 的位置)

- [ ] **Step 1:** 在现有 webhook handler 函数里(grep `stripe.Webhook.construct_event` 定位),加 `account.updated` 分支。基于 D6 的精确位置插入:

```python
elif event.type == 'account.updated':
    from backend.app.models_expert import Expert
    from sqlalchemy import select, update
    from backend.app import models

    acct = event.data.object
    result = await db.execute(
        select(Expert).where(Expert.stripe_account_id == acct.id)
    )
    expert = result.scalar_one_or_none()
    if not expert:
        # 不是团队账户(可能是个人 user 的 Connect 账户),无视
        return {"received": True}

    new_status = bool(acct.charges_enabled)
    if expert.stripe_onboarding_complete != new_status:
        expert.stripe_onboarding_complete = new_status
        if not new_status:
            # 断开时自动挂起所有 active 团队服务
            await db.execute(
                update(models.TaskExpertService)
                .where(
                    models.TaskExpertService.owner_type == 'expert',
                    models.TaskExpertService.owner_id == expert.id,
                    models.TaskExpertService.status == 'active'
                )
                .values(status='inactive')
            )
        await db.commit()
    return {"received": True}
```

- [ ] **Step 2:** 跑测试:

```bash
cd backend && pytest tests/test_stripe_webhook_handlers.py::test_account_updated_disables_charges_suspends_services -v
```

预期: PASS

- [ ] **Step 3:** **手动**(或通过 README 提醒)在 Stripe Dashboard → Developers → Webhooks 给现有 endpoint 订阅 `account.updated` 事件,并勾选 "Listen to events on Connected accounts"。

- [ ] **Step 4:** Commit

```bash
git add backend/app/routers.py backend/tests/test_stripe_webhook_handlers.py
git commit -m "feat(webhook): handle account.updated to sync expert stripe status"
```

---

# Phase 4: 老 task_expert_routes.py 内部重写(S2)

### Task 4.1: 修改服务发布端点 — 加 Stripe + GBP 门槛

**Files:**
- Modify: `backend/app/expert_service_routes.py:106-133`

- [ ] **Step 1:** 在 `POST /api/experts/{expert_id}/services` handler 函数体的开头(`_get_member_or_403` 之后)加:

```python
expert = await db.get(Expert, expert_id)
if not expert:
    raise HTTPException(404, "Expert team not found")
if not expert.stripe_onboarding_complete:
    raise HTTPException(status_code=409, detail={
        "error_code": "expert_stripe_not_ready",
        "message": "Team must complete Stripe onboarding before publishing services",
    })

# 币种检查 §1.4
if (body.currency or 'GBP').upper() != 'GBP':
    raise HTTPException(status_code=422, detail={
        "error_code": "expert_currency_unsupported",
        "message": "Team services only support GBP currently",
    })
```

- [ ] **Step 2:** 确认 `Expert` 已 import 在文件顶部。

- [ ] **Step 3:** 写测试 `backend/tests/test_expert_publish_endpoints.py`:

```python
def test_publish_service_blocked_when_stripe_not_ready(
    client, db_session, test_expert_no_stripe, team_owner_user
):
    test_expert_no_stripe.stripe_onboarding_complete = False
    db_session.commit()

    resp = client.post(
        f"/api/experts/{test_expert_no_stripe.id}/services",
        json={'service_name': 'Test', 'base_price': 100, 'currency': 'GBP', 'category': 'test'},
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert resp.status_code == 409
    assert resp.json()['detail']['error_code'] == 'expert_stripe_not_ready'


def test_publish_service_blocked_when_non_gbp(
    client, db_session, test_expert_with_stripe, team_owner_user
):
    resp = client.post(
        f"/api/experts/{test_expert_with_stripe.id}/services",
        json={'service_name': 'Test', 'base_price': 100, 'currency': 'USD', 'category': 'test'},
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert resp.status_code == 422
    assert resp.json()['detail']['error_code'] == 'expert_currency_unsupported'


def test_publish_service_succeeds_when_ready(
    client, db_session, test_expert_with_stripe, team_owner_user
):
    resp = client.post(
        f"/api/experts/{test_expert_with_stripe.id}/services",
        json={'service_name': 'Test', 'base_price': 100, 'currency': 'GBP', 'category': 'test'},
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert resp.status_code in (200, 201)
```

- [ ] **Step 4:** 跑测试,3 个 PASS。

- [ ] **Step 5:** Commit

```bash
git add backend/app/expert_service_routes.py backend/tests/test_expert_publish_endpoints.py
git commit -m "feat(expert): gate service publishing on Stripe onboarding + GBP"
```

### Task 4.2: 改 task_expert_routes.py 咨询任务创建 — 调 helper

**Files:**
- Modify: `backend/app/task_expert_routes.py:3090-3130`

- [ ] **Step 1:** 找到咨询任务创建函数(grep "task_source.*consultation" 或 "咨询" 定位)。在创建 Task 之前,把:

```python
new_task = models.Task(
    title=f"咨询: {service.service_name}",
    ...
    poster_id=current_user.id,
    taker_id=service.owner_user_id,  # ← 旧
    expert_service_id=service.id,
    ...
)
```

改成:

```python
from backend.app.services.expert_task_resolver import resolve_task_taker_from_service

taker_id_value, taker_expert_id_value = await resolve_task_taker_from_service(db, service)

new_task = models.Task(
    title=f"咨询: {service.service_name}",
    ...
    poster_id=current_user.id,
    taker_id=taker_id_value,
    taker_expert_id=taker_expert_id_value,  # 新字段
    expert_service_id=service.id,
    ...
)
```

- [ ] **Step 2:** 写集成测试 `backend/tests/test_consultation_creation.py`:

```python
def test_consultation_team_service_sets_taker_expert_id(
    client, db_session, test_team_service, customer_user, test_expert_with_stripe
):
    """团队服务咨询 → Task 同时填 taker_id (owner) 和 taker_expert_id."""
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


def test_consultation_personal_service_no_taker_expert(
    client, db_session, test_personal_service, customer_user
):
    """个人服务咨询 → Task 只填 taker_id, taker_expert_id IS NULL."""
    resp = client.post(
        '/api/expert-services/consult',
        json={'service_id': test_personal_service.id},
        headers={'Authorization': f'Bearer {customer_user.token}'},
    )
    assert resp.status_code == 200
    task_id = resp.json()['task_id']
    task = db_session.query(models.Task).get(task_id)
    assert task.taker_expert_id is None
    assert task.taker_id == test_personal_service.owner_id
```

- [ ] **Step 3:** 跑测试,2 个 PASS。

- [ ] **Step 4:** Commit

```bash
git add backend/app/task_expert_routes.py backend/tests/test_consultation_creation.py
git commit -m "refactor(expert): consultation creation uses resolve_task_taker helper"
```

### Task 4.3: 改 task_expert_routes.py 正式服务任务创建

**Files:**
- Modify: `backend/app/task_expert_routes.py:3820-3860`

- [ ] **Step 1:** 找到正式服务任务创建函数(grep `taker_id=application.expert_id` 定位)。在创建 Task 之前先加载 service 并调 helper:

```python
service = await db.get(models.TaskExpertService, application.service_id)
if not service:
    raise HTTPException(404, "Service not found")

from backend.app.services.expert_task_resolver import resolve_task_taker_from_service
taker_id_value, taker_expert_id_value = await resolve_task_taker_from_service(db, service)

new_task = models.Task(
    ...
    poster_id=application.applicant_id,
    taker_id=taker_id_value,
    taker_expert_id=taker_expert_id_value,
    ...
)
```

去掉原来的 `taker_id=application.expert_id` 那一行。

- [ ] **Step 2:** 写测试(类似 4.2,但走正式服务路径)。

- [ ] **Step 3:** 跑测试 PASS。

- [ ] **Step 4:** Commit

### Task 4.4: 改 Payment Intent 创建(根据 §4.4 决策)

**Files:**
- Modify: `backend/app/task_expert_routes.py:3870-3899`

- [ ] **Step 1:** **根据 discovery §4.4 决策走 A 或 B:**

**走 A(统一 manual transfer):** 把 Payment Intent 创建里的 `transfer_data` 和 `application_fee_amount` 全部去掉:

```python
intent = stripe.PaymentIntent.create(
    amount=int(gross_pence),
    currency=currency.lower(),
    payment_method_types=['card'],
    metadata={
        'task_id': str(new_task.id),
        'task_type': 'expert_service',
        'taker_expert_id': taker_expert_id_value or '',
        'taker_id': taker_id_value,
    },
    # 不设 transfer_data / application_fee_amount
)
```

**走 B(分叉):**

```python
intent_kwargs = dict(
    amount=int(gross_pence),
    currency=currency.lower(),
    payment_method_types=['card'],
    metadata={
        'task_id': str(new_task.id),
        'task_type': 'expert_service',
        'taker_expert_id': taker_expert_id_value or '',
        'taker_id': taker_id_value,
    },
)
if taker_expert_id_value is None:
    # 个人路径:维持现状,destination charge
    intent_kwargs['transfer_data'] = {'destination': taker_stripe_account_id}
    intent_kwargs['application_fee_amount'] = fee_pence
intent = stripe.PaymentIntent.create(**intent_kwargs)
```

- [ ] **Step 2:** 写测试,验证团队任务的 Payment Intent **不带** `transfer_data`:

```python
def test_team_service_payment_intent_no_destination(
    client, db_session, test_team_service, customer_user
):
    with patch('stripe.PaymentIntent.create') as mock_create:
        mock_create.return_value = MagicMock(id='pi_test', client_secret='cs_test')
        client.post(
            '/api/expert-services/order',
            json={'application_id': ...},
            headers={'Authorization': f'Bearer {customer_user.token}'},
        )
        kwargs = mock_create.call_args.kwargs
        assert 'transfer_data' not in kwargs
        assert 'application_fee_amount' not in kwargs
```

- [ ] **Step 3:** 跑测试 PASS。

- [ ] **Step 4:** Commit

```bash
git add backend/app/task_expert_routes.py backend/tests/test_consultation_creation.py
git commit -m "refactor(expert): Payment Intent uses manual transfer for team tasks"
```

---

# Phase 5: 活动路径

### Task 5.1: 创建 expert_activity_routes.py — 团队活动发布

**Files:**
- Create: `backend/app/expert_activity_routes.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1:** 创建文件:

```python
"""
团队活动发布端点。spec §2.2
现有个人活动创建端点 (multi_participant_routes.py:1754-1939) 不动,作为 grandfather。
"""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from backend.app.database import get_db
from backend.app import models
from backend.app.models_expert import Expert, ExpertMember
from backend.app.expert_routes import _get_member_or_403
from backend.app.secure_auth import get_current_user_secure_async_csrf

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
    deadline: str  # ISO datetime
    activity_end_date: Optional[str] = None
    images: Optional[list] = None
    # ... 复用现有 activity create body 字段,plan 阶段 mirror 完整列表


@router.post("/{expert_id}/activities")
async def create_team_activity(
    expert_id: str,
    body: TeamActivityCreate,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    """团队 owner/admin 创建活动。owner 自动成为 'expert_id' (legacy 字段) 的代表。"""
    expert = await db.get(Expert, expert_id)
    if not expert:
        raise HTTPException(404, "Expert team not found")

    await _get_member_or_403(db, expert_id, current_user.id, roles=['owner', 'admin'])

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

    # 找团队 owner 作为 legacy expert_id 字段
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
        # Y方案
        expert_id=owner.user_id,        # legacy 字段填代表
        owner_type='expert',            # 多态:团队
        owner_id=expert.id,
        status='open',
        is_public=True,
    )
    db.add(activity)
    await db.commit()
    await db.refresh(activity)

    return {"id": activity.id, "owner_type": "expert", "owner_id": expert.id}
```

- [ ] **Step 2:** 在 `main.py` 注册 router:

```python
from backend.app.expert_activity_routes import router as expert_activity_router
app.include_router(expert_activity_router)
```

- [ ] **Step 3:** 写测试:

```python
# backend/tests/test_team_activity_publish.py
def test_create_team_activity_happy_path(
    client, test_expert_with_stripe, team_owner_user
):
    resp = client.post(
        f"/api/experts/{test_expert_with_stripe.id}/activities",
        json={
            'title': 'Test Activity',
            'location': 'London',
            'task_type': 'workshop',
            'original_price_per_participant': 50,
            'currency': 'GBP',
            'max_participants': 10,
            'deadline': '2026-12-31T23:59:59Z',
        },
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body['owner_type'] == 'expert'
    assert body['owner_id'] == test_expert_with_stripe.id


def test_create_team_activity_blocked_no_stripe(
    client, db_session, test_expert_no_stripe, team_owner_user
):
    test_expert_no_stripe.stripe_onboarding_complete = False
    db_session.commit()

    resp = client.post(
        f"/api/experts/{test_expert_no_stripe.id}/activities",
        json={
            'title': 'X', 'location': 'L', 'task_type': 'x',
            'original_price_per_participant': 1, 'max_participants': 1,
            'deadline': '2026-12-31T23:59:59Z',
        },
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert resp.status_code == 409
```

- [ ] **Step 4:** 跑测试 PASS。

- [ ] **Step 5:** Commit

### Task 5.2: 改 multi_participant_routes.py 活动报名 → Task

**Files:**
- Modify: `backend/app/multi_participant_routes.py:236-599`

- [ ] **Step 1:** 找到所有活动报名生成 Task 的代码点(grep `parent_activity_id` 在该文件的赋值)。每个 Task 创建处插入:

```python
from backend.app.services.expert_task_resolver import resolve_task_taker_from_activity
taker_id_value, taker_expert_id_value = await resolve_task_taker_from_activity(db, activity)
```

然后把原来 `taker_id=activity.expert_id` 替换为:

```python
taker_id=taker_id_value,
taker_expert_id=taker_expert_id_value,
```

- [ ] **Step 2:** 在活动报名端点开头(在解析活动之后)加 Stripe 门槛检查(对团队活动):

```python
if activity.owner_type == 'expert':
    expert = await db.get(Expert, activity.owner_id)
    if expert and not expert.stripe_onboarding_complete:
        raise HTTPException(409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team is temporarily unable to accept new sign-ups",
        })
```

- [ ] **Step 3:** 写集成测试:团队活动报名 → 生成 Task 带 `taker_expert_id`。

- [ ] **Step 4:** 跑测试 PASS。

- [ ] **Step 5:** Commit

---

# Phase 6: Money Flow — Celery Transfer Task

### Task 6.1: 写 enqueue_expert_transfer Celery 任务测试

**Files:**
- Create: `backend/tests/test_expert_transfer_celery.py`

- [ ] **Step 1:** 创建测试(用 mock Stripe):

```python
"""测试 Celery enqueue_expert_transfer 任务. spec §3.2"""
import pytest
from decimal import Decimal
from unittest.mock import patch, MagicMock
import stripe


def test_transfer_happy_path(db_session, test_team_task_completed):
    """成功 Transfer → 写入 succeeded 行 + stripe_transfer_id."""
    from backend.app.tasks.expert_transfer import enqueue_expert_transfer
    from backend.app.models_expert import ExpertStripeTransfer

    with patch('stripe.Transfer.create') as mock_create:
        mock_create.return_value = MagicMock(id='tr_test01')
        enqueue_expert_transfer(test_team_task_completed.id)

    row = db_session.query(ExpertStripeTransfer).filter_by(
        task_id=test_team_task_completed.id
    ).one()
    assert row.status == 'succeeded'
    assert row.stripe_transfer_id == 'tr_test01'
    assert row.amount > 0


def test_transfer_idempotent_already_succeeded(db_session, test_team_task_with_succeeded_transfer):
    """已成功的任务不重复发起。"""
    from backend.app.tasks.expert_transfer import enqueue_expert_transfer
    with patch('stripe.Transfer.create') as mock_create:
        enqueue_expert_transfer(test_team_task_with_succeeded_transfer.id)
        mock_create.assert_not_called()


def test_transfer_zero_reward_short_circuit(db_session, test_team_task_zero_reward):
    """零值任务记一行 succeeded 但不调 Stripe."""
    from backend.app.tasks.expert_transfer import enqueue_expert_transfer
    from backend.app.models_expert import ExpertStripeTransfer
    with patch('stripe.Transfer.create') as mock_create:
        enqueue_expert_transfer(test_team_task_zero_reward.id)
        mock_create.assert_not_called()
    row = db_session.query(ExpertStripeTransfer).filter_by(
        task_id=test_team_task_zero_reward.id
    ).one()
    assert row.status == 'succeeded'
    assert row.amount == 0


def test_transfer_stripe_business_error_marks_failed(db_session, test_team_task_completed):
    """Stripe 业务错(4xx)→ status=failed,不重试."""
    from backend.app.tasks.expert_transfer import enqueue_expert_transfer
    from backend.app.models_expert import ExpertStripeTransfer
    with patch('stripe.Transfer.create') as mock_create:
        mock_create.side_effect = stripe.error.InvalidRequestError(
            "Test error", param='destination', code='account_invalid'
        )
        enqueue_expert_transfer(test_team_task_completed.id)
    row = db_session.query(ExpertStripeTransfer).filter_by(
        task_id=test_team_task_completed.id
    ).one()
    assert row.status == 'failed'
    assert 'account_invalid' in (row.error_code or '')


def test_transfer_window_expired(db_session, test_team_task_old_payment):
    """超过 89 天的任务直接 failed,不调 Stripe (§3.4a)."""
    from backend.app.tasks.expert_transfer import enqueue_expert_transfer
    from backend.app.models_expert import ExpertStripeTransfer
    with patch('stripe.Transfer.create') as mock_create:
        enqueue_expert_transfer(test_team_task_old_payment.id)
        mock_create.assert_not_called()
    row = db_session.query(ExpertStripeTransfer).filter_by(
        task_id=test_team_task_old_payment.id
    ).one()
    assert row.status == 'failed'
    assert row.error_code == 'stripe_transfer_window_expired'
```

- [ ] **Step 2:** 跑测试,确认全 fail (模块不存在)。

- [ ] **Step 3:** Commit

### Task 6.2: 实现 enqueue_expert_transfer Celery 任务

**Files:**
- Create: `backend/app/tasks/__init__.py`(若不存在)
- Create: `backend/app/tasks/expert_transfer.py`

- [ ] **Step 1:** 确认 tasks 包存在:

```bash
test -d backend/app/tasks || mkdir -p backend/app/tasks && touch backend/app/tasks/__init__.py
```

- [ ] **Step 2:** 创建 `backend/app/tasks/expert_transfer.py`:

```python
"""
Celery task: 任务完成时把钱 Transfer 到团队 Stripe Connect 账户。
spec §3.2 + §3.4a (90-day window)
"""
from datetime import datetime, timedelta
from decimal import Decimal
import stripe
from celery import shared_task

from backend.app.database import SessionLocal  # discovery D11 确认 sync session
from backend.app import models
from backend.app.models_expert import Expert, ExpertStripeTransfer

TRANSFER_WINDOW_DAYS = 89  # 留 1 天 buffer 防 Stripe 90 天硬限


def _compute_application_fee(gross: Decimal) -> Decimal:
    """
    沿用现有平台抽成计算。具体函数名见 discovery D3。
    Phase 0 grep 完后,这里 import 真函数,删掉这个 fallback。
    """
    # 临时占位:5% 平台抽成。Phase 0 D3 grep 后替换。
    return (gross * Decimal('0.05')).quantize(Decimal('0.01'))


def _notify_team_owner_of_transfer_failure(expert_id: str, task_id: int, error):
    """通知 owner Transfer 失败。具体实现见 Task 6.5。"""
    pass  # Task 6.5 实现


def _notify_team_owner_of_reversal(transfer_row):
    """通知 owner Transfer 被反向。Task 6.5 实现。"""
    pass


@shared_task(
    bind=True,
    name='expert_transfer.enqueue',
    max_retries=10,
    default_retry_delay=300,
    retry_backoff=True,
    retry_backoff_max=3600,
    retry_jitter=True,
)
def enqueue_expert_transfer(self, task_id: int):
    """
    任务完成后异步把钱 Transfer 到团队 Stripe 账户。
    幂等:UNIQUE(task_id) + UNIQUE(idempotency_key) + Stripe-side idempotency_key。
    """
    db = SessionLocal()
    try:
        task = db.get(models.Task, task_id)
        if not task or not task.taker_expert_id:
            return  # 不应该发生,防御性

        idempotency_key = f"task_{task_id}_transfer"

        # 并发保护:SKIP LOCKED,让其他 worker 自己放弃
        existing = db.query(ExpertStripeTransfer).filter_by(
            idempotency_key=idempotency_key
        ).with_for_update(skip_locked=True).first()

        if existing:
            if existing.status in ('succeeded', 'failed', 'reversed'):
                return  # 已 final state,不重试

        expert = db.get(Expert, task.taker_expert_id)
        if not expert:
            # 团队消失(理论上 ON DELETE RESTRICT 阻止,防御性)
            return

        if not expert.stripe_account_id:
            _mark_failed(db, existing, task_id, expert.id, 'missing_stripe_account', 'Team has no Stripe account')
            return

        # 币种检查 §1.4
        if (task.currency or 'GBP').upper() != 'GBP':
            _mark_failed(db, existing, task_id, expert.id, 'currency_unsupported', f'Currency {task.currency} not supported')
            return

        # 90 天时效检查 §3.4a
        if task.payment_completed_at:
            age = datetime.utcnow() - task.payment_completed_at.replace(tzinfo=None)
            if age > timedelta(days=TRANSFER_WINDOW_DAYS):
                _mark_failed(
                    db, existing, task_id, expert.id,
                    'stripe_transfer_window_expired',
                    f'Task age {age.days}d exceeds {TRANSFER_WINDOW_DAYS}d Transfer window'
                )
                return

        # 计算净额
        gross = task.agreed_reward or task.reward
        if gross is None or gross <= 0:
            # 零值任务,记 succeeded 行(amount=0)
            if not existing:
                existing = ExpertStripeTransfer(
                    task_id=task_id,
                    expert_id=expert.id,
                    amount=Decimal('0'),
                    currency='GBP',
                    status='succeeded',
                    idempotency_key=idempotency_key,
                    attempt_count=0,
                )
                db.add(existing)
            else:
                existing.amount = Decimal('0')
                existing.status = 'succeeded'
            db.commit()
            return

        fee = _compute_application_fee(gross)
        net = gross - fee

        if not existing:
            existing = ExpertStripeTransfer(
                task_id=task_id,
                expert_id=expert.id,
                amount=net,
                currency='GBP',
                stripe_charge_id=getattr(task, 'payment_charge_id', None),  # discovery D4
                status='pending',
                idempotency_key=idempotency_key,
                attempt_count=0,
            )
            db.add(existing)
            db.commit()

        existing.attempt_count += 1
        existing.last_attempt_at = datetime.utcnow()
        db.commit()

        try:
            transfer = stripe.Transfer.create(
                amount=int(net * 100),
                currency='gbp',
                destination=expert.stripe_account_id,
                transfer_group=f"task_{task_id}",
                metadata={
                    'task_id': str(task_id),
                    'expert_id': expert.id,
                    'platform_fee_pence': str(int(fee * 100)),
                },
                idempotency_key=idempotency_key,
            )
            existing.stripe_transfer_id = transfer.id
            existing.status = 'succeeded'
            db.commit()

        except stripe.error.StripeError as e:
            existing.error_code = getattr(e, 'code', None) or type(e).__name__
            existing.error_message = str(e)
            db.commit()

            if isinstance(e, (stripe.error.APIConnectionError, stripe.error.APIError)):
                # 网络/Stripe 内部错,重试
                raise self.retry(exc=e)
            else:
                # 业务错,标 failed
                existing.status = 'failed'
                db.commit()
                _notify_team_owner_of_transfer_failure(expert.id, task_id, e)
    finally:
        db.close()


def _mark_failed(db, existing, task_id, expert_id, error_code, error_message):
    if not existing:
        existing = ExpertStripeTransfer(
            task_id=task_id,
            expert_id=expert_id,
            amount=Decimal('0'),
            currency='GBP',
            status='failed',
            idempotency_key=f"task_{task_id}_transfer",
            error_code=error_code,
            error_message=error_message,
            attempt_count=1,
        )
        db.add(existing)
    else:
        existing.status = 'failed'
        existing.error_code = error_code
        existing.error_message = error_message
    db.commit()


# on_failure 回调:Celery 达到 max_retries 时把 pending → failed
@enqueue_expert_transfer.on_failure
def _on_failure(self, exc, task_id_arg, args, kwargs, einfo):
    db = SessionLocal()
    try:
        task_id = args[0] if args else kwargs.get('task_id')
        row = db.query(ExpertStripeTransfer).filter_by(
            idempotency_key=f"task_{task_id}_transfer"
        ).first()
        if row and row.status == 'pending':
            row.status = 'failed'
            row.error_code = 'max_retries_exhausted'
            db.commit()
            _notify_team_owner_of_transfer_failure(row.expert_id, row.task_id, exc)
    finally:
        db.close()
```

- [ ] **Step 3:** **替换 `_compute_application_fee`** —— 根据 Discovery D3 找到的真实函数,改 import 行,删掉 fallback。

- [ ] **Step 4:** 跑测试:

```bash
cd backend && pytest tests/test_expert_transfer_celery.py -v
```

预期: 5 个 PASS

- [ ] **Step 5:** Commit

```bash
git add backend/app/tasks/__init__.py backend/app/tasks/expert_transfer.py
git commit -m "feat(celery): expert transfer task with idempotency, retry, 90d window"
```

### Task 6.3: 在任务完成端点 enqueue Celery

**Files:**
- Modify: 任务完成端点(根据 Discovery D2 的位置,可能多处)

- [ ] **Step 1:** 在每个把 `task.status = 'completed'` 的地方,**`db.commit()` 之后**加:

```python
if task.taker_expert_id is not None:
    from backend.app.tasks.expert_transfer import enqueue_expert_transfer
    enqueue_expert_transfer.delay(task_id=task.id)
```

注意:**必须**在 commit 之后(避免在 DB 事务里调 Celery 触发的潜在问题)。

- [ ] **Step 2:** 写集成测试,验证 task 状态变 completed 后 Celery 任务被 enqueue:

```python
def test_team_task_completion_enqueues_transfer(
    client, db_session, test_team_task_in_progress, customer_user
):
    with patch('backend.app.tasks.expert_transfer.enqueue_expert_transfer.delay') as mock_delay:
        client.post(
            f'/api/tasks/{test_team_task_in_progress.id}/complete',
            headers={'Authorization': f'Bearer {customer_user.token}'},
        )
        mock_delay.assert_called_once_with(task_id=test_team_task_in_progress.id)


def test_individual_task_completion_does_not_enqueue(
    client, db_session, test_individual_task_in_progress, customer_user
):
    with patch('backend.app.tasks.expert_transfer.enqueue_expert_transfer.delay') as mock_delay:
        client.post(
            f'/api/tasks/{test_individual_task_in_progress.id}/complete',
            headers={'Authorization': f'Bearer {customer_user.token}'},
        )
        mock_delay.assert_not_called()
```

- [ ] **Step 3:** 跑测试 PASS。

- [ ] **Step 4:** Commit

### Task 6.4: 60 天预警监控 Celery beat 任务

**Files:**
- Modify: `backend/app/tasks/expert_transfer.py`(加新 task)
- Modify: Celery beat schedule (位置 plan 阶段 grep,可能 `celery_app.py`)

- [ ] **Step 1:** 在 `expert_transfer.py` 末尾追加:

```python
@shared_task(name='expert_transfer.warn_long_running')
def warn_long_running_team_tasks():
    """
    每天扫一次,通知 owner 接近 90 天 Transfer 时效的 in-flight 团队任务。
    spec §3.4a
    """
    db = SessionLocal()
    try:
        threshold = datetime.utcnow() - timedelta(days=60)
        from sqlalchemy import select
        result = db.execute(
            select(models.Task).where(
                models.Task.taker_expert_id.is_not(None),
                models.Task.status.in_(['in_progress', 'disputed']),
                models.Task.payment_completed_at < threshold,
            )
        )
        tasks = result.scalars().all()
        for t in tasks:
            _notify_team_owner_of_transfer_window_warning(t)
    finally:
        db.close()


def _notify_team_owner_of_transfer_window_warning(task):
    """Task 6.5 实现。"""
    pass
```

- [ ] **Step 2:** 在 Celery beat 配置里(grep `beat_schedule` 或 `celerybeat`)加:

```python
'expert-transfer-warn-daily': {
    'task': 'expert_transfer.warn_long_running',
    'schedule': crontab(hour=9, minute=0),  # 每天 9 AM
},
```

- [ ] **Step 3:** Commit

### Task 6.5: 实现 _notify_team_owner_of_* 通知函数

**Files:**
- Modify: `backend/app/tasks/expert_transfer.py`

- [ ] **Step 1:** 找到现有通知系统(grep `Notification\|create_notification\|send_notification`),复用:

```python
from backend.app.notification_service import create_notification  # 实际名 plan 阶段 grep

def _notify_team_owner_of_transfer_failure(expert_id, task_id, error):
    """给团队 owner 发应用内通知 + 邮件."""
    db = SessionLocal()
    try:
        from backend.app.models_expert import ExpertMember
        owner = db.query(ExpertMember).filter_by(
            expert_id=expert_id, role='owner', status='active'
        ).first()
        if owner:
            create_notification(
                db,
                user_id=owner.user_id,
                type='expert_transfer_failed',
                title='打款失败',
                body=f"任务 #{task_id} 的款项 Transfer 失败: {str(error)[:200]}",
                related_id=task_id,
            )
            db.commit()
    finally:
        db.close()


def _notify_team_owner_of_reversal(transfer_row):
    """同上,reversal 通知。"""
    db = SessionLocal()
    try:
        from backend.app.models_expert import ExpertMember
        owner = db.query(ExpertMember).filter_by(
            expert_id=transfer_row.expert_id, role='owner', status='active'
        ).first()
        if owner:
            create_notification(
                db,
                user_id=owner.user_id,
                type='expert_transfer_reversed',
                title='款项已反向',
                body=f"任务 #{transfer_row.task_id} 的 £{transfer_row.amount} 已被反向 (原因: {transfer_row.reversed_reason})",
                related_id=transfer_row.task_id,
            )
            db.commit()
    finally:
        db.close()


def _notify_team_owner_of_transfer_window_warning(task):
    db = SessionLocal()
    try:
        from backend.app.models_expert import ExpertMember
        owner = db.query(ExpertMember).filter_by(
            expert_id=task.taker_expert_id, role='owner', status='active'
        ).first()
        if owner:
            create_notification(
                db,
                user_id=owner.user_id,
                type='expert_transfer_window_warning',
                title='款项接近时效',
                body=f"任务 #{task.id} 已超过 60 天未完成,请尽快完成,否则款项无法 Transfer",
                related_id=task.id,
            )
            db.commit()
    finally:
        db.close()
```

- [ ] **Step 2:** 跑全部 transfer 相关测试,确保没 break。

- [ ] **Step 3:** Commit

```bash
git add backend/app/tasks/expert_transfer.py
git commit -m "feat(notify): implement expert transfer notification functions"
```

---

# Phase 7: Refund / Dispute / Reversal

### Task 7.1: 写 dispute webhook handler 测试

**Files:**
- Modify: `backend/tests/test_stripe_webhook_handlers.py`

- [ ] **Step 1:** 追加测试:

```python
def test_dispute_created_reverses_transfer(db_session, client, test_succeeded_transfer):
    """charge.dispute.created → 触发 Transfer reversal."""
    payload = json.dumps(_build_event('charge.dispute.created', {
        'charge': test_succeeded_transfer.stripe_charge_id,
    }))

    with patch('stripe.Webhook.construct_event') as mock_verify, \
         patch('stripe.Transfer.create_reversal') as mock_reverse:
        mock_verify.return_value = json.loads(payload)
        mock_reverse.return_value = MagicMock(id='trr_test01')
        client.post('/api/stripe/webhook', data=payload, headers={'Stripe-Signature': 'fake'})

    db_session.refresh(test_succeeded_transfer)
    assert test_succeeded_transfer.status == 'reversed'
    assert test_succeeded_transfer.stripe_reversal_id == 'trr_test01'
    assert test_succeeded_transfer.reversed_reason == 'dispute'
```

- [ ] **Step 2:** 跑测试 fail。

- [ ] **Step 3:** Commit

### Task 7.2: 实现 charge.dispute.created webhook 分支

**Files:**
- Modify: `backend/app/routers.py`

- [ ] **Step 1:** 在 webhook handler 加分支:

```python
elif event.type == 'charge.dispute.created':
    from backend.app.models_expert import ExpertStripeTransfer
    from datetime import datetime
    from sqlalchemy import select

    charge_id = event.data.object.charge if hasattr(event.data.object, 'charge') else event.data.object.get('charge')
    result = await db.execute(
        select(ExpertStripeTransfer).where(
            ExpertStripeTransfer.stripe_charge_id == charge_id
        )
    )
    row = result.scalar_one_or_none()
    if row and row.status == 'succeeded':
        try:
            reversal = stripe.Transfer.create_reversal(
                row.stripe_transfer_id,
                amount=int(row.amount * 100),
                metadata={'task_id': str(row.task_id), 'reason': 'dispute'},
            )
            row.stripe_reversal_id = reversal.id
            row.status = 'reversed'
            row.reversed_at = datetime.utcnow()
            row.reversed_reason = 'dispute'
            await db.commit()

            from backend.app.tasks.expert_transfer import _notify_team_owner_of_reversal
            _notify_team_owner_of_reversal(row)
        except stripe.error.StripeError as e:
            # 反向失败 (通常是团队余额不足),保持 status='succeeded' + 通过现有 admin 通知系统报警
            import logging
            logging.error(f"Failed to reverse transfer for task {row.task_id}: {e}")
            from backend.app.tasks.expert_transfer import _notify_team_owner_of_reversal
            # 反向失败时先标记 reversal 尝试过,error_message 记录失败原因供管理员查
            row.reversed_reason = f'dispute_reversal_failed: {str(e)[:200]}'
            await db.commit()
            # 触发管理员告警(沿用现有失败 transfer 告警通道,见 Task 6.5 的 notification)
            from backend.app.notification_service import create_admin_alert
            create_admin_alert(
                title='Transfer 反向失败',
                body=f'Task #{row.task_id} dispute reversal failed: {e}',
                severity='high',
            )

    return {"received": True}
```

- [ ] **Step 2:** 跑测试 PASS。

- [ ] **Step 3:** **手动**在 Stripe Dashboard 订阅 `charge.dispute.created` 事件。

- [ ] **Step 4:** Commit

### Task 7.3: 改 refund 端点扩展(管理员主动 refund)

**Files:**
- Modify: refund 端点(根据 Discovery D10 的位置)

- [ ] **Step 1:** 在 refund 端点逻辑里,**先 refund 客户之前**,检查是否有团队 transfer:

```python
# 在 refund 之前
if task.taker_expert_id is not None:
    from backend.app.models_expert import ExpertStripeTransfer
    from sqlalchemy import select
    from datetime import datetime

    result = await db.execute(
        select(ExpertStripeTransfer).where(
            ExpertStripeTransfer.task_id == task.id,
            ExpertStripeTransfer.status == 'succeeded',
        )
    )
    row = result.scalar_one_or_none()
    if row:
        # 先反向 transfer
        reversal = stripe.Transfer.create_reversal(
            row.stripe_transfer_id,
            amount=int(row.amount * 100),
            metadata={'task_id': str(task.id), 'reason': 'refund'},
        )
        row.stripe_reversal_id = reversal.id
        row.status = 'reversed'
        row.reversed_at = datetime.utcnow()
        row.reversed_reason = 'refund'
        await db.commit()

# 然后再正常 refund 客户(现有代码)
```

- [ ] **Step 2:** 写测试。

- [ ] **Step 3:** 跑测试 PASS。

- [ ] **Step 4:** Commit

---

# Phase 8: Dashboard Query Endpoints + Serializer

### Task 8.1: 写 build_taker_display 测试

**Files:**
- Create: `backend/tests/test_taker_display_serializer.py`

- [ ] **Step 1:**

```python
"""测试 build_taker_display. spec §4.6"""
import pytest
from unittest.mock import AsyncMock, MagicMock


@pytest.mark.asyncio
async def test_taker_display_team_task(mock_db, fake_expert):
    from backend.app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = 'u_owner01'
    task.taker_expert_id = 'e_test01'
    fake_expert.name = '星光摄影团队'
    fake_expert.avatar = 'https://.../logo.png'
    mock_db.get.return_value = fake_expert

    result = await build_taker_display(task, mock_db)
    assert result['type'] == 'expert'
    assert result['entity_id'] == 'e_test01'
    assert result['name'] == '星光摄影团队'


@pytest.mark.asyncio
async def test_taker_display_individual_task(mock_db, fake_user):
    from backend.app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = 'u_indiv01'
    task.taker_expert_id = None
    fake_user.name = '李四'
    fake_user.avatar = 'https://.../u.png'
    mock_db.get.return_value = fake_user

    result = await build_taker_display(task, mock_db)
    assert result['type'] == 'user'
    assert result['entity_id'] == 'u_indiv01'
    assert result['name'] == '李四'


@pytest.mark.asyncio
async def test_taker_display_unclaimed_task(mock_db):
    from backend.app.serializers.task_taker_display import build_taker_display
    task = MagicMock()
    task.taker_id = None
    task.taker_expert_id = None

    result = await build_taker_display(task, mock_db)
    assert result is None
```

- [ ] **Step 2:** Commit fail 状态。

### Task 8.2: 实现 build_taker_display

**Files:**
- Create: `backend/app/serializers/__init__.py`(若不存在)
- Create: `backend/app/serializers/task_taker_display.py`

- [ ] **Step 1:**

```bash
test -d backend/app/serializers || mkdir -p backend/app/serializers && touch backend/app/serializers/__init__.py
```

- [ ] **Step 2:** 创建 `task_taker_display.py`:

```python
"""
统一的 taker 显示信息序列化。spec §4.6 (U2 方案)

客户端读 task.taker_display 决定显示团队 logo+名字还是个人头像+名字,
不需要关心底层是 taker_id 还是 taker_expert_id。
"""
from typing import Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app import models
from backend.app.models_expert import Expert


async def build_taker_display(
    task: "models.Task",
    db: AsyncSession,
) -> Optional[Dict[str, Any]]:
    """
    根据 task 的 taker_id / taker_expert_id 返回展示信息。

    Returns:
        - 团队任务: {type:'expert', entity_id, name, avatar}
        - 个人任务: {type:'user',   entity_id, name, avatar}
        - 未认领:   None
    """
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

- [ ] **Step 3:** 跑测试 PASS。

- [ ] **Step 4:** Commit

### Task 8.3: 在 Task 响应序列化里调 build_taker_display

**Files:**
- Modify: 各处返回 Task 信息的端点(grep `taker_id` 在 router 文件里)

- [ ] **Step 1:** 找到所有 Task 详情/列表 API,在 response dict 构建处加:

```python
from backend.app.serializers.task_taker_display import build_taker_display
task_dict['taker_display'] = await build_taker_display(task, db)
```

- [ ] **Step 2:** 写一个集成测试覆盖最关键的端点。

- [ ] **Step 3:** Commit

### Task 8.4: 创建 expert_earnings_routes.py — 团队任务列表

**Files:**
- Create: `backend/app/expert_earnings_routes.py`

- [ ] **Step 1:** 创建文件:

```python
"""
达人管理页面的查询端点。spec §5
所有端点鉴权:团队所有 active 成员可查。
"""
from typing import Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from backend.app.database import get_db
from backend.app import models
from backend.app.models_expert import Expert, ExpertStripeTransfer
from backend.app.expert_routes import _get_member_or_403
from backend.app.secure_auth import get_current_user_secure_async_csrf

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
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    """团队任务列表 (LEFT JOIN expert_stripe_transfers)。"""
    await _get_member_or_403(db, expert_id, current_user.id, roles=['owner', 'admin', 'member'])

    # 构建过滤
    conditions = [models.Task.taker_expert_id == expert_id]
    if status:
        statuses = [s.strip() for s in status.split(',')]
        conditions.append(models.Task.status.in_(statuses))
    if task_source:
        conditions.append(models.Task.task_source == task_source)
    if start_date:
        conditions.append(models.Task.created_at >= start_date)
    if end_date:
        conditions.append(models.Task.created_at <= end_date)

    # 总数
    count_q = select(func.count()).select_from(models.Task).where(and_(*conditions))
    total = (await db.execute(count_q)).scalar_one()

    # 主查询
    q = (
        select(models.Task, ExpertStripeTransfer)
        .join(ExpertStripeTransfer, ExpertStripeTransfer.task_id == models.Task.id, isouter=True)
        .where(and_(*conditions))
        .order_by(models.Task.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    rows = (await db.execute(q)).all()

    items = []
    for task, xfer in rows:
        poster = await db.get(models.User, task.poster_id)
        items.append({
            "id": task.id,
            "title": task.title,
            "status": task.status,
            "task_source": task.task_source,
            "poster": {
                "id": poster.id if poster else None,
                "name": poster.name if poster else None,
                "avatar": getattr(poster, 'avatar', None) if poster else None,
            } if poster else None,
            "gross_amount": str(task.agreed_reward or task.reward or 0),
            "currency": task.currency or 'GBP',
            "transfer": {
                "status": xfer.status,
                "net_amount": str(xfer.amount),
                "stripe_transfer_id": xfer.stripe_transfer_id,
                "error_message": xfer.error_message,
            } if xfer else None,
            "created_at": task.created_at.isoformat() if task.created_at else None,
            "completed_at": task.completed_at.isoformat() if getattr(task, 'completed_at', None) else None,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}
```

- [ ] **Step 2:** 注册 router in `main.py`。

- [ ] **Step 3:** 写测试 (基础 happy path)。

- [ ] **Step 4:** Commit

### Task 8.5: earnings/summary 端点

**Files:**
- Modify: `backend/app/expert_earnings_routes.py`

- [ ] **Step 1:** 追加:

```python
@router.get("/{expert_id}/earnings/summary")
async def earnings_summary(
    expert_id: str,
    period: str = Query('all_time', regex='^(all_time|this_month|last_30d|last_90d)$'),
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    await _get_member_or_403(db, expert_id, current_user.id, roles=['owner', 'admin', 'member'])

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

    conditions = [ExpertStripeTransfer.expert_id == expert_id]
    if start:
        conditions.append(ExpertStripeTransfer.created_at >= start)

    # 主查询: JOIN tasks 表算 gross,LEFT JOIN expert_stripe_transfers 算 net/reversed
    q = (
        select(
            func.coalesce(func.sum(models.Task.agreed_reward), 0).label('total_gross'),
            func.coalesce(func.sum(
                ExpertStripeTransfer.amount
            ).filter(ExpertStripeTransfer.status == 'succeeded'), 0).label('total_net'),
            func.count(ExpertStripeTransfer.id).filter(ExpertStripeTransfer.status == 'succeeded').label('succeeded_count'),
            func.count(ExpertStripeTransfer.id).filter(ExpertStripeTransfer.status == 'pending').label('pending_count'),
            func.count(ExpertStripeTransfer.id).filter(ExpertStripeTransfer.status == 'failed').label('failed_count'),
            func.coalesce(func.sum(
                ExpertStripeTransfer.amount
            ).filter(ExpertStripeTransfer.status == 'reversed'), 0).label('total_reversed'),
        )
        .select_from(models.Task)
        .join(ExpertStripeTransfer, ExpertStripeTransfer.task_id == models.Task.id, isouter=True)
        .where(models.Task.taker_expert_id == expert_id)
        .where(and_(*[c for c in conditions if 'expert_id' not in str(c)]))  # exclude expert_id condition (now on tasks)
    )

    row = (await db.execute(q)).one()
    total_gross = row.total_gross or 0
    total_net = row.total_net or 0
    total_fee = total_gross - total_net  # 平台抽成 = gross - net (不算 reversed)

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

- [ ] **Step 2:** 测试基本响应结构。

- [ ] **Step 3:** Commit

### Task 8.6: earnings/transfers 历史端点

**Files:**
- Modify: `backend/app/expert_earnings_routes.py`

- [ ] **Step 1:** 追加:

```python
@router.get("/{expert_id}/earnings/transfers")
async def transfer_history(
    expert_id: str,
    status: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user_secure_async_csrf),
):
    await _get_member_or_403(db, expert_id, current_user.id, roles=['owner', 'admin', 'member'])

    conditions = [ExpertStripeTransfer.expert_id == expert_id]
    if status:
        conditions.append(ExpertStripeTransfer.status.in_(status.split(',')))
    if start_date:
        conditions.append(ExpertStripeTransfer.created_at >= start_date)
    if end_date:
        conditions.append(ExpertStripeTransfer.created_at <= end_date)

    total_q = select(func.count()).select_from(ExpertStripeTransfer).where(and_(*conditions))
    total = (await db.execute(total_q)).scalar_one()

    q = (
        select(ExpertStripeTransfer)
        .where(and_(*conditions))
        .order_by(ExpertStripeTransfer.created_at.desc())
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
            "stripe_transfer_id": r.stripe_transfer_id,
            "stripe_reversal_id": r.stripe_reversal_id,
            "created_at": r.created_at.isoformat(),
            "attempt_count": r.attempt_count,
            "error_message": r.error_message,
            "reversed_at": r.reversed_at.isoformat() if r.reversed_at else None,
            "reversed_reason": r.reversed_reason,
        })

    return {"items": items, "total": total, "page": page, "page_size": page_size}
```

- [ ] **Step 2:** 测试 + Commit

---

# Phase 9: 历史数据回填

### Task 9.1: 跑预审 SQL,记录冲突任务

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

- [ ] **Step 2:** 把结果保存到 discovery 文档新增段:

```markdown
## §9.1 回填预审结果
日期: <YYYY-MM-DD>
冲突任务数: <N>
冲突详情:
- task_id=X taker=Y candidates=[a, b]
- ...
处理决策: <人工 case-by-case / 跳过这些任务>
```

- [ ] **Step 3:** Commit

### Task 9.2: Migration 179 — 回填脚本

**Files:**
- Create: `backend/migrations/179_backfill_tasks_taker_expert.sql`

- [ ] **Step 1:** 创建文件 (使用 spec §6.2 的最终版本):

```sql
-- ===========================================
-- 迁移 179: 在飞任务回填 taker_expert_id
-- spec §6.2
-- 注意:这是 ONE-TIME 数据迁移,不是 schema migration。
-- 跑之前必须先做 §9.1 预审!
-- ===========================================

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

- [ ] **Step 2:** 在 staging 跑迁移,记录 NOTICE 输出。

- [ ] **Step 3:** Commit

### Task 9.3: ownership transfer 端点同步未完成任务 taker_id

**Files:**
- Modify: `backend/app/expert_routes.py`(根据 D7 的位置)

- [ ] **Step 1:** 在 ownership transfer 函数末尾,`db.commit()` 之前加:

```python
from sqlalchemy import update
await db.execute(
    update(models.Task)
    .where(
        models.Task.taker_expert_id == expert.id,
        models.Task.status.in_(['pending','pending_payment','in_progress','disputed'])
    )
    .values(taker_id=new_owner_user_id)
)
```

- [ ] **Step 2:** 写测试。

- [ ] **Step 3:** Commit

---

# Phase 10: E2E + Sanity Checks + 文档

### Task 10.1: E2E 冒烟测试 — 团队任务全流程

**Files:**
- Create: `backend/tests/test_e2e_team_task_money_flow.py`

- [ ] **Step 1:**

```python
"""端到端冒烟测试: 发布服务 → 下单 → 付款 → 完成 → Transfer 成功. spec §9.2 #1, #7, #8"""
import pytest
from unittest.mock import patch, MagicMock


def test_e2e_team_service_money_flow(
    client, db_session, test_expert_with_stripe, team_owner_user, customer_user
):
    # 1. 团队 owner 发布服务
    publish_resp = client.post(
        f"/api/experts/{test_expert_with_stripe.id}/services",
        json={'service_name': 'E2E Test', 'base_price': 100, 'currency': 'GBP', 'category': 'test'},
        headers={'Authorization': f'Bearer {team_owner_user.token}'},
    )
    assert publish_resp.status_code in (200, 201)
    service_id = publish_resp.json()['id']

    # 2. 客户咨询(创建 task)
    consult_resp = client.post(
        '/api/expert-services/consult',
        json={'service_id': service_id},
        headers={'Authorization': f'Bearer {customer_user.token}'},
    )
    assert consult_resp.status_code == 200
    task_id = consult_resp.json()['task_id']
    task = db_session.query(models.Task).get(task_id)
    assert task.taker_expert_id == test_expert_with_stripe.id

    # 3. 模拟付款完成 + 任务进入 in_progress (跳过 Stripe 实际付款)
    task.status = 'in_progress'
    task.payment_completed_at = datetime.utcnow()
    db_session.commit()

    # 4. 客户标记完成
    with patch('stripe.Transfer.create') as mock_transfer:
        mock_transfer.return_value = MagicMock(id='tr_e2e_test')
        complete_resp = client.post(
            f'/api/tasks/{task_id}/complete',
            headers={'Authorization': f'Bearer {customer_user.token}'},
        )
        assert complete_resp.status_code == 200

    # 5. (Celery 同步执行) 验证 transfer 行
    from backend.app.models_expert import ExpertStripeTransfer
    row = db_session.query(ExpertStripeTransfer).filter_by(task_id=task_id).one()
    assert row.status == 'succeeded'
    assert row.stripe_transfer_id == 'tr_e2e_test'
    mock_transfer.assert_called_once()
```

- [ ] **Step 2:** 跑测试 PASS。

- [ ] **Step 3:** Commit

### Task 10.2: 跑全部新测试 + sanity check

- [ ] **Step 1:**

```bash
cd backend && pytest tests/test_expert_task_resolver.py tests/test_expert_transfer_celery.py tests/test_expert_publish_endpoints.py tests/test_expert_stripe_routes.py tests/test_team_activity_publish.py tests/test_taker_display_serializer.py tests/test_e2e_team_task_money_flow.py tests/test_stripe_webhook_handlers.py -v
```

预期: ALL PASS

- [ ] **Step 2:** Sanity check spec §6.3:

```bash
psql $DATABASE_URL -c "
SELECT
  owner_type,
  COUNT(*) AS n,
  COUNT(*) FILTER (WHERE owner_id IS NULL) AS n_null_owner,
  COUNT(*) FILTER (WHERE owner_type='expert' AND NOT EXISTS (
    SELECT 1 FROM experts e WHERE e.id = owner_id
  )) AS n_orphan_expert,
  COUNT(*) FILTER (WHERE owner_type='user' AND NOT EXISTS (
    SELECT 1 FROM users u WHERE u.id = owner_id
  )) AS n_orphan_user
FROM task_expert_services
GROUP BY owner_type;
"
```

预期: 所有 `n_*_orphan*` 和 `n_null_owner` 为 0

- [ ] **Step 3:** 跑回归 - 确保现有测试不挂:

```bash
cd backend && pytest -x -q
```

预期: 全部 PASS

- [ ] **Step 4:** Commit anything outstanding

```bash
git status
git commit -am "test: full passing suite for expert team as task taker" || true
```

### Task 10.3: 更新 spec 状态 + 写收尾文档

**Files:**
- Modify: `docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md`(顶部状态)

- [ ] **Step 1:** 把 spec 顶部 `**状态:** Draft(等待实施 plan)` 改成 `**状态:** Implemented (<日期>)`

- [ ] **Step 2:** 在 spec §10 加一行:

```markdown
| `2026-04-07-expert-team-as-task-taker.md` | **本 spec 的实施 plan** |
```

- [ ] **Step 3:** Commit

```bash
git add docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md
git commit -m "docs(spec): mark expert-team-as-taker spec as implemented"
```

### Task 10.4: 准备 release notes / runbook

**Files:**
- Create: `docs/runbooks/expert-team-stripe-transfers.md`

- [ ] **Step 1:** 写一份运维 runbook 说明:
  - 失败 transfer 的手工处理流程
  - 监控指标在哪看
  - Stripe Dashboard 上常见对账场景
  - 90 天时效任务的应急流程

- [ ] **Step 2:** Commit

### Task 10.5: 上线 checklist 跑一遍

参考 spec §6.6,逐项确认:

- [ ] §6.3 sanity check 全部零 ✓
- [ ] §9.1 预审已处理冲突 ✓
- [ ] 所有 migration 在 staging 跑通 ✓
- [ ] 所有新测试 PASS ✓
- [ ] Webhook events 已在 Stripe Dashboard 订阅 ✓
- [ ] E2E 冒烟测试通过 ✓
- [ ] 负测试(未 onboard 团队发布) → 409 ✓
- [ ] Celery worker 在 staging 接到任务 ✓

全部勾完后,plan 即可视为完成。

---

# 完成

整个 plan 共 **10 个 phase, 约 50 个 task**,核心改动覆盖 spec §1-§6 的全部内容。Phase 0 必须先跑(否则后续 phase 拿不到 grep 结果),Phase 1-3 强烈建议按顺序,Phase 4-10 之间有少量并行空间但建议线性执行避免 merge 冲突。
