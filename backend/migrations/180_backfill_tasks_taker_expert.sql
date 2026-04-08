-- ===========================================
-- 迁移 180: 回填 in-flight 任务的 taker_expert_id
-- spec §6.2
--
-- (no-run) — 这是一次性数据迁移,不在此 session 执行
-- 上线前必须先跑 180_backfill_tasks_taker_expert_PREAUDIT.sql 检查多团队冲突
-- ===========================================

BEGIN;

-- 1. 用临时表收集本次回填涉及的 task_id（DISTINCT ON 选 owner 优先、joined_at 最早）
CREATE TEMP TABLE _backfill_180_candidates ON COMMIT DROP AS
SELECT DISTINCT ON (t.id)
    t.id AS task_id,
    em.expert_id,
    em.role
FROM tasks t
JOIN expert_members em ON em.user_id = t.taker_id
JOIN experts e ON e.id = em.expert_id
WHERE t.status IN ('pending', 'pending_payment', 'in_progress', 'disputed')
  AND t.taker_expert_id IS NULL
  AND (t.expert_service_id IS NOT NULL OR t.parent_activity_id IS NOT NULL)
  AND COALESCE(t.currency, 'GBP') = 'GBP'
  AND em.role IN ('owner', 'admin')
  AND em.status = 'active'
  AND e.status = 'active'
ORDER BY t.id,
         CASE em.role
             WHEN 'owner' THEN 0
             WHEN 'admin' THEN 1
             ELSE 2
         END,
         em.joined_at ASC;

-- 2. 执行回填
UPDATE tasks t
SET taker_expert_id = c.expert_id
FROM _backfill_180_candidates c
WHERE t.id = c.task_id
  AND t.taker_expert_id IS NULL;

-- 3. 报告本次实际回填的行数(精确计数,而不是全表 IS NOT NULL 计数)
DO $$
DECLARE
    backfilled_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO backfilled_count FROM _backfill_180_candidates;
    RAISE NOTICE 'Backfill 180: % in-flight tasks updated with taker_expert_id', backfilled_count;
END $$;

COMMIT;
