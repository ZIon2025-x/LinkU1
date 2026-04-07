-- ===========================================
-- 迁移 179: tasks 加 payment_completed_at
-- spec §1.5
-- ===========================================
BEGIN;

ALTER TABLE tasks ADD COLUMN payment_completed_at TIMESTAMPTZ NULL;

CREATE INDEX ix_tasks_payment_completed_at
  ON tasks(payment_completed_at)
  WHERE payment_completed_at IS NOT NULL;

COMMENT ON COLUMN tasks.payment_completed_at IS
  '客户付款 Stripe charge 成功的时间。用于 Stripe Transfer 90 天时效检查 (spec §3.4a)。';

COMMIT;
