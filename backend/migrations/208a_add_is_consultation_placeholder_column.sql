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
