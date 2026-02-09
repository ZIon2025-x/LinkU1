# TaskScheduler 定时任务系统文档

> 最后更新：2026-02-09

## 概述

TaskScheduler 是 Link2Ur 后端的进程内定时任务调度器，替代原先的 Celery Worker + Celery Beat 架构。
它运行在 FastAPI 主进程的一个守护线程中，通过 `SCHEDULER_MODE=local` 环境变量启用（跳过 Celery 检测，节省约 10 秒启动时间）。

**核心文件**：
- `app/task_scheduler.py` — 调度器类 + 任务注册
- `app/scheduled_tasks.py` — 大部分任务的业务逻辑实现
- `app/customer_service_tasks.py` — 客服相关任务
- `app/payment_transfer_service.py` — 转账相关逻辑
- `app/main.py` — 启动调度器（`startup_event`）

---

## 架构风险与缓解措施

### 1. 单线程单进程风险

**现状**：调度器运行在 FastAPI 主进程的守护线程中。

**风险点**：
- 主进程崩溃/重启时，所有定时任务中断，且没有补偿机制。转账任务若执行到一半时重启，可能导致状态已更新但转账未执行（或反过来）
- 守护线程中未捕获异常可能导致线程静默退出，任务不再执行但主进程看起来正常运行
- 如果将来水平扩展（多实例），所有实例会同时执行相同任务，转账类任务会导致重复支付

**缓解措施**：

| 优先级 | 措施 | 状态 |
|--------|------|------|
| P0 | 所有任务函数顶层 try-except，防止单个任务异常杀死线程 | ✅ 已实现（`_run_task` 中有统一 catch） |
| P0 | 转账类任务加 PostgreSQL advisory lock 或 `SELECT ... FOR UPDATE SKIP LOCKED`，防止多实例重复执行 | ⬜ 待实现 |
| P1 | 调度器线程加健康检查心跳：主进程定期检测线程是否存活，死亡则重启 + 告警 | ⬜ 待实现 |
| P1 | 每日任务加补偿执行机制：记录上次执行时间（Redis/DB），如果发现错过了则补执行 | ⬜ 待实现 |
| P2 | 关键任务（转账）加基于 Redis 的分布式锁，为多实例部署做准备 | ⬜ 待评估 |

### 2. `escrow_amount` 使用 Float 类型存储金额

**问题**：Task 模型中 `escrow_amount = Column(Float, default=0.0)`，浮点数在金融场景下会产生精度误差。

**建议**：应使用 `DECIMAL(12, 2)` 或整数存储（以分/便士为单位）。`PaymentTransfer.amount` 已使用 `DECIMAL(12, 2)`。

**状态**：✅ 已完成（迁移 `085`，`models.py` + `migrations/085_escrow_amount_to_decimal_and_auto_transfer.sql`）

---

## 当前已注册任务清单（30 个）

### 一、高频任务（30 秒 ~ 1 分钟）

| # | 任务名 | 间隔 | 源函数 | 说明 |
|---|--------|------|--------|------|
| 1 | `process_customer_service_queue` | 30s | `customer_service_tasks.process_customer_service_queue` | 将排队用户分配给空闲客服坐席 |
| 2 | `auto_end_timeout_chats` | 30s | `customer_service_tasks.auto_end_timeout_chats` | 自动结束超过 2 分钟无响应的客服对话 |
| 3 | `send_timeout_warnings` | 30s | `customer_service_tasks.send_timeout_warnings` | 对话即将超时时（1 分钟）发送预警 |
| 4 | `cancel_expired_tasks` | 60s | `main.cancel_expired_tasks` | 取消已过截止日期的普通任务 |
| 5 | `auto_complete_expired_time_slot_tasks` | 60s | `scheduled_tasks.auto_complete_expired_time_slot_tasks` | 自动完成已过期时间段的达人任务 + 3 天后自动转账（详见下方重点说明） |

### 二、中频任务（5 ~ 15 分钟）

| # | 任务名 | 间隔 | 源函数 | 说明 |
|---|--------|------|--------|------|
| 6 | `check_expired_payment_tasks` | 5m | `scheduled_tasks.check_expired_payment_tasks` | 检查并取消 `payment_expires_at` 已过期的待支付任务 |
| 7 | `process_pending_payment_transfers` | 5m | `payment_transfer_service.process_pending_transfers` | 重试 pending/retrying 状态的 Stripe 转账 |
| 8 | `sync_forum_view_counts` | 5m | (内联) | 将论坛帖子浏览数从 Redis 增量同步到 PostgreSQL |
| 9 | `sync_leaderboard_view_counts` | 5m | (内联) | 将榜单浏览数从 Redis 增量同步到 PostgreSQL |
| 10 | `check_expired_coupons` | 15m | `scheduled_tasks.check_expired_coupons` | 标记已过期的优惠券及用户持有记录 |
| 11 | `check_expired_invitation_codes` | 15m | `scheduled_tasks.check_expired_invitation_codes` | 处理过期的邀请码 |
| 12 | `check_and_end_activities` | 15m | `scheduled_tasks.check_and_end_activities_sync` → `task_expert_routes.check_and_end_activities` | 检查多人活动是否应结束（最后时间段过期 / 截止日期到达），标记为 completed，取消 open/taken 状态的子任务 |
| 12a | `send_auto_transfer_reminders` | 1h | `scheduled_tasks.send_auto_transfer_reminders` | **[Phase 2]** 对已完成未确认的达人任务，按 confirmation_deadline 倒计时发送提醒（第1天/第2天各一次） |
| 12b | `auto_transfer_expired_tasks` | 15m | `scheduled_tasks.auto_transfer_expired_tasks` | **[Phase 3]** 达人任务过期 3 天后自动确认 + Stripe Transfer 转账给达人（含防重复、行级锁、金额校验） |
| 12c | `auto_confirm_expired_tasks` | 15m | `scheduled_tasks.auto_confirm_expired_tasks` | 自动确认超过 5 天未确认的 pending_confirmation 任务（通用） |
| 12d | `send_confirmation_reminders` | 15m | `scheduled_tasks.send_confirmation_reminders` | 发送确认提醒通知（pending_confirmation 状态任务的 72h/24h/6h/1h 提醒） |

> **⚠️ #5 与 #12 的边界重叠问题**：
> `auto_complete_expired_time_slot_tasks`（#5）处理的是**个别任务**的时间段过期（标记单个 task 为 completed）。
> `check_and_end_activities`（#12）处理的是**活动级别**的整体过期（标记 Activity 为 completed，取消 open/taken 子任务）。
> 
> 如果在 #5 中也加入活动过期检查（Phase 2），两个任务会竞争修改同一批数据。
> **决策**：#5 不再新增 Phase 2（活动过期检查），维持 #12 独立负责活动级别的过期逻辑。#5 专注于：① 标记个别任务完成 ② 3 天后自动转账。

### 三、低频任务（10 分钟 ~ 1 小时）

| # | 任务名 | 间隔 | 源函数 | 说明 |
|---|--------|------|--------|------|
| 13 | `update_all_users_statistics` | 10m | `main.update_all_users_statistics` | 批量更新用户的 task_count、completed_task_count、avg_rating 等统计字段 |
| 14 | `check_expired_points` | 1h | `scheduled_tasks.check_expired_points` | 标记已到期的用户积分为过期 |
| 15 | `process_expired_verifications` | 1h | `scheduled_tasks.process_expired_verifications` | 兜底处理过期的学生认证（正常由 webhook 处理，这里是兜底） |
| 16 | `check_expired_vip_subscriptions` | 1h | `crud.check_and_update_expired_subscriptions` | 将已到期的 VIP 订阅状态更新为 expired |
| 17 | `check_transfer_timeout` | 1h | `payment_transfer_service.check_transfer_timeout` | 检查 pending 状态超过 24 小时的转账记录，标记为超时 |
| 18 | `revert_unpaid_application_approvals` | 1h | `crud.revert_unpaid_application_approvals` | 撤销 `pending_payment` 超过 24 小时未付款的申请批准，状态回退为 `open` |
| 19 | `update_popular_tasks` | 30m | (内联) | 基于 24 小时内的 UserTaskInteraction 数据，计算热门任务 Top 50，缓存到 Redis |
| 20 | `precompute_recommendations` | 1h | (内联) | 为最近 7 天有交互行为的活跃用户（最多 100 个）预计算推荐结果 |

> **⚠️ #13 性能隐患**：
> 当前全量扫描更新所有用户统计，用户量增长后将成为数据库瓶颈。
> **后续优化方向**：改为事件驱动（任务完成时增量更新 `update_user_statistics`），或降频到每小时 + 增量更新代替全量扫描。

### 四、每日任务（每小时检查，仅在指定 UTC 时间执行）

| # | 任务名 | 执行时间 | 源函数 | 说明 |
|---|--------|----------|--------|------|
| 21 | `cleanup_long_inactive_chats` | UTC 2:00 | `customer_service_tasks.cleanup_long_inactive_chats` | 清理 30 天以上无活动的客服对话 |
| 22 | `send_expiry_reminders` | UTC 2:00 | `scheduled_tasks.send_expiry_reminders` + `send_expiry_notifications` | 学生认证过期提醒（30天/7天/1天前 + 过期当天通知） |
| 23 | `cleanup_recommendation_data` | UTC 2:00 | `recommendation_data_cleanup.cleanup_recommendation_data` | 清理过时的推荐系统数据 |
| 24 | `update_featured_task_experts_response_time` | UTC 3:00 | `crud.update_all_featured_task_experts_response_time` | 更新特征达人的 response_time / response_time_en |
| 25 | `optimize_recommendation_system` | UTC 4:00 | `recommendation_optimizer.optimize_recommendation_system` | 优化推荐系统参数/模型 |

> **⚠️ 每日任务漏执行风险**：
> 当前"每小时检查，仅在指定 UTC 小时执行"的实现方式，如果目标整点恰好在部署/重启期间，任务会被跳过整整一天。
> **待实现**：补偿执行机制——记录每个任务上次成功执行时间（Redis key 或 DB），启动后检查是否错过了应执行的窗口，错过则立即补执行。

### 五、每周任务

| # | 任务名 | 执行时间 | 源函数 | 说明 |
|---|--------|----------|--------|------|
| 26 | `anonymize_old_data` | 每周日 UTC 3:00 | `data_anonymization.anonymize_old_interactions` + `anonymize_old_feedback` | 匿名化 90 天以上的交互记录和反馈数据（隐私合规） |

---

## 待开发功能：自动转账（Auto-Transfer）

### 需求描述

在达人任务的时间段过期 **3 天后**，如果参与者（发布者）已付款但一直未确认完成，系统应自动触发全额转账给达人，保护达人的利益。

### 目标流程

```
时间段过期（slot_end_datetime）
  → 自动标记 completed（Phase 1，现有逻辑）
  → 第 1-2 天：发送提醒通知给发布者
        「您的任务 #XX 将在 X 天后自动确认并转账，如有问题请及时反馈」
  → 第 3 天系统检查（Phase 3）：
        slot_end_datetime <= now - 3 days（注意：用时间段结束时间，不用 completed_at）
        AND is_paid = 1
        AND confirmed_at IS NULL
        AND escrow_amount > 0
  → 计算实际转账金额 = escrow_amount - sum(已成功转账)
  → 如果金额 > 0：创建 PaymentTransfer + 执行 Stripe Transfer
  → 更新任务确认状态
  → 发送通知给双方
```

### 关键设计决策

#### 1. 3 天起算锚点：使用时间段结束时间，而非 `completed_at`

**原因**：`completed_at` 是 Phase 1 自动标记的时间，受定时任务执行频率影响，可能比实际过期时间晚数分钟甚至数小时。如果以 `completed_at` 起算，会导致等待期不准确。

**实现**：Phase 3 需重新查询任务的 `max(slot_end_datetime)`，判断是否 `<= now - 3 days`。

#### 2. `confirmation_deadline` 字段与自动转账时间的统一

**现状**：Task 模型中有 `confirmation_deadline` 字段（注释为 completed_at + 5 天），但自动转账是 3 天。

**决策**：统一为 **3 天**。
- `confirmation_deadline` 设为 `slot_end_datetime + 3 days`（在 Phase 1 标记完成时同步设置）
- 自动转账在 `slot_end_datetime + 3 days` 后触发
- 删除原有的"5 天"逻辑，避免歧义

#### 3. 提前通知机制（争议窗口）

3 天自动转账对发布者可能太突然。需要提前通知：

| 时间点 | 动作 |
|--------|------|
| 时间段过期时 | 标记 completed，发送通知「任务已完成，请确认」 |
| 过期后第 1 天 | 发送提醒「您的任务将在 2 天后自动确认并转账」 |
| 过期后第 2 天 | 发送提醒「您的任务将在明天自动确认并转账，如有问题请及时反馈」 |
| 过期后第 3 天 | 执行自动转账 |

可复用 `confirmation_reminder_sent` 位掩码字段记录提醒发送状态。

#### 4. 不在 #5 中合并活动过期检查

**原因**：任务 #12 (`check_and_end_activities`) 已独立处理活动级别的过期逻辑（含异步 DB 操作、审计日志、关联任务取消）。如果在 #5 中也加入活动过期检查，两个任务会竞争修改同一批数据。

**决策**：#5 只负责个别任务的完成 + 3 天自动转账。活动过期由 #12 独立处理。多人活动的子任务同样适用 3 天自动转账规则（因为子任务也是 Task，Phase 3 会统一覆盖）。

### 实现方案

#### Phase 1（现有，微调）：标记过期任务为 completed

在标记任务为 completed 时，同步设置：
```python
task.status = "completed"
task.completed_at = current_time
task.confirmation_deadline = max_end_time + timedelta(days=3)  # 用时间段结束时间
```

#### Phase 2（新增）：发送确认提醒通知

在同一个函数中查询已完成但未确认的任务，根据时间段过期天数发送提醒。

```python
# 查询条件：
#   status == "completed"
#   expert_service_id IS NOT NULL
#   is_paid == 1
#   confirmed_at IS NULL
#   completed_at IS NOT NULL
# 按 confirmation_reminder_sent 位掩码判断哪些提醒还没发
```

使用 `confirmation_reminder_sent` 位掩码：
- bit 0 (值 1)：第 1 天提醒已发送
- bit 1 (值 2)：第 2 天提醒已发送

#### Phase 3（新增）：3 天后自动转账

**步骤 1 — 查询待自动转账的任务**：
```python
conditions:
  - status == "completed"
  - expert_service_id IS NOT NULL       # 达人任务
  - is_paid == 1                        # 已付款
  - confirmed_at IS NULL                # 发布者未确认
  - escrow_amount > 0                   # 有托管金额
  - stripe_dispute_frozen != 1          # 非争议冻结
  # 通过时间段结束时间判断是否已过 3 天（需 JOIN 查询，见下方）
```

**步骤 2 — 计算时间段过期天数**：
```python
# 重新查询任务的 max(slot_end_datetime)
# 优先取 TaskTimeSlotRelation，备选取 ActivityTimeSlotRelation
# 条件：max_end_time <= now - 3 days
```

**步骤 3 — 金额一致性校验**：
```python
from decimal import Decimal
from sqlalchemy import func, and_

# 查询已成功转账的总额
total_transferred = db.query(
    func.coalesce(func.sum(PaymentTransfer.amount), Decimal('0'))
).filter(
    and_(
        PaymentTransfer.task_id == task.id,
        PaymentTransfer.status == "succeeded"
    )
).scalar()

# 计算实际应转金额
auto_transfer_amount = Decimal(str(task.escrow_amount)) - Decimal(str(total_transferred))

if auto_transfer_amount <= Decimal('0'):
    # 已全额转账，只需更新确认状态
    update_confirmation_status(task)
    continue

if auto_transfer_amount != Decimal(str(task.escrow_amount)):
    # 金额不一致（可能有部分转账），记录告警
    logger.warning(f"⚠️ 任务 {task.id} 自动转账金额 £{auto_transfer_amount} 与 escrow £{task.escrow_amount} 不一致，已有转账 £{total_transferred}")
```

**步骤 4 — 防重复转账（双重保护）**：
```python
# 保护层 1：检查是否已有 pending/retrying/processing 状态的转账记录
existing_pending = db.query(PaymentTransfer).filter(
    and_(
        PaymentTransfer.task_id == task.id,
        PaymentTransfer.status.in_(["pending", "retrying", "processing"])
    )
).first()
if existing_pending:
    logger.info(f"任务 {task.id} 已有待处理转账记录，跳过")
    continue

# 保护层 2：用 SELECT ... FOR UPDATE 锁定任务行，防止并发创建
task = db.query(Task).filter(Task.id == task.id).with_for_update(skip_locked=True).first()
if not task or task.confirmed_at is not None:
    continue  # 已被其他实例处理

# 保护层 3（兜底）：数据库唯一约束
# PaymentTransfer 表建议增加：
#   UNIQUE INDEX ix_payment_transfer_auto_confirm ON (task_id) WHERE transfer_source = 'auto_confirm_3days'
# 如果唯一约束冲突，catch IntegrityError 并跳过
```

**步骤 5 — 创建转账记录并执行**：
```python
transfer_record = create_transfer_record(
    db,
    task_id=task.id,
    taker_id=task.taker_id,
    poster_id=task.poster_id,
    amount=auto_transfer_amount,
    currency="GBP",
    metadata={
        "transfer_source": "auto_confirm_3days",
        "slot_end_time": str(max_end_time),
        "original_escrow": str(task.escrow_amount),
        "total_previously_transferred": str(total_transferred),
    }
)

# 如果达人有 Stripe Connect 账户：立即执行
taker = crud.get_user_by_id(db, task.taker_id)
if taker and taker.stripe_account_id:
    success, transfer_id, error = execute_transfer(db, transfer_record, taker.stripe_account_id)
    if success:
        update_confirmation_status(task, auto_transfer_amount)
    else:
        logger.error(f"自动转账执行失败: task={task.id}, error={error}")
        # 转账记录保留为 pending/failed，由 process_pending_payment_transfers 重试
else:
    # 无 Stripe 账户，保留 pending 记录等待 process_pending_payment_transfers 处理
    logger.info(f"达人 {task.taker_id} 无 Stripe 账户，自动转账记录已创建待后续处理")
```

**步骤 6 — 更新任务确认状态**：
```python
def update_confirmation_status(task, transfer_amount):
    """
    更新确认状态。
    注意：不清零 escrow_amount，保留原始金额用于审计追溯。
    """
    task.confirmed_at = get_utc_time()
    task.auto_confirmed = 1       # 系统自动确认
    task.is_confirmed = 1
    task.paid_to_user_id = task.taker_id
    # ⚠️ escrow_amount 保持原值不变（Stripe Transfer 记录已记录实际转账金额）
    # 如果需要标记已释放：可增加 escrow_released_at 字段
    db.commit()
```

> **关于 `escrow_amount` 的处理**：
> Stripe Transfer API 调用成功不代表资金已最终到账（存在结算延迟）。如果在转账成功后立即清零 `escrow_amount`，会导致无法追溯原始托管金额。
> 
> **方案 A**（推荐）：保留 `escrow_amount` 原始值，通过 `is_confirmed = 1` + `PaymentTransfer.status = "succeeded"` 来判断是否已释放。
> **方案 B**：新增 `original_escrow_amount` 字段保留历史值，`escrow_amount` 清零。
> **方案 C**：新增 `escrow_released_at` 时间戳标记释放。

**步骤 7 — 发送通知**：
```python
# 给发布者
create_notification(
    user_id=task.poster_id,
    type="auto_confirm_transfer",
    title="任务已自动确认",
    content=f"您的任务「{task.title}」已超过 3 天未确认，系统已自动确认并将报酬转给达人"
)

# 给达人
create_notification(
    user_id=task.taker_id,
    type="auto_confirm_transfer",
    title="任务报酬已自动发放",
    content=f"任务「{task.title}」已自动确认完成，报酬 £{auto_transfer_amount:.2f} 已转入您的账户"
)
```

**步骤 8 — 审计日志**：
```python
# TaskAuditLog：记录完整的操作快照
audit_log = TaskAuditLog(
    task_id=task.id,
    action_type="auto_confirmed_3days",
    action_description=f"系统自动确认（时间段过期 3 天），自动转账 £{auto_transfer_amount:.2f}",
    user_id=None,  # 系统操作
    old_status="completed",
    new_status="completed",  # 状态不变，但确认状态变了
    extra_data={
        "transfer_record_id": transfer_record.id,
        "transfer_amount": str(auto_transfer_amount),
        "original_escrow": str(task.escrow_amount),
        "total_previously_transferred": str(total_transferred),
        "stripe_transfer_id": transfer_id,
        "slot_end_time": str(max_end_time),
        "taker_id": task.taker_id,
        "poster_id": task.poster_id,
    }
)
db.add(audit_log)
```

### 单次执行上限与告警

为防止异常数据导致大规模误转，Phase 3 设置**单次执行上限**：

```python
MAX_AUTO_TRANSFERS_PER_CYCLE = 20

auto_transfer_count = 0
for task in tasks_to_auto_transfer:
    if auto_transfer_count >= MAX_AUTO_TRANSFERS_PER_CYCLE:
        logger.critical(
            f"🚨 自动转账达到单次上限 {MAX_AUTO_TRANSFERS_PER_CYCLE}，"
            f"剩余 {len(tasks_to_auto_transfer) - auto_transfer_count} 个待处理，需人工确认"
        )
        # TODO: 发送告警到管理员（邮件/Slack）
        break
    # ... 执行转账逻辑 ...
    auto_transfer_count += 1
```

### 涉及的数据库字段（Task 模型）

| 字段 | 类型 | 说明 |
|------|------|------|
| `status` | String | 任务状态，completed 表示已完成 |
| `is_paid` | Integer | 1=已付款 |
| `escrow_amount` | Float ⚠️ | 托管金额（任务金额 - 平台服务费）。**待迁移为 DECIMAL(12,2)** |
| `is_confirmed` | Integer | 1=已确认转账 |
| `confirmed_at` | DateTime | 确认时间（手动或自动） |
| `auto_confirmed` | Integer | 1=系统自动确认, 0=发布者手动确认 |
| `paid_to_user_id` | String(8) | 收款人用户ID |
| `completed_at` | DateTime | 任务完成时间（由 Phase 1 设置） |
| `confirmation_deadline` | DateTime | 自动确认截止时间 = slot_end_datetime + 3 天 |
| `confirmation_reminder_sent` | Integer | 提醒状态位掩码：bit0=第1天提醒, bit1=第2天提醒 |
| `stripe_dispute_frozen` | Integer | 1=Stripe 争议冻结中，禁止转账 |
| `expert_service_id` | Integer | 达人服务ID（非空=达人任务） |
| `taker_id` | String(8) | 任务接受人（达人）ID |
| `poster_id` | String(8) | 任务发布者ID |

### 涉及的外部服务

| 服务 | 用途 |
|------|------|
| Stripe Transfer API | 从平台账户转账到达人的 Connect 账户 |
| 通知系统 | 应用内通知 + 推送通知（APNs/FCM） |

---

## 安全与合规清单

### P0（上线前必须完成）

- [ ] **Float → Decimal**：`Task.escrow_amount` 从 Float 迁移为 `DECIMAL(12,2)`
- [ ] **防重复转账兜底**：`PaymentTransfer` 表增加唯一约束或条件唯一索引（`task_id` + `transfer_source = 'auto_confirm_3days'`）
- [ ] **转账前行级锁**：使用 `SELECT ... FOR UPDATE SKIP LOCKED` 锁定 Task 行
- [ ] **3 天起算用时间段结束时间**：不使用 `completed_at`
- [ ] **发布者提前通知**：至少在自动转账前 1 天发送提醒

### P1（上线后尽快完成）

- [ ] **调度器线程健康检查**：主进程定期检测线程存活状态
- [ ] **每日任务补偿机制**：记录上次执行时间，错过则补执行
- [ ] **单次转账数量上限**：上限 20 条，超出则告警人工介入
- [ ] **统一 `confirmation_deadline`**：从 5 天改为 3 天

### P2（后续迭代）

- [ ] **#13 改为增量更新**：事件驱动 + 降频
- [ ] **审计日志规范**：标准化 `extra_data` 结构，确保涉及资金的操作可完整还原
- [ ] **限流告警**：Prometheus 指标 + 告警规则
- [ ] **`escrow_amount` 处理策略**：选择方案 A/B/C 并实现

---

## 测试要点

### 自动转账核心场景

- [ ] 时间段过期后 < 3 天：不应触发自动转账
- [ ] 时间段过期后 >= 3 天 + 已付款 + 未确认：应触发自动转账
- [ ] 发布者已手动确认的任务（confirmed_at 非空）：不应触发
- [ ] 未付款的任务（is_paid=0）：不应触发
- [ ] 已有成功转账记录（sum >= escrow）：不应重复转账，应只更新确认状态
- [ ] 已有部分转账：应只转剩余金额
- [ ] 达人无 Stripe 账户：应创建 pending 记录等待 `process_pending_payment_transfers` 处理
- [ ] Stripe 争议冻结（stripe_dispute_frozen=1）：不应转账
- [ ] 多人活动的子任务：同样适用 3 天自动转账规则

### 提醒通知场景

- [ ] 第 1 天提醒：发送后 bit0 置 1
- [ ] 第 2 天提醒：发送后 bit1 置 1
- [ ] 提醒已发送的不重复发送（位掩码检查）
- [ ] 发布者在提醒期间手动确认：不应再发提醒或自动转账

### 边界与并发场景

- [ ] Phase 1 和 Phase 3 同一周期执行：Phase 1 刚标记完成的任务不满足 3 天条件
- [ ] 两个执行周期同时进入 Phase 3：FOR UPDATE SKIP LOCKED 保证不重复处理
- [ ] `completed_at` 与 `slot_end_datetime` 差距较大时：以 `slot_end_datetime` 为准
- [ ] 单次超过 20 条待转账：应限流并告警

---

## 架构说明

### TaskScheduler vs Celery 对比

| 维度 | Celery (已弃用) | TaskScheduler (当前) |
|------|-----------------|---------------------|
| 部署 | 需要 Worker + Beat 两个独立服务 | 主进程内守护线程，零额外服务 |
| 成本 | ~$10/月（两个 Railway 服务） | $0（与后端共享资源） |
| Redis 依赖 | 需要作为消息队列 | 不依赖 Redis（仅业务层使用） |
| 可靠性 | 分布式锁 + ACK 机制 | 单进程，需额外加锁机制 |
| 并发控制 | 多 Worker 支持 | 单线程顺序执行 |
| 适用场景 | 大规模分布式任务 | 中小规模定时任务（当前阶段足够） |

### 环境变量

| 变量 | 值 | 说明 |
|------|-----|------|
| `SCHEDULER_MODE` | `local` | 使用 TaskScheduler，跳过 Celery 检测 |
| `SCHEDULER_MODE` | `celery` | 强制使用 Celery（需部署 Worker + Beat） |
| `SCHEDULER_MODE` | `auto` | 自动检测 Celery 可用性（默认值） |

---

## 开发日志

### 2026-02-09

- **TaskScheduler 替代 Celery**：将 Celery Beat 的 29 个任务（合并后 26 个）全部迁移到 TaskScheduler
- **修复 `precompute_recommendations`**：`User.last_active` 字段不存在，改用 `UserTaskInteraction.interaction_time` 查询活跃用户
- **修复 `update_task_experts_bio`**：错误调用了 bio 更新，改为 `update_all_featured_task_experts_response_time`（更新 response_time / response_time_en）
- **优化 `main.py` 启动逻辑**：`SCHEDULER_MODE=local` 时直接跳过 Celery 检测，节省 ~10 秒启动时间
- **撰写本文档**：完整记录 26 个任务清单、自动转账设计方案、安全合规清单
- **识别架构风险**：单线程无补偿机制、Float 金额精度、防重复转账竞态条件、`confirmation_deadline` 不一致等问题
- **明确 #5 与 #12 边界**：#5 负责个别任务完成 + 自动转账，#12 独立负责活动级别过期检查，不合并

### 2026-02-09（续）— 自动转账功能实现

- **数据库迁移 `085`**：`escrow_amount` Float → DECIMAL(12,2)，消除浮点精度误差；新增 `ix_payment_transfer_auto_confirm_unique` 部分唯一索引防止重复自动转账
- **模型更新**：`models.py` 中 `Task.escrow_amount` 类型同步改为 `DECIMAL(12, 2)`
- **Phase 1 微调**：`auto_complete_expired_time_slot_tasks` 在标记任务完成时同步设置 `confirmation_deadline = max_end_time + 3 days`
- **Phase 2 实现**：新增 `send_auto_transfer_reminders()` — 对已完成但未确认的达人任务发送提醒（过期第1天、第2天各一次），复用 `confirmation_reminder_sent` 位掩码
- **Phase 3 实现**：新增 `auto_transfer_expired_tasks()` — 3 天后自动确认 + Stripe Transfer 转账给达人，含以下安全机制：
  - 退款/争议/冻结检查
  - 金额一致性校验（已转账总额 vs escrow_amount）
  - `SELECT ... FOR UPDATE SKIP LOCKED` 行级锁防并发
  - 唯一约束 `ix_payment_transfer_auto_confirm_unique` 防重复（IntegrityError 兜底）
  - 单次执行上限 20 笔（防大规模误转）
- **通知**：自动转账成功后同时通知发布者和达人（应用内 + 推送 + 聊天系统消息）
- **TaskScheduler 注册**：新增 4 个任务 —
  - `send_auto_transfer_reminders`（1小时），`auto_transfer_expired_tasks`（15分钟）
  - `auto_confirm_expired_tasks`（15分钟），`send_confirmation_reminders`（15分钟）
- **12 项代码审查修复**（上一轮）：DB 连接泄漏、Redis 数据丢失、失败重试、每日任务补偿、rollback、线程安全、健康检查、优先级、Prometheus import、耗时告警

### 待开发（按优先级）

| 优先级 | 任务 | 预估工作量 |
|--------|------|-----------|
| ~~P0~~ | ~~`escrow_amount` Float → DECIMAL 迁移~~ | ✅ 已完成 |
| ~~P0~~ | ~~Phase 3 自动转账核心逻辑实现~~ | ✅ 已完成 |
| ~~P0~~ | ~~Phase 2 确认提醒通知~~ | ✅ 已完成 |
| ~~P0~~ | ~~防重复转账唯一约束 + 行级锁~~ | ✅ 已完成 |
| ~~P1~~ | ~~调度器线程健康检查心跳~~ | ✅ 已完成 |
| ~~P1~~ | ~~每日任务补偿执行机制~~ | ✅ 已完成 |
| P2 | #13 增量更新改造（推荐系统/统计/浏览数） | 2-3h |
| P2 | 审计日志规范化（TaskAuditLog 模型统一） | 1h |
| P2 | `routers.py` 中 `escrow_amount = 0.0` 改为 `Decimal('0.00')` | 0.5h |
