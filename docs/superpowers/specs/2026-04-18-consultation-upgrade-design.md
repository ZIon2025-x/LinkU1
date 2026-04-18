# Consultation 架构升级 — 占位 task 语义污染修复

- **日期**: 2026-04-18
- **范围**: 修复 `SA.task_id` 覆盖 bug + 消除占位 task 的语义污染,不重构咨询架构
- **状态**: Design
- **前置要求**:**Track 1(`2026-04-17-consultation-fixes-design.md`)必须先合入**。本 spec 在 B.1 / D.4 / 测试 13 直接引用了 Track 1 的 F4 (`create_placeholder_task`) / F3 (`require_team_role`) / F6 (`INSUFFICIENT_TEAM_ROLE` 错误码) 三个产物,不做独立实现。实施前先 verify Track 1 已 merge 到 main
- **相关文档**:
  - `2026-04-17-consultation-fixes-design.md`(Track 1 — 代码层修复,本 spec 的前置)
  - `project_consultation_task_id_overwrite.md`(待修复的技术债,本 spec 解决)
  - `product_no_private_messaging.md`(产品约束:咨询必须绑定业务对象)

---

## 背景

咨询功能(service / task / flea_market)有两类真实风险,不是"只是不好看":

1. **`SA.task_id` 覆盖 bug (B1/B2)** — approve 时 `SA.task_id = new_task.id` 把咨询占位 id 改成真任务 id,team 非 owner 成员通过 `SA.task_id` 访问旧咨询消息的路径断裂(见 `expert_consultation_routes.py:1025` / `user_service_application_routes.py:681`)
2. **占位 task 潜在漏洞** — `/tasks/{id}/{pay,complete,cancel,review,dispute,refund}` 等 task-level API 未检查 `task_source`,占位 task id 泄露时理论上可被这些 API 调用触发非预期行为

另外还有一些**非阻塞但值得一并清理**的问题:
- `scheduled_tasks.py` 的 stale cleanup 未覆盖 `task_consultation` (B3)
- 占位 task 的识别依赖脆弱的 `task_source` 字符串匹配
- Admin 面板 / 统计查询可能把占位 task 计入任务总数

### 产品约束(不碰)

- 保留"咨询必须绑定 task/service/flea_market_item"的反滥用设计
- 三张申请表(`service_applications` / `task_applications` / `flea_market_purchase_requests`)保留
- 现有业务流程(咨询→议价→正式申请/购买→履约→评价)保留
- Flutter API 端点签名不变(只新增字段,不删不改)

### 业务约定(本 spec 遵守)

咨询 task 是"任务进行前的确认对话"的载体,真任务才是业务一等公民:
- 支付 / 评价 / 争议 / 完成等所有交易操作发生在**真任务**上
- `SA.task_id` 语义:**当前业务关心的任务**
  - approve 前:咨询占位 task
  - approve 后:真任务(现状,保留)
- 咨询历史(approve 前产生的消息)通过新字段 `SA.consultation_task_id` 查找

---

## 目标

1. 修复 B1/B2 消息 orphan bug,不改动 `SA.task_id` 现有语义
2. 用显式字段 `Task.is_consultation_placeholder` 取代脆弱的 `task_source` 字符串匹配
3. 堵住 task-level API 对占位 task 的访问路径(潜在漏洞预防)
4. 修 B3 stale cleanup 覆盖三类咨询
5. Admin 面板 / 统计排除占位 task

**不在范围**:
- 不动 `ck_messages_task_bind` CHECK 约束(messages 仍按 task_id 挂占位 task)
- 不改咨询 API 端点签名
- 不做 conversation-first 重构
- Track 1 的代码层修复(celery 锁 / 权限 helper / 错误码 / 通知双语化)是独立议题,不受此 spec 影响

---

## 改动总览

| 层 | 文件 | 行数量级 |
|---|---|---|
| DB migration 208a(列 + 回填) | `backend/migrations/208a_add_is_consultation_placeholder_column.sql` | ~10 行 SQL |
| DB migration 208b(CHECK 约束)— **必须在新代码完全接管后才跑** | `backend/migrations/208b_add_consultation_placeholder_check.sql` | ~15 行 SQL |
| DB migration 209 | `backend/migrations/209_application_consultation_task_id.sql` | ~15 行 SQL |
| SQLAlchemy models | `backend/app/models.py`(Task + 3 个 Application 表) | ~6 行 |
| Helper 扩展 | `consultation/helpers.py::create_placeholder_task`:内部加 `is_consultation_placeholder=True` | 1 行 |
| 统一路由 helper | `consultation/helpers.py::consultation_task_id_for(app)` | ~8 行 |
| Task 创建点迁移 | `expert_consultation_routes.py:~429`(team) / `flea_market_routes.py:~4064` / `task_chat_routes.py:~4860` 从 inline Task() 改调 helper | **净减少 ~20 行**(inline ~15 行 → call helper ~7 行,3 处) |
| Overwrite 修复(SA) | `expert_consultation_routes.py:1025` / `user_service_application_routes.py:681` | 4 行(每处加 1 行备份) |
| TA 正式转换修复(B.2.3) | `task_chat_routes.py:5392` 创建 `orig_application` 时加 `consultation_task_id=task_id` + `task_chat_routes.py:5427` 占位 TA 状态 `"pending"` → `"cancelled"` | 2 行 |
| Flea market 占位晋升 | `flea_market_routes.py:2451` 附近 | 2 行(两字段原子改) |
| Task API 守卫 helper | 新建 `backend/app/utils/task_guards.py` | ~20 行 |
| 守卫应用点 | 18 个 task-level endpoint(16 处 `db.get` → `load_real_task_or_404` 替换 + 2 处 admin 加 warning 日志) | ~16 处 2-3 行替换 + 2 处 log |
| 团队权限检查迁移(顺手) | 上述 18 个 endpoint 里有 team check 的约 6-8 个,改用 `require_team_role` helper | ~6-8 处 3 行替换 |
| Stale cleanup 修复 | `scheduled_tasks.py:965-982` | ~15 行(加 `task_consultation` 分支 + 防御性 else) |
| Admin / 统计过滤 | `admin_task_management_routes.py` + `crud/task.py` + profile routes | 5-6 处 2-3 行 |
| Flutter 四个 model | `service_application.dart` + `task_application.dart` + `flea_market_purchase_request.dart` + `task.dart` | ~20 行(4 个 model) |
| Flutter 三个独立 extension | `lib/data/models/` 下对应 model 各自的扩展(不依赖共同基类) | ~15 行 |
| 历史数据诊断 | Section G 诊断 SQL | 4 条查询(不改生产,先跑看数字) |
| 可选 best-effort 回填 | `migration 211_backfill_consultation_task_id.sql`(根据诊断结果决定跑不跑) | ~40 行 SQL |
| 测试 | pytest + bloc_test | ~21 个新测试(后端 16 + Flutter 5) |

**工程量估计:3.5-4.5 天全职**(原 3-4 天,self-review P1 发现 TA 分支独立处理 + C.3 统一路由 helper 增加 0.5 天),不含上线观察。

---

## Section A — DB Migrations

### A.1 Migration 拆分:208a(列+回填)和 208b(CHECK 约束)

**为什么拆**(回应 self-review E):原计划的 208 里同时 ADD COLUMN + UPDATE + ADD CONSTRAINT。问题:Railway 滚动更新期间,新 migration 跑完后、旧代码完全退役前,**旧代码仍在接请求**。旧代码写占位 task 时用 `default FALSE` + `task_source='consultation'` → 直接违反 CHECK 约束 → 500 返回用户。

**解决**:拆两次 migration,中间放一段"代码完全接管"的观察期。

#### `backend/migrations/208a_add_is_consultation_placeholder_column.sql`

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

#### `backend/migrations/208b_add_consultation_placeholder_check.sql`

**只在所有代码实例都是新版本后才执行**(见"上线顺序"Day 2):

```sql
-- 兜底回填(防止 208a 到 208b 之间有旧代码漏写 flag 的行)
UPDATE tasks
SET is_consultation_placeholder = TRUE
WHERE task_source IN ('consultation', 'task_consultation', 'flea_market_consultation')
  AND is_consultation_placeholder = FALSE;

-- 双保险 ASSERT:若仍有违反行(新代码漏改的 / 兜底 UPDATE 未覆盖的边界),中止 migration 并报告,
-- 避免 ADD CONSTRAINT 崩溃在"扫描表时发现违反"的模糊错误信息上(回应 self-review U11)
-- ⚠️ 要求 migration runner 用 ON_ERROR_STOP=on(psql -v ON_ERROR_STOP=1 / --single-transaction)或等效设置,
--    否则 RAISE EXCEPTION 触发后 runner 可能仍继续执行下面的 ADD CONSTRAINT,失去双保险意义
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

-- 强约束两个字段一致,避免 source-of-truth 漂移
-- 新代码已全部通过 create_placeholder_task helper 同时写两字段,此时加约束不会破坏任何写入
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

**Source of truth 约定**:
- `is_consultation_placeholder` 是**业务路由的主过滤键**(stale cleanup / admin / 守卫 / 统计过滤全部查它)
- `task_source` 保留用于**区分咨询子类型**(`'consultation'` vs `'task_consultation'` vs `'flea_market_consultation'`,用于 stale cleanup 分支处理关联哪张申请表)
- 两者由 CHECK 约束(208b)强制同步,应用层**永远不单独改其中一个字段**;flea market 晋升(B.3)需要在同一事务内同时改两者
- 208a→208b 之间(Day 1→Day 2)约束**尚未生效**,依赖应用层正确——helper 迁移完 + 208a 已跑 + 兜底 UPDATE 保证安全窗口
- 未来新增咨询类型,需要改 CHECK 约束 + 三个业务分支同步处理(不常见,可接受硬编码)

### A.2 `backend/migrations/209_application_consultation_task_id.sql`

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

**说明**:
- `ON DELETE SET NULL`:**只保 SA/TA/FMPR 记录不被级联删除**。注意 `messages.task_id` 仍是 `ON DELETE CASCADE`(现有 schema,本 spec 不改)——即占位 task 被删仍会连带删掉咨询消息。见风险表"占位 task 被手动 DELETE 的连带消息丢失"
- 不做数据回填:历史已 approve 的 SA 的占位 id 在覆盖 bug 发生时已丢失,我们**向前修复**,不尝试考古回溯
- 不同于之前讨论的 `fulfillment_task_id` 方案,本 spec 新增字段是 `consultation_task_id`:`SA.task_id` 保持"当前业务任务"语义不变,避免 15 处读取点审计

### A.3 SQLAlchemy 模型更新

`backend/app/models.py`:

```python
# Task 模型(~类 Task 内)
is_consultation_placeholder = Column(Boolean, nullable=False, default=False, server_default='false')

# ServiceApplication 模型
consultation_task_id = Column(
    Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True
)

# TaskApplication 模型
consultation_task_id = Column(
    Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True
)

# FleaMarketPurchaseRequest 模型
consultation_task_id = Column(
    Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True
)
```

---

## Section B — 后端写入点修改

### B.1 占位 task 创建点(4 处)— 同时迁到 `create_placeholder_task` helper

Track 1 F4 已经写好了 `backend/app/consultation/helpers.py::create_placeholder_task`,但**只有 1 处 caller**(`expert_consultation_routes.py:~292` 个人服务分支)。本 spec 借加字段这个窗口**一次性把剩下 3 处也迁过来**,避免 helper 永远是"只有一处调用"的半成品(回应 review 第 6 条)。

**Helper 改动**(一行):`create_placeholder_task` 内部构造 Task 时自动设置 `is_consultation_placeholder=True`(它本来就是造占位的,不需要参数):

```diff
 task = models.Task(
     title=title,
     description=description,
     poster_id=applicant_id,
     taker_id=taker_id,
     status="consulting",
     task_source=consultation_type,
+    is_consultation_placeholder=True,
     **extra_fields,
 )
```

**4 处 caller 的改造状态**:

| 文件:行 | 场景 | 当前状态 | 改动 |
|---|---|---|---|
| `expert_consultation_routes.py:~292` | 服务咨询(个人服务) | 已用 helper | 零改动(helper 自动带 flag) |
| `expert_consultation_routes.py:~429` | 服务咨询(团队服务) | **inline `Task(...)`** | 迁到 `create_placeholder_task(...)` |
| `flea_market_routes.py:~4064` | 商品咨询 | **inline `Task(...)`** | 迁到 `create_placeholder_task(...)` |
| `task_chat_routes.py:~4860` | 任务咨询 | **inline `Task(...)`** | 迁到 `create_placeholder_task(...)` |

示例(`task_chat_routes.py:~4860`):

```diff
-consulting_task = models.Task(
-    title=f"咨询：{task.title}",
-    description=...,
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
+    description=...,
+    # extra_fields 透传各路由特有字段(reward/currency/location 等)
+)
```

**约束保证一致性**:helper 同时 set `task_source=consultation_type` + `is_consultation_placeholder=True`,满足 A.1 的 CHECK 约束。调用点不用考虑两者关系。

### B.2 Application task_id 修复

**三张申请表的 approve 流程实际上各不相同**,本 spec 给各自的修复点分开列(回应 self-review P1):

#### B.2.1 SA — Overwrite bug(B1/B2)

`expert_consultation_routes.py:~1025`(团队服务 approve):

```python
+ # 备份咨询占位 id,保留 team 成员访问历史消息的路径
+ if application.task_id and not application.consultation_task_id:
+     application.consultation_task_id = application.task_id
  application.task_id = new_task.id  # 保持原语义
```

`user_service_application_routes.py:~681`(个人服务 approve):

```python
+ if application.task_id and not application.consultation_task_id:
+     application.consultation_task_id = application.task_id
  application.task_id = new_task.id
```

**防御性兜底**:现有代码 `expert_consultation_routes.py:807-815` 已有 idempotency 检查(approved 状态直接返回,不会再走 approve 流程)。`if not application.consultation_task_id` 是**双层防护**——即使上游 idempotency 检查失效(比如未来有人改代码漏了),consultation_task_id 也不会被错误地改成真任务 id。

#### B.2.2 FMPR — 占位晋升(见 B.3)

FMPR 不 overwrite task_id,而是把占位 task 晋升为真任务。`consultation_task_id` 在晋升时写入,和 task_id 指向同一行。详细见 B.3。

#### B.2.3 TA — 并行创建新记录

`task_chat_routes.py:5307 consult_formal_apply` 的流程**和 SA 完全不同**(self-review P1 发现):

```
- 占位 TaskApplication(task_id=占位)在咨询阶段创建,这条记录**不**被 overwrite
- 正式申请提交时,**新建**一条 `orig_application`(task_id=原任务)承接履约
- 两条 TA 并存:占位那条是咨询线,新那条是履约线
```

所以 TA 的修复**不是加备份**,而是**在新建 "原任务申请"(代码中变量名 `orig_application`)时写入 consultation_task_id 回链占位 task**:

`task_chat_routes.py:~5392`(创建 `orig_application` 处):

```diff
 orig_application = models.TaskApplication(
     task_id=original_task_id,
     applicant_id=current_user.id,
     status="pending",
     currency=application.currency or orig_task.currency or "GBP",
     negotiated_price=application.negotiated_price,
     message=body.message or application.message,
     created_at=current_time,
+    consultation_task_id=task_id,  # task_id 参数就是占位 task id(来自路由 /tasks/{task_id}/applications/{app_id}/formal-apply)
 )
```

**额外小修**:同一函数 `task_chat_routes.py:5427` 现有代码把占位 TA(即函数里的 `application` 变量)状态改成 `"pending"`,但实际正式申请已经是另一条 `orig_application` 承载——占位 TA 此时应作废:

```diff
-application.status = "pending"
+# 占位 TA 已被 orig_application 取代,标记为 cancelled 以避免 "pending" 歧义
+application.status = "cancelled"
```

**边界场景**(占位 TA 作为"咨询但未转正式"场景):
- 如果用户咨询但直接调 `/close-consultation` 取消:占位 TA 被 `consult_close` 关闭(**实施时 verify 该函数的确切 status 变更**;若改成 cancelled 或 closed 皆可,task_id 仍指占位),通过 fallback 规则(见 Section C)仍能查咨询消息
- 如果用户咨询→正式申请后 `orig_application` 被拒绝,占位 TA 已是 cancelled(B.2.3 改),`orig_application.consultation_task_id` 非空,通过 consultation_task_id 查咨询消息

### B.3 Flea market 占位晋升(B5 对称性)

`flea_market_routes.py:~2446-2453`(付款时复用占位 task):

```python
 existing_task.status = "in_progress" if is_free_purchase else "pending_payment"
 ...
 # ⚠️ 以下两行必须同一事务内同时改,否则违反 ck_tasks_consultation_placeholder_matches_source
 existing_task.task_source = "flea_market"
+existing_task.is_consultation_placeholder = False  # 从占位晋升为真实订单任务
 existing_task.accepted_at = get_utc_time()
 new_task = existing_task

+# 和 SA/TA 对称:记录咨询 id 以便看历史
+if not purchase_request.consultation_task_id:
+    purchase_request.consultation_task_id = existing_task.id  # 晋升前该 id 就是咨询占位
```

**原子性要求**:`task_source` 和 `is_consultation_placeholder` 两个字段由 CHECK 约束绑定,晋升时必须在同一事务内同时改写,否则 DB 会拒绝 commit。这是对应用代码的**硬约束**,也是 CHECK 约束的意义(回应 review 第 1 条)。

**特殊逻辑说明**:
- FMPR 不覆盖 `task_id`(现状,见 `flea_market_routes.py` 路径审计报告)
- 但此时 task 已经**从占位晋升为真任务**(`is_consultation_placeholder=False`),所以 `task.id` 值不变但语义变了
- 为保持和 SA/TA 的读取一致性:`consultation_task_id` 仍写入这个 id,让"想看咨询历史"的代码有个统一字段
- 效果:**FMPR 的 `task_id` 和 `consultation_task_id` 最终指向同一行 task**(晋升后的那一行)。这是表面"怪异"但语义正确(那行 task 既是当前业务任务也是咨询起源),**不是 bug**。Flutter model 文档必须明确注明(见 F.1)

### B.4 Stale cleanup 修复(B3)

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
+    if task.task_source == 'consultation':
+        await _close_related_service_application(db, task)
+    elif task.task_source == 'task_consultation':
+        await _close_related_task_application(db, task)  # 新增(修 B3)
+    elif task.task_source == 'flea_market_consultation':
+        await _close_related_flea_market_request(db, task)
+    else:
+        # 不应发生(CHECK 约束保证 is_consultation_placeholder=TRUE → task_source ∈ 三值)
+        logger.error("Placeholder task with unknown task_source", extra={"task_id": task.id, "task_source": task.task_source})
```

**不变量**:CHECK 约束保证"进入这个循环的 task 必定 task_source ∈ 三值之一",`else` 分支是防御性断言。

---

## Section C — 后端读取点(基本不动) + 咨询消息路由统一规则

### C.1 现有 `application.task_id` 读取点零改动

`application.task_id` 当前 15 处读取点**语义和现状一致**(读"当前业务任务"),方案 Y 不改变此语义,因此**全部保留**,无需审计改动。三种申请表都成立。

### C.2 TA 的心智负担(不需要改动,但要意识到)

TA 场景有个特殊性:**同一次"咨询+正式申请"流程涉及两条 TaskApplication 记录**:
- 占位记录:`task_id` 指占位 task,状态 `consulting`→`cancelled`(B.2.3 修改后)
- 正式记录(`orig_application`):`task_id` 指原任务,状态 `pending`→...

C.1 的"读取点零改动"仍然成立——单条记录内 task_id 不变。但读代码时**要清楚"操作哪条 TA"**:
- 咨询聊天 UI 作用于占位记录
- 履约/审批/支付作用于 `orig_application`

这是现有代码的心智负担,本 spec 不消除(消除需要重构 TA 模型,超出范围)。

### C.3 ★ 咨询消息路由统一规则(回应 self-review P2)

任何代码想要**定位一条咨询消息流**(无论调用方是 Flutter / 后端 / admin),都遵循:

```python
# backend/app/consultation/helpers.py
def consultation_task_id_for(app) -> Optional[int]:
    """返回应该用来查 messages 的 task_id。None 表示不存在咨询消息。

    适用于 ServiceApplication / TaskApplication / FleaMarketPurchaseRequest
    三种申请类型,遵循 "consultation_task_id 优先,fallback 到 task_id" 的规则。
    """
    if app.consultation_task_id is not None:
        return app.consultation_task_id   # approve/正式转换后场景
    if app.task_id is not None:
        # app.task_id 指向的 task 此时 is_consultation_placeholder=True
        # SA approve 前 / TA 占位态 / FMPR 未晋升态 都走这条
        return app.task_id
    return None
```

**分场景表**(7 种场景):

| 申请类型 | 阶段 | consultation_task_id | task_id | 用哪个 |
|---|---|---|---|---|
| SA | approve 前(consulting/negotiating/price_agreed) | NULL | 指占位 | task_id(fallback) |
| SA | approve 后 | 指占位 | 指真任务 | **consultation_task_id** |
| TA(占位记录) | 咨询中 | NULL | 指占位 | task_id(fallback) |
| TA(占位记录) | formal apply 后(cancelled) | NULL | 仍指占位 | task_id(fallback,仍有效) |
| TA(`orig_application` 记录) | formal apply 后 | 指占位 | 指原任务 | **consultation_task_id** |
| FMPR | 咨询中 | NULL | 指占位 | task_id(fallback) |
| FMPR | 付款晋升后 | 指同一行 task | 指同一行 task | 两者等价(helper 返回 consultation_task_id) |

**实现约定**:
- 后端 helper:`app/consultation/helpers.py::consultation_task_id_for(app) -> Optional[int]`(见上面代码块)
- Flutter:三个 model 各自独立 extension(SA/TA/FMPR 在 Link2Ur 中**没有共同基类**,不能用 `on Application`),或在 repository 层提供一个顶层函数。具体实施见 F.3
- 所有"打开咨询聊天"的路径**必须调此 helper 或对应 getter**,不能直接读 `consultation_task_id` 或 `task_id`

### C.4 新读取路径的使用场景

- Team 成员进入已 approve 的服务任务,想看当初的咨询聊天记录
- Admin 查案(客服处理纠纷时回溯谈话)
- 咨询中途的聊天入口(任何阶段,用统一 helper)

UI 入口是否加属于另一小项目,不在本 spec 范围。后端字段和 helper 先就位。

---

## Section D — Task 级 API 守卫

### D.1 新建 `backend/app/utils/task_guards.py`

```python
"""Task 级 API 的通用守卫:拒绝对咨询占位 task 的业务操作。"""

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app import models


async def load_real_task_or_404(db: AsyncSession, task_id: int) -> models.Task:
    """
    加载 Task,并确保它不是咨询占位。

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

### D.2 守卫应用点(18 处)

**写操作(必拦,返回 404)**:

| Endpoint | 文件 |
|---|---|
| `POST /tasks/{id}/accept` | `routers.py:1862` |
| `POST /tasks/{id}/reject` | `routers.py:2070` |
| `POST /tasks/{id}/review` | `routers.py:2195` |
| `POST /tasks/{id}/complete` | `routers.py:2315` |
| `POST /tasks/{id}/dispute` | `routers.py:2545` |
| `POST /tasks/{id}/refund-request` | `routers.py:2673` |
| `POST /tasks/{id}/refund-request/{rid}/cancel` | `routers.py:3524` |
| `POST /tasks/{id}/refund-request/{rid}/rebuttal` | `routers.py:3653` |
| `POST /tasks/{id}/cancel` | `routers.py:4481` |
| `POST /tasks/{id}/pay` | `routers.py:6714` |
| `POST /tasks/{id}/payment` | `coupon_points_routes.py:502` |

**读操作(拦并返回 404)**:

| Endpoint | 文件 |
|---|---|
| `GET /tasks/{id}/reviews` | `routers.py:2276` |
| `GET /tasks/{id}/refund-status` | `routers.py:3008` |
| `GET /tasks/{id}/dispute-timeline` | `routers.py:3094` |
| `GET /tasks/{id}/refund-history` | `routers.py:3428` |
| `GET /tasks/{id}/payment-status` | `coupon_points_routes.py:2200` |

**Admin 操作(不拦但打 warning 日志)**:

| Endpoint | 文件 |
|---|---|
| `POST /admin/tasks/{id}/complete` | `multi_participant_routes.py:1144` |
| `POST /admin/tasks/{id}/complete/custom` | `multi_participant_routes.py:2904` |

Admin 路径保留穿透能力以支持客服手动清理/纠错,但在触碰占位 task 时记录日志便于追查。**完整 diff 示例**(放在 `db.get` 后、业务逻辑前):

```diff
 @router.post("/admin/tasks/{task_id}/complete")
 async def admin_complete_task(task_id: int, ...):
     task = await db.get(models.Task, task_id)
     if not task:
         raise HTTPException(status_code=404, detail="任务不存在")
+    # 不拦,但记录客服对占位 task 的操作便于事后审计
+    if task.is_consultation_placeholder:
+        logger.warning(
+            "Admin operation on consultation placeholder task",
+            extra={
+                "task_id": task.id,
+                "admin_user": current_admin.id,
+                "endpoint": request.url.path,
+            },
+        )
     # 后续业务逻辑不变(admin 穿透,不拦)
```

### D.3 替换模式

每个 endpoint 开头(18 处)的模式:

```diff
-task = await db.get(models.Task, task_id)
-if not task:
-    raise HTTPException(status_code=404, detail="任务不存在")
+from app.utils.task_guards import load_real_task_or_404
+task = await load_real_task_or_404(db, task_id)
 # 后续业务逻辑不变
```

### D.4 顺手迁移:inline 团队权限检查 → `require_team_role`

Track 1 F3 写了 `backend/app/permissions/expert_permissions.py::require_team_role` helper,**零真实 caller**——纯死代码(回应 review 第 4 条)。本 spec 改 18 个 endpoint 开头的守卫时,借此窗口**顺手迁移该 endpoint 的 inline 团队权限检查**,避免 Track 1 helper 永远闲置。

**范围(仅"顺手",不主动扩)**:只在改这 18 个 endpoint 时做;其它 inline team check 不动。

**需要迁移的典型模式**:

```diff
-# 现状:inline 检查 "必须是 team owner 或 admin"
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

+# 迁移后
+from app.permissions.expert_permissions import require_team_role
+if task.taker_expert_id:
+    await require_team_role(db, task.taker_expert_id, current_user.id, minimum="admin")
```

**18 个 endpoint 里需要 team 检查的**(预估,实施时逐个审):
- 写操作含团队分支的:accept / reject / complete / cancel / dispute / refund-request 系列
- 读操作大多不需要(走公共读取权限)
- Admin 操作自带 admin 守卫,不改

**不在范围**:
- 咨询 / 审批路由(`expert_consultation_routes.py` / `user_service_application_routes.py`)里的 team check 迁移——那些属于 Track 1 F3 本来就该做的,本 spec 不接手
- 独立 team management 路由(`expert_routes.py` 等)——同上

**Rationale**:把死代码盘活的成本很低(`require_team_role` 签名简洁,替换是机械操作),还能让后面的 consultation 相关 endpoint 迁移时有现成模式参考。

---

## Section E — Admin 面板 / 统计过滤

### E.1 Admin task 列表

`admin_task_management_routes.py` 的 task 列表 endpoint:

```diff
 @router.get("/admin/tasks")
 async def list_tasks(
+    include_placeholders: bool = False,  # 新增 query param,默认 False 排除占位
     ...
 ):
     query = select(models.Task)
+    # 默认排除占位 task;客服显式需要时加 ?include_placeholders=true
+    if not include_placeholders:
+        query = query.where(models.Task.is_consultation_placeholder == False)
```

### E.2 用户主页"我发布的任务数"

审计位置(预估):
- `crud/task.py` — 计算用户发布任务总数的 helper
- `profile` 相关 routes — 用户主页显示的统计

每处在 `where(Task.poster_id == user_id)` 后加 `.where(Task.is_consultation_placeholder == False)`。

### E.3 其他潜在过滤点

- `sitemap_routes.py`:公开 sitemap 按 `status='open'` 过滤,占位 task 天然排除(`status='consulting'`),**无需改动**
- `task_listing.py`:同上
- `recommendation/engine.py`:走上游 open 过滤,**无需改动**

---

## Section F — Flutter 改动

### F.1 Model 新增字段(**四个 model**:SA + TA + FMPR + Task)

migration 209 给三个申请表加了 `consultation_task_id`,208a 给 tasks 表加了 `is_consultation_placeholder`。Flutter 对应**四个** model 都要改。

#### F.1.1 三个申请 model 加 `consultationTaskId`

**`lib/data/models/service_application.dart`**:

```diff
 class ServiceApplication {
   final int id;
   final int? taskId;
+  /// 咨询占位 task id。approve 前为 null;approve 时从 [taskId] 备份过来,
+  /// 之后永久保留,用于回溯 approve 前的咨询对话消息。
+  final int? consultationTaskId;
   ...
 }
```

**`lib/data/models/task_application.dart`**:同上,加 `consultationTaskId` + 同样的 doc。

**`lib/data/models/flea_market_purchase_request.dart`**:加 `consultationTaskId`,但 dart doc **必须明确注明特殊性**:

```dart
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
```

三个申请 model 的 `fromJson` 都加 `consultationTaskId: json['consultation_task_id'] as int?`。

#### F.1.2 Task model 加 `isConsultationPlaceholder`

对应后端 A.1 的新列:

```dart
class Task {
  ...
  final bool isConsultationPlaceholder;
}
```

`fromJson` 加 `isConsultationPlaceholder: json['is_consultation_placeholder'] as bool? ?? false`。

### F.2 "是否已成单"判断规范

由于 FMPR 的 `taskId == consultationTaskId` 怪异性(见 F.1.1),Flutter 代码里**统一用 `task.isConsultationPlaceholder`** 或申请状态字段判断。

`consultationTaskId == taskId` 比较只在 FMPR 晋升后为 true,SA/TA 永远 false——**不是**跨类型的成单判断,不可依赖。

### F.3 咨询消息路由 extension(C.3 规则落地)

Link2Ur 的 Flutter model **SA / TA / FMPR 没有共同基类**(各自独立的 class),所以 C.3 的统一规则无法用一个 `on Application` extension 实现。三种落地方式(挑一种):

**方式 a — 三个独立 extension(推荐,最直接)**:

三个 extension 统一命名 `<ModelName>ConsultationRoute`,各暴露 `consultationMessageTaskId` getter:

```dart
// service_application.dart
extension ServiceApplicationConsultationRoute on ServiceApplication {
  /// 咨询消息路由 id。C.3 规则:优先 consultationTaskId,fallback taskId。
  int? get consultationMessageTaskId => consultationTaskId ?? taskId;
}

// task_application.dart
extension TaskApplicationConsultationRoute on TaskApplication {
  int? get consultationMessageTaskId => consultationTaskId ?? taskId;
}

// flea_market_purchase_request.dart
extension FleaMarketPurchaseRequestConsultationRoute on FleaMarketPurchaseRequest {
  int? get consultationMessageTaskId => consultationTaskId ?? taskId;
}
```

**方式 b — 顶层函数(如果想集中在一处)**:

```dart
// lib/data/models/application_utils.dart
int? consultationMessageTaskIdFor({
  required int? consultationTaskId,
  required int? taskId,
}) => consultationTaskId ?? taskId;

// 调用方:application_utils.consultationMessageTaskIdFor(
//   consultationTaskId: app.consultationTaskId, taskId: app.taskId
// )
```

**方式 c — 加 mixin**(需要改 model 继承,工程量最大,不推荐)。

实施时任选一种,保持整个 Flutter 代码库一致即可。

### F.4 咨询历史跳转(可选,独立 feature)

本 spec 范围内仅把字段带到 Flutter。具体 UI 入口("查看咨询历史记录"按钮)是否加,按产品需求决定,不属于 bug 修复必要改动。

若要加,**必须使用 F.3 的 `consultationMessageTaskId` getter**(或顶层函数),不能直接用 `consultationTaskId`(approve 前为 null 会崩):

```dart
final chatTaskId = application.consultationMessageTaskId;  // 走 F.3 extension
if (chatTaskId != null) {
  context.push('/chat/application', extra: {
    'taskId': chatTaskId,
    'applicationId': application.id,
    'isHistory': application.status == 'approved',
  });
}
```

### F.5 不变

- 咨询过程中(approve 前)的消息访问:继续走 `application.taskId`,路径不变
- 成单后的业务操作:继续走 `application.taskId`(现在指真任务),路径不变
- 所有现有 API 端点 / BLoC 事件 / 路由:不变

---

## Section G — 历史数据影响面评估(回应 review 第 3 条)

### 问题

覆盖 bug 从上线日起就在。每一次已发生的 team-service approve 都造成:
- `SA.task_id` 被改成真任务 id
- 原占位 task id 从 `SA` 里丢失
- 消息仍挂在原占位 task_id 上,**team 非 owner 成员从 `SA` 找不到**

本 spec 不反向回填(第 A.2 节说明),历史受损 SA 的咨询消息**永久**对 team 非 owner 成员不可见,除非跑 best-effort 脚本或客服手动处理。

### 上线前必须跑的诊断 SQL

```sql
-- 1. 受影响的 SA 总数(approved 及之后状态 + 有真任务)
SELECT COUNT(*) AS affected_sa_count
FROM service_applications sa
WHERE sa.status IN ('approved', 'in_progress', 'completed')
  AND sa.task_id IS NOT NULL;

-- 2. 其中属于 team service 的(真正受 team 可见性影响的子集;
-- 个人服务虽然字段也被覆盖,但 owner 一人可见不构成可见性问题)
SELECT COUNT(*) AS affected_team_sa_count
FROM service_applications sa
JOIN tasks t ON t.id = sa.task_id
WHERE sa.status IN ('approved', 'in_progress', 'completed')
  AND t.taker_expert_id IS NOT NULL;

-- 3. 这些 team 里的非 owner 成员数(可见性实际受影响人数上限)
SELECT COUNT(DISTINCT em.user_id) AS affected_team_member_count
FROM service_applications sa
JOIN tasks t ON t.id = sa.task_id
JOIN expert_members em ON em.expert_id = t.taker_expert_id
WHERE sa.status IN ('approved', 'in_progress', 'completed')
  AND t.taker_expert_id IS NOT NULL
  AND em.role != 'owner';

-- 4. 已知丢失消息数(在 task_source='consultation' + status='closed' 的旧占位上,
-- 即 approve 后孤立的咨询消息)
SELECT COUNT(*) AS orphaned_messages
FROM messages m
JOIN tasks t ON t.id = m.task_id
WHERE t.task_source = 'consultation'
  AND t.status = 'closed'
  AND m.conversation_type = 'task';
```

### 决策分支

| 诊断结果 | 对策 |
|---|---|
| affected_team_sa_count < 50 **且** orphaned_messages < 500 | 接受技术债,不回填;客服 case-by-case 处理投诉 |
| affected_team_sa_count 50-500 | 跑 best-effort 回填脚本(见下),客户侧兜底客服 |
| affected_team_sa_count > 500 | 必须做自动回填 + 提前发公告 |

### Best-effort 回填脚本(可选,`migration 211` 或独立脚本)

**启发式匹配**:根据"占位 task 的 poster/taker pair + service_id 线索 + 创建时间窗"反查每个已 approve SA 的原始占位 task id。

```sql
-- 候选关联:找每个 team-service approved SA 的"最可能的原始占位 task"
-- 匹配条件:
-- a) 占位 task status='closed', task_source='consultation'
-- b) 占位 task 的 poster_id = SA 的 applicant_id
-- c) 占位 task 的 created_at < 真任务 created_at (因果顺序)
-- d) 若有多个候选,取 created_at 最接近真任务的

-- 先预览结果不写入
WITH candidates AS (
  SELECT
    sa.id AS sa_id,
    sa.task_id AS real_task_id,
    t_real.created_at AS real_created_at,
    placeholder.id AS placeholder_task_id,
    placeholder.created_at AS placeholder_created_at,
    ROW_NUMBER() OVER (
      PARTITION BY sa.id
      ORDER BY placeholder.created_at DESC
    ) AS rn
  FROM service_applications sa
  JOIN tasks t_real ON t_real.id = sa.task_id
  JOIN tasks placeholder ON (
    placeholder.task_source = 'consultation'
    AND placeholder.status = 'closed'
    AND placeholder.poster_id = sa.applicant_id
    AND placeholder.created_at < t_real.created_at
    AND placeholder.created_at > t_real.created_at - INTERVAL '30 days'
  )
  WHERE sa.status IN ('approved', 'in_progress', 'completed')
    AND sa.consultation_task_id IS NULL
    AND t_real.taker_expert_id IS NOT NULL
)
SELECT sa_id, real_task_id, placeholder_task_id FROM candidates WHERE rn = 1;
-- 人工审核几行结果合理后,改成 UPDATE:
-- UPDATE service_applications SET consultation_task_id = <placeholder_task_id> WHERE id = <sa_id>;
```

**局限**:
- 精度不是 100%(如果用户对同一个 service 发起过多次咨询最终只成单一次,可能匹配错)
- TA / FMPR 的回填逻辑同理,脚本模板相似,需要分别写
- 建议:只回填 `rn = 1` 且"时间窗 < 3 天"的高置信度条目;其余留给客服

### 客服兜底流程

若有用户投诉"我是 team 成员但看不到已 approve 咨询的历史消息":
1. 客服查 `tasks` 表找 `task_source='consultation'` + `poster_id=<applicant>` + 最近 30 天内
2. 找到匹配的占位 task_id,手动更新对应 SA.consultation_task_id
3. 用户刷新即可看到历史

---

## 测试策略

### 后端(pytest)

新增测试文件 `backend/tests/test_consultation_placeholder_upgrade.py`:

1. `test_overwrite_backs_up_consultation_task_id_team` — team 服务 approve 后 `SA.consultation_task_id = 旧 task_id`,`SA.task_id = 新 task_id`
2. `test_overwrite_backs_up_consultation_task_id_personal` — 个人服务同上
3. `test_overwrite_idempotent` — 重复 approve 不会把新 task_id 写进 consultation_task_id
4. `test_flea_market_promote_sets_consultation_task_id` — flea_market 付款后 `FMPR.consultation_task_id = task.id`,`task.is_consultation_placeholder=False`
5. `test_stale_cleanup_covers_task_consultation` — 14 天无活动的 `task_consultation` 占位被清理(B3 修复验证)
6. `test_stale_cleanup_still_covers_service_and_flea_market` — 原有两类仍被清理(回归)
7. `test_task_api_rejects_placeholder_payment` — `POST /tasks/{占位 id}/pay` 返回 404(**抽样**:从 16 个拦截点中覆盖 pay)
8. `test_task_api_rejects_placeholder_write_sample` — **抽样**覆盖写操作 complete / review / cancel 都返回 404(不逐个测 11 个写端点;守卫 helper 是单一实现,共用逻辑,抽样足以防回归)
9. `test_admin_task_list_excludes_placeholders_by_default` — admin 默认看不到占位
10. `test_admin_task_list_include_placeholders_flag` — `?include_placeholders=true` 能看到
11. `test_check_constraint_rejects_inconsistent_flag_and_source` — 试图 `UPDATE tasks SET is_consultation_placeholder=TRUE` 但保留非咨询 `task_source`,DB 抛 IntegrityError(验证 A.1 的 CHECK 约束)
12. `test_create_placeholder_task_sets_both_fields` — `create_placeholder_task` helper 同时设置 `task_source` 和 `is_consultation_placeholder=True`(回归,防止以后有人只改其中一个)
13. `test_require_team_role_used_by_guarded_endpoints` — 随机抽 2-3 个团队守卫的 endpoint,验证 403 返回的 detail.code 是 `INSUFFICIENT_TEAM_ROLE`(确认迁移生效,不是 inline 实现漏改)。**依赖 Track 1 F3 已合入**(`require_team_role` helper 以此错误码形式抛 HTTPException);PR 2/3 合入前需 verify Track 1 已 merge
14. `test_ta_formal_apply_creates_orig_application_with_consultation_task_id` — B.2.3 验证:task consultation → formal apply 后,新建的 `orig_application` 的 `consultation_task_id` 指向占位 task
15. `test_ta_formal_apply_cancels_placeholder_ta` — B.2.3 验证:formal apply 后占位 TA 状态为 `cancelled`,不是 `pending`
16. `test_consultation_task_id_for_all_scenarios` — C.3 统一规则 helper 覆盖 **C.3 分场景表全部 7 种场景**(SA 2 + TA 3 + FMPR 2)+ NULL 边界

### Flutter(bloc_test + model test)

1. `service_application_model_test.dart` — `consultationTaskId` 从 JSON 正确解析 + `ServiceApplicationConsultationRoute.consultationMessageTaskId` 覆盖 SA 2 种场景(approve 前/后)
2. `task_application_model_test.dart` — `consultationTaskId` 解析 + extension 覆盖 TA 3 种场景(占位咨询中 / 占位 cancelled 后 / `orig_application`)
3. `flea_market_purchase_request_model_test.dart` — `consultationTaskId` 解析 + extension 覆盖 FMPR 2 种场景(咨询中 / 晋升后),且断言"FMPR 晋升后 consultationTaskId == taskId 但判断用 isConsultationPlaceholder"
4. `task_model_test.dart` — `isConsultationPlaceholder` 字段解析
5. `consultation_route_extensions_test.dart` — 三个 extension **各自独立断言** NULL 边界(SA/TA/FMPR 各 1 条,共 3 条,都测 consultationTaskId 和 taskId 都为 null 时 getter 返回 null)。虽然实现相同,分开断言保证后续有人改某个 model 的 extension 时不会漏测

### 集成测试

本 spec 不新增 e2e 集成测试;staging 手工验证:
- 完整走一次"张三咨询→议价→李四 approve→张三付款→完成→评价"流程
- 验证 team 非 owner 成员能通过 `consultation_task_id` 看到咨询历史消息

---

## 风险和回滚

| 风险 | 影响 | 缓解 |
|---|---|---|
| **CHECK 约束 vs 滚动更新窗口期冲突**(self-review E) | 旧代码仍在接请求时,新约束已生效,旧代码创建咨询返回 500 | **拆 208a / 208b 两次 migration**,208b 必须等新代码完全接管(Day 2)才跑,208b 开头有兜底 UPDATE |
| Migration 208a 的 UPDATE 在大表上锁表 | `tasks` 表写入阻塞数分钟 | 如果 `tasks` 表已超过 500 万行,改成分批 UPDATE(WHERE id BETWEEN... LIMIT 10000)。当前估计规模可接受 |
| 新字段回填遗漏占位 task | stale cleanup 漏清理 | 回填 SQL 覆盖所有 `task_source IN (...)`,且不依赖代码路径;完成后 COUNT 验证 |
| Overwrite 修复的备份逻辑幂等失败 | consultation_task_id 被真任务 id 错误覆盖 | `if not application.consultation_task_id` 守卫 + 单测 3 覆盖 |
| Task API 守卫漏掉某个 endpoint | 占位 task 仍可被调用 | 用 grep `@router.*"/tasks/{task_id}"` 完整枚举,不漏掉 |
| Flea market 晋升逻辑改动破坏现有支付流 | 商品购买断裂 | 晋升代码只加 2 行,不改现有逻辑;回归测试覆盖 |
| **Flea market 晋升两字段赋值之间 flush** | 中间态违反 CHECK 约束,commit 失败 | SQLAlchemy ORM 的两字段 Python 赋值在一次 flush 产出单条 UPDATE,天然原子。**PR review 必须确认 B.3 的两行之间没有 `db.flush()` / `db.commit()` / 查询(隐式 flush)调用**——否则两字段分成两条 UPDATE,中间态违反 CHECK |
| Admin 默认过滤导致客服看不到需要处理的占位 | 客服工作流受阻 | `?include_placeholders=true` 参数保留穿透;上线前和客服同步 |
| 208b 跑时仍有少量 FALSE+咨询 source 的 task(旧代码漏写 flag) | ADD CONSTRAINT 失败或 208b 执行后旧数据违反 | 208b 开头的兜底 UPDATE 兜所有这类行 |
| **手动 DELETE 占位 task 导致咨询消息丢失**(self-review S7) | `messages.task_id` FK 是 `ON DELETE CASCADE`,删除占位 task 会连带删消息;`consultation_task_id ON DELETE SET NULL` 救不了消息,只救 SA/TA/FMPR 记录 | **文档层约束**:不要 `DELETE FROM tasks WHERE is_consultation_placeholder=TRUE` 清理占位,只能 `UPDATE status='closed'`。**PR 1 同步在 `backend/docs/` 下追加说明**(可选位置:追加到 `TASK_SCHEDULER_GUIDE.md` 一节,或新建独立 `consultation_placeholder_maintenance.md`——实施时按当前文档组织选最合适的),标题"占位 task 维护注意",说明 DELETE 禁令 + 原因。如果未来真要物理清理,必须先把 messages.task_id FK 改成 SET NULL 或手动清关联消息 |

**回滚**:
- Migration 208a / 208b / 209 可反向 `DROP COLUMN` / `DROP CONSTRAINT`(新列无数据丢失)
- 代码改动分 3 个核心 PR + 1 个可选 PR:
  - **PR 1**: Migration **208a**(列+回填,不加 constraint)+ **209** + models + helper 扩展(create_placeholder_task + consultation_task_id_for)+ 3 处创建点迁移 + 守卫 helper(不应用)+ admin/统计过滤
  - **PR 2**: Migration **208b**(CHECK 约束)+ SA overwrite 备份(B.2.1) + TA 正式转换修复(B.2.3) + FMPR 晋升(B.3) + stale cleanup 修复(B.4)
  - **PR 3**: 18 个 task API 守卫应用 + 顺手迁移 team role + Flutter 四个 model + 三个 extension
  - **PR 4**(可选,按 Day 0 诊断结果决定): migration 211 历史 best-effort 回填
- 每个 PR 可以独立 revert,但 PR 2/3 依赖 PR 1 的 migration 列存在;PR 2 的 208b 依赖 PR 1 先完全上线(见"上线顺序" Day 1→Day 2 的窗口期要求);PR 4 依赖 PR 2 的语义(不依赖代码)

---

## 上线顺序

### Day 0 — 诊断(上线前)

1. 在 staging 和 prod 跑 Section G 的 4 条诊断 SQL(只读,零风险)
2. 看 `affected_team_sa_count` 和 `orphaned_messages`,决定是否跑 best-effort 回填(`migration 211` 要不要写)
3. 无论走哪条路径,Day 1-3 的主体工作照做

### ⚠️ 部署顺序硬约束(回应 self-review P6)

#### 单 PR 内:migration 必须先于代码

每个 PR 内部:**migration 必须在代码部署之前跑完**。Railway 默认 migration 和代码同步部署没问题;如果走手动部署或蓝绿发布,务必:

```
1. Pull request merged
2. Railway triggers deploy
3. Migration 先跑(新列/约束生效)
4. 代码才启动(新代码引用新列)
```

否则新代码会因为 "column does not exist" 在启动时崩溃。PR 内的 migration 和代码改动**必须同 commit / 同 PR**,不能拆开跨次部署。

#### 跨 PR:208b 绝不能混进 PR 1

**关键约束**(self-review E):CHECK 约束(208b)**必须放到 PR 2**,绝不能提前到 PR 1 和 208a 一起上。原因:

```
PR 1 部署时:
  ├─ migration 208a 跑完(列加了,没约束)
  ├─ 新容器启动(新代码写 is_consultation_placeholder=TRUE)
  └─ 旧容器仍在接请求(旧代码写 default FALSE)  ← 这个窗口存在

如果 208b 和 208a 一起跑:
  旧代码创建 `task_source='consultation'` + `is_consultation_placeholder=FALSE`
  → 违反 CHECK → 旧容器返回 500 给用户  ❌

拆开后:
  PR 1:208a 跑完,旧代码创建的"违规"行被容忍(没约束)
  观察期:等所有旧容器退役,新容器全接管
  PR 2:208b 跑兜底 UPDATE 修正 PR 1 期间旧代码写错的行 → 加 CHECK 约束  ✅
```

观察期标志:Day 1 步骤 9 的 `SELECT COUNT(*) ... WHERE flag=FALSE AND source IN (3种) AND created_at > '<PR1 时间>'` 连续 24 小时为 0。

### Day 1 — DB(不含 CHECK) + Models + Helper 扩展 + 创建点迁移(PR 1)

1. 合 **migration 208a**(ADD COLUMN + 回填,**不加** CHECK 约束) + migration 209
2. 合 models.py 新字段(Task 加 `is_consultation_placeholder`;三个 Application 表加 `consultation_task_id`)
3. 合 `consultation/helpers.py::create_placeholder_task` 加 `is_consultation_placeholder=True` 一行
4. 合 `consultation/helpers.py::consultation_task_id_for(app)` helper(C.3 规则)
5. 合 3 个 inline 创建点迁移到 helper(回应 review 第 6 条)
6. 合 `task_guards.py` helper(但不应用)
7. 合 admin 默认过滤 + 用户主页"我发布 N 条任务"过滤
8. Staging 验证:新创建的咨询 task 带 flag;三个创建点都走 helper;admin 面板默认不显示占位
9. **观察 24-48 小时**:确认生产上所有新创建占位 task 的 `is_consultation_placeholder=TRUE`(通过查询 `SELECT COUNT(*) FROM tasks WHERE task_source IN (3种) AND is_consultation_placeholder=FALSE AND created_at > '<PR1 部署时间>'`,结果应为 0)

### Day 2 — CHECK 约束 + Bug 修(PR 2)

1. 合 **migration 208b**(CHECK 约束 + 兜底 UPDATE)—— **必须确认 Day 1 观察期结果为 0 才能跑**
2. 合 SA overwrite 备份逻辑(B.2.1,2 处)
3. 合 TA 正式转换修复(B.2.3):`orig_application` 加 `consultation_task_id=task_id` + 占位 TA 状态 `pending` → `cancelled`
4. 合 flea market 晋升逻辑(两字段原子改,满足 CHECK 约束)
5. 合 stale cleanup 修复(加 `task_consultation` 分支 + 防御性 else)
6. 合配套单测(1-6, 11-12, 14-16)
7. Staging 验证:新 approve 的 SA/TA/FMPR 都有正确的 `consultation_task_id`;stale cleanup log 覆盖三类;`consultation_task_id_for` helper 7 种场景全跑通;CHECK 约束挡住不一致写入(pytest test 11)

### Day 3 — 守卫应用 + team role 迁移 + Flutter(PR 3)

1. 18 个 task API 替换 `db.get` → `load_real_task_or_404`
2. **顺手**迁移其中 6-8 个的 inline team check → `require_team_role`
3. Admin 路径加 warning 日志
4. 合配套单测(7-10, 13)
5. Flutter 改 **4 个 model**(SA/TA/FMPR/Task)+ **三个独立 extension**(SA/TA/FMPR 各自的 `consultationMessageTaskId` getter,见 F.3 方式 a)
6. 合 Flutter 测试 1-5
7. Staging 验证:拿一个占位 task_id 手测所有业务 API 返 404;team 权限守卫的 403 返回 `INSUFFICIENT_TEAM_ROLE` 错误码;Flutter 打开咨询消息 7 种场景(见 C.3 分场景表)均工作

### Day 3.5(可选)— 历史回填(PR 4,只在 Day 0 诊断显示需要时做)

1. 写 `migration 211_backfill_consultation_task_id.sql`(用 Section G 的启发式脚本)
2. 先在 staging 跑 preview 模式看匹配结果
3. 人工审核 20 条样本,确认匹配合理
4. 在 prod 跑 UPDATE(高置信度条目),其余留客服
5. 发内部通告给客服培训 Section G 的手动处理流程

### 观察期(1 周)

- 监控 `logger.warning("Admin operation on consultation placeholder task")` 条数,判断客服是否需要 `?include_placeholders=true`
- 观察 `ix_tasks_consultation_placeholder_status` 索引使用情况,确认 stale cleanup 性能正常

---

## 成功标准

- [ ] Migration 208a + 208b + 209 全部合入,所有历史占位 task 被正确标记,CHECK 约束生效
- [ ] PR 1→PR 2 之间观察期内,"FALSE+咨询 source" 的新插入行数连续 24 小时为 0
- [ ] **SA** approve 后保留 `consultation_task_id`,历史消息可通过此字段找回(B.2.1)
- [ ] **TA** formal apply 后 `orig_application` 有正确 `consultation_task_id`,占位 TA 状态为 `cancelled` 不再是 `pending`(B.2.3)
- [ ] **FMPR** 付款晋升后 task 的 `is_consultation_placeholder=False` + `consultation_task_id` 写入(B.3)
- [ ] B3 修复:`task_consultation` 类型的 stale task 被 14 天清理覆盖
- [ ] **16 个** task-level API 对占位 task_id 返回 404 + **2 个 admin endpoint** 触碰占位时打 warning 日志(合计 D.2 的 18 处)
- [ ] Track 1 `create_placeholder_task` helper 被 4 处 caller 使用(不再是半成品)
- [ ] Track 1 `require_team_role` helper 被 6-8 个 endpoint 使用(不再是死代码)
- [ ] **C.3 `consultation_task_id_for` helper** 在后端存在,Flutter 有三个独立 extension,所有"打开咨询聊天"路径统一调它
- [ ] Admin 面板默认不显示占位 task
- [ ] 用户主页"我发布 N 条任务"不含占位
- [ ] Flutter 4 个 model(SA/TA/FMPR/Task)都加新字段 + 三个 extension
- [ ] 新增测试 ≥ 21 个(后端 16 + Flutter 5),全部通过
- [ ] Staging 完整 e2e 走通 + team 成员能看到 approve 后的咨询历史 + C.3 **7 种场景**全工作
- [ ] Section G 诊断 SQL 跑过,影响面已量化并记录
- [ ] 无生产流量回归(现有咨询/任务流程行为不变)

---

## 附录:为什么选方案 Y(`consultation_task_id`)而不是方案 X(`fulfillment_task_id`)

讨论阶段曾考虑"`SA.task_id` 永远指占位 + 新字段 `fulfillment_task_id` 指真任务"(方案 X)。最终选择方案 Y(保持 `SA.task_id` 现有语义 + 新字段 `consultation_task_id`),原因:

1. **业务约定**:Link2Ur 的交易/评价/争议/完成都发生在真任务上,"`SA.task_id` 指当前业务任务"是现有代码和开发者心智模型的基础。方案 X 反转此约定
2. **改动面**:方案 X 需审计 15 处 `.task_id` 读取点 + 改通知/AI/推荐等引用;方案 Y 零读取点审计
3. **工程量**:方案 X 估 4-5 天;方案 Y 估 3.5-4.5 天(初版 2-3 天,两轮 self-review 后加入创建点迁移 / team role 迁移 / 诊断 SQL / TA 独立分支处理 / migration 拆分 208a+208b)
4. **修复效果等价**:两个方案对 B1/B2/B3/占位污染的修复效果相同
5. **历史兼容**:方案 Y 不改变现状 API 行为,Flutter 老版本无感知;方案 X 要求 Flutter 分辨两个 task_id 字段
