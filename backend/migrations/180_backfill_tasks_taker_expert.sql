-- ===========================================
-- 迁移 180: 回填 in-flight 任务的 taker_expert_id
-- spec §6.2
--
-- (no-run) — 这是一次性数据迁移,不在此 session 执行
-- 上线前必须先跑 180_backfill_tasks_taker_expert_PREAUDIT.sql 检查多团队冲突
-- ===========================================

BEGIN;

WITH candidate AS (
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
             em.joined_at ASC
)
UPDATE tasks t
SET taker_expert_id = c.expert_id
FROM candidate c
WHERE t.id = c.task_id
  AND t.taker_expert_id IS NULL;

-- 报告回填数量(staging 上观察)
DO $$
DECLARE
    backfilled_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO backfilled_count
    FROM tasks
    WHERE status IN ('pending', 'pending_payment', 'in_progress', 'disputed')
      AND taker_expert_id IS NOT NULL;
    RAISE NOTICE 'Backfilled in-flight tasks with taker_expert_id: %', backfilled_count;
END $$;

COMMIT;
