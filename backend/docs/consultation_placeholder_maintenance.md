# 咨询占位 Task 维护注意

本文档由 `docs/superpowers/specs/2026-04-18-consultation-upgrade-design.md` 的风险表 S7 产出。

## 关键约束:不要 DELETE 占位 task

`messages.task_id` FK 是 `ON DELETE CASCADE`。删除 `is_consultation_placeholder=TRUE` 的 task 会**级联删掉所有咨询消息**。

### ❌ 禁止的操作

```sql
DELETE FROM tasks WHERE is_consultation_placeholder = TRUE;  -- 不要!
```

### ✅ 正确的方式

只更新状态,保留 task row + 消息:

```sql
UPDATE tasks SET status = 'closed'
WHERE is_consultation_placeholder = TRUE
  AND status = 'consulting'
  AND created_at < now() - interval '14 days';
```

已有 `backend/app/scheduled_tasks.py` 的 stale cleanup 自动做这件事,每 14 天关闭一次无活跃占位。不需要手动 DELETE。

### 如果未来真的需要物理清理占位 task

必须先:
1. 把 `messages.task_id` FK 改成 `ON DELETE SET NULL`(写新 migration)
2. 或在 DELETE 前手动 archive / 删除相关 messages
3. 考虑级联影响:`service_applications.consultation_task_id` / `task_applications.consultation_task_id` / `flea_market_purchase_requests.consultation_task_id` FK 是 `ON DELETE SET NULL`(不会级联删申请记录,只清空引用)

## 客服手动处理"看不到咨询历史"投诉

### 症状

用户(特别是**团队非 owner 成员**)报告"我是 team 成员,为什么看不到已 approve 咨询的历史消息"。

### 原因(历史 bug)

2026-04-18 之前代码有 bug:approve 服务申请时 `SA.task_id` 被覆盖成真任务 id,原咨询占位 task id 从 `ServiceApplication` 表里丢失。team 非 owner 成员通过 `SA.task_id` JOIN `ExpertMember` 鉴权后找不到占位 task 的历史消息。

2026-04-18 之后新 approve 的 SA 会自动 backup 占位 id 到 `SA.consultation_task_id`,但**历史已经 approve 的 SA 无法恢复**(占位 id 丢失)。

### 手工修复步骤

1. **查找用户在该服务下的占位 task**:

```sql
SELECT t.id AS placeholder_task_id, t.created_at, t.status
FROM tasks t
WHERE t.task_source = 'consultation'
  AND t.poster_id = '<applicant_user_id>'      -- 用户的 User.id
  AND t.created_at >= '<approx_date - 30 days>'  -- 申请前后 30 天窗口
ORDER BY t.created_at DESC;
```

找到时间上最接近用户投诉对应的 `ServiceApplication` 的占位 task。

2. **更新 SA.consultation_task_id**:

```sql
UPDATE service_applications
SET consultation_task_id = <placeholder_task_id>
WHERE id = <sa_id>
  AND consultation_task_id IS NULL;  -- 只处理未回填的
```

3. **用户刷新**:用户下次打开任务详情即可看到历史咨询消息(通过 `SA.consultation_task_id` 路由)。

4. **确认成功**:让用户确认能看到历史。若仍看不到,可能是客户端缓存问题 — 要求用户重新登录或清除 app 缓存。

### 如果匹配不唯一或模糊

若 step 1 查到多个候选占位 task(用户对同一服务发起过多次咨询),**不要盲选**。采取以下之一:
- 让用户描述记忆中的咨询时间,缩小时间窗后重查
- 把候选列表(taker_id, created_at, closed_at)给用户看,让用户辨认
- 若无法确定,回复用户"技术原因暂无法恢复,抱歉"

### 同样流程适用于 TA 和 FMPR

TA:
```sql
UPDATE task_applications SET consultation_task_id = <placeholder_task_id>
WHERE id = <ta_id> AND consultation_task_id IS NULL;
```

FMPR:
```sql
UPDATE flea_market_purchase_requests SET consultation_task_id = <placeholder_task_id>
WHERE id = <fmpr_id> AND consultation_task_id IS NULL;
```

## 参考

- Spec: `docs/superpowers/specs/2026-04-18-consultation-upgrade-design.md`
- Migrations: `backend/migrations/208a_*.sql`, `208b_*.sql`, `209_*.sql`
- Stale cleanup: `backend/app/scheduled_tasks.py::close_stale_consultations`
- Helper: `backend/app/consultation/helpers.py::consultation_task_id_for`
