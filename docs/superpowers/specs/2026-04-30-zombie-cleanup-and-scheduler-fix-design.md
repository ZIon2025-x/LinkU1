# Zombie 清理 + 定时任务调度修补

**日期**: 2026-04-30
**作者**: Ryan + Claude
**状态**: design draft v2（v1 因缺失 full-stack 一致性 gate 被驳回，本版补齐）

---

## 1. 目标 & 核心原则

一次性消除两块小臃肿/小风险，为后续更大规模的重构腾出干净的起点：

1. **A**：drop 两张已无模型支撑的 zombie 表 + 删 `routers.py` 里 115 行 `_deprecated_*` 死函数
2. **B**：把 3 个被旧 fallback 路径"困住"、线上其实没在跑的提醒/兜底任务，正式接入 Celery beat；同时清掉 deprecated 的 `run_scheduled_tasks()` + main.py 里的 fallback 分支

**核心原则：准确修复，不"先上再说"**

- **A** 是死代码清理（低风险、可独立完成、可独立回滚）
- **B** 实际上等于"上线一个被埋了几个月的功能" —— 因此 B 必须先通过 §3.B0 的 full-stack 一致性 gate 才允许真正打开 cron。代码可以先准备好，但 `beat_schedule` 注册和 `prod` 启用要 gate 全过才动
- 任何 gate 不过 → 暂停 B（A 不受影响），把缺失项作为前置工作处理后再回来

不在本次范围（明确划出来）：
- `task_experts` 表 / `TaskExpert` 模型（11 个文件还在用，留给后续 phase）
- `featured_task_experts` 表 / `FeaturedTaskExpert` 模型（`admin_task_expert_routes.py` 仍在写入；Expert 表替代未完成）
- `task_expert_services` 表（核心数据）
- `crud/task_expert.py` 三个函数的重命名
- 三套 auth 合并、巨型路由文件拆分、Flutter 模型迁 freezed 等更大块的重构

---

## 2. 背景

### A 部分背景
2026-04-09 的 task_expert_routes.py 整体删除后留下了已知尾巴：
- `task_expert_applications` 和 `task_expert_profile_update_requests` 两张表的模型已从 `models.py` 删除（`models.py:1549, 1596` 留有注释提示后续 migration 可 drop），但表未 drop。grep 全 backend，**0 处真实读写**（仅 migration 历史 SQL 中出现）。
- `routers.py:897-1011` 的 `_deprecated_get_public_task_experts(...)`：`@router.get("/task-experts")` 已被注释、函数名带 `_deprecated_` 前缀、grep 全 backend **0 调用方**。`routers.py` 整体已是 helper-only 残壳（main.py:42-45 注释说明 routers.py 不再 expose router）。

### B 部分背景
扫描 `scheduled_tasks.py` 23 个函数 vs `celery_app.py` `beat_schedule` 53 条注册时发现：

3 个函数**只在** `run_scheduled_tasks()` 内被调用：
- `send_deadline_reminders(db, hours_before)` — 任务截止前提醒，原本调度 24/12/6/1 四档
- `send_payment_reminders(db, hours_before)` — 支付到期前提醒，原本调度 12/6/1 三档
- `check_stale_disputes(db, days=7)` — 7 天未处理争议兜底检查

而 `run_scheduled_tasks()` 自己（`scheduled_tasks.py:1786`）已挂 `DeprecationWarning`，并且在 `main.py:1417-1457` 是**双重 fallback** 的最后一层：

```
celery_available?       → 不启 fallback
TaskScheduler 启动成功? → 用 TaskScheduler
都失败                  → 启动 run_scheduled_tasks 5 分钟轮询线程
```

线上 Celery 是正常运行的主调度器，所以这条 fallback 路径从来不会被触发——意味着这三类提醒/争议检查**实际上从未发出过**。

⚠️ **关键认知**：B 不是"重构"或"清理"，而是**上线一个新功能**。三个函数的 notification type、push template、前端处理逻辑、l10n 文案在过去几个月里没有被实际触发过——任何环节缺失都会让通知发出去之后用户看不到/推送失败。所以本 spec 的 B 部分必须以"新功能上线"的标准走 full-stack 一致性 gate（§3.B0），不能简单当成"接个 Celery wrapper"完事。

---

## 3. 设计

### A. zombie 清理

#### A1. 新增 migration `220_drop_zombie_task_expert_tables.sql`

```sql
-- 删除 2026-04-09 task_expert_routes.py 移除后留下的两张 zombie 表
-- 模型已删（见 models.py:1549, 1596 注释），全 backend 零读写
DROP TABLE IF EXISTS task_expert_profile_update_requests CASCADE;
DROP TABLE IF EXISTS task_expert_applications CASCADE;
```

`CASCADE` 是为了把可能残留的 FK / 索引一并清掉。两张表都是 zombie，CASCADE 不会牵连活跃数据。

#### A2. 删 `routers.py:897-1011`

整段 `_deprecated_get_public_task_experts` 函数（含上面 3 行注释掉的 decorator），共约 115 行。

#### A3. 同步清理 `models.py:1549, 1596` 的旧注释

把 "保留 (历史数据,不接收新写入),后续 migration 可 drop" 这两条注释改成 "已通过 migration 220 drop"。

---

### B. 定时任务调度修补

#### B0. 上线前 full-stack 一致性 gate（**必做，gate 全过才能进 B2 注册 beat**）

implementation plan 第一步是跑这个 gate。每条都必须留下证据（grep 输出 / 截图 / 文件行号引用）。任何一条不过 → 把它作为前置工作处理后再回来开 cron。

**G1. 通知 type 字符串确认**
读源码确认三个函数实际写入 `notifications.type` 的精确字符串（v1 spec 把 `task_deadline_reminder` 写错过——已知函数实际用的是 `deadline_reminder`、`payment_reminder`、`stale_dispute_alert`，但 implementation 阶段必须再 grep 一次定死）：
```bash
grep -n "type=" backend/app/scheduled_tasks.py | grep -E "deadline|payment|dispute"
grep -n "create_notification" backend/app/scheduled_tasks.py | head -20
```

**G2. Backend push template 注册情况**
对每个 type 检查推送服务是否能识别：
```bash
grep -rn "deadline_reminder\|payment_reminder\|stale_dispute_alert" backend/app/push_notification_service*.py backend/app/task_notifications*.py
```
- 如果 template 注册表有 → ✅
- 如果只有日志 print、没真正注册 template → ❌ gate 不过，先补 template

**G3. Flutter NotificationBloc / NotificationItem 处理**
```bash
grep -rn "deadline_reminder\|payment_reminder\|stale_dispute_alert" link2ur/lib/features/notification/ link2ur/lib/data/models/notification*.dart
```
- 检查 `NotificationItem` 的 type → icon 映射、点击 → 跳转目标（应跳到 task detail / dispute detail）
- 缺哪条补哪条（图标 + 跳转 handler + l10n）

**G4. l10n 文案齐全**
三类提醒在 backend 已写死中文/英文（见 `scheduled_tasks.py:1162-1163` 的硬编码字符串），但 Flutter 端通知列表如果用 type 做翻译 key（而不是 backend 传过来的 content），需要确认 `app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb` 三套都有对应 key。

**G5. 索引存在性**
```bash
grep -rn "CREATE INDEX.*tasks.*deadline\|tasks_deadline" backend/migrations/
grep -rn "CREATE INDEX.*payment_expires_at\|tasks_payment_expires" backend/migrations/  # 058 应该已建
```
缺失则补 migration 221（建索引），优先级高于 B 启用 cron。

**Gate 通过的判定**：5 条都有明确证据，且任何"补缺"工作（template / Flutter / l10n / index）已经合并到 main。否则 B 部分停在 B1（写代码）和 B3-B4（删 fallback），不进 B2（注册 beat）。

#### B1. 在 `app/celery_tasks.py` 加 3 个包装器

沿用文件里 `send_expiry_reminders_task`（`celery_tasks_expiry.py`）的现成模式：

```python
@celery_app.task(
    name='app.celery_tasks.send_deadline_reminders_task',
    bind=True,
    max_retries=3,
)
def send_deadline_reminders_task(self, hours_before: int):
    from app.scheduled_tasks import send_deadline_reminders
    db = SessionLocal()
    try:
        return send_deadline_reminders(db, hours_before=hours_before)
    finally:
        db.close()

# 同样模式包 send_payment_reminders_task(hours_before)
# 同样模式包 check_stale_disputes_task(days=7)
```

底层 `send_deadline_reminders` / `send_payment_reminders` / `check_stale_disputes` 三个函数本体**保留不动**，只是上面套一层 Celery wrapper。

#### B2. 在 `app/celery_app.py` `beat_schedule` 加 5 条（**仅 gate 通过后才注册**）

按用户确认的"砍档"方案。**调度频率取决于函数本身的扫描机制**——读完三个函数实现后定下：

- `send_deadline_reminders` / `send_payment_reminders` 内部以 `±5 分钟` 时间窗扫描即将到期的 task，**必须每 10 分钟内至少跑一次**否则会漏。两者都内置"最近 1 小时已发过则跳过"去重，高频运行不会重发。
- `check_stale_disputes` 无去重——每次跑都给所有 admin 重发"超时争议"通知，**每天 1 次足够**。

```python
# Deadline reminders（任务截止提醒）：24h / 6h 两档；每 10 分钟扫一次窗口
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

# Payment reminders（支付到期前提醒）：6h / 1h 两档；同样每 10 分钟
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

# Stale disputes：每天一次（凌晨 2:20，避开其他 daily 任务）
'check-stale-disputes': {
    'task': 'app.celery_tasks.check_stale_disputes_task',
    'schedule': crontab(hour=2, minute=20),
    'kwargs': {'days': 7},
},
```

#### B3. 删 `scheduled_tasks.py:1786-1946` 的 `run_scheduled_tasks()`

整个函数 + 文件末尾 `if __name__ == '__main__': run_scheduled_tasks()`（约 165 行）整段删除。

底层三个函数（`send_deadline_reminders`、`send_payment_reminders`、`check_stale_disputes`）**保留**。

#### B4. 删 `main.py:1417-1457` 的 fallback 分支

简化成：
```python
if celery_available:
    pass  # Celery 是主调度器
else:
    logger.info("📋 启动 TaskScheduler 作为备用调度器...")
    from app.task_scheduler import init_scheduler
    scheduler = init_scheduler()
    scheduler.start()
    logger.info("✅ TaskScheduler 已启动")
```

去掉 `run_scheduled_tasks` import + 5 分钟轮询线程那整块。如果 TaskScheduler 也启动失败，让异常往上抛、应用启动失败——明确比静默回退到一个其实没在跑功能的 fallback 好。

#### B5. 同步更新 `backend/docs/TASK_SCHEDULER_GUIDE.md`

去掉对 `run_scheduled_tasks` 的引用、加上 5 条新 beat 任务的说明。

#### B6. 首次启用通知洪水预案（**B2 注册 beat 之前必做**）

三个函数过去几个月没跑过，第一次启用时**积压数据**会被一次性扫描到。逐项分析：

- **`send_deadline_reminders` / `send_payment_reminders`**：内部对每个 (task, type) 做 1 小时去重，且窗口仅 ±5min（10 分钟 span）。意味着第一次扫描只看到"未来 24h±5min / 6h±5min / 1h±5min"区间内到期的 task ——这本来就是要发提醒的那批，不算"洪水"。**结论：无特别处理**，但 implementation plan 第一步要做 dry-count：
  ```sql
  -- linktest 启用 beat 前先跑：
  SELECT count(*) FROM tasks
  WHERE status='in_progress'
    AND deadline BETWEEN now() + interval '23h 55min' AND now() + interval '24h 5min';
  -- 三档分别跑一次。结果记入 implementation plan 的部署日志。
  ```

- **`check_stale_disputes`**：**无去重**，第一次跑会给**每个 admin** 重发**所有 stale dispute** 的通知。这才是真正的洪水风险点。
  ```sql
  SELECT count(*) FROM task_disputes
  WHERE status='pending' AND created_at < now() - interval '7 days';
  ```
  - 若结果 ≤ 5：直接启用，admin 接受少量通知作为初始化代价
  - 若结果 6-30：先 implementation plan 评审；可考虑人工归档明显已弃置的（与用户确认后操作）
  - 若结果 > 30：**B6 gate 不过**，必须先：(a) 函数加去重字段（`stale_alerted_at`）、或 (b) 仅扫描"近 14 天内创建的 stale 争议"忽略远古积压、或 (c) 人工批量归档 → 才能启用 cron。函数改造 = 另开一份 spec

---

## 4. 提交与部署顺序

严格按此顺序，避免 Railway 自动部署遇到表/列不存在导致 500（用户记忆里 2026-04-20 因此整个 Task/Review 路径挂过）：

| # | Commit | 内容 | 前置 |
|---|---|---|---|
| 1 | A-migration | `migrations/220_drop_zombie_*.sql` | linktest DB 先跑 SQL → 验证表消失 → 再 push |
| 2 | A-code | 删 `routers.py:897-1011` + 改 `models.py` 注释 | 启动 linktest 验证无 ImportError |
| 3 | B-gate | **跑 §3.B0 的 G1-G5 + §3.B6 dry-count，结果记到 implementation plan** | 任何 gate 不过 → 停在这里、补缺、再回来 |
| 4 | B-补缺（可能多个 commit） | 视 gate 结果补 push template / Flutter handler / l10n / 索引 migration 221 | 各自 push 后 linktest 验证 |
| 5 | B-wrapper-only | B1（3 个 Celery wrapper）+ B3-B4（删 fallback）+ B5（docs）；**B2 不写或先注释掉** | linktest 启动验证应用正常、Celery worker 不报错 |
| 6 | B-enable-beat | B2 注册 5 条 beat | linktest 跑 **72 小时**观察日志 + notifications 表抽查 |
| 7 | prod 启用 | 把 commit 6 push 到 main | linktest 72h 全绿 |
| 8 | prod 观察 48h | — | 验收清单 §6 全过 |

**commit 1 必须独立先发**。commit 2 可与其他合并（A 部分纯前置）。**commit 6 不能合并到 commit 5**——拆开是为了让"启用 beat"成为独立的、可单独 revert 的动作。

---

## 5. 风险与回滚

| # | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| 1 | migration 220 drop 表时遇到未知 FK | 低 | DB 操作失败 | `CASCADE` 兜底；先 linktest 验证 |
| 2 | `routers.py:897-1011` 被某外部 import 而我没找到 | 极低 | 启动失败 | grep 已确认零调用；linktest 启动验证 |
| 3 | **三类通知 type 在 push template 缺失** | 中 | 通知写入 DB 但推送不到用户手机 | §3.B0 G2 gate 强制检查；缺则补再上 |
| 4 | **Flutter NotificationBloc 不识别这三个 type** | 中 | 通知列表里能看到但点击不跳/无图标 | §3.B0 G3 gate 强制检查；缺则补再上 |
| 5 | l10n key 缺失 | 低 | 部分语言下显示原始 key 字符串 | §3.B0 G4 gate 强制检查 |
| 6 | `Task.deadline` 缺索引 | 中 | reminder 任务慢查询拖累 DB | §3.B0 G5 gate；缺则先发 migration 221 |
| 7 | 4 reminder 每 10 分钟同跑 DB 压力 | 低 | 慢查询 | 函数都用窄时间窗（±5min）+ 索引；linktest EXPLAIN 验证 |
| 8 | 三个底层函数（多年没跑）现在跑起来发现已经 broken（如调用了已删的 helper） | 中 | 通知不发或报错刷屏 | linktest 跑 72h 观察日志；wrapper 自带 max_retries=3 + 错误日志；保留底层函数代码 |
| 9 | **`check_stale_disputes` 第一次跑通知洪水** | 中-高（取决于积压数） | admin 收到几十～几百条重复通知 | §3.B6 强制 dry-count；> 30 则视为新 spec |
| 10 | 删 fallback 后 Celery + TaskScheduler 同时挂 | 极低 | 应用启动失败 | 这种场景下旧 fallback 也跑不了正确的功能（前面分析过）；显式失败比静默假跑好 |

**回滚预案**：
- migration 220 一旦 drop，恢复要从 pg_dump 还原 → **commit 1 部署前必须先 pg_dump 备份**（写进 implementation plan）
- commit 6（B-enable-beat）出问题：直接 revert commit 6，5 条 beat 即刻失效；底层 wrapper 不会被调用；其他改动不动
- commit 5（B-wrapper-only）出问题：revert commit 5；fallback 分支恢复（虽然 fallback 本来就没跑过这三个函数）

---

## 6. 验收标准

**A 部分（commit 1-2 后）：**
- [ ] `psql -c "\dt task_expert_applications"` / `task_expert_profile_update_requests` 在 prod 都返回 "Did not find any relation"
- [ ] grep `_deprecated_get_public_task_experts` 全 repo 0 命中
- [ ] linktest + prod 启动日志无 ImportError

**B-gate（commit 3 后）：**
- [ ] §3.B0 的 G1-G5 全部留下证据，归档到 implementation plan 的"gate report"小节
- [ ] §3.B6 的 dry-count 数字记入 plan，且 stale_disputes count ≤ 30（或已有处置方案）

**B-enable（commit 6 后 72h）：**
- [ ] grep `run_scheduled_tasks` 全 repo 0 命中（除 git history）
- [ ] Celery beat 启动后 `celery -A app.celery_app inspect scheduled` 看到 5 条新任务
- [ ] linktest 72h 内 `notifications` 表查到至少 1 条 `type='deadline_reminder'`、1 条 `type='payment_reminder'` 新记录
- [ ] linktest 72h 内**有真实用户/测试账号**收到对应推送（在 Flutter 端实际看到通知，不只是 DB 里有记录）
- [ ] `EXPLAIN` 验证 `send_deadline_reminders` 和 `send_payment_reminders` 核心查询走索引

**prod 启用后 48h（commit 7 后）：**
- [ ] prod `notifications` 表新增三类 type 记录
- [ ] 无 admin 收到 stale_dispute 通知洪水（>10 条/天单 admin 视为洪水）
- [ ] 错误日志不显著上升（对比启用前 7 天均值）

---

## 7. 后续延伸（不在本次范围）

做完这次后，下一个候选臃肿目标在原 punch list 里待选：

- **C**：拆 `task_chat_routes.py`（6244 行）/ `schemas.py`（5020 行）/ `flea_market_routes.py`（4762 行）
- **D**：合并三套 auth（`secure_auth` 3305 + `separate_auth` 1062 + `cs_auth` 343 = 4710 行）
- **E**：Flutter model 迁 freezed（37 个手写 model，10544 行可削 ~3.5K）
- **F**：Flutter 抽 `DetailViewScaffold`
- **G**：Flutter `task_expert_bloc.dart` (2234) + `task_detail_bloc.dart` (1667) 拆分
- **H**：`frontend/` web 端去留决策

本次完成后再坐下来挑下一个攻。
