-- Fix: add columns that were added to 125 after it had already been executed on production
-- These columns exist in the SQLAlchemy model but may be missing from the DB

-- Personal service columns (may have been missed if 125 ran before they were added)
ALTER TABLE task_expert_services
  ADD COLUMN IF NOT EXISTS service_type VARCHAR(20) NOT NULL DEFAULT 'expert',
  ADD COLUMN IF NOT EXISTS user_id VARCHAR(8) REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS pricing_type VARCHAR(20) NOT NULL DEFAULT 'fixed',
  ADD COLUMN IF NOT EXISTS location_type VARCHAR(20) NOT NULL DEFAULT 'online';

-- Make expert_id nullable (idempotent — safe to re-run)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'task_expert_services'
    AND column_name = 'expert_id'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE task_expert_services ALTER COLUMN expert_id DROP NOT NULL;
  END IF;
END $$;

-- Service application columns
ALTER TABLE service_applications
  ADD COLUMN IF NOT EXISTS service_owner_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'service_applications'
    AND column_name = 'expert_id'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE service_applications ALTER COLUMN expert_id DROP NOT NULL;
  END IF;
END $$;

-- Indexes (safe with IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_task_expert_services_type_status
  ON task_expert_services(service_type, status);

CREATE INDEX IF NOT EXISTS idx_task_expert_services_user_id
  ON task_expert_services(user_id);

-- Backfill service_owner_id
UPDATE service_applications sa
SET service_owner_id = te.id
FROM task_experts te
WHERE sa.expert_id = te.id AND sa.service_owner_id IS NULL;
