# Expert Team As Taker — Discovery Report

> 配套 plan: `2026-04-07-expert-team-as-task-taker.md`
> Phase 0 执行结果。**包含 7 项重大发现,plan 需要修订。**

---

## D1. 个人服务当前资金流模式

**结论: Manual Transfer(钱进平台账户,任务完成时再 Transfer 给 taker)。**

证据: `task_expert_routes.py:3878-3902` 创建 PaymentIntent 时,`create_pi_kw` dict 里**没有** `transfer_data` 也没有 `application_fee_amount`,只在 `metadata` 里记了 `taker_stripe_account_id` 和 `application_fee` 供后续 transfer 使用。

**对 §4.4 的影响:** 走 **A 路径**(统一 manual transfer)。Phase 4.4 的 B 回退方案不需要。

---

## D2. 任务完成端点位置

**多个入口,全部要加 taker_expert_id 分叉:**

| 文件:行 | 触发方式 |
|---------|---------|
| `routers.py:3920` | 客户手动确认完成(主流程,`task.status = "completed"`) |
| `scheduled_tasks.py:267` | 定时任务(超时确认或类似) |
| `scheduled_tasks.py:1012` | `auto_confirm_expired_tasks` 自动确认 |
| `scheduled_tasks.py:1133` | 另一处 scheduled completion |

**对 plan 的影响:** Phase 6.3 改 1 处 → 改 4 处。

---

## D3. `_compute_application_fee` 函数

**结论:实际函数名是 `calculate_application_fee_pence`,参数和返回都是便士(pence,int),不是英镑(Decimal)。**

- 文件: `backend/app/utils/fee_calculator.py`
- 调用例: `task_expert_routes.py:3870`
  ```python
  from app.utils.fee_calculator import calculate_application_fee_pence
  application_fee_pence = calculate_application_fee_pence(
      task_amount_pence, task_source="expert_service", task_type=None
  )
  ```

**对 plan 的影响:** Phase 6.2 的 `_compute_application_fee` 占位符替换为 `calculate_application_fee_pence`,**注意单位是便士不是英镑**,plan 里写的 Decimal 计算需要改成 int 计算。

---

## D4. `tasks.payment_charge_id` 字段

**结论:Task 没有 `payment_charge_id` 字段,但有 `payment_intent_id`(`models.py:214`)。**

可以通过 `stripe.PaymentIntent.retrieve(payment_intent_id).latest_charge` 反查 charge_id,或者在 webhook `payment_intent.succeeded` 时落库。

**对 plan 的影响:** §3.5 dispute 反查需要的是 charge_id。两种方案:
1. 新增 `tasks.payment_charge_id` 列(plan 增加一个 migration)
2. 反查时调 Stripe API(慢但够用)

**推荐方案 1**(新增字段),plan 加一个 migration `180_add_tasks_payment_charge_id.sql`。

---

## D5. `ExpertStripeTransfer` ORM 模型放哪

**🔴 重大发现:不需要新建 `expert_stripe_transfers` 表!**

现有 `payment_transfers` 表(`models.py:3248`)已经包含几乎所有需要的字段:
- `task_id`, `taker_id` (FK users), `amount`, `currency`
- `status`, `retry_count`, `max_retries`, `last_error`, `next_retry_at`
- `transfer_id` (Stripe Transfer ID)
- `succeeded_at`, `created_at`, `updated_at`
- `extra_metadata` (JSONB)

**缺少的字段:**
- `taker_expert_id` (新需求)
- `idempotency_key UNIQUE` (幂等保护,新需求)
- `stripe_charge_id` (dispute 反查,新需求)
- `stripe_reversal_id` (反向跟踪,新需求)
- `reversed_at`, `reversed_reason` (反向审计,新需求)

**对 plan 的影响:** Phase 1.3 从"创建新表"改为"**ALTER 现有 `payment_transfers` 表**加 5 列",大幅减少代码量,**复用现有所有逻辑**。

---

## D6. Webhook handler 位置 + 验签

- 文件:`routers.py:6536`
- 验签函数:`stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)`
- 入口位置:`routers.py:6508` 读取 `STRIPE_WEBHOOK_SECRET` 环境变量

**已存在的 webhook 分支(grep 结果):**
- `charge.dispute.created`(line 7620)— 已实现冻结任务 + 通知,**未做反向 transfer**
- `charge.dispute.updated`(line 7690)
- `charge.dispute.closed`(line 7697)
- `charge.dispute.funds_withdrawn`(line 7739)
- `charge.dispute.funds_reinstated`(line 7745)

**对 plan 的影响:** Phase 3.4(`account.updated` 分支)是**新增**。Phase 7(dispute 处理)是**在现有 `charge.dispute.created` 分支里追加团队任务的 reversal 逻辑**,不是新建。

---

## D7. ownership transfer 端点

- 文件:`expert_routes.py:833`
- 函数:`async def transfer_ownership(...)`

**对 plan 的影响:** Phase 9.3 已正确指向这个函数。

---

## D8. Stripe Account 类型

**🔴 重大发现:Stripe Onboarding 端点已经存在!**

- `POST /api/experts/{expert_id}/stripe-connect`(`expert_routes.py:1176`,创建 Stripe Account)
- `GET /api/experts/{expert_id}/stripe-connect/status`(`expert_routes.py:1250`,查状态)

现有代码用的是 `type="express"`(line 1212)+ `business_type="individual"` + `capabilities={card_payments, transfers}`。

**对 plan 的影响:** Phase 3.1 + 3.2(创建 `expert_stripe_routes.py`)**整个删掉**!这两个端点已经存在,只是 URL 是 `/stripe-connect` 不是 `/stripe/onboarding`。

Plan 需要把对这些端点的引用统一到 `/stripe-connect` 路径。

---

## D9. 个人 wallet_accounts.balance credit 路径

**结论:存在,而且非常完整。**

- `wallet_service.py:124` `credit_wallet(db, user_id, amount, source, idempotency_key, ...)` —— 加余额 + 写 wallet_transactions 流水 + 锁保护
- `payment_transfer_service.py` 是**整套现成的 manual transfer 实现**,包含:
  - `create_transfer_record(task_id, ...)` 创建审计行
  - `execute_transfer(db, transfer_record, taker_stripe_account_id)` 调 `stripe.Transfer.create`
  - `retry_failed_transfer(...)` 重试失败 transfer
  - `process_pending_transfers(...)` 批处理待转账
  - 在 Stripe 失败时 fallback 到 `credit_wallet`

**对 plan 的影响:** **巨大** —— Phase 6 的 Celery `enqueue_expert_transfer` 任务**不需要从零写**。直接在 `payment_transfer_service.execute_transfer` 里加一段:

```python
if task.taker_expert_id:
    expert = db.get(Expert, task.taker_expert_id)
    destination = expert.stripe_account_id
else:
    destination = taker_stripe_account_id  # 现状
```

可能 50 行的修改,而不是 200 行的新文件。

---

## D10. refund 端点位置

- 主文件:`refund_service.py:73` `stripe.Refund.create`
- **反向 Transfer 已实现!** `refund_service.py:131` `stripe.Transfer.create_reversal` —— 在 admin 退款流程里已经会自动反向相关的 PaymentTransfer。

**对 plan 的影响:** Phase 7.3(管理员主动 refund 反向 transfer)**已实现**。需要确认对**团队任务**(transfer 实际去了 `experts.stripe_account_id`)是否能正确工作 —— `Transfer.create_reversal` API 用的是 `transfer_id` 不是 destination,所以应该能 work,但需要 staging 验证。

---

## D11. Celery sync session factory

**结论:全部 Celery 任务用 sync session。**

- `from app.database import SessionLocal`
- 例:`celery_tasks.py:85, 113, 146, ...` 都是 `db = SessionLocal()`
- Celery tasks 目录:`backend/app/tasks/` **不存在**(plan 假设它存在,要新建)
- 现有 Celery 任务文件:`celery_tasks.py`, `celery_app.py`, `celery_tasks_expiry.py`, `customer_service_tasks.py`, `recommendation_tasks.py`, `official_draw_task.py`

**对 plan 的影响:** Phase 6.2 的新 task 应该:
- **直接放在 `celery_tasks.py` 里**(沿用现有惯例)
- 或者在 `payment_transfer_service.py` 里加函数(因为大部分逻辑可复用)
- **不要**新建 `backend/app/tasks/expert_transfer.py`

---

## D12. `tasks.payment_completed_at` 字段

**结论:不存在。**

Task 类(`models.py:200-285`)只有 `accepted_at`, `completed_at`, `confirmed_at`,**没有**付款成功时间戳。

**对 plan 的影响:** 需要新增列。Phase 1.4 (条件任务) 必跑,migration 编号 `178a` 或纳入主迁移序列。

---

## D13. Webhook signing secret 环境变量

**结论:`STRIPE_WEBHOOK_SECRET`** (`routers.py:6508`)

---

## D14. 积分发放函数

- `coupon_points_crud.py:76` `add_points_transaction(...)` —— 是积分流水入口
- `multi_participant_routes.py` 也调它

**对 plan 的影响:** §3.7 假设的 `credit_user_points()` 不存在,实际名字是 `add_points_transaction`。但因为团队任务的 `taker_id = team owner.user_id`,现有积分发放代码**不需要任何修改**(沿用 Y 方案的天然好处)—— 只要积分发放的代码本身是基于 `task.taker_id` 的。Plan §3.7 文字描述准确,代码示例的函数名要改。

---

## D15. `_get_member_or_403` helper 签名

- 文件:`expert_routes.py`(grep 多次引用)
- **参数名是 `required_roles=`,不是 `roles=`!**

```python
await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])
```

**对 plan 的影响:** Plan 里所有 `roles=['owner','admin']` 都要改成 `required_roles=['owner','admin']`。涉及多个 task。

---

## §4.4 决策

基于 D1 + D9 的结果:

- **D1 = manual transfer**(已经是了)
- **D9 = wallet credit + transfer 路径都存在,且非常完整**

**走 §4.4 路径 A** —— 团队任务复用现有 manual transfer 路径,只需要在 `execute_transfer` 加一个 `taker_expert_id` 分支(改 destination)。

---

# 🔴 重大发现汇总 & Plan 修订需求

| # | 发现 | 对 plan 的影响 | 修订量 |
|---|------|---------------|--------|
| 1 | **Stripe Onboarding 端点已存在** (`expert_routes.py:1176, 1250`) | Phase 3.1, 3.2 删除 | -200 行 plan |
| 2 | **`payment_transfers` 表已存在,大部分字段已有** | Phase 1.3 从"建表"改为"加 5 列",ORM 模型删除 | -100 行 plan |
| 3 | **`payment_transfer_service.py` 已有完整 manual transfer + retry 实现** | Phase 6.2 从"建新 Celery task"改为"在现有 service 里加分支" | -300 行 plan |
| 4 | **`charge.dispute.created` webhook 已存在** | Phase 7.2 从"建新分支"改为"在现有分支里追加团队 reversal 逻辑" | -50 行 plan |
| 5 | **退款反向 transfer 已实现** (`refund_service.py:131`) | Phase 7.3 大部分变成"验证现有逻辑对团队任务也工作" | -100 行 plan |
| 6 | **多个任务完成入口** (4 处) | Phase 6.3 从"改 1 处"变"改 4 处" | +30 行 plan |
| 7 | **`required_roles=` 不是 `roles=`** | 全 plan 参数名修正 | +10 行 plan |

**净 plan 减少:约 -700 行** —— plan 从 3151 行可以缩到 ~2400 行,实际**实施工作量减半以上**。

**最关键的认知修正:** 我之前以为这是一个"新建整套基础设施"的工作,实际上 90% 的支付基础设施已经为个人 taker 构建好了,我们只是要**把它扩展到支持团队**。这是个 EXTENSION 任务,不是 GREENFIELD 任务。

---

## 推荐的下一步

**强烈建议:返回 brainstorming 阶段,让 spec 和 plan 都基于"扩展现有 payment_transfers + payment_transfer_service 基础设施"的真实前提重写,而不是"新建 expert_stripe_transfers + 新 Celery task"。**

这是一个**真正的设计缺陷** —— 我和用户在 brainstorming 阶段没有充分探索现有代码,导致 spec 假设了不存在的 greenfield。

revisit 的代价:写一份 ~400 行的修订 spec patch + 重写 plan 的 Phase 1, 3, 6, 7。
不 revisit 的代价:实施时不停发现重复代码,要么造成两套并行系统(技术债),要么实施过程中频繁调整 plan(混乱)。
