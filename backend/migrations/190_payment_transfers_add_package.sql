-- backend/migrations/190_payment_transfers_add_package.sql
-- Add package_id nullable FK to payment_transfers, enforce task_id/package_id
-- mutual exclusivity via CHECK constraint.

BEGIN;

ALTER TABLE payment_transfers
  ADD COLUMN IF NOT EXISTS package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE payment_transfers
  DROP CONSTRAINT IF EXISTS payment_transfers_target_check;

ALTER TABLE payment_transfers
  ADD CONSTRAINT payment_transfers_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX IF NOT EXISTS ix_payment_transfers_package
  ON payment_transfers(package_id)
  WHERE package_id IS NOT NULL;

COMMIT;
