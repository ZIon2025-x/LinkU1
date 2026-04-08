-- ===========================================
-- 迁移 178: 扩展 payment_transfers 支持团队接单
-- spec §1.3 (v2)
-- ===========================================
BEGIN;

-- 1. 加新字段
ALTER TABLE payment_transfers
  ADD COLUMN taker_expert_id VARCHAR(8) NULL
    REFERENCES experts(id) ON DELETE RESTRICT,
  ADD COLUMN idempotency_key VARCHAR(64) NULL,
  ADD COLUMN stripe_charge_id VARCHAR(255) NULL,
  ADD COLUMN stripe_reversal_id VARCHAR(255) NULL,
  ADD COLUMN reversed_at TIMESTAMPTZ NULL,
  ADD COLUMN reversed_reason TEXT NULL;

-- 2. 回填现有行的 idempotency_key
UPDATE payment_transfers
SET idempotency_key = 'legacy_' || id::text
WHERE idempotency_key IS NULL;

-- 3. 加约束
ALTER TABLE payment_transfers
  ALTER COLUMN idempotency_key SET NOT NULL,
  ADD CONSTRAINT uq_payment_transfers_idempotency UNIQUE (idempotency_key);

-- 4. 索引
CREATE INDEX ix_pt_taker_expert
  ON payment_transfers(taker_expert_id)
  WHERE taker_expert_id IS NOT NULL;

CREATE INDEX ix_pt_charge
  ON payment_transfers(stripe_charge_id)
  WHERE stripe_charge_id IS NOT NULL;

-- 5. status 取值约束
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_payment_transfers_status'
  ) THEN
    ALTER TABLE payment_transfers
      ADD CONSTRAINT chk_payment_transfers_status
      CHECK (status IN ('pending','succeeded','failed','retrying','reversed'));
  END IF;
END $$;

COMMENT ON COLUMN payment_transfers.taker_expert_id IS
  '团队接单时填团队 ID。非 NULL 时 destination 是 experts.stripe_account_id。';
COMMENT ON COLUMN payment_transfers.idempotency_key IS
  '幂等键。新行: task_{task_id}_transfer。老行: legacy_{id}。';

COMMIT;
