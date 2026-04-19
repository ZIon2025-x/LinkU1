-- 备份咨询占位 task id,用于 approve 后仍能找回咨询历史消息
-- 不回填历史数据(历史已 approve 的 SA 的占位 id 已在覆盖时丢失,接受此技术债)

ALTER TABLE service_applications
  ADD COLUMN IF NOT EXISTS consultation_task_id INTEGER NULL REFERENCES tasks(id) ON DELETE SET NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_sa_consultation_task_id
  ON service_applications (consultation_task_id)
  WHERE consultation_task_id IS NOT NULL;

ALTER TABLE task_applications
  ADD COLUMN IF NOT EXISTS consultation_task_id INTEGER NULL REFERENCES tasks(id) ON DELETE SET NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_ta_consultation_task_id
  ON task_applications (consultation_task_id)
  WHERE consultation_task_id IS NOT NULL;

ALTER TABLE flea_market_purchase_requests
  ADD COLUMN IF NOT EXISTS consultation_task_id INTEGER NULL REFERENCES tasks(id) ON DELETE SET NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_fmpr_consultation_task_id
  ON flea_market_purchase_requests (consultation_task_id)
  WHERE consultation_task_id IS NOT NULL;
