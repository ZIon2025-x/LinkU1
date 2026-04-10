-- backend/migrations/189_package_lifecycle_fields.sql
-- Add lifecycle fields to UserServicePackage, remove dead task_id column,
-- and enforce status enum via CHECK constraint.

BEGIN;

-- 1. Add new columns (all nullable for safe in-place migration)
ALTER TABLE user_service_packages
  ADD COLUMN IF NOT EXISTS cooldown_until TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS released_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS released_amount_pence INTEGER NULL,
  ADD COLUMN IF NOT EXISTS platform_fee_pence INTEGER NULL,
  ADD COLUMN IF NOT EXISTS refunded_amount_pence INTEGER NULL,
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS unit_price_pence_snapshot INTEGER NULL;

-- 2. Drop dead task_id column (never written or read by any code path)
ALTER TABLE user_service_packages DROP COLUMN IF EXISTS task_id;

-- 3. Status enum CHECK constraint
ALTER TABLE user_service_packages
  DROP CONSTRAINT IF EXISTS user_service_packages_status_check;

ALTER TABLE user_service_packages
  ADD CONSTRAINT user_service_packages_status_check
  CHECK (status IN (
    'active','exhausted','expired','released',
    'refunded','partially_refunded','disputed','cancelled'
  ));

-- 4. Indexes for scheduled jobs
CREATE INDEX IF NOT EXISTS ix_user_packages_status_expires
  ON user_service_packages (status, expires_at);

CREATE INDEX IF NOT EXISTS ix_user_packages_cooldown
  ON user_service_packages (cooldown_until)
  WHERE cooldown_until IS NOT NULL;

COMMIT;
