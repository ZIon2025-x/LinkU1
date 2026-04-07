-- ===========================================
-- 迁移 176: tasks 加 taker_expert_id 列
-- spec §1.1
-- ===========================================
BEGIN;

ALTER TABLE tasks
  ADD COLUMN taker_expert_id VARCHAR(8) NULL
    REFERENCES experts(id) ON DELETE RESTRICT;

CREATE INDEX ix_tasks_taker_expert
  ON tasks(taker_expert_id)
  WHERE taker_expert_id IS NOT NULL;

COMMENT ON COLUMN tasks.taker_id IS
  '任务接单自然人。团队接单时填团队 owner 的 user_id 作为"团队代表"。';
COMMENT ON COLUMN tasks.taker_expert_id IS
  '团队接单时的经济主体。非 NULL 时钱转到 experts.stripe_account_id。';

COMMIT;
