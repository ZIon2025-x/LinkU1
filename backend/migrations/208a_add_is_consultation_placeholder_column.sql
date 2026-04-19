-- 显式标记占位 task,取代脆弱的 task_source 字符串匹配
-- 此 migration 跑完后可以和旧代码共存,因为还没加 CHECK 约束

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS is_consultation_placeholder BOOLEAN NOT NULL DEFAULT FALSE;

-- 回填历史占位 task
UPDATE tasks
SET is_consultation_placeholder = TRUE
WHERE task_source IN ('consultation', 'task_consultation', 'flea_market_consultation')
  AND is_consultation_placeholder = FALSE
  AND status = 'consulting';  -- only rows that are actually still placeholders (protect already-promoted tasks)

-- 针对 stale cleanup 和 admin 过滤的局部索引
-- NOTE: 不用 CONCURRENTLY。项目 migration runner (app.db_migrations) 在 transaction block 内
-- 执行每个 migration,而 PostgreSQL 禁止 CONCURRENTLY 在 transaction 内。实测 2026-04-19
-- 部署时 CONCURRENTLY 语句被 runner swallow 成 WARNING 导致 index 未建成。改用普通 CREATE INDEX,
-- 在现有表规模下锁表时间毫秒级可忽略。若未来需要真正并发建索引,应手动 psql 执行,不入 migration。
CREATE INDEX IF NOT EXISTS ix_tasks_consultation_placeholder_status
  ON tasks (is_consultation_placeholder, status)
  WHERE is_consultation_placeholder = TRUE;
