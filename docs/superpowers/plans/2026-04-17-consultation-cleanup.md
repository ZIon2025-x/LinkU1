# 咨询聊天过期清理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复咨询占位 Task 的生命周期：状态联动 + 14 天不活跃自动关闭。

**Architecture:** 两部分改动：(1) 在 `expert_consultation_routes.py` 的 4 个状态变更点同步关闭咨询 Task 并发系统消息；(2) 在 `scheduled_tasks.py` 新增定时清理函数，由 `task_scheduler.py` 每小时调度。咨询 Task 使用 `closed` 状态（非 `cancelled`），保留消息列表可见性，但阻止新消息发送。

**Tech Stack:** Python, FastAPI, SQLAlchemy (sync for scheduled tasks, async for routes)

---

### Task 1: 状态联动 — reject/close/approve 时同步关闭咨询 Task

**Files:**
- Modify: `backend/app/expert_consultation_routes.py:601-603` (respond-negotiation reject)
- Modify: `backend/app/expert_consultation_routes.py:728-731` (close)
- Modify: `backend/app/expert_consultation_routes.py:967-974` (approve — 关闭旧咨询 Task)
- Modify: `backend/app/expert_consultation_routes.py:1057-1060` (reject)

**Why:** 当 ServiceApplication 状态变为 rejected/cancelled/approved 时，底层的咨询占位 Task 仍然停留在 `consulting`，变成孤儿。需要同步关闭。

- [ ] **Step 1: 添加辅助函数 `_close_consultation_task`**

在文件顶部（imports 之后、路由之前）添加一个复用的辅助函数，统一关闭咨询 Task 并发系统消息：

```python
async def _close_consultation_task(
    db: AsyncSession,
    application: "models.ServiceApplication",
    *,
    reason: str = "咨询已关闭",
    new_status: str = "closed",
):
    """关闭 ServiceApplication 关联的咨询占位 Task，并发送系统消息。

    仅当 Task 状态仍为 'consulting' 时才操作，保证幂等。
    """
    if not application.task_id:
        return
    task = await db.get(models.Task, application.task_id)
    if not task or task.status != "consulting":
        return
    task.status = new_status
    # 系统消息 — 与 flea_market_routes.py:4537 保持一致
    system_msg = models.Message(
        sender_id=None,
        receiver_id=task.taker_id if task.taker_id != application.applicant_id else task.poster_id,
        content=reason,
        task_id=task.id,
        message_type="system",
        conversation_type="task",
    )
    db.add(system_msg)
```

- [ ] **Step 2: `/respond-negotiation` reject 分支 (L601-603) — 添加关闭逻辑**

在 `application.status = "rejected"` 和 `application.rejected_at = get_utc_time()` 之后（L603 之后），添加：

```python
    elif action == "reject":
        application.status = "rejected"
        application.rejected_at = get_utc_time()
        # 同步关闭咨询占位 Task
        await _close_consultation_task(db, application, reason="协商已被拒绝")
```

- [ ] **Step 3: `/close` (L728-730) — 添加关闭逻辑**

在 `application.status = "cancelled"` 和 `application.updated_at = get_utc_time()` 之后（L729 之后），添加：

```python
    application.status = "cancelled"
    application.updated_at = get_utc_time()
    # 同步关闭咨询占位 Task
    await _close_consultation_task(db, application, reason="咨询已关闭", new_status="closed")
```

- [ ] **Step 4: `/approve` (L967-974) — 关闭旧咨询 Task**

在 approve 流程中，`application.task_id` 在 L970 被新 Task 覆盖。需要在覆盖之前保存旧 task_id 并关闭旧 Task。

在 `_approve_team_service_application` 函数中，L967 `application.status = "approved"` 之前，添加：

```python
    # 关闭旧的咨询占位 Task（task_id 即将被新 Task 覆盖）
    old_consultation_task_id = application.task_id
    if old_consultation_task_id:
        old_task = await db.get(models.Task, old_consultation_task_id)
        if old_task and old_task.status == "consulting":
            old_task.status = "closed"
            system_msg = models.Message(
                sender_id=None,
                receiver_id=old_task.taker_id if old_task.taker_id != application.applicant_id else old_task.poster_id,
                content="咨询已转为正式订单",
                task_id=old_task.id,
                message_type="system",
                conversation_type="task",
            )
            db.add(system_msg)
```

- [ ] **Step 5: `/reject` (L1057-1060) — 添加关闭逻辑**

在 `application.status = "rejected"` 之后（L1059 之后），添加：

```python
    application.status = "rejected"
    application.rejected_at = get_utc_time()
    application.updated_at = get_utc_time()
    # 同步关闭咨询占位 Task
    await _close_consultation_task(db, application, reason="申请已被拒绝")
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/expert_consultation_routes.py
git commit -m "fix: sync close consultation Task when ServiceApplication status changes"
```

---

### Task 2: 定时清理 — 14 天不活跃咨询自动关闭

**Files:**
- Modify: `backend/app/scheduled_tasks.py` (新增 `close_stale_consultations` 函数)
- Modify: `backend/app/task_scheduler.py` (注册定时任务)

- [ ] **Step 1: 在 `scheduled_tasks.py` 添加 `close_stale_consultations` 函数**

在 `check_expired_payment_tasks` 函数之后添加：

```python
def close_stale_consultations(db: Session, inactive_days: int = 14):
    """自动关闭超过 inactive_days 天不活跃的咨询占位任务。

    不活跃 = 该 Task 下最后一条消息时间距今超过阈值。
    无消息则以 Task.created_at 为准。
    """
    from sqlalchemy import select, func, and_, or_
    try:
        cutoff = get_utc_time() - timedelta(days=inactive_days)

        # 子查询: 每个 task 的最后消息时间
        last_msg_subq = (
            db.query(
                models.Message.task_id,
                func.max(models.Message.created_at).label("last_msg_at"),
            )
            .filter(models.Message.conversation_type == "task")
            .group_by(models.Message.task_id)
            .subquery()
        )

        # 主查询: consulting 状态 + consultation 来源 + 不活跃
        stale_tasks = (
            db.query(models.Task)
            .outerjoin(last_msg_subq, models.Task.id == last_msg_subq.c.task_id)
            .filter(
                models.Task.status == "consulting",
                models.Task.task_source.in_(["consultation", "flea_market_consultation"]),
                func.coalesce(last_msg_subq.c.last_msg_at, models.Task.created_at) < cutoff,
            )
            .all()
        )

        if not stale_tasks:
            return

        closed_count = 0
        for task in stale_tasks:
            task.status = "closed"

            # 系统消息
            receiver_id = task.taker_id or task.poster_id
            system_msg = models.Message(
                sender_id=None,
                receiver_id=receiver_id,
                content="咨询已自动关闭（14天未活跃）",
                task_id=task.id,
                message_type="system",
                conversation_type="task",
            )
            db.add(system_msg)

            # 同步关闭关联的 ServiceApplication
            if task.task_source == "consultation":
                app = db.execute(
                    select(models.ServiceApplication).where(
                        models.ServiceApplication.task_id == task.id
                    )
                ).scalar_one_or_none()
                if app and app.status in ("consulting", "negotiating"):
                    app.status = "cancelled"

            # 同步关闭关联的 FleaMarketPurchaseRequest
            elif task.task_source == "flea_market_consultation":
                pr = db.execute(
                    select(models.FleaMarketPurchaseRequest).where(
                        models.FleaMarketPurchaseRequest.task_id == task.id
                    )
                ).scalar_one_or_none()
                if pr and pr.status in ("consulting", "negotiating"):
                    pr.status = "cancelled"

            closed_count += 1

        db.commit()
        if closed_count > 0:
            logger.info(f"✅ 自动关闭 {closed_count} 个不活跃咨询任务")

    except Exception as e:
        db.rollback()
        logger.error(f"close_stale_consultations 失败: {e}", exc_info=True)
```

- [ ] **Step 2: 在 `task_scheduler.py` 注册定时任务**

在 `check_expired_payment_tasks` 注册块之后（约 L643），添加：

```python
    # 自动关闭不活跃咨询 - 每小时
    scheduler.register_task(
        'close_stale_consultations',
        with_db(close_stale_consultations),
        interval_seconds=3600,
        description="自动关闭超过14天不活跃的咨询占位任务"
    )
```

- [ ] **Step 3: 在 `task_scheduler.py` 的 import 块添加导入**

在现有的 `from app.scheduled_tasks import` 块中添加 `close_stale_consultations`。

- [ ] **Step 4: Commit**

```bash
git add backend/app/scheduled_tasks.py backend/app/task_scheduler.py
git commit -m "feat: add scheduled cleanup for stale consultation tasks (14-day TTL)"
```

---

### Task 3: 验证

- [ ] **Step 1: 启动后端确认无导入错误**

```bash
cd backend && python -c "from app.scheduled_tasks import close_stale_consultations; print('OK')"
cd backend && python -c "from app.task_scheduler import register_all_tasks; print('OK')"
```

- [ ] **Step 2: 检查现有积压数据量**

连接数据库查看当前有多少孤儿咨询 Task：

```sql
SELECT count(*) FROM tasks
WHERE status = 'consulting'
  AND task_source IN ('consultation', 'flea_market_consultation');
```

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: consultation lifecycle cleanup - sync close + 14-day auto-expire"
```
