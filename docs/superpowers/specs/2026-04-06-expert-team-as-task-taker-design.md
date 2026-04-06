# 达人团队作为任务接单方 —— 设计文档

**日期:** 2026-04-06
**状态:** Draft(等待实施 plan)
**作者:** Brainstorm session with Claude
**取代:** `docs/superpowers/plans/2026-04-04-expert-team-phase5-chat-multiuser.md`(该 plan 在本 spec 确定方向后废弃,多人聊天问题将在团队接单模型落地后重新评估)

---

## §0 Context / 前提事实

本 spec 基于以下**已经成立**的事实(均已通过 2026-04-06 代码审查确认):

1. **达人已统一为团队语义,无"个人达人"概念。** `experts` 表每行即一个团队,`expert_members` 记录成员。1 人团队是合法形态(`experts.member_count` 默认 1,无下限约束)。申请通过 `admin_expert_routes.py:102-136` 无条件同时创建 `experts` + `expert_members(role='owner')` 两行。
2. **老 `task_experts` 表已迁移完毕,只读不写。** 迁移见 `backend/migrations/159_migrate_expert_data.sql:38-65`。新系统所有代码路径都操作 `experts` / `expert_members`。
3. **`task_expert_services.owner_type ∈ {'expert','user'}` 已回填。** Migration 160-161 完成,`'expert'` 表示达人团队服务,`'user'` 表示个人用户直接发布的服务(与达人体系无关)。本 spec **只处理 `owner_type='expert'` 的路径**;个人服务路径的资金流改造作为顺带正确化(见 §4.4)。
4. **`experts` 表已有 Stripe Connect 字段** `stripe_account_id` / `stripe_connect_country` / `stripe_onboarding_complete`(`models_expert.py:32-74`),但当前**全链路无人使用**。
5. **`activities` 表目前是"个人所有"模型** —— `expert_id FK → users.id`,无多态列。本 spec 将为其引入多态所有权。
6. **客户对达人团队的交互是"被动履约"**:团队只发布服务 / 活动,客户浏览下单,系统自动创建 Task,团队无"接单"动作。
7. **平台钱包 (`wallet_accounts`) 只支持 user**,没有 expert 支持(`wallet_models.py:8-24`)。本 spec **不引入** expert 钱包表。

---

## §1 数据模型变更

三处 schema 变动,通过编号 SQL 迁移文件(编号在 plan 阶段确定,此处记为 `N`、`N+1`、`N+2`)。

### 1.1 `tasks` 表 —— 新增 `taker_expert_id` 列

**迁移文件:** `N_add_tasks_taker_expert_id.sql`

```sql
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

**语义铁律(强制写进代码注释):**
- `taker_expert_id IS NOT NULL` → 团队任务,任务完成时走 Stripe Transfer 到团队 Connect 账户
- `taker_expert_id IS NULL` → 个人任务,按现有流程走
- `taker_id` **始终非 NULL**,团队任务时填 owner 的 user_id(Y 方案)
- `ON DELETE RESTRICT`:团队不允许被硬删除,必须通过 `experts.status` 软删除

### 1.2 `activities` 表 —— 加多态所有权列

**迁移文件:** `N+1_add_activities_owner_polymorphic.sql`

```sql
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
  '[legacy] 原个人 owner 字段,保留以避免全代码库 grep 风险。团队活动时填 team owner 的 user_id 作为代表(Y 方案对齐)';

COMMIT;
```

**保留 `activities.expert_id` 不 DROP 的理由:** 大量既有代码用 `activities.expert_id = :user_id` 过滤,丢字段会导致 grep 风险。让它作为"团队代表"的自然人指针继续存在,语义与 `tasks.taker_id` 一致。

### 1.3 `expert_stripe_transfers` 审计表(新建)

**迁移文件:** `N+2_create_expert_stripe_transfers.sql`

```sql
BEGIN;

CREATE TABLE expert_stripe_transfers (
    id                   BIGSERIAL PRIMARY KEY,
    task_id              INTEGER NOT NULL REFERENCES tasks(id) ON DELETE RESTRICT,
    expert_id            VARCHAR(8) NOT NULL REFERENCES experts(id) ON DELETE RESTRICT,
    amount               DECIMAL(12,2) NOT NULL,   -- 净额(扣除 application_fee 后打给团队的金额)
    currency             VARCHAR(3) NOT NULL DEFAULT 'GBP',
    stripe_transfer_id   VARCHAR(255) NULL,        -- Stripe 返回的 tr_xxx
    stripe_reversal_id   VARCHAR(255) NULL,        -- 被 reverse 时的 trr_xxx
    stripe_charge_id     VARCHAR(255) NULL,        -- 对应客户付款的 Charge,用于 dispute 反查
    status               VARCHAR(20) NOT NULL,     -- pending / succeeded / failed / reversed
    idempotency_key      VARCHAR(64) NOT NULL,     -- 'task_{task_id}_transfer'
    error_message        TEXT NULL,
    error_code           VARCHAR(100) NULL,        -- Stripe error code(如果有)
    attempt_count        INTEGER NOT NULL DEFAULT 0,
    last_attempt_at      TIMESTAMPTZ NULL,
    reversed_at          TIMESTAMPTZ NULL,
    reversed_reason      TEXT NULL,                -- dispute / refund / manual
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

**关键不变量:**
- `UNIQUE(task_id)`:一个任务最多一条 transfer 记录。反向(dispute / refund)通过 **in-place update** 同一行的 `status='reversed'` + 填 `stripe_reversal_id` 实现,**不另开新行**。
- `UNIQUE(idempotency_key)`:第二次 INSERT 尝试会失败,配合 `SELECT ... FOR UPDATE SKIP LOCKED` 处理并发 worker。
- 这张表**不是钱包** —— 没有余额字段。团队真实可用余额的事实来源是 Stripe Dashboard。

---

## §2 发布端点 + Stripe 门槛(M2 + R2)

### 2.1 服务发布 —— 改已有端点

现有 `POST /api/experts/{expert_id}/services`(`expert_service_routes.py:106-133`)已经:
- 要求调用者是团队 owner/admin(`_get_member_or_403`)
- 写 `task_expert_services.owner_type='expert', owner_id=expert_id`

**本 spec 的改动:** 在端点开头加一道 Stripe 门槛检查:

```python
expert = await db.get(Expert, expert_id)
if not expert:
    raise HTTPException(404, "Expert team not found")
if not expert.stripe_onboarding_complete:
    raise HTTPException(status_code=409, detail={
        "error_code": "expert_stripe_not_ready",
        "message": "Team must complete Stripe onboarding before publishing services"
    })
```

### 2.2 活动发布 —— 新建团队专用端点

**新建:** `POST /api/experts/{expert_id}/activities`(新文件 `backend/app/expert_activity_routes.py`,或放在 `expert_routes.py`,plan 阶段定)。

- **鉴权:** `_get_member_or_403(expert_id, roles=['owner','admin'])`
- **Stripe 门槛检查:** 同 2.1
- **数据写入:**
  - `activities.owner_type = 'expert'`
  - `activities.owner_id = expert_id`
  - `activities.expert_id = owner.user_id`(Y 方案:legacy 字段填代表)
- **Body schema:** 复用现有 `multi_participant_routes.py:1754-1939` 的活动创建 body,具体字段列表在 plan 阶段 mirror。

**现有个人活动创建端点** (`multi_participant_routes.py:1754-1939`) **不动**,保持个人身份创建的老流程作为 grandfather 路径。

### 2.3 Stripe Onboarding 入口 + 状态查询

**新建文件 `backend/app/expert_stripe_routes.py`**,包含两个端点:

```
POST /api/experts/{expert_id}/stripe/onboarding
  鉴权: owner 或 admin
  行为: 若 experts.stripe_account_id 为空,先调 stripe.Account.create(type=<see §8>, ...);
        然后调 stripe.AccountLink.create(account=stripe_account_id, type='account_onboarding', ...)
  返回: { "url": "<stripe onboarding url>", "expires_at": 1234567890 }

GET /api/experts/{expert_id}/stripe/status
  鉴权: owner/admin/member(所有活跃成员可查)
  返回: {
    "onboarding_complete": true/false,
    "charges_enabled": true/false,
    "requirements": { ... Stripe requirements object ... }
  }
```

### 2.4 Stripe Webhook 同步 `account.updated`

在现有 webhook 处理器(`routers.py:8058-8080` 区域,具体位置 plan 阶段 grep 确认)里加 `account.updated` 分支:

```python
if event.type == 'account.updated':
    acct = event.data.object
    expert = await db.execute(
        select(Expert).where(Expert.stripe_account_id == acct.id)
    ).scalar_one_or_none()
    if not expert:
        return  # 不是团队账户,无视

    new_status = bool(acct.charges_enabled)
    if expert.stripe_onboarding_complete != new_status:
        expert.stripe_onboarding_complete = new_status
        if not new_status:
            # 断开时自动挂起所有 active 服务(复用现有 'inactive' 状态)
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
```

**关于活动在 Stripe 断开时的处理:** 活动的 `status` 字段是业务状态(`open/closed/cancelled/completed`),**不自动改**。新报名被拦在源头 —— 活动报名端点 (`multi_participant_routes.py:236-599`) 加一道检查:

```python
if activity.owner_type == 'expert':
    expert = await db.get(Expert, activity.owner_id)
    if expert and not expert.stripe_onboarding_complete:
        raise HTTPException(409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team is temporarily unable to accept new sign-ups"
        })
```

已报名的活动继续履约,任务完成时照样走 Transfer(Stripe 账户"在但 `charges_enabled=False`"不等于 destination 不可达,实际结果取决于 Stripe,失败的话走 §3.4 的人工介入流程)。

---

## §3 支付结算 + Transfer 执行流程

### 3.1 触发点

任务完成(`task.status` 转为 `'completed'`)时,**DB commit 之后**,对有 `taker_expert_id` 的任务 enqueue Celery 任务:

```python
await db.commit()

if task.taker_expert_id is not None:
    from app.tasks.expert_transfer import enqueue_expert_transfer
    enqueue_expert_transfer.delay(task_id=task.id)
```

**为什么 Celery 而非同步:** (1) 不阻塞客户端 UX,(2) 网络错误可以重试,(3) 失败/监控/审计都能独立运作。

**待定:** "任务完成"在代码里的准确位置(可能多处,plan 阶段 grep 定位)。

### 3.2 Celery 任务实现

**新建:** `backend/app/tasks/expert_transfer.py`

```python
from celery import shared_task
from app.database import SessionLocal
from app import models
from app.models_expert import Expert, ExpertMember
from app.models.expert_stripe_transfer import ExpertStripeTransfer  # 新建 ORM 模型
import stripe

@shared_task(
    bind=True,
    max_retries=10,
    default_retry_delay=300,
    retry_backoff=True,
    retry_backoff_max=3600,
    retry_jitter=True,
)
def enqueue_expert_transfer(self, task_id: int):
    db = SessionLocal()
    try:
        task = db.get(models.Task, task_id)
        if not task or not task.taker_expert_id:
            return

        idempotency_key = f"task_{task_id}_transfer"

        # 并发保护:SKIP LOCKED,让其他 worker 自己放弃
        existing = db.query(ExpertStripeTransfer).filter_by(
            idempotency_key=idempotency_key
        ).with_for_update(skip_locked=True).first()

        if existing:
            if existing.status in ('succeeded', 'failed', 'reversed'):
                return

        expert = db.get(Expert, task.taker_expert_id)
        if not expert.stripe_account_id:
            _mark_failed(db, existing, 'missing_stripe_account', 'Team has no Stripe account')
            return

        # 计算净额
        gross = task.agreed_reward or task.reward
        if gross is None or gross <= 0:
            # 零值任务,记一条成功用于审计完整性
            if not existing:
                existing = ExpertStripeTransfer(
                    task_id=task_id, expert_id=expert.id, amount=0,
                    currency=task.currency or 'GBP', status='succeeded',
                    idempotency_key=idempotency_key, attempt_count=0,
                )
                db.add(existing)
            else:
                existing.amount = 0
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
                currency=(task.currency or 'GBP').upper(),
                stripe_charge_id=task.payment_charge_id,  # 字段名 plan 阶段确认
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
                currency=existing.currency.lower(),
                destination=expert.stripe_account_id,
                transfer_group=f"task_{task_id}",
                metadata={
                    'task_id': str(task_id),
                    'expert_id': expert.id,
                    'platform_fee_pence': str(int(fee * 100)),
                },
                idempotency_key=idempotency_key,  # Stripe 端幂等
            )
            existing.stripe_transfer_id = transfer.id
            existing.status = 'succeeded'
            db.commit()

        except stripe.error.StripeError as e:
            existing.error_code = getattr(e, 'code', None) or type(e).__name__
            existing.error_message = str(e)
            db.commit()

            if isinstance(e, (stripe.error.APIConnectionError, stripe.error.APIError)):
                raise self.retry(exc=e)
            else:
                existing.status = 'failed'
                db.commit()
                _notify_team_owner_of_transfer_failure(expert.id, task_id, e)
    finally:
        db.close()


def on_failure(self, exc, task_id_arg, args, kwargs, einfo):
    """Celery 达到 max_retries 时的 fallback。"""
    db = SessionLocal()
    try:
        row = db.query(ExpertStripeTransfer).filter_by(
            idempotency_key=f"task_{args[0]}_transfer"
        ).first()
        if row and row.status == 'pending':
            row.status = 'failed'
            row.error_code = 'max_retries_exhausted'
            db.commit()
            _notify_team_owner_of_transfer_failure(row.expert_id, row.task_id, exc)
    finally:
        db.close()
```

### 3.3 平台抽成

**沿用** `task_expert_routes.py:3874-3899` 区域现有的 `_compute_application_fee()` 函数(实际名字 plan 阶段 grep 确认)。团队任务和个人任务**同一套** fee 规则(P1 决策)。fee 在本地计算从 gross 扣掉,Stripe Transfer 只传净额。

### 3.4 失败处理

`status='failed'` 的 transfer:
1. 应用内通知 + 邮件给团队 owner
2. 管理员后台新增 `GET /api/admin/expert-transfers?status=failed` 监控端点
3. 管理员手工重试端点 `POST /api/admin/expert-transfers/{id}/retry`(把 status 改回 pending 再 enqueue)

### 3.5 退款 / 争议处理

**场景 A:任务完成前退款** —— 钱还在平台账户,团队未收到。现有退款流程不动,`expert_stripe_transfers` 行尚未创建,零影响。

**场景 B:任务完成后客户 dispute** —— Webhook `charge.dispute.created` 分支里:

```python
if event.type == 'charge.dispute.created':
    charge_id = event.data.object.charge
    row = db.query(ExpertStripeTransfer).filter_by(
        stripe_charge_id=charge_id
    ).first()

    if row and row.status == 'succeeded':
        reversal = stripe.Transfer.create_reversal(
            row.stripe_transfer_id,
            amount=int(row.amount * 100),
            metadata={'task_id': str(row.task_id), 'reason': 'dispute'},
        )
        row.stripe_reversal_id = reversal.id
        row.status = 'reversed'
        row.reversed_at = datetime.utcnow()
        row.reversed_reason = 'dispute'
        db.commit()
        _notify_team_owner_of_reversal(row)
```

**反向失败(团队 Stripe 余额不足):** Stripe 返回错误 → 保持 `status='succeeded'` + 管理员报警 + 人工介入。

**场景 C:管理员主动退款给已完成任务的客户** —— 现有 refund 端点里,若任务 `taker_expert_id` 非空且已存在 `status='succeeded'` 的 transfer,先调 `Transfer.create_reversal`,再 refund 给客户。

### 3.6 `TaskParticipantReward` 对团队任务

**团队任务(`taker_expert_id IS NOT NULL`)不创建 `TaskParticipantReward` 行。** 审计事实来源是 `expert_stripe_transfers`。这避免两套审计表争夺事实来源。

任务完成时的分叉:

```python
if task.taker_expert_id is not None:
    enqueue_expert_transfer.delay(task_id=task.id)
else:
    # 个人任务:现有 TaskParticipantReward + wallet_accounts 流程(不动)
    ...
```

---

## §4 老系统迁移(S2)

### 4.1 改动点清单

| # | 文件:行(现状) | 改动 |
|---|----------------|------|
| 1 | `task_expert_routes.py:3090-3130`(咨询任务创建) | 通过 `resolve_task_taker_from_service()` helper 解析,填 `taker_id` + `taker_expert_id` |
| 2 | `task_expert_routes.py:3820-3860`(正式服务任务创建) | 同上 |
| 3 | `task_expert_routes.py:3870-3899`(Payment Intent 创建) | 取消 `transfer_data.destination`,统一走 manual transfer(见 4.4) |
| 4 | 任务完成端点(位置 plan 阶段 grep) | 加 `taker_expert_id` 分叉,enqueue Celery Transfer |

### 4.2 & 4.3 任务创建分叉 —— 新 helper

**新建 `backend/app/services/expert_task_resolver.py`:**

```python
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException
from app import models
from app.models_expert import Expert, ExpertMember

async def resolve_task_taker_from_service(
    db: AsyncSession,
    service: models.TaskExpertService,
) -> tuple[str, Optional[str]]:
    """
    返回 (taker_id, taker_expert_id):
      - owner_type='expert':(team owner user_id, expert_id) —— 团队接单
      - owner_type='user':  (user_id, None) —— 个人接单(legacy personal service)
    团队路径会校验 Stripe onboarding 状态,未完成抛 409。
    """
    if service.owner_type == 'expert':
        expert = await db.get(Expert, service.owner_id)
        if not expert:
            raise HTTPException(404, "Expert team not found")
        if not expert.stripe_onboarding_complete:
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_stripe_not_ready",
                "message": "This service is temporarily unavailable"
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
            raise HTTPException(500, detail={
                "error_code": "expert_owner_missing",
                "message": "Team has no active owner"
            })

        return (owner.user_id, expert.id)

    elif service.owner_type == 'user':
        return (service.owner_id, None)

    else:
        raise HTTPException(500, f"Unknown service owner_type: {service.owner_type}")
```

**在 `task_expert_routes.py` 两处调用点统一使用此 helper,`taker_id` 和 `taker_expert_id` 从 tuple 解构。**

### 4.4 Payment Intent 统一 Manual Transfer

**现状(待 plan 阶段 grep 确认):** `task_expert_routes.py:3870-3899` 可能在 Payment Intent 里设了 `transfer_data.destination`(destination charge 模式),让钱直接进 taker 的 Stripe Connect 账户。

**改后:** Payment Intent 不设 `transfer_data`,钱先进平台账户,等任务完成时再 Transfer 出去:

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

**影响范围:** 如果当前个人服务走 destination charge,这个改动把它们**顺带对齐**到 manual transfer,让所有路径统一。plan 阶段的 **Task 1 必须 grep 确认** 当前资金流模式,影响后续任务的拆分粒度。如果已经是 manual transfer,这段基本无改动。

### 4.5 受影响下游代码

读 `taker_id` 的代码(通知、"我的任务"列表、权限判断)继续 work,因为 `taker_id` 始终是一个合法的 user_id(团队 owner)。团队其他成员通过**达人管理页面**(§5)看团队任务,不依赖个人"我的任务"列表。

### 4.6 客户侧"接单方" UI 显示(U2 方案)

**问题:** 客户端读 `taker_id → users 表`,看到的是 owner 个人头像而非团队信息。

**解决:** Task 详情/列表响应统一加 `taker_display` 字段:

```json
{
  "taker_id": "u_abc123",
  "taker_expert_id": "e_xyz789",
  "taker_display": {
    "type": "expert",          // or "user"
    "entity_id": "e_xyz789",
    "name": "星光摄影团队",
    "avatar": "https://.../team_logo.png"
  }
}
```

**实现:** 新建 `backend/app/serializers/task_taker_display.py`(如果没有 serializers 目录就直接在 routers 层建一个 helper),集中一个 `build_taker_display(task, db) -> dict` 函数。所有返回 Task 的端点调用它。

**客户端:** 只读 `taker_display`,不关心底层字段。Flutter 侧改 `Task` model,plan 阶段评估影响面。

---

## §5 达人管理页面查询端点

所有端点鉴权:**团队所有 active 成员可查**(`_get_member_or_403(expert_id, roles=['owner','admin','member'])`)。纯只读展示。

### 5.1 团队任务列表

```
GET /api/experts/{expert_id}/tasks
```

**Query:** `status`(多选,逗号分隔)、`task_source`(consultation/expert_service/activity)、`start_date`、`end_date`、`page`、`page_size`(默认 1/20)

**Response:**
```json
{
  "items": [
    {
      "id": 12345,
      "title": "咨询: 品牌设计",
      "status": "completed",
      "task_source": "consultation",
      "poster": { "id": "u_abc", "name": "张三", "avatar": "..." },
      "gross_amount": "200.00",
      "currency": "GBP",
      "transfer": {
        "status": "succeeded",
        "net_amount": "190.00",
        "stripe_transfer_id": "tr_xxx",
        "error_message": null
      },
      "created_at": "2026-04-01T10:00:00Z",
      "completed_at": "2026-04-05T14:30:00Z"
    }
  ],
  "total": 123,
  "page": 1,
  "page_size": 20
}
```

**实现:** `tasks` LEFT JOIN `expert_stripe_transfers`(不是所有任务都有 transfer 行)。

### 5.2 团队收入汇总

```
GET /api/experts/{expert_id}/earnings/summary
```

**Query:** `period`(`all_time`/`this_month`/`last_30d`/`last_90d`,默认 `all_time`)

**Response:**
```json
{
  "period": "all_time",
  "currency": "GBP",
  "total_gross": "4500.00",
  "total_net": "4275.00",
  "total_fee": "225.00",
  "total_reversed": "100.00",
  "pending_count": 2,
  "failed_count": 0,
  "succeeded_count": 45,
  "note": "Actual balance is held in your team's Stripe account. Check the Stripe Dashboard for real-time balance."
}
```

**关键:** `note` 字段必须显式提示"真实余额看 Stripe Dashboard",避免用户误以为这里的数字 = 可提现余额。MVP 不缓存,纯 SUM/COUNT 聚合。

### 5.3 Transfer 审计历史

```
GET /api/experts/{expert_id}/earnings/transfers
```

**Query:** `status`、`start_date`、`end_date`、`page`、`page_size`

**Response:** `expert_stripe_transfers` 行直接展开,附带关联 task 标题 + poster 信息。

### 5.4 Stripe 状态 + Onboarding 入口

已在 §2.3 定义(`GET /api/experts/{id}/stripe/status`、`POST /api/experts/{id}/stripe/onboarding`)。达人管理页面顶部红条幅消费这两个。

---

## §6 历史数据回填 + 迁移策略

### 6.1 已完成任务 —— 不动

已完成(`status='completed'`)的任务**不回填** `taker_expert_id`。理由:
1. 经济结算已完成,钱已在原个人 taker 的 `wallet_accounts` 里
2. 回填会让历史任务"看起来像"团队任务但实际无对应 Stripe Transfer 行,造成审计脱节
3. §5.1 列表查询返回时,这些任务的 `transfer` 字段为 `null`,前端可显示"legacy"标签或隐藏该列

### 6.2 未完成任务 —— 尽力回填

**目标:** 让"正在飞"的任务在完成时走新路径。

**预审步骤(必须先跑,决定是否需要人工介入):**

```sql
-- 列出 taker 可映射到多个团队的任务(需要人工决策)
SELECT t.id, t.taker_id, array_agg(em.expert_id) AS candidate_experts
FROM tasks t
JOIN expert_members em ON em.user_id = t.taker_id
WHERE t.status IN ('pending','pending_payment','in_progress','disputed')
  AND t.taker_expert_id IS NULL
  AND t.expert_service_id IS NOT NULL
  AND em.status = 'active'
GROUP BY t.id, t.taker_id
HAVING COUNT(DISTINCT em.expert_id) > 1;
```

**预审非空 → 人工决定,然后再跑主回填:**

**迁移文件:** `N+3_backfill_tasks_taker_expert.sql`

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
    AND t.expert_service_id IS NOT NULL
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

-- 统计报告
DO $$
DECLARE
  total_inflight INT;
  backfilled INT;
BEGIN
  SELECT COUNT(*) INTO total_inflight
  FROM tasks
  WHERE status IN ('pending','pending_payment','in_progress','disputed')
    AND expert_service_id IS NOT NULL;

  SELECT COUNT(*) INTO backfilled
  FROM tasks
  WHERE taker_expert_id IS NOT NULL
    AND status IN ('pending','pending_payment','in_progress','disputed');

  RAISE NOTICE 'In-flight expert service tasks: %', total_inflight;
  RAISE NOTICE 'Backfilled with taker_expert_id: %', backfilled;
  RAISE NOTICE 'Remaining individual-model tasks: %', total_inflight - backfilled;
END $$;

COMMIT;
```

**无法回填的任务**(taker 不在任何 active 团队 / 团队非 active / 非达人服务来源 / taker 只是 member 而非 owner/admin):保留个人模型继续流转,新代码不触发 Transfer(`taker_expert_id IS NULL`)。

> **为什么只回填 taker 是 owner/admin 的任务?** 因为普通 member 可能同时属于多个团队,自动归属会错位。实际上,现有老代码(`task_expert_routes.py:3107, 3851`)创建任务时 `taker_id` 几乎总是服务/申请的 owning user(多数是团队 owner),所以实际回填覆盖率应该很高。普通 member 被指定为 taker 的场景极少,保留个人模型是安全默认。

### 6.3 `task_expert_services` sanity check(预检,非迁移)

```sql
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
```

**期望:** 所有 `n_*_orphan*` 和 `n_null_owner` 均为 0。任何非零都要 migration 160-161 查漏补缺后再上线。

### 6.4 activities 历史数据

迁移脚本 §1.2 的 UPDATE 把所有历史活动统一设为 `owner_type='user', owner_id=expert_id`。新的 `POST /api/experts/{id}/activities` 上线后创建的活动才是 `owner_type='expert'`。**老活动永远保持个人所有**,不做迁移。

### 6.5 Team Owner Transfer 时同步未完成任务的 `taker_id`

在 `expert_routes.py` 的 ownership transfer 端点(具体函数名 plan 阶段确认)追加:

```python
await db.execute(
    update(models.Task)
    .where(
        models.Task.taker_expert_id == expert.id,
        models.Task.status.in_(['pending','pending_payment','in_progress','disputed'])
    )
    .values(taker_id=new_owner_user_id)
)
```

**已完成任务的 `taker_id` 不动**,保留历史快照。

### 6.6 上线前 checklist

1. ✅ §6.3 sanity check 全部零
2. ✅ §6.2 预审 SQL 非空的情况已人工决策
3. ✅ 所有新 migration 在 staging 跑通
4. ✅ `resolve_task_taker_from_service` helper 单元测试
5. ✅ Celery worker 能接到 `enqueue_expert_transfer`(Stripe test mode)
6. ✅ Webhook `account.updated` / `charge.dispute.created` 分支在 Stripe test dashboard 触发验证
7. ✅ E2E 冒烟:发布服务 → 下单 → 付款 → 完成 → Transfer 成功
8. ✅ 负测试:未 onboard 的团队发布服务 → 409
9. ✅ 故障注入:Stripe 5xx → Celery retry → 成功

---

## §7 Out of Scope(明确不做)

| 项 | 不做的理由 |
|----|-----------|
| 团队内部分账 | 团队用 Stripe Dashboard / 银行 / 自家薪资系统自行处理,平台不介入 |
| 团队余额展示 | 平台不持有余额,余额事实来源是 Stripe Dashboard;§5.2 只显示汇总 + 指向 Stripe |
| 团队内部提现 | 同上 |
| 达人管理页面 Flutter UI 实现 | 交给 `expert-dashboard-rewrite.md` plan |
| 税务 / 合规报表 | 远超范围 |
| 多人任务聊天 | 本 spec 替代了 `2026-04-04-expert-team-phase5-chat-multiuser.md`,聊天问题等本 spec 落地后重新评估 |
| 老 `task_experts` 表写入 | 只读,不动 |
| 老个人活动创建流程 | `multi_participant_routes.py:1754-1939` 保持 grandfather |

---

## §8 Plan 阶段待确认事项

以下细节**不影响本 spec 的设计决策**,但 plan 阶段必须解决:

1. **下一个可用 migration 编号**(本 spec 用 `N/N+1/N+2/N+3` 占位):`ls backend/migrations/ | tail`
2. **个人服务当前的资金流路径**(destination charge vs manual transfer):grep `task_expert_routes.py:3870-3899` 附近的 PaymentIntent 创建代码,确认是否设了 `transfer_data.destination`。这决定 §4.4 的改动范围。
3. **任务完成端点的准确位置**(`task.status → 'completed'` 的转移点,可能多处)
4. **`_compute_application_fee()` 或等价 fee 计算函数的实际名字和签名**
5. **`tasks.payment_charge_id` 或等价字段名**(存放客户付款 Charge ID,用于 §3.5 dispute 反查)
6. **`expert_stripe_transfers` ORM 模型放在哪个文件**(`models.py` / `models_expert.py` / 新文件)
7. **现有 webhook 处理器的准确位置**(`routers.py:8058-8080` 附近,需精确定位)
8. **ownership transfer 端点的函数名**(`expert_routes.py` 内)
9. **Stripe Account 类型**(`type='standard'` vs `'express'` vs `'custom'`):grep 现有个人用户 Stripe Connect 创建代码(若有),与之对齐。若现有代码没有 Account 创建路径(只做 Account Link),plan 阶段根据业务需求决定

---

## §9 测试策略

### 9.1 单元测试

- `resolve_task_taker_from_service()` —— 覆盖 owner_type='expert'、'user'、团队未 onboard、团队无 owner、未知 owner_type 五种情况
- `enqueue_expert_transfer` Celery task —— mock Stripe,覆盖成功、APIConnectionError retry、Stripe error failed、zero reward、已 succeeded 跳过、并发锁等场景
- `build_taker_display()` —— 团队任务、个人任务、NULL taker 三种

### 9.2 集成测试(pytest + Stripe test mode)

1. 团队服务下单 → Task 正确填 `taker_id` + `taker_expert_id`
2. 个人服务下单 → Task 只填 `taker_id`
3. 未 onboard 团队发布服务 → 409
4. 未 onboard 团队的活动报名 → 409
5. 团队 owner 收到"新订单"通知
6. 客户看到的 `taker_display` 对团队/个人分别正确
7. 任务完成 → `expert_stripe_transfers` 行创建 + Celery job enqueue
8. Stripe Transfer 成功 → `status='succeeded'` + `stripe_transfer_id` 填入
9. Stripe 5xx → Celery retry
10. Stripe 4xx → `status='failed'` + owner 收到失败通知
11. Dispute webhook → `status='reversed'`

### 9.3 迁移验证

- §6.3 sanity check 的所有 orphan 指标为 0
- §6.2 回填脚本在 staging 快照上的成功率报告 > 80%(预估,实际以预审结果为准)

### 9.4 前端契约测试

Flutter 侧只需要适配:
- `Task` model 增加 `takerExpertId` 字段和 `takerDisplay` 对象
- `ExpertDashboard` 三个新查询端点的 Bloc + View 消费(属于 dashboard rewrite plan,本 spec 不展开)

---

## §10 与其他 spec / plan 的关系

| 相关文档 | 关系 |
|---------|------|
| `2026-04-04-expert-team-phase5-chat-multiuser.md` | **本 spec 取代之**。该 plan 基于"聊天层扩展"假设,但团队经济主体缺失这一更根本的问题未解决。本 spec 落地后,多人聊天问题会自然消解(团队成员天然属于团队,聊天可见性可以直接查 `expert_members`) |
| `2026-04-05-expert-dashboard-rewrite.md` | **并行且互补**。本 spec 定义后端查询端点契约(§5),dashboard rewrite plan 定义 Flutter 侧的 Bloc + View 消费方式。两个 plan 可以并行开发,在前端 Bloc 调用新端点时对接 |
| `2026-04-01-group-chat-design.md` | **无直接关系**。群聊系统是独立的 Phase 1 能力,不涉及经济主体 |

---

**文档结束。**
