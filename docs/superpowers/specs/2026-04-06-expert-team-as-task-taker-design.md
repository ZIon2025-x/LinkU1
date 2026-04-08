# 达人团队作为任务接单方 —— 设计文档

**日期:** 2026-04-06(初版),2026-04-07(v2 修订)
**状态:** Implemented (2026-04-07) on branch `feat/expert-team-as-taker`
**作者:** Brainstorm session with Claude
**取代:** `docs/superpowers/plans/2026-04-04-expert-team-phase5-chat-multiuser.md`(该 plan 在本 spec 确定方向后废弃,多人聊天问题将在团队接单模型落地后重新评估)

> **v2 修订说明:** 初版 spec 假设要新建 `expert_stripe_transfers` 表 + 新 Celery 任务 + 新 Stripe Onboarding 端点。Phase 0 discovery (`docs/superpowers/plans/2026-04-07-expert-team-discovery.md`) 揭示这些**绝大多数已经存在**:`payment_transfers` 表 + `payment_transfer_service.py` + `expert_routes.py` 里的 stripe-connect 端点。本 v2 把"新建"全部改为"扩展现有",大幅减少改动面。

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
8. **🆕 (Phase 0 discovery)** 现有支付基础设施已经为个人 taker 完整实现,本 spec 主要是**扩展**它们支持团队 taker:
   - `payment_transfers` 表 (`models.py:3248`):manual transfer 审计表,有 `task_id`/`taker_id`/`amount`/`status`/`retry_count`/`transfer_id`/`last_error`/`next_retry_at`/`succeeded_at`/`extra_metadata`
   - `payment_transfer_service.py`:`create_transfer_record()`、`execute_transfer()`、`retry_failed_transfer()`、`process_pending_transfers()` —— 完整的 manual transfer + retry 实现
   - `expert_routes.py:1176, 1250`:**已存在**的 Stripe Onboarding 端点 `POST /api/experts/{id}/stripe-connect` + `GET /api/experts/{id}/stripe-connect/status`,用 `type='express'` 创建 Account
   - `routers.py:7620`:**已存在**的 `charge.dispute.created` webhook handler(冻结任务 + 通知,**未做反向 transfer**)
   - `refund_service.py:131`:**已存在**的 `stripe.Transfer.create_reversal` 调用,在 admin 退款流程里自动反向相关 PaymentTransfer
   - `wallet_service.py:124` `credit_wallet()`:个人 taker 的 wallet credit 入口(在 transfer 失败时 fallback 用)
   - `_get_member_or_403` 参数名是 `required_roles=`(不是 `roles=`)
   - `STRIPE_WEBHOOK_SECRET` 是 webhook 验签的环境变量名
   - Celery 用 sync session(`from app.database import SessionLocal`),没有 `backend/app/tasks/` 目录,Celery 任务文件全部在 `backend/app/celery_*.py`
   - 平台抽成函数:`from app.utils.fee_calculator import calculate_application_fee_pence`(参数是**便士 int**,不是英镑 Decimal)

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
- `taker_expert_id IS NULL` → 个人任务 / 未认领任务,按现有流程走
- 团队任务创建时 `taker_id` **必须填** owner 的 user_id(Y 方案);**不要因为是团队任务就把 `taker_id` 置 NULL**。`tasks.taker_id` 列本身在数据库层仍然是 nullable(未认领的普通任务可能为 NULL),Y 方案的约束是"业务层在创建团队任务时不准 NULL"
- `ON DELETE RESTRICT`:团队不允许被硬删除,必须通过 `experts.status` 软删除
- **币种约束:** 团队任务强制 GBP(见 §1.4)

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

### 1.3 扩展现有 `payment_transfers` 表(v2 修订)

> **v2:** 不再新建 `expert_stripe_transfers`。现有 `payment_transfers` (`models.py:3248`) 已经包含 90% 字段,只需 ALTER 加 6 列 + 改 status 取值约束。这让团队任务能直接复用 `payment_transfer_service.py` 的所有 manual transfer + retry 逻辑。

**现有 `payment_transfers` 字段映射:**

| 字段 | 已有 | 新需求 |
|------|------|---------|
| id, task_id, taker_id, poster_id, amount, currency | ✓ | — |
| transfer_id (Stripe tr_xxx) | ✓ | — |
| status (pending/succeeded/failed/retrying) | ✓ | 加 `'reversed'` |
| retry_count, max_retries, last_error, next_retry_at | ✓ | — |
| succeeded_at, created_at, updated_at, extra_metadata | ✓ | — |
| **taker_expert_id** | — | 新增 (FK experts) |
| **idempotency_key** | — | 新增 (UNIQUE) |
| **stripe_charge_id** | — | 新增 (dispute 反查用) |
| **stripe_reversal_id** | — | 新增 (反向跟踪) |
| **reversed_at, reversed_reason** | — | 新增 (反向审计) |

**迁移文件:** `N+2_extend_payment_transfers_for_team_taker.sql`

```sql
-- ===========================================
-- 迁移 N+2: 扩展 payment_transfers 表支持团队接单
-- spec §1.3 (v2)
-- ===========================================

BEGIN;

-- 1. 新增团队接单字段
ALTER TABLE payment_transfers
  ADD COLUMN taker_expert_id VARCHAR(8) NULL
    REFERENCES experts(id) ON DELETE RESTRICT,
  ADD COLUMN idempotency_key VARCHAR(64) NULL,
  ADD COLUMN stripe_charge_id VARCHAR(255) NULL,
  ADD COLUMN stripe_reversal_id VARCHAR(255) NULL,
  ADD COLUMN reversed_at TIMESTAMPTZ NULL,
  ADD COLUMN reversed_reason TEXT NULL;

-- 2. 回填现有行的 idempotency_key (让 UNIQUE 约束能加上)
UPDATE payment_transfers
SET idempotency_key = 'legacy_' || id::text
WHERE idempotency_key IS NULL;

-- 3. 加 NOT NULL + UNIQUE 约束
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

-- 5. status 约束(加 'reversed' 取值)
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
COMMENT ON COLUMN payment_transfers.stripe_charge_id IS
  '原始 Charge ID,dispute 反查用';
COMMENT ON COLUMN payment_transfers.stripe_reversal_id IS
  '被 reverse 时的 Stripe trr_xxx';

COMMIT;
```

**关键不变量(v2):**
- `UNIQUE(idempotency_key)` 配合 `SELECT ... FOR UPDATE SKIP LOCKED` 处理并发 worker
- 团队任务的 idempotency_key 格式 = `'task_{task_id}_transfer'`
- 反向(dispute / refund)通过 **in-place update** `status='reversed'` + 填 `stripe_reversal_id`,**不另开新行**
- `payment_transfers.taker_id` 在团队任务时仍填 owner.user_id(Y 方案对齐),`taker_expert_id` 标识真正经济主体
- 这张表**不是钱包** —— 没有余额字段

**ORM 模型变更:** `models.py:3248` 的 `PaymentTransfer` 类追加 6 个新 Column 字段,**不需要新建模型**。

### 1.4 币种约束 —— 团队任务强制 GBP

本 spec 范围内,**所有涉及 `taker_expert_id` 的任务、服务、活动强制使用 GBP**。理由:Link2Ur 主战场是英国,无多币种业务诉求;真要做国际化是另一个 Phase 的事。

**强制点(以下所有代码块都必须显式检查):**

1. `POST /api/experts/{id}/services`(§2.1)收到 body 时校验 `currency == 'GBP'`,否则 422
2. `POST /api/experts/{id}/activities`(§2.2)同上
3. `resolve_task_taker_from_service()`(§4.2)在 `owner_type='expert'` 分支校验 `service.currency == 'GBP'`,否则抛 409 `error_code='expert_currency_unsupported'`
4. `resolve_task_taker_from_activity()`(§4.3a)在 `owner_type='expert'` 分支校验 `activity.currency == 'GBP'`,同上
5. `payment_transfer_service.execute_transfer`(§3.2)在调 Stripe 之前断言 `transfer_record.currency == 'GBP'`,异常则标 `failed`,error_code=`currency_unsupported`
6. `§6.2` 回填脚本只回填 `currency = 'GBP'` 的在飞任务

**个人任务 / 个人服务的币种**不受此约束(继续走原流程)。

**`payment_transfers.currency` 列已存在**(`DEFAULT 'GBP'`),为未来扩展留口子,但**当前 spec 范围内对团队任务只允许 'GBP'**。

---

## §2 发布端点 + Stripe 门槛(M2 + R2)

### 2.1 服务发布 —— 改已有端点

现有 `POST /api/experts/{expert_id}/services`(`expert_service_routes.py:106-133`)已经:
- 要求调用者是团队 owner/admin(`_get_member_or_403`)
- 写 `task_expert_services.owner_type='expert', owner_id=expert_id`

**本 spec 的改动:** 在端点开头加 Stripe 门槛 + 币种检查:

```python
expert = await db.get(Expert, expert_id)
if not expert:
    raise HTTPException(404, "Expert team not found")
if not expert.stripe_onboarding_complete:
    raise HTTPException(status_code=409, detail={
        "error_code": "expert_stripe_not_ready",
        "message": "Team must complete Stripe onboarding before publishing services"
    })

# 币种检查(§1.4)
if (body.currency or 'GBP').upper() != 'GBP':
    raise HTTPException(status_code=422, detail={
        "error_code": "expert_currency_unsupported",
        "message": "Team services only support GBP currently"
    })
```

### 2.2 活动发布 —— 新建团队专用端点

**新建:** `POST /api/experts/{expert_id}/activities`(新文件 `backend/app/expert_activity_routes.py`,或放在 `expert_routes.py`,plan 阶段定)。

- **鉴权:** `_get_member_or_403(expert_id, roles=['owner','admin'])`
- **Stripe 门槛检查:** 同 2.1
- **币种检查(§1.4):** body.currency 必须是 GBP,否则 422 `expert_currency_unsupported`
- **数据写入:**
  - `activities.owner_type = 'expert'`
  - `activities.owner_id = expert_id`
  - `activities.expert_id = owner.user_id`(Y 方案:legacy 字段填代表)
- **Body schema:** 复用现有 `multi_participant_routes.py:1754-1939` 的活动创建 body,具体字段列表在 plan 阶段 mirror。

**现有个人活动创建端点** (`multi_participant_routes.py:1754-1939`) **不动**,保持个人身份创建的老流程作为 grandfather 路径。

### 2.3 Stripe Onboarding 入口 + 状态查询(v2:已存在)

> **v2 修订:** Phase 0 discovery 发现这两个端点**已经存在**:

- `POST /api/experts/{expert_id}/stripe-connect` (`expert_routes.py:1176`) —— 创建 Stripe Express Account + AccountLink
- `GET /api/experts/{expert_id}/stripe-connect/status` (`expert_routes.py:1250`) —— 查 Account 状态,会自动同步 `stripe_onboarding_complete` 字段

**实现细节:**
- Account 类型:`type='express'`(不是 `'standard'`)
- `business_type='individual'`
- `capabilities={card_payments:{requested:True}, transfers:{requested:True}}`
- 鉴权:`required_roles=["owner", "admin"]`
- GET status 端点会**主动调 Stripe API** retrieve account,并把 `details_submitted` 同步到 `expert.stripe_onboarding_complete`(line 1275-1277)

**本 spec 不需要新建任何端点。** 达人管理页面顶部的红条幅直接调 `GET /api/experts/{id}/stripe-connect/status`。

**唯一要补的小改动:** 现有 status 端点的 `required_roles=["owner", "admin"]` 限制了只有 owner/admin 能查。如果产品上希望普通 member 也能在达人管理页面看到 onboarding 状态(以便了解为什么团队不能接单),需要把这个改成 `["owner", "admin", "member"]`。**本 spec 建议改**,但放进 plan 阶段决定。

### 2.4 Stripe Webhook 同步 `account.updated`

**前置配置(plan 阶段必做):**

1. 在 **Stripe Dashboard → Developers → Webhooks** 给现有 webhook endpoint 订阅以下事件(若已订阅则跳过):
   - `account.updated`(团队 Connect 账户状态变化)
   - `charge.dispute.created`(争议产生,见 §3.5)
   - `charge.dispute.closed`(争议结束,可选,用于审计)
2. **Webhook signing secret** 通过现有环境变量(具体名 plan 阶段 grep 确认)注入,新分支沿用同一密钥校验
3. **Connect 账户的事件源:** 需要确认现有 webhook endpoint 是否同时接收 platform account 事件 + connected account 事件。`account.updated` 是 connected account 事件,可能需要在 Stripe Dashboard 单独勾选 "Listen to events on Connected accounts"

**Race condition 注意:** 调 `stripe.Account.create` 时,Stripe 会**立即**异步 fire 一个 `account.updated` 事件。如果该事件在我们 `db.commit()`(写入 `experts.stripe_account_id`)**之前**到达,handler 查 `Expert.stripe_account_id == acct.id` 会查不到,事件被静默忽略。**实践上不致命** —— 后续状态变化(用户填了表单等)会再触发新的 `account.updated` 事件,handler 那时能找到记录。但 plan 阶段最好把 `Account.create` 和 `db.commit()` 放在**同一事务**且**先 commit 再返回 onboarding URL**,缩短窗口。

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

### 3.1 触发点(v2)

任务完成(`task.status` 转为 `'completed'`)时,**复用现有 `payment_transfer_service` 流程** —— 个人 taker 任务和团队 taker 任务都走同一条路径,只是 destination 不同。

**任务完成端点(共 4 处,见 §8 D2):**

| 文件:行 | 触发方式 |
|---------|---------|
| `routers.py:3920` | 客户手动确认完成 |
| `scheduled_tasks.py:267` | 定时超时确认 |
| `scheduled_tasks.py:1012` | `auto_confirm_expired_tasks` |
| `scheduled_tasks.py:1133` | 另一处 scheduled completion |

每处的 `task.status = 'completed'` 之后,现有代码已经调 `payment_transfer_service.create_transfer_record()` 和 `execute_transfer()`。**本 spec 不需要在任务完成端点加任何代码** —— 现有调用会自动 work,只要 `execute_transfer` 内部知道怎么处理 `taker_expert_id`(见 §3.2)。

**唯一可能要改:** 现有 `create_transfer_record()` 调用方传 `taker_id=task.taker_id`,需要确认它会顺带读 `task.taker_expert_id`。如果不读,§3.2 给出的修改方案要在调用方加一个 `taker_expert_id` 参数。

### 3.2 扩展 `payment_transfer_service.execute_transfer`(v2 替代原 Celery 任务)

> **v2 修订:** 不再新建 Celery 任务。直接在现有 `execute_transfer()` 里加 `taker_expert_id` 分支。

**现有 `execute_transfer` 签名(`payment_transfer_service.py:108`):**
```python
def execute_transfer(
    db: Session,
    transfer_record: models.PaymentTransfer,
    taker_stripe_account_id: str,
    commit: bool = True
) -> tuple[bool, Optional[str], Optional[str]]:
    """执行 Stripe Transfer 转账"""
    ...
```

**v2 改动 1 —— `create_transfer_record` 接受 `taker_expert_id`:**

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
    # ... 现有幂等检查 ...

    transfer_record = models.PaymentTransfer(
        task_id=task_id,
        taker_id=taker_id,
        taker_expert_id=taker_expert_id,           # ★ 新增
        poster_id=poster_id,
        amount=amount,
        currency=currency,
        status="pending",
        idempotency_key=f"task_{task_id}_transfer", # ★ 新增,启用 v2 幂等
        # 其他字段不变
    )
    ...
```

**v2 改动 2 —— `execute_transfer` 内部读 `taker_expert_id` 决定 destination:**

```python
def execute_transfer(
    db: Session,
    transfer_record: models.PaymentTransfer,
    taker_stripe_account_id: Optional[str] = None,  # ★ 改为 Optional
    commit: bool = True
) -> tuple[bool, Optional[str], Optional[str]]:
    ...
    task = db.query(models.Task).filter(models.Task.id == transfer_record.task_id).first()
    if not task:
        return False, None, "任务不存在"

    # ★ v2 新增:团队任务的 destination 是 experts.stripe_account_id
    if transfer_record.taker_expert_id:
        from app.models_expert import Expert
        expert = db.query(Expert).filter(Expert.id == transfer_record.taker_expert_id).first()
        if not expert or not expert.stripe_account_id:
            return False, None, "Team has no Stripe Connect account"
        if not expert.stripe_onboarding_complete:
            return False, None, "Team Stripe onboarding not complete"
        destination_account = expert.stripe_account_id
    else:
        destination_account = taker_stripe_account_id  # 个人 taker,沿用现状

    # ★ v2 新增:90 天 Transfer 时效检查 (§3.4a)
    if task.payment_completed_at:
        from datetime import datetime, timedelta
        age = datetime.utcnow() - task.payment_completed_at.replace(tzinfo=None)
        if age > timedelta(days=89):
            transfer_record.status = 'failed'
            transfer_record.last_error = f'Transfer window expired ({age.days}d)'
            db.commit()
            return False, None, 'stripe_transfer_window_expired'

    # ★ v2 新增:币种检查
    if transfer_record.taker_expert_id and (transfer_record.currency or 'GBP').upper() != 'GBP':
        transfer_record.status = 'failed'
        transfer_record.last_error = 'Currency not supported for team tasks'
        db.commit()
        return False, None, 'currency_unsupported'

    # ... 后续逻辑(stripe_dispute_frozen 检查、Stripe Account validate、Transfer.create)
    # 调 stripe.Transfer.create 时把 destination=destination_account 传进去
    # 同时把 idempotency_key 也传给 Stripe (transfer_record.idempotency_key)
```

**v2 改动 3 —— 任务完成端点的现有调用补 `taker_expert_id`:**

每个任务完成端点(§3.1 列的 4 处)在调 `create_transfer_record` 时多传一个参数:

```python
transfer_record = create_transfer_record(
    db=db,
    task_id=task.id,
    taker_id=task.taker_id,
    poster_id=task.poster_id,
    amount=transfer_amount,
    currency=task.currency or 'GBP',
    taker_expert_id=task.taker_expert_id,  # ★ 新增
    metadata={...}
)
```

**复用的现有逻辑(零改动):**
- ✅ 幂等检查(`create_transfer_record` 已经查 task_id+taker_id+status)
- ✅ Stripe 调用错误处理
- ✅ Retry 机制(`retry_failed_transfer` + `process_pending_transfers`)
- ✅ 失败时 fallback 到 `credit_wallet`(对个人 taker)
- ✅ 余额监控、日志记录、错误格式化

**为什么不再用 Celery `delay()`:** 现有 `execute_transfer` 是**同步调用**(在任务完成端点的事务里直接执行),失败的话有 `retry_failed_transfer` 和 `process_pending_transfers` 这两个独立的重试入口。这个模式对个人 taker 已经验证过,团队 taker 沿用即可。如果将来要异步化,改的是整个 transfer service,不是本 spec 的范围。

**待定:** "任务完成"在代码里的准确位置 —— Phase 0 已确认是上面 4 处。

### 3.3 平台抽成(v2)

**实际函数:** `from app.utils.fee_calculator import calculate_application_fee_pence`

```python
application_fee_pence = calculate_application_fee_pence(
    task_amount_pence,            # int 便士,不是英镑
    task_source="expert_service",
    task_type=None
)
```

团队任务和个人任务**同一套** fee 规则(P1 决策)。fee 由 PaymentIntent 创建时记录在 metadata,任务完成 transfer 时从 gross 扣 fee 后传 net 给 Stripe Transfer。**所有计算都用便士 int,不要混 Decimal**(精度问题)。

### 3.4 失败处理(v2)

**复用现有 retry 机制:** `payment_transfer_service.retry_failed_transfer` + `process_pending_transfers` 已经处理 retry。团队任务的失败会被同样的 Celery beat / cron 自动重试。

**新增 admin 监控:** 加 `GET /api/admin/expert-transfers?status=failed` 端点(等同于现有个人任务监控,只是带 `taker_expert_id IS NOT NULL` 过滤)。如果现有 admin 监控已经有"失败 transfer 列表",直接让它显示 `taker_expert_id` 字段即可,不需要新端点。

**通知:** Transfer 失败时,通过现有通知系统(`crud.create_notification`)给 `team owner.user_id`(也就是 `transfer_record.taker_id`)发"打款失败"通知。无需新建通知通道。

#### 3.4a Stripe Transfer 90 天时效

**Stripe API 规则:** `stripe.Transfer.create` 必须在原始 Charge **90 天内**调用。

**实现位置:** §3.2 给的 `execute_transfer` 改造里已经包含了 90 天检查,在调 Stripe 之前显式检查 `task.payment_completed_at` 与 `datetime.utcnow()` 的差,超过 89 天直接标 failed 不发 Stripe 请求。

**预防性监控:** 加一个 daily Celery beat 任务,扫描 `in_progress` 且 `payment_completed_at < now() - 60d` 的团队任务,通知 owner "接近 Transfer 时效"。这个 task 加在现有 `celery_tasks.py` 里,**不要新建 `tasks/` 目录**(D11 确认无此目录)。

**人工兜底:** 管理员手工通过 Stripe Dashboard 转账,然后在 admin 端点把对应 `payment_transfers` 行手工标 `succeeded` + 填 transfer_id 和备注。

### 3.5 退款 / 争议处理(v2)

**场景 A:任务完成前退款** —— 钱还在平台账户,团队未收到。现有退款流程不动,`payment_transfers` 行尚未创建,零影响。

**场景 B:任务完成后客户 dispute** —— `routers.py:7620` 的 `charge.dispute.created` webhook handler **已存在**,目前会:
1. 设置 `task.stripe_dispute_frozen=1`(冻结后续 transfer)
2. 通知 poster + taker + admin
3. 发系统消息

**v2 改动:** 在该 handler 内追加一段"团队任务自动反向 transfer"的逻辑(在现有冻结/通知逻辑之后):

```python
# 加在现有 charge.dispute.created 分支末尾
if task and task.taker_expert_id:
    # 团队任务:查 payment_transfers,如果已经 succeeded 就反向
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
            # 通知团队 owner(taker_id 已经是 owner.user_id)
            crud.create_notification(
                db, str(pt.taker_id),
                "expert_transfer_reversed", "款项已反向",
                f"任务 #{task_id} 的 £{pt.amount} 因争议被反向", auto_commit=False
            )
        except stripe.error.StripeError as e:
            logger.error(f"Failed to reverse team transfer for task {task_id}: {e}")
            # 反向失败:保持 succeeded,管理员介入
```

**反向失败(团队 Stripe 余额不足):** 沿用现有 `refund_service.py:131` 的处理模式 —— 记录 warning,留给管理员手工处理。

**场景 C:管理员主动退款给已完成任务的客户** —— `refund_service.py:131` **已存在** `stripe.Transfer.create_reversal` 调用,会自动反向 `PaymentTransfer` 行。**对团队任务自动 work**(因为 Reversal API 用 transfer_id,与 destination 无关)。

**v2 唯一要补的:** 现有 reversal 代码用 `original_transfer.transfer_id` 反向,但**没有写 `stripe_reversal_id` / `reversed_at` / `reversed_reason` 这三个新字段**。需要在 `refund_service.py:131-141` 的 reversal 成功分支里追加这三个字段的写入。

### 3.6 `TaskParticipantReward` 对团队任务(v2)

**团队任务(`taker_expert_id IS NOT NULL`)不创建 `TaskParticipantReward` 行。** 审计事实来源是 `payment_transfers`(扩展了 6 列后的版本)。这避免两套审计表争夺事实来源。

任务完成时的代码路径:**实际上不需要分叉** —— 任务完成端点都已经在调 `create_transfer_record(...)` + `execute_transfer(...)`,只要这俩函数知道怎么处理 `taker_expert_id` 即可(见 §3.2 的改造)。

**`TaskParticipantReward` 的写入位置在哪?** Phase 0 没具体定位,但它和 `payment_transfers` 是平行的两套机制(前者是多人任务的"每个参与者拿多少"快照,后者是真正打款的审计)。在团队任务路径里,**两者都跳过**(因为团队任务不分账给成员)。

**实施确认:** Phase 4 里改任务创建的代码时,要确认团队任务的代码路径不会触发 `TaskParticipantReward` 创建。如果触发了,要加个 if 跳过。

### 3.7 积分奖励 (`task.points_reward`) 的处理

**决策:积分进团队 owner 的个人积分账户**(对应 Y 方案"owner 是经济代表"的语义)。

**理由:**
- 沿用现金的 Y 方案心智:owner 是团队的对外代表,平台不介入团队内分配
- 实现成本几乎为零 —— 复用现有 user `points_balance` 流程,不需要为 expert 加 points 字段或新表
- Owner 在团队内自行决定是否、如何把积分分给成员
- 不引入"团队积分钱包"违反 §0 第 7 条和 §7 范围声明

**实现:** 任务完成时,无论是个人还是团队任务,积分发放逻辑统一走"发给 `task.taker_id` 这个 user_id"。因为团队任务的 `taker_id` 已经被 §4.2 / §4.3a helper 填成了 owner 的 user_id,所以**积分代码完全不需要分叉,自然就发到 owner 头上**。

**实际函数(D14 grep 结果):** `add_points_transaction()` 在 `coupon_points_crud.py:76`。Phase 4 改任务完成路径时确认这个函数被调用且 `user_id` 参数取自 `task.taker_id`。

```python
# 现有积分发放代码(实际函数名)
from app.coupon_points_crud import add_points_transaction
if task.points_reward and task.points_reward > 0:
    add_points_transaction(
        db,
        user_id=task.taker_id,  # 团队任务时 = owner.user_id, 个人任务时 = 个人 taker
        amount=task.points_reward,
        source=f"task_completion_{task.id}",
    )
```

**注意:** 这是 Y 方案的天然好处之一 —— 个人和团队两条路径在积分层面**完全同构**,不需要任何 if-else。

**限制:** 如果未来产品决定"团队任务的积分应该按贡献分摊给所有团队成员",那时需要新功能,但本 spec 不做这件事。Y 方案的当前实现意味着"积分全归 owner",owner 自行处理分发(在团队管理 UI 里手动发,或私下用其他方式)。

---

## §4 老系统迁移(S2)

### 4.1 改动点清单

| # | 文件:行(现状) | 改动 |
|---|----------------|------|
| 1 | `task_expert_routes.py:3090-3130`(咨询任务创建) | 通过 `resolve_task_taker_from_service()` helper 解析,填 `taker_id` + `taker_expert_id` |
| 2 | `task_expert_routes.py:3820-3860`(正式服务任务创建) | 同上 |
| 3 | `task_expert_routes.py:3870-3899`(Payment Intent 创建) | 取消 `transfer_data.destination`,统一走 manual transfer(见 4.4) |
| 4 | `multi_participant_routes.py:236-599`(活动报名 → Task 创建) | 通过 `resolve_task_taker_from_activity()` helper 解析,填 `taker_id` + `taker_expert_id`(详见 4.3a) |
| 5 | 任务完成端点(位置 plan 阶段 grep) | 加 `taker_expert_id` 分叉,enqueue Celery Transfer |

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
        # 币种检查(§1.4)
        if (service.currency or 'GBP').upper() != 'GBP':
            raise HTTPException(status_code=409, detail={
                "error_code": "expert_currency_unsupported",
                "message": "Team services only support GBP currently"
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

### 4.3a 活动报名 → Task 创建分叉 —— 对偶 helper

`multi_participant_routes.py:236-599` 现有逻辑里,活动报名时会创建 Task(单人活动),Task 的 `taker_id` 取自 `activity.expert_id`(老的个人 user_id 字段)。本 spec 落地后,活动有 `owner_type` / `owner_id` 多态列(§1.2),所以这里也要分叉。

**在同一个 `expert_task_resolver.py` 文件里加一个对偶 helper:**

```python
async def resolve_task_taker_from_activity(
    db: AsyncSession,
    activity: models.Activity,
) -> tuple[str, Optional[str]]:
    """
    返回 (taker_id, taker_expert_id):
      - owner_type='expert':(team owner user_id, expert_id) —— 团队活动
      - owner_type='user':  (user_id, None) —— 个人活动(legacy / grandfather)
    团队路径会校验 Stripe onboarding + 币种(GBP)。
    """
    if activity.owner_type == 'expert':
        expert = await db.get(Expert, activity.owner_id)
        if not expert:
            raise HTTPException(404, "Expert team not found")
        if not expert.stripe_onboarding_complete:
            raise HTTPException(409, detail={
                "error_code": "expert_stripe_not_ready",
                "message": "Team is temporarily unable to accept sign-ups"
            })
        if (activity.currency or 'GBP').upper() != 'GBP':
            raise HTTPException(409, detail={
                "error_code": "expert_currency_unsupported",
                "message": "Team activities only support GBP currently"
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

    elif activity.owner_type == 'user':
        return (activity.expert_id, None)  # legacy 个人活动

    else:
        raise HTTPException(500, f"Unknown activity owner_type: {activity.owner_type}")
```

**`multi_participant_routes.py` 的 Task 创建处**(具体行号 plan 阶段 grep 确认,可能不止一处:单人活动 / 时间槽活动 / 多人活动,见 §0 探索报告)调用此 helper,把 `taker_id` 和 `taker_expert_id` 一起写入新 Task。

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

**影响范围:** 如果当前个人服务走 destination charge,这个改动把它们**顺带对齐**到 manual transfer,让所有路径统一。plan 阶段的 **Task 1 必须 grep 确认** 当前资金流模式,影响后续任务的拆分粒度。

**两种结果分支:**

- **A. 当前已经是 manual transfer**(钱进平台账户 → wallet_accounts credit → 用户提现):§4.4 这段基本无改动,只是个人 taker 路径不变,团队 taker 路径**新增** §3.2 的 Celery Transfer。
- **B. 当前是 destination charge**(钱直接进 taker Stripe):必须**补建** "个人任务完成 → wallet_accounts.balance credit" 的代码路径,否则改成 manual transfer 后个人 taker 的钱会被锁在平台账户。这是一个**额外子任务**,plan 阶段如果发现是 B,要扩范围或者**回退本 spec 的 Payment Intent 改动**(Payment Intent 仍按 taker 类型分叉:团队走 manual,个人走 destination charge)。

**选 B 的回退方案(plan 阶段如果不想扩范围):**

```python
if taker_expert_id_value:
    # 团队任务:Payment Intent 不设 transfer_data,等 Celery Transfer
    intent_kwargs = {...}  # 同上
else:
    # 个人任务:维持现状,destination charge
    intent_kwargs = {
        ...,
        'transfer_data': {'destination': taker_stripe_account_id},
        'application_fee_amount': fee_pence,
    }
```

这个回退保留了"团队走新流程,个人不动"的最小爆炸半径。**plan Task 1 grep 之后再决定走 A 还是回退。**

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

**实现:** `tasks` LEFT JOIN `payment_transfers`(不是所有任务都有 transfer 行;`taker_expert_id` 在 `tasks` 上做 WHERE 过滤)。

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

**Response:** `payment_transfers` 行直接展开(只过滤 `taker_expert_id IS NOT NULL` 的行),附带关联 task 标题 + poster 信息。

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
-- 注意:同时覆盖服务来源 (expert_service_id) 和活动来源 (parent_activity_id)
SELECT t.id, t.taker_id, array_agg(em.expert_id) AS candidate_experts
FROM tasks t
JOIN expert_members em ON em.user_id = t.taker_id
WHERE t.status IN ('pending','pending_payment','in_progress','disputed')
  AND t.taker_expert_id IS NULL
  AND (t.expert_service_id IS NOT NULL OR t.parent_activity_id IS NOT NULL)
  AND COALESCE(t.currency, 'GBP') = 'GBP'  -- §1.4 GBP-only
  AND em.status = 'active'
GROUP BY t.id, t.taker_id
HAVING COUNT(DISTINCT em.expert_id) > 1;
```

**预审非空 → 人工决定,然后再跑主回填:**

**迁移文件:** `N+3_backfill_tasks_taker_expert.sql`

```sql
BEGIN;

-- 回填规则:
--   1. 任务必须是达人来源(expert_service_id IS NOT NULL 或 parent_activity_id IS NOT NULL)
--   2. 必须是 GBP(§1.4)
--   3. taker 必须是某 active 团队的 owner/admin
--   4. 团队本身 active
--   5. 多团队归属时取(owner > admin)+(joined_at 最早)
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

-- 统计报告
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

  RAISE NOTICE 'In-flight expert tasks (service + activity, GBP only): %', total_inflight;
  RAISE NOTICE 'Backfilled with taker_expert_id: %', backfilled;
  RAISE NOTICE 'Remaining individual-model tasks: %', total_inflight - backfilled;
END $$;

COMMIT;
```

**无法回填的任务**(taker 不在任何 active 团队 / 团队非 active / 非达人来源 / taker 只是 member 而非 owner/admin / 非 GBP 币种):保留个人模型继续流转,新代码不触发 Transfer(`taker_expert_id IS NULL`)。

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
5. ✅ 扩展后的 `payment_transfer_service.execute_transfer` 在 staging 用团队任务跑通(Stripe test mode)
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

## §8 Plan 阶段待确认事项(v2:Phase 0 后绝大多数已解决)

✅ **下面 14 项已经在 Phase 0 discovery 解决:** `docs/superpowers/plans/2026-04-07-expert-team-discovery.md`

| # | 事项 | 结论 |
|---|------|------|
| 1 | 下一个 migration 编号 | **176**(基于现有 175) |
| 2 | 个人服务资金流模式 | **manual transfer**,§4.4 走 A 路径,无回退需要 |
| 3 | 任务完成端点位置 | **4 处:** `routers.py:3920`, `scheduled_tasks.py:267,1012,1133` |
| 4 | fee 计算函数 | `from app.utils.fee_calculator import calculate_application_fee_pence`,**参数和返回都是便士 int** |
| 5 | `tasks.payment_charge_id` 字段 | **不存在**。Task 有 `payment_intent_id`,可调 Stripe API 反查;或加新字段(plan 决定) |
| 6 | ORM 模型位置 | (v2 已解决)扩展 `PaymentTransfer` 类,不新建 |
| 7 | webhook handler 位置 | `routers.py:6536` (`stripe.Webhook.construct_event`),已有 `charge.dispute.*` 5 个分支 |
| 8 | ownership transfer 端点 | `expert_routes.py:833` `transfer_ownership` |
| 9 | Stripe Account 类型 | (D8 解决)**`type='express'`**,already in use at `expert_routes.py:1212` |
| 10 | wallet credit 路径 | (D9 解决)`wallet_service.py:124` `credit_wallet()` 存在;且 `payment_transfer_service.py` 是完整 manual transfer 实现 |
| 11 | refund 端点位置 | `refund_service.py`,反向 transfer 已经在 line 131 实现 |
| 12 | Celery session | (D11 解决)全部 sync,`from app.database import SessionLocal`,**没有 `tasks/` 目录** |
| 13 | `tasks.payment_completed_at` | **不存在**。需要 Phase 1 加 column |
| 14 | webhook secret 环境变量 | `STRIPE_WEBHOOK_SECRET` |
| 15 | 积分发放函数 | `coupon_points_crud.py:76` `add_points_transaction()` |

**剩余真正的 plan 阶段决策:**
- 是否新增 `tasks.payment_charge_id` 列(便利 dispute 反查)还是用 `payment_intent_id` 反查 charge

**剩余的"已存在端点是否需要小调整":**
- `GET /api/experts/{id}/stripe-connect/status` 现在 `required_roles=["owner","admin"]`,本 spec 建议放宽到 `["owner","admin","member"]`,让普通成员在达人管理页面也能看到 Stripe 状态(plan 决定)

---

## §9 测试策略

### 9.1 单元测试

- `resolve_task_taker_from_service()` —— 覆盖 owner_type='expert'、'user'、团队未 onboard、团队无 owner、未知 owner_type 五种情况
- `resolve_task_taker_from_activity()` —— 同上,加币种检查
- **扩展后**的 `payment_transfer_service.execute_transfer()` —— 增加团队任务测试:mock Stripe,覆盖成功、destination 走 expert.stripe_account_id、Stripe error → status=failed、90 天时效拦截、币种 non-GBP 拦截、idempotency key UNIQUE 冲突
- `build_taker_display()` —— 团队任务、个人任务、NULL taker 三种

### 9.2 集成测试(pytest + Stripe test mode)

1. 团队服务下单 → Task 正确填 `taker_id` + `taker_expert_id`
2. 个人服务下单 → Task 只填 `taker_id`
3. 未 onboard 团队发布服务 → 409
4. 未 onboard 团队的活动报名 → 409
5. 团队 owner 收到"新订单"通知
6. 客户看到的 `taker_display` 对团队/个人分别正确
7. 任务完成 → `payment_transfers` 行创建(带 taker_expert_id)+ `execute_transfer` 同步执行
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
| `2026-04-07-expert-team-as-task-taker.md` | **本 spec 的实施 plan**(已完成) |

---

**文档结束。**
