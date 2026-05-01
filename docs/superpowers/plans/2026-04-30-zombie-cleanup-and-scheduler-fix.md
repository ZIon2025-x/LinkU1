# Zombie Cleanup + Scheduler Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drop two zombie task_expert tables, delete 115 lines of dead routes code, and properly wire 3 long-buried scheduled-reminder functions to Celery beat — without missing the full-stack consistency checks the v1 spec missed.

**Architecture:** Two independent phases. Phase A (zombie cleanup) is pure deletion: 1 migration + dead code removal. Phase B is "shipping a buried feature" — guarded by 5 full-stack gates (G1–G5) and a flood-risk dry-count (B6); only after all gates pass do we register beat schedules and observe linktest 72h before prod.

**Tech Stack:** PostgreSQL (Railway), FastAPI, SQLAlchemy, Celery + Celery Beat, Flutter (BLoC), Python 3.13.

**Spec:** `docs/superpowers/specs/2026-04-30-zombie-cleanup-and-scheduler-fix-design.md`

**User constraints to remember (from CLAUDE.md / memory):**
- 中文沟通；commit 直推 main，不建 feature 分支
- migration 必须先在 linktest DB 跑过、验证后再 push 代码（否则 Railway 自动部署会挂）
- 加 scheduled_tasks 必须同步加 Celery 包装 + beat_schedule

---

## File Structure

| 文件 | 操作 | 责任 |
|---|---|---|
| `backend/migrations/220_drop_zombie_task_expert_tables.sql` | 新建 | drop `task_expert_applications` + `task_expert_profile_update_requests` |
| `backend/app/models.py` | 修改 (lines 1549, 1596) | 更新两处注释为"已通过 migration 220 drop" |
| `backend/app/routers.py` | 修改 (lines 897-1011) | 删除 `_deprecated_get_public_task_experts` 整段（含上面注释掉的 decorator） |
| `backend/app/celery_tasks.py` | 修改（追加） | 加 3 个 Celery task wrapper：`send_deadline_reminders_task` / `send_payment_reminders_task` / `check_stale_disputes_task` |
| `backend/app/celery_app.py` | 修改 (`beat_schedule` 字典) | 加 5 条 beat entries |
| `backend/app/scheduled_tasks.py` | 修改 (lines 1786-1946 + 文件末尾) | 删除 `run_scheduled_tasks()` 函数 + `if __name__ == '__main__'` 入口 |
| `backend/app/main.py` | 修改 (lines 1417-1457) | 简化 fallback 分支，移除 `run_scheduled_tasks` 路径 |
| `backend/docs/TASK_SCHEDULER_GUIDE.md` | 修改 | 移除对 `run_scheduled_tasks` 的引用，加 5 条新 beat 任务说明 |
| `backend/migrations/221_add_task_deadline_index.sql` | 新建（**条件性**，仅 G5 gate 失败时） | 给 `tasks.deadline` 加 BTree 索引 |

**条件性补缺**（gate 失败时才需要）：
- 若 G2 失败：补 push notification template（具体文件 implementation 阶段定）
- 若 G3 失败：补 Flutter `NotificationBloc` / `NotificationItem` 对三个 type 的处理
- 若 G4 失败：补 `link2ur/lib/l10n/app_{en,zh,zh_Hant}.arb` 的提醒文案 key

---

## Phase A — Zombie 清理

### Task 1: 写 migration 220 + pg_dump 备份

**Files:**
- Create: `backend/migrations/220_drop_zombie_task_expert_tables.sql`

- [ ] **Step 1: 在 linktest DB 上备份这两张表（保险）**

```bash
# 用户需要在本地 shell 执行（要 linktest DB 连接信息）
pg_dump -h <linktest_host> -U <user> -d <db> \
  --table=task_expert_applications \
  --table=task_expert_profile_update_requests \
  -f /tmp/zombie_tables_backup_2026-04-30.sql
```

Expected: `/tmp/zombie_tables_backup_2026-04-30.sql` 文件 > 0 字节（即使表是空的也会有 schema dump）。

- [ ] **Step 2: 写 migration SQL**

```sql
-- backend/migrations/220_drop_zombie_task_expert_tables.sql
--
-- 删除 2026-04-09 task_expert_routes.py 移除后留下的两张 zombie 表。
-- 模型已删（见 models.py:1549, 1596 注释）；全 backend 零读写。
-- 备份见 /tmp/zombie_tables_backup_2026-04-30.sql。

DROP TABLE IF EXISTS task_expert_profile_update_requests CASCADE;
DROP TABLE IF EXISTS task_expert_applications CASCADE;
```

- [ ] **Step 3: 自查文件存在**

```bash
ls -la backend/migrations/220_drop_zombie_task_expert_tables.sql
```
Expected: 显示文件 + 字节数 > 0。

- [ ] **Step 4: 提交（仅 migration 文件）**

```bash
git add backend/migrations/220_drop_zombie_task_expert_tables.sql
git commit -m "feat(migrations): add 220 to drop zombie task_expert tables"
```

**注意：还不要 push。**Push 顺序在 Task 3。

---

### Task 2: 在 linktest DB 上执行 migration 220

- [ ] **Step 1: 连接到 linktest DB 并 dry-run 看看 EXPLAIN（确认表存在但空）**

```sql
-- linktest DB（用户在 Railway dashboard 或本地 psql 执行）
SELECT count(*) FROM task_expert_applications;
SELECT count(*) FROM task_expert_profile_update_requests;
```

Expected: 两条 SELECT 都返回 0（或低数字；如果 > 0 也无所谓——本来就要 drop）。如果**表不存在**，说明已被某次手动操作 drop 过，记录到 plan 报告里、跳到 Step 4。

- [ ] **Step 2: 跑 migration**

```sql
-- linktest DB
DROP TABLE IF EXISTS task_expert_profile_update_requests CASCADE;
DROP TABLE IF EXISTS task_expert_applications CASCADE;
```

Expected: 两条 `DROP TABLE` 各返回 `DROP TABLE` 或 `NOTICE: table does not exist, skipping`（IF EXISTS 兜底）。

- [ ] **Step 3: 验证表已消失**

```sql
\dt task_expert_applications
\dt task_expert_profile_update_requests
```

Expected: 两条 `\dt` 都返回 `Did not find any relation named "..."`。

- [ ] **Step 4: 在 plan 报告里记录**

把执行时间、执行人、Step 1-3 的输出粘进 implementation 报告（plan 里 § Implementation Log 一节，自己创建一个）。

---

### Task 3: 推 migration 220 到 main + Railway 自动部署 prod

- [ ] **Step 1: 同样的 SQL 在 prod DB 上跑（prod 表也要先备份）**

```bash
pg_dump -h <prod_host> -U <user> -d <db> \
  --table=task_expert_applications \
  --table=task_expert_profile_update_requests \
  -f /tmp/zombie_tables_prod_backup_2026-04-30.sql
```

```sql
-- prod DB
DROP TABLE IF EXISTS task_expert_profile_update_requests CASCADE;
DROP TABLE IF EXISTS task_expert_applications CASCADE;
```

Expected: 同 Task 2 Step 2-3，两表消失。

- [ ] **Step 2: Push commit 到 main**

```bash
git push origin main
```

- [ ] **Step 3: 监控 Railway 自动部署日志**

打开 Railway dashboard → backend service → 看 Deployments tab 最新一条。

Expected: 部署成功，启动日志无 `relation "task_expert_applications" does not exist` 之类错误（因为代码里 0 引用，本来就不会出错）。

- [ ] **Step 4: linktest 启动验证**

打开 `https://linktest.up.railway.app/health` 或类似 health endpoint。

Expected: HTTP 200。

---

### Task 4: 删 `routers.py` 里 115 行死函数 + 改 `models.py` 注释

**Files:**
- Modify: `backend/app/routers.py:897-1011`（删除整段 `_deprecated_get_public_task_experts` + 上面 3 行注释掉的 decorator）
- Modify: `backend/app/models.py:1549`（注释更新）
- Modify: `backend/app/models.py:1596`（注释更新）

- [ ] **Step 1: 再 grep 一次确认 0 调用方**

```bash
grep -rn "_deprecated_get_public_task_experts" backend/
```

Expected: 仅一行 — `backend/app/routers.py:901:def _deprecated_get_public_task_experts(`。任何其他命中 → 立即停止 plan，调研后续步骤。

- [ ] **Step 2: 删除 routers.py 第 897-1011 行**

用 Edit 工具，匹配以下 old_string：

```python
# 公开 API - 获取任务达人列表（已迁移到 task_expert_routes.py）
# @router.get("/task-experts")
# @measure_api_performance("get_task_experts")
# @cache_response(ttl=600, key_prefix="public_task_experts")
def _deprecated_get_public_task_experts(
```

…一直到第 1011 行的：
```python
        raise HTTPException(status_code=500, detail="获取任务达人列表失败")


```

整段（约 115 行）替换为空字符串（删除）。

- [ ] **Step 3: 改 models.py 第 1549 行的注释**

old_string:
```python
#   - 表 `task_expert_applications` 保留 (历史数据,不接收新写入),后续 migration 可 drop
```

new_string:
```python
#   - 表 `task_expert_applications` 已通过 migration 220 (2026-04-30) drop
```

- [ ] **Step 4: 改 models.py 第 1596 行的注释**

old_string:
```python
#   - 表 `task_expert_profile_update_requests` 保留 (历史数据),后续 migration 可 drop
```

new_string:
```python
#   - 表 `task_expert_profile_update_requests` 已通过 migration 220 (2026-04-30) drop
```

- [ ] **Step 5: 本地启动一下 backend 验证无 ImportError**

```bash
cd backend && python -c "from app.main import app; print('OK')"
```

Expected: 输出 `OK` 而不是 ImportError。

- [ ] **Step 6: Commit + push**

```bash
git add backend/app/routers.py backend/app/models.py
git commit -m "refactor: remove dead _deprecated_get_public_task_experts (115 lines) + update zombie table comments"
git push origin main
```

- [ ] **Step 7: linktest 启动验证**

监控 Railway 部署日志，确认无 ImportError 或启动 traceback。

---

## Phase B Gate — 全部 5 项必须通过才能继续

Phase B 不是"接 wrapper 上 cron"那么简单，而是上线一个被埋了几个月的功能。**任何 gate 不过 → 暂停 Phase B、把缺失项作为前置工作处理后再回来执行 Task 12+。**

每条 gate 的"证据"都要写到本 plan 文末的 § Implementation Log → § Gate Report 一节。

### Task 5: Gate G1 — 通知 type 字符串确认

- [ ] **Step 1: grep 三个函数实际写入 `notifications.type` 的值**

```bash
grep -n 'type=' backend/app/scheduled_tasks.py | grep -iE 'deadline|payment|dispute'
```

Expected output（已知；若有差异则记录差异）：
```
1134:                        models.Notification.type == "deadline_reminder",
1168:                            type="deadline_reminder",
1209:                            type="deadline_reminder",
1673:                        type="stale_dispute_alert",
1749:                        models.Notification.type == "payment_reminder",
```

- [ ] **Step 2: 再确认 send_payment_reminders 内的实际写入**

```bash
grep -nA 30 "def send_payment_reminders" backend/app/scheduled_tasks.py | head -50
```

注意：`send_payment_reminders` 调用 `send_payment_reminder_notification`（在 `app/task_notifications.py`），所以 `type` 字符串实际可能在那里。再 grep：

```bash
grep -n "type=" backend/app/task_notifications.py | grep -i payment
```

Expected: 找到 `type="payment_reminder"` 的写入。如果实际名字不同（如 `task_payment_reminder`），把**实际名**作为权威，记入 Gate Report。

- [ ] **Step 3: 锁定 3 个权威 type 字符串**

把 G2/G3/G4 要查的精确字符串写入 Gate Report：
```
deadline_reminder
payment_reminder       # （或 task_notifications.py 里的实际名）
stale_dispute_alert
```

- [ ] **Step 4: G1 判定**

PASS：3 个字符串都已确认；FAIL：任何 grep 命令找不到对应写入位置。

---

### Task 6: Gate G2 — Backend push template 注册情况

- [ ] **Step 1: grep push notification service 是否识别这三个 type**

```bash
grep -rn "deadline_reminder\|payment_reminder\|stale_dispute_alert" \
  backend/app/push_notification_service*.py \
  backend/app/task_notifications*.py \
  backend/app/notification_templates*.py 2>/dev/null
```

- [ ] **Step 2: 解读结果**

对每个 type，分类落到以下三档之一：
- ✅ **已注册**：在 `push_notification_service.py` 或 `task_notifications.py` 里有 template / 处理函数（如 `send_payment_reminder_notification` 已存在）
- ⚠️ **写入 DB 但未推送**：仅在 `crud.create_notification` 里出现，没有对应的 `send_push_notification` 调用
- ❌ **完全缺失**：grep 0 命中

- [ ] **Step 3: 已知现状（来自 spec 调研）**

- `deadline_reminder`：`scheduled_tasks.py:1178-1192` 直接调 `send_push_notification(notification_type='deadline_reminder', ...)` → 需要确认 `push_notification_service` 有对应模板
- `payment_reminder`：`task_notifications.py:send_payment_reminder_notification` 应该已封装好
- `stale_dispute_alert`：`scheduled_tasks.py:1670-1678` 仅调 `crud.create_notification`，**没有 push** → 这是已知空缺，需决策是补 push 还是只走站内通知

- [ ] **Step 4: G2 判定**

PASS：三类都明确知道走"站内通知"还是"站内+推送"，且代码已支持；FAIL：任何一类的 push template 没注册但又期望推送。

stale_dispute_alert 若决定**只发站内通知**（admin 通常在 web 后台看，无需 push），记入 Gate Report 视为 PASS。

---

### Task 7: Gate G3 — Flutter NotificationBloc / NotificationItem 对三类 type 的处理

- [ ] **Step 1: grep Flutter 端识别情况**

```bash
grep -rn 'deadline_reminder\|payment_reminder\|stale_dispute_alert' \
  link2ur/lib/features/notification/ \
  link2ur/lib/data/models/notification 2>/dev/null
```

- [ ] **Step 2: 检查 NotificationItem 的 type → 图标/路由映射**

```bash
grep -n "NotificationType\|notification_type\|switch.*type" link2ur/lib/features/notification/views/*.dart | head -30
```

读相关文件，确认每个 type 命中以下三处之一：
1. 图标映射（按 type 选 icon）
2. 跳转目标（点击通知 → 跳到 task_detail / dispute_detail）
3. fallback / "未知 type" 兜底（最次也要不崩溃）

- [ ] **Step 3: G3 判定**

PASS：三个 type 都有明确的图标 + 跳转处理；OR 有 generic fallback 能优雅渲染未知 type；FAIL：通知会让 UI 崩溃 / 跳到错误页。

如果只是缺图标不缺跳转，记 ⚠ 警告但视为 PASS（视觉小瑕疵，不阻断）。
如果点击通知会崩溃或跳到 404，FAIL。

`stale_dispute_alert` 是发给 admin 的，admin 用 web 后台不是 Flutter——所以 Flutter 端**不要求**处理它（前提是 G2 确认 stale_dispute_alert 不发到 user notification 列表里给普通用户看）。

---

### Task 8: Gate G4 — l10n 文案齐全

- [ ] **Step 1: 确认 backend 通知是发"硬编码字符串"还是"翻译 key"**

读 `scheduled_tasks.py:1162-1163` 看到：
```python
notification_content = f"任务「{task.title}」将在{time_text}后到期，请及时关注任务进度。"
notification_content_en = f"Task「{task.title}」will expire in {time_text}. Please pay attention to the task progress."
```

→ backend 直接把中英文字符串塞进 `notifications.content` / `notifications.content_en`。Flutter 端只需要根据用户语言读对应字段（`content` 或 `content_en`），不需要 l10n key。

- [ ] **Step 2: 确认 Flutter notification list 怎么渲染 content**

```bash
grep -n "content\|content_en\|notification.content" link2ur/lib/features/notification/views/*.dart | head
```

Expected: 找到根据当前 locale 选用 `content`（中文）或 `content_en`（英文）的代码。如果 Flutter 端只读 `content`（不区分语言），英文用户会看到中文——记为 ⚠ 警告。

- [ ] **Step 3: G4 判定**

PASS：backend 提供双语 content，Flutter 按 locale 读取；ZH_HANT（繁体）通常 fallback 到 zh，可接受；FAIL：发现某语言下完全没文案。

---

### Task 9: Gate G5 — `Task.deadline` 索引存在性

- [ ] **Step 1: grep migrations 看 deadline 索引**

```bash
grep -rn "CREATE INDEX.*deadline\|tasks_deadline\|ix_tasks_deadline" backend/migrations/
grep -n "Index.*deadline" backend/app/models.py
```

- [ ] **Step 2: 直接到 linktest DB 查实际索引**

```sql
\d tasks
```

或：
```sql
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'tasks' AND indexdef LIKE '%deadline%';
```

Expected: 至少一条索引含 `deadline` 列（不一定要单独索引，复合索引含 `(status, deadline)` 也可）。

- [ ] **Step 3: 跑 EXPLAIN 看实际查询计划**

```sql
EXPLAIN
SELECT * FROM tasks
WHERE status = 'in_progress'
  AND deadline IS NOT NULL
  AND deadline >= now() + interval '23h 55min'
  AND deadline <= now() + interval '24h 5min'
  AND is_flexible != 1;
```

Expected: `Index Scan` 或 `Bitmap Index Scan`，**不是** `Seq Scan`（除非表很小）。

- [ ] **Step 4: G5 判定**

PASS：EXPLAIN 显示 Index Scan；
FAIL：Seq Scan 且表 > 10K 行 → 必须先发 migration 221 加索引：

```sql
-- 仅 G5 fail 时新建：backend/migrations/221_add_task_deadline_index.sql
CREATE INDEX IF NOT EXISTS ix_tasks_status_deadline
  ON tasks (status, deadline)
  WHERE deadline IS NOT NULL;
```

如果需要 migration 221，把它单独走 Task 1-3 那种"先 linktest 再 prod"的流程，再回来继续。

---

### Task 10: B6 通知洪水 dry-count

- [ ] **Step 1: linktest DB 执行四个窗口的 dry-count**

```sql
-- 24h deadline reminders
SELECT count(*) AS cnt_deadline_24h FROM tasks
WHERE status='in_progress'
  AND is_flexible != 1
  AND deadline BETWEEN now() + interval '23h 55min' AND now() + interval '24h 5min';

-- 6h deadline reminders
SELECT count(*) AS cnt_deadline_6h FROM tasks
WHERE status='in_progress'
  AND is_flexible != 1
  AND deadline BETWEEN now() + interval '5h 55min' AND now() + interval '6h 5min';

-- 6h payment reminders
SELECT count(*) AS cnt_payment_6h FROM tasks
WHERE status='pending_payment'
  AND is_paid = 0
  AND payment_expires_at BETWEEN now() + interval '5h 55min' AND now() + interval '6h 5min';

-- 1h payment reminders
SELECT count(*) AS cnt_payment_1h FROM tasks
WHERE status='pending_payment'
  AND is_paid = 0
  AND payment_expires_at BETWEEN now() + interval '55min' AND now() + interval '1h 5min';

-- stale disputes（关键）
SELECT count(*) AS cnt_stale_disputes FROM task_disputes
WHERE status='pending'
  AND created_at < now() - interval '7 days';

-- admin 数量（用于估算 stale_dispute 通知爆量）
SELECT count(*) AS cnt_admins FROM admin_users WHERE is_active = true;
```

- [ ] **Step 2: 重复在 prod DB 执行**

同 Step 1 的 6 条 SELECT，记录到 Gate Report。

- [ ] **Step 3: B6 判定**

按 spec §3.B6 阈值：

| 指标 | ≤ 阈值 | 处置 |
|---|---|---|
| `cnt_deadline_*` / `cnt_payment_*` | 任意值 | PASS（窗口窄+1h 去重保护，不算洪水）|
| `cnt_stale_disputes` | ≤ 5 | PASS |
| `cnt_stale_disputes` | 6–30 | 评审 PASS：与用户确认 admin 接受 N×M 条通知初始化代价 |
| `cnt_stale_disputes` | > 30 | **FAIL**：暂停 Phase B 启用，另开 spec 给 dispute 加去重字段 |

把决策写进 Gate Report。

---

### Task 11: Gate 总评 + Go/No-Go 决策

- [ ] **Step 1: 汇总 G1–G5 + B6 的判定结果**

填写 Gate Report 的总表：

| Gate | 状态 | 备注 |
|---|---|---|
| G1 通知 type 字符串 | PASS / FAIL | … |
| G2 push template | PASS / FAIL / ⚠ | … |
| G3 Flutter 处理 | PASS / FAIL / ⚠ | … |
| G4 l10n 文案 | PASS / FAIL / ⚠ | … |
| G5 索引 | PASS / FAIL | (含 migration 221 若需要) |
| B6 dry-count | PASS / FAIL | (含决策结果) |

- [ ] **Step 2: 决策**

- 全 PASS（含可接受的 ⚠）→ 继续 Task 12
- 任何 FAIL → 列出"补缺工作"清单，决定：
  - (a) 在本 plan 内补完（追加 Task 11.x）
  - (b) 或暂停 Phase B、把补缺作为新 spec → 单独排期

把决策记入 Implementation Log。

- [ ] **Step 3: 用户审批**

向用户报告 Gate Report 结果 + 决策建议，等用户确认后再进 Task 12。

---

## Phase B 主体 — Celery 接入（Gate 全过后）

### Task 12: 写 `send_deadline_reminders_task` Celery wrapper

**Files:**
- Modify: `backend/app/celery_tasks.py`（追加，参照已有 `update_featured_task_experts_response_time_task` 模式）

- [ ] **Step 1: 找一个合适的位置追加（如文件末尾或同类任务附近）**

```bash
grep -n "@celery_app.task" backend/app/celery_tasks.py | tail -5
```

记录最后一个 `@celery_app.task` decorator 的行号（用作 anchor）。

- [ ] **Step 2: 加 wrapper（在 anchor 后追加）**

```python
    @celery_app.task(
        name='app.celery_tasks.send_deadline_reminders_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60,
    )
    def send_deadline_reminders_task(self, hours_before: int):
        """发送任务截止日期提醒 - Celery 任务包装。

        hours_before 由 beat_schedule 通过 kwargs 传入（24/6 两档）。
        函数内部用 ±5min 时间窗 + 1h 去重，安全地每 10 分钟运行一次。
        """
        start_time = time.time()
        task_name = f'send_deadline_reminders_task_{hours_before}'
        logger.info(f"🔄 开始执行定时任务: {task_name}")
        db = SessionLocal()
        try:
            from app.scheduled_tasks import send_deadline_reminders
            send_deadline_reminders(db, hours_before=hours_before)
            duration = time.time() - start_time
            logger.info(f"{task_name} 完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "hours_before": hours_before}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"{task_name} 失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
```

注意：模板中 `_record_task_metrics` / `SessionLocal` / `time` / `logger` 是文件已有 import（参考已有任务）。

- [ ] **Step 3: 本地 import 检查**

```bash
cd backend && python -c "from app.celery_tasks import send_deadline_reminders_task; print('OK')"
```

Expected: 输出 `OK`，无 ImportError。如果失败，检查 indent（注意已有 wrapper 都在 `if/while/else` 块内 → 看 anchor 上下文，indent 跟随）。

- [ ] **Step 4: 不要 commit，等 Task 13/14 一起。**

---

### Task 13: 写 `send_payment_reminders_task` Celery wrapper

**Files:**
- Modify: `backend/app/celery_tasks.py`（追加，紧跟 Task 12 加的 wrapper 之后）

- [ ] **Step 1: 加 wrapper**

```python
    @celery_app.task(
        name='app.celery_tasks.send_payment_reminders_task',
        bind=True,
        max_retries=3,
        default_retry_delay=60,
    )
    def send_payment_reminders_task(self, hours_before: int):
        """发送支付到期前提醒 - Celery 任务包装。

        hours_before 由 beat_schedule 通过 kwargs 传入（6/1 两档）。
        函数内部用 ±5min 时间窗 + 1h 去重。
        """
        start_time = time.time()
        task_name = f'send_payment_reminders_task_{hours_before}'
        logger.info(f"🔄 开始执行定时任务: {task_name}")
        db = SessionLocal()
        try:
            from app.scheduled_tasks import send_payment_reminders
            send_payment_reminders(db, hours_before=hours_before)
            duration = time.time() - start_time
            logger.info(f"{task_name} 完成 (耗时: {duration:.2f}秒)")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "hours_before": hours_before}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"{task_name} 失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            if self.request.retries < self.max_retries:
                logger.info(f"任务将重试 ({self.request.retries + 1}/{self.max_retries})")
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
```

- [ ] **Step 2: 本地 import 检查**

```bash
cd backend && python -c "from app.celery_tasks import send_payment_reminders_task; print('OK')"
```

Expected: `OK`。

---

### Task 14: 写 `check_stale_disputes_task` Celery wrapper

**Files:**
- Modify: `backend/app/celery_tasks.py`（追加，紧跟 Task 13）

- [ ] **Step 1: 加 wrapper**

```python
    @celery_app.task(
        name='app.celery_tasks.check_stale_disputes_task',
        bind=True,
        max_retries=2,
        default_retry_delay=300,
    )
    def check_stale_disputes_task(self, days: int = 7):
        """检查长期未处理争议 - Celery 任务包装。

        每天跑一次（凌晨 2:20）。函数无去重保护——首次启用前必须做 dry-count
        见 spec §3.B6。
        """
        start_time = time.time()
        task_name = 'check_stale_disputes_task'
        logger.info(f"🔄 开始执行定时任务: {task_name} (days={days})")
        db = SessionLocal()
        try:
            from app.scheduled_tasks import check_stale_disputes
            result = check_stale_disputes(db, days=days)
            duration = time.time() - start_time
            logger.info(f"{task_name} 完成 (耗时: {duration:.2f}秒, 结果: {result})")
            _record_task_metrics(task_name, "success", duration)
            return {"status": "success", "result": result}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"{task_name} 失败: {e}", exc_info=True)
            _record_task_metrics(task_name, "error", duration)
            if self.request.retries < self.max_retries:
                raise self.retry(exc=e)
            raise
        finally:
            db.close()
```

- [ ] **Step 2: 本地 import 检查**

```bash
cd backend && python -c "from app.celery_tasks import check_stale_disputes_task; print('OK')"
```

Expected: `OK`。

---

### Task 15: 删 `run_scheduled_tasks()` 函数

**Files:**
- Modify: `backend/app/scheduled_tasks.py`（删 lines 1786-1946 + 文件末尾 `if __name__ == '__main__'` 入口）

- [ ] **Step 1: 用 Edit 工具删除函数体**

old_string（精确匹配 line 1786 起的函数定义直到 1946 闭合）：参照实际文件内容（前面已 Read 过 line 1786-1946）。

new_string：空字符串（彻底删除）。

- [ ] **Step 2: 删 文件末尾 `if __name__ == '__main__'` 入口**

```bash
grep -n "if __name__" backend/app/scheduled_tasks.py
```

Expected: 找到 `if __name__ == '__main__': run_scheduled_tasks()`（约 line 2777）。

用 Edit 工具替换：

old_string:
```python
if __name__ == '__main__':
    run_scheduled_tasks()
```

new_string: 空字符串。

- [ ] **Step 3: 本地启动检查**

```bash
cd backend && python -c "import app.scheduled_tasks; print('OK')"
```

Expected: `OK`。

- [ ] **Step 4: 确认 grep 0 残留**

```bash
grep -n "run_scheduled_tasks" backend/app/scheduled_tasks.py
```

Expected: 0 命中。

---

### Task 16: 简化 `main.py` fallback 分支

**Files:**
- Modify: `backend/app/main.py:1417-1457`

- [ ] **Step 1: 用 Edit 替换整个 fallback 块**

old_string（参照前面 Read 看到的 1417-1457 行内容，精确匹配）：

```python
        # 在迁移完成后启动 TaskScheduler，确保所有列已存在
        if celery_available:
            pass  # Celery 可用，不启动 TaskScheduler
        else:
            logger.info("📋 启动 TaskScheduler 作为备用调度器...")
            try:
                from app.task_scheduler import init_scheduler
                scheduler = init_scheduler()
                scheduler.start()
                logger.info("✅ 细粒度定时任务调度器（TaskScheduler）已启动（备用方案）")
            except Exception as e:
                logger.error(f"❌ 启动任务调度器失败，回退到旧方案: {e}", exc_info=True)
                from app.scheduled_tasks import run_scheduled_tasks

                def run_tasks_periodically():
                    """每5分钟执行一次定时任务（回退方案）"""
                    global _shutdown_flag
                    from app.state import is_app_shutting_down

                    while not _shutdown_flag and not is_app_shutting_down():
                        try:
                            run_scheduled_tasks()
                        except Exception as e:
                            error_str = str(e)
                            if is_app_shutting_down() and (
                                "Event loop is closed" in error_str
                                or "loop is closed" in error_str
                                or "attached to a different loop" in error_str
                            ):
                                logger.debug(f"定时任务在关闭时跳过: {e}")
                                break
                            logger.error(f"定时任务执行失败: {e}", exc_info=True)

                        for _ in range(300):  # 5分钟 = 300秒
                            if _shutdown_flag or is_app_shutting_down():
                                break
                            time.sleep(1)

                scheduler_thread = threading.Thread(target=run_tasks_periodically, daemon=True)
                scheduler_thread.start()
                logger.info("✅ 定时任务已启动（回退方案，每5分钟执行一次）")
```

new_string:

```python
        # 在迁移完成后启动 TaskScheduler，确保所有列已存在
        if celery_available:
            pass  # Celery 是主调度器
        else:
            logger.info("📋 启动 TaskScheduler 作为备用调度器...")
            from app.task_scheduler import init_scheduler
            scheduler = init_scheduler()
            scheduler.start()
            logger.info("✅ TaskScheduler 已启动")
```

如果 TaskScheduler 启动失败，让异常向上抛、应用启动失败——明确比静默回退假跑好。

- [ ] **Step 2: 检查 `threading` / `time` import 还有没有别处用**

```bash
grep -n "^import threading\|^from threading\|import time$" backend/app/main.py
grep -n "threading\.\|time\." backend/app/main.py | head -10
```

如果 `threading` / `time` 在文件其他地方还在用（很可能在用），保留 import；若**没人用了**，连同 import 一起删。

- [ ] **Step 3: 本地启动检查**

```bash
cd backend && python -c "from app.main import app; print('OK')"
```

Expected: `OK`，无 ImportError、SyntaxError。

---

### Task 17: 更新 `TASK_SCHEDULER_GUIDE.md` 文档

**Files:**
- Modify: `backend/docs/TASK_SCHEDULER_GUIDE.md`

- [ ] **Step 1: grep 文档里对 `run_scheduled_tasks` 的引用**

```bash
grep -n "run_scheduled_tasks" backend/docs/TASK_SCHEDULER_GUIDE.md
```

- [ ] **Step 2: 用 Edit 清理这些引用**

把每处涉及 `run_scheduled_tasks` 的描述改成"已移除（2026-04-30 整合到 Celery beat）"或直接删除该段。具体改动以 grep 结果为准（implementation 阶段执行时阅读上下文调整）。

- [ ] **Step 3: 在适当位置加新 5 条 beat 任务的说明**

在文档的"定时任务列表"或"Beat schedule"章节加一段（找到合适位置插入）：

```markdown
### 提醒/兜底任务（2026-04-30 接入）

- `send-deadline-reminders-24h` / `send-deadline-reminders-6h`：每 10 分钟扫一次未来 24h±5min / 6h±5min 内截止的进行中任务，发提醒；±5min 窗口 + 1h 去重。
- `send-payment-reminders-6h` / `send-payment-reminders-1h`：每 10 分钟扫一次未来 6h±5min / 1h±5min 内支付到期的待支付任务，发提醒。
- `check-stale-disputes`：每天 02:20 检查 7 天未处理的 pending dispute 并通知所有 admin。
```

---

### Task 18: 提交 wrapper-only commit + push + 验证 linktest（**B2 不写**）

**关键：本 commit 只含 wrapper 代码 + 删 fallback + 改 docs，不含 beat_schedule 改动。**

- [ ] **Step 1: 检查暂存区不含 `celery_app.py`**

```bash
git status
```

应该看到 modified：
- `backend/app/celery_tasks.py`（3 个 wrapper）
- `backend/app/scheduled_tasks.py`（删 run_scheduled_tasks）
- `backend/app/main.py`（简化 fallback）
- `backend/docs/TASK_SCHEDULER_GUIDE.md`（更新 docs）

**不应该**有 `backend/app/celery_app.py`。

- [ ] **Step 2: Commit**

```bash
git add backend/app/celery_tasks.py backend/app/scheduled_tasks.py backend/app/main.py backend/docs/TASK_SCHEDULER_GUIDE.md
git commit -m "refactor(scheduler): add 3 Celery wrappers (deadline/payment reminders + stale disputes), remove deprecated run_scheduled_tasks fallback"
git push origin main
```

- [ ] **Step 3: 监控 Railway linktest 部署**

看 Railway dashboard linktest service。

Expected: 部署成功；启动日志无 ImportError；Celery worker 日志能看到新任务被注册（即使还没被调度，worker 启动时也会列出已知 task names）。

```
# 在 linktest worker 日志里搜索（任何 Railway logs UI 都支持搜索）：
send_deadline_reminders_task
send_payment_reminders_task
check_stale_disputes_task
```

Expected: 能搜到这些 task 名（来自 worker 启动时的 task registry）。

- [ ] **Step 4: 用 Celery inspect 验证 worker 注册了 task**

如果 Railway 提供 shell 接入：
```bash
celery -A app.celery_app inspect registered
```

Expected: 输出包含三个新 task name。

---

### Task 19: 注册 5 条 beat_schedule（**Gate 已过 + Task 18 已部署稳定后**）

**Files:**
- Modify: `backend/app/celery_app.py`（在 `beat_schedule` 字典末尾追加）

- [ ] **Step 1: 在 `celery_app.conf.beat_schedule` 字典末尾追加 5 条**

找到 `beat_schedule = {` 块的末尾（spec §3.B2 已给定）。在最后一个 `}` 闭合大括号之前插入：

```python
    # ========== 提醒/兜底任务（2026-04-30 接入，详见 spec 2026-04-30-zombie-cleanup-and-scheduler-fix-design.md）==========

    # 任务截止提醒：24h / 6h 两档；每 10 分钟扫窗口（函数内 ±5min + 1h 去重）
    'send-deadline-reminders-24h': {
        'task': 'app.celery_tasks.send_deadline_reminders_task',
        'schedule': crontab(minute='*/10'),
        'kwargs': {'hours_before': 24},
    },
    'send-deadline-reminders-6h': {
        'task': 'app.celery_tasks.send_deadline_reminders_task',
        'schedule': crontab(minute='*/10'),
        'kwargs': {'hours_before': 6},
    },

    # 支付到期前提醒：6h / 1h 两档；每 10 分钟
    'send-payment-reminders-6h': {
        'task': 'app.celery_tasks.send_payment_reminders_task',
        'schedule': crontab(minute='*/10'),
        'kwargs': {'hours_before': 6},
    },
    'send-payment-reminders-1h': {
        'task': 'app.celery_tasks.send_payment_reminders_task',
        'schedule': crontab(minute='*/10'),
        'kwargs': {'hours_before': 1},
    },

    # 争议超时检查：每天凌晨 02:20（与其他 daily 任务错峰）
    'check-stale-disputes': {
        'task': 'app.celery_tasks.check_stale_disputes_task',
        'schedule': crontab(hour=2, minute=20),
        'kwargs': {'days': 7},
    },
```

- [ ] **Step 2: 本地 import 检查（确认语法）**

```bash
cd backend && python -c "from app.celery_app import celery_app; print(len(celery_app.conf.beat_schedule), 'beat entries')"
```

Expected: 数字比之前多 5（原本 53 → 58）。

- [ ] **Step 3: Commit + push**

```bash
git add backend/app/celery_app.py
git commit -m "feat(scheduler): register 5 beat schedules for deadline/payment reminders + stale disputes"
git push origin main
```

- [ ] **Step 4: 监控 linktest 部署 + Celery beat 日志**

Railway linktest beat service（`celery -A app.celery_app beat`）启动后日志应显示：
```
Scheduler: Sending due task send-deadline-reminders-24h
Scheduler: Sending due task send-deadline-reminders-6h
Scheduler: Sending due task send-payment-reminders-6h
Scheduler: Sending due task send-payment-reminders-1h
Scheduler: Sending due task check-stale-disputes
```

不一定立刻全看到（需要等 cron 时刻），但 10 分钟内 4 个 reminder 都该被触发一次。

---

### Task 20: linktest 72h 观察期

- [ ] **Step 1: 立刻检查（commit 后 15 分钟内）**

linktest beat 日志：
- 4 个 reminder 都被 `Sending due task` 触发了至少一次

linktest worker 日志：
- 4 个 reminder 都执行成功（找 `🔄 开始执行定时任务: send_deadline_reminders_task_24` / `_6` / `payment_*_6` / `_1`）
- 无 traceback

linktest DB:
```sql
-- 抽查最近 1 小时是否有新通知（如果有命中窗口的 task）
SELECT type, count(*) FROM notifications
WHERE type IN ('deadline_reminder', 'payment_reminder')
  AND created_at > now() - interval '1 hour'
GROUP BY type;
```

如果 0 行——可能是当前没 task 落在窗口里（正常），或 worker 报错（需查日志）。

- [ ] **Step 2: 24h 检查点**

```sql
-- 24h 内有多少新通知
SELECT type, count(*) FROM notifications
WHERE type IN ('deadline_reminder', 'payment_reminder')
  AND created_at > now() - interval '24 hours'
GROUP BY type;
```

Expected: 至少各 1 条。如果某 type 完全是 0，调查（可能 G2 漏检测了什么）。

- [ ] **Step 3: 48h 检查点**

```sql
-- check_stale_disputes 应该已经跑过两次（凌晨 02:20）
-- 看 admin 收到的 stale_dispute_alert 通知数
SELECT user_id, count(*) FROM notifications
WHERE type = 'stale_dispute_alert'
  AND created_at > now() - interval '48 hours'
GROUP BY user_id;
```

Expected: 通知数 = `dry_count_stale_disputes × 2 (天) × cnt_admins`（如果 dry-count 是 5，admins 是 3，应该是 30 条）。如果差距大，调查。

- [ ] **Step 4: 72h 检查点 + EXPLAIN 验证**

```sql
EXPLAIN ANALYZE
SELECT * FROM tasks
WHERE status = 'in_progress'
  AND deadline IS NOT NULL
  AND deadline >= now() + interval '23h 55min'
  AND deadline <= now() + interval '24h 5min'
  AND is_flexible != 1;
```

Expected: `Index Scan` 而不是 `Seq Scan`，total time < 100ms。

- [ ] **Step 5: 找一个测试用户/账号在 Flutter 端实际收到通知**

这步是 spec §6 验收的 "Flutter 端实际看到通知"。准备一个测试 task，把 deadline 设成"未来 24h ± 5min" 的某点，等下一个 :*0 分钟周期，应该看到推送。

如果 Flutter 端没收到：
- 检查 G2/G3 的 Gate Report 看是否漏了 push 部分
- 检查 push token 是否注册（可能与本 plan 无关）

记录结果到 Implementation Log。

- [ ] **Step 6: 决策：上 prod or hold**

- 72h 内全绿 + Flutter 收到通知 → 进 Task 21
- 任一条不通过 → 调查根因，修复后继续观察 24-48h

---

### Task 21: prod 启用（Railway 自动部署，linktest 已 72h 验证后）

**注意：Railway 通常 main 分支 push 同时部署 linktest + prod。如果 Task 19 push main 时 linktest 和 prod 都已经部署，那 prod 实际上已经在跑 72h 了，本任务是"补做 prod 验证"。**

- [ ] **Step 1: 确认 prod 已经收到 commit 19**

```bash
git log --oneline -3 origin/main
# 看 commit hash 与 prod 部署版本是否一致
```

如果 Railway 把 linktest 和 prod 放在同一分支同时部署：commit 19 push 时 prod 也立刻收到了 → 跳到 Step 2。

如果有 staging gate（main → linktest，需手动 promote 到 prod）：现在做 promote。

- [ ] **Step 2: prod beat / worker 日志立即检查**

同 Task 20 Step 1，确认 prod 也跑起来了。

- [ ] **Step 3: prod DB 抽查**

```sql
-- prod
SELECT type, count(*) FROM notifications
WHERE type IN ('deadline_reminder', 'payment_reminder')
  AND created_at > now() - interval '24 hours'
GROUP BY type;
```

---

### Task 22: prod 48h 观察 + 验收

- [ ] **Step 1: 验收清单逐条勾选（spec §6）**

A 部分：
- [ ] `\dt task_expert_applications` / `task_expert_profile_update_requests` 在 prod 都返回 "Did not find any relation"
- [ ] grep `_deprecated_get_public_task_experts` 全 repo 0 命中
- [ ] linktest + prod 启动日志无 ImportError

B-gate：
- [ ] §3.B0 G1-G5 全部留下证据，归档到 Gate Report
- [ ] §3.B6 dry-count 数字记入 plan，stale_disputes count ≤ 30 或已有处置方案

B-enable（commit 19 后 72h linktest）：
- [ ] grep `run_scheduled_tasks` 全 repo 0 命中（除 git history）
- [ ] `celery inspect scheduled` 看到 5 条新 beat 任务
- [ ] linktest 72h 内 `notifications` 表查到至少 1 条 `deadline_reminder` + 1 条 `payment_reminder`
- [ ] 真实/测试账号在 Flutter 端实际看到通知
- [ ] EXPLAIN 验证两个 reminder 查询走索引

prod 48h（commit 21 后）：
- [ ] prod `notifications` 表新增三类 type 记录
- [ ] 无 admin 收到 stale_dispute_alert 洪水（>10 条/天单 admin）
- [ ] 错误日志不显著上升（对比启用前 7 天均值）

- [ ] **Step 2: 把 spec 状态从 "design draft v2" 改为 "implemented"**

在 spec 文件顶部状态行加：
```markdown
**状态**: implemented (2026-MM-DD by Ryan)
```

- [ ] **Step 3: 发完成报告给用户**

简短总结：Phase A 删了 X 行，Phase B 接了 5 条 beat，linktest/prod 总共发出了 N 条提醒，无报错。

---

## Implementation Log

执行实录（2026-04-30 ~ 2026-05-01，linktest 全程参与，prod 暂未启用）。

### A 部分执行记录

- **Task 1 写 migration 220**（commits `f699ad1f0` initial + `3e6ef908f` polish）
  - polish 包括：加 `BEGIN; / COMMIT;` 事务包装、加 spec/plan 路径引用、用 symbol 替代行号、加 CASCADE deliberate 注释（quality reviewer 反馈采纳）
- **Task 2 linktest 跑 migration 220**：自动跑（`db_migrations.py:491` 启动时调用 `run_migrations`），耗时 23ms，0 失败。日志摘录：
  ```
  [INFO] 🔄 执行迁移: 220_drop_zombie_task_expert_tables.sql
  [INFO] ✅ 迁移执行成功: 220_drop_zombie_task_expert_tables.sql (耗时: 23ms)
  [INFO] 迁移完成: 1 个已执行, 223 个已跳过, 0 个失败
  ```
- **Task 3 prod 跑 migration**：**未启用**——用户决定 prod 升级时机自定。Railway 不会让 prod 自动跟 main，需要 manual promote。
- **Task 4 删 `_deprecated_get_public_task_experts` + 改 model.py 注释**（commits `d663a1799` 主体 + `79517618f` orphan import 清理）
  - 主体删 117 行函数 + 4 行 commented decorator + 改两处注释
  - quality review 发现删除引入 `Query` / `or_` / `func` / `select` 三个 orphan import + 多余空行 → 后续清理 commit
  - 验证：`python -c "from app.main import app"` 持续 OK

### Gate Report (Task 5-11)

- **G1 通知 type 字符串** ✅ PASS（精确字串 verbatim 确认）
  - `deadline_reminder` — `scheduled_tasks.py:1168, 1183, 1209`
  - `payment_reminder` — `task_notifications.py:1639, 1652`（实际写入由 `send_payment_reminder_notification` 完成）
  - `stale_dispute_alert` — `scheduled_tasks.py:1673`
- **G2 push template** ❌ FAIL → 已 fix
  - `deadline_reminder` ✅ template 在 `push_notification_templates.py:435-443`
  - `payment_reminder` ❌ **完全缺失** → fix in commit `3a87dfa16`（加 12 行新 template 模仿 `deadline_reminder` 形态，`{task_title}` + `{hours_remaining}` 两个 placeholder 都在 caller `template_vars` 里）
  - `stale_dispute_alert` ⚠️ DB-only（无 push）— 设计如此，admin 走 web 后台，无需 push
- **G3 Flutter NotificationBloc/Item** ✅ PASS
  - `deadline_reminder` + `payment_reminder` 都在 `notification_list_view.dart:443-454` tap-handler switch 里命中、跳 `/tasks/{id}`；图标走 default fallback `Icons.notifications`（不崩，但没专属图标——可后续 polish）
  - `stale_dispute_alert` Flutter 不接收（admin-only）→ N/A
- **G4 l10n 覆盖** ✅ PASS
  - backend 直接把双语文本写进 `notifications.content` + `notifications.content_en`；Flutter 按 locale 选用（`localized_string.dart:16` 用 `languageCode.startsWith('zh')` 判断）
  - zh_Hant 自然 fallback 到 zh，因为 backend 没第三列；本来就只有两个选项
- **G5 `Task.deadline` 索引** ✅ PASS
  - `ix_tasks_deadline`（单列）+ `ix_tasks_status_deadline`（复合）+ `idx_tasks_status_deadline`（filtered for `status IN ('open','taken')`）
  - `payment_expires_at` 也有 migration 058 的 3 个 filtered 索引，覆盖完整
- **G6 prod vs linktest 调度器**（spec 阶段新加的 gate）⚠️ CONDITIONAL → 已查清并采纳分支策略
  - `celery_available` 由 `main.py:1153, 1163` 通过 `celery_app.control.inspect().ping()` 检测 worker 在线
  - **linktest 没 Celery worker** → web service 启动 TaskScheduler 兜底 → 我们加的 5 条 beat **永远不在 linktest 触发**
  - **prod 有独立 Celery worker + beat service** → 5 条 beat 上 prod 后会真的触发
  - 决策：放弃"linktest 72h 观察"原计划（无意义），改成"linktest 验证 import / 启动 OK 即可，beat 触发在 prod 直接灰度观察"
- **B6 dry-count** ✅ PASS（关键值 `stale_disputes_count = 0`）
  - prod DB 跑 6 个窗口/计数：
    - `deadline_24h_window` = 0
    - `deadline_6h_window` = 0
    - `payment_6h_window` = 0
    - `payment_1h_window` = 0
    - `stale_disputes_count` = 0  ← 关键，无积压 = 无洪水
    - `active_admins` = (Railway GUI 返回异常 0 行；不重要，因为 stale_disputes = 0)
  - 决策：第一次启用 cron 会全空扫描，**零通知发出**，零洪水风险

**Gate 总评**：6 项 gate 全部通过（含 G2 修复后），可以进 Phase B 主体。

### Phase B 执行记录

- **G2 fix commit `3a87dfa16`** — 在 `celery_tasks.py` 的 wrapper 之前先补 `payment_reminder` push template（12 行），消除 G2 阻断
- **Task 12-17 一次性 commit `5d4129bff`**（plan 提的 wrapper-only commit）— 4 个文件，+120 / -206：
  - `celery_tasks.py` 加 3 个 wrapper（`send_deadline_reminders_task` / `send_payment_reminders_task` / `check_stale_disputes_task`），都嵌套在 `if CELERY_AVAILABLE:` 块内、4 空格缩进
  - `scheduled_tasks.py` 删 `run_scheduled_tasks()` 函数 + 文件末尾 `if __name__ == '__main__'` 入口（合计 -169 行）
  - `main.py:1417-1425` 简化 fallback：从 try/except + 5 分钟轮询线程降为 `if celery_available: pass else: TaskScheduler 启动并让异常自然抛出`
  - `TASK_SCHEDULER_GUIDE.md` 加历史标注 + 新 5 条 beat 说明
  - 双审通过；唯一 quality minor（`check_stale_disputes_task` 缺一条 retry log 行）用户决定不修
- **Task 19 commit `959b5d7e4`**（beat-register） — 在 `celery_app.conf.beat_schedule` 末尾加 5 条 entries：
  - `send-deadline-reminders-{24h,6h}` 每 10 分钟（`crontab(minute='*/10')`）
  - `send-payment-reminders-{6h,1h}` 每 10 分钟
  - `check-stale-disputes` 每天 02:20（与现有 daily 任务错峰，确认 02:00/02:05/02:10/02:15/02:30 已占）
  - 注册后 `len(beat_schedule)` 从 53 → 58
  - 双审通过；quality minor（schedule 同分钟同时触发的负载、trailing comma 风格漂移）都是 nice-to-have，不修
- **Task 18 wrapper-only push** ✅ — main 推到 origin 触发 linktest 自动 redeploy，启动正常、import 无 ImportError、迁移全部 ⏭ 跳过
- **Task 19 beat-register push** ✅ — linktest 又 redeploy 一次，启动正常（但 beat 不触发，linktest 没 Celery）
- **Task 20 linktest 72h 观察期** — **跳过**（G6 决策：linktest 无意义；用 linktest 启动 OK 替代）
- **Task 21 prod 启用** — **未做**，等用户决定
- **Task 22 prod 48h 验收** — **未做**，依赖 Task 21

### Issues / Surprises

1. **Auto migration runner 发现** — 起初我让用户 manual `psql` 跑 SQL，被用户反问"迁移不是自动跑的吗"。查代码发现 `app/db_migrations.py:491` 在 `main.py:1394` 启动时自动跑 `migrations/*.sql`，有 `migration_tracker` 表做 idempotency。用户记忆里"不用 Python 自动迁移"实际指的是不用 Alembic，但项目自己的 SQL runner 会自动跑——大幅简化了 Plan Task 2-3 流程（变成"push + 监控"）。
2. **G6 关键发现：调度器在两环境不一致** — linktest 的 web service 启动日志出现"启动 TaskScheduler 作为备用调度器"，触发 G6 gate；进一步调研发现 linktest 没独立 Celery worker service、prod 有。这改变了"linktest 72h 观察"的设计前提。
3. **Quality reviewer 发现的 orphan imports** — 删 `_deprecated_get_public_task_experts` 引入 4 个 orphan import（`Query` / `or_` / `func` / `select`）+ 多余空行；implementer 独立 verify 后清理，commit `79517618f`。这条提醒：删大段函数后要主动 grep 检查 import。
4. **CASCADE 决策被 quality reviewer 质疑** — initial migration commit (`f699ad1f0`) 被 quality reviewer 提出"CASCADE 风险（应用层零调用 ≠ DB 层零依赖）"。spec 阶段已经定下 CASCADE 是 deliberate；polish commit (`3e6ef908f`) 加了内联注释说明 deliberate + 提示 plan Task 2 的 `\d+` pre-flight 验证。两条意见都被纳入。
5. **Spec v1 → v2 升级** — 起初 spec 没有 G2/G3/G4 这些 full-stack consistency gate，被用户驳回（"我不确定这样是否优质"）。v2 加了 §3.B0 的 5 项 gate + §3.B6 通知洪水预案，把"上线一个被埋了几个月的功能"的真实复杂度建模出来。这次驳回让 plan 多吸收了 G2 的真实缺口。

---

## Verification Summary

完成后用户可一眼确认全过：

| 项 | 期望 |
|---|---|
| Migration 220 已跑 prod | ✅ |
| `_deprecated_get_public_task_experts` grep 0 命中 | ✅ |
| `run_scheduled_tasks` grep 0 命中 | ✅ |
| Celery beat 多了 5 条 | ✅ |
| linktest 72h 无报错 | ✅ |
| prod 48h 三类通知都有新增 | ✅ |
| Flutter 端实际收到通知 | ✅ |
| 无通知洪水 | ✅ |
