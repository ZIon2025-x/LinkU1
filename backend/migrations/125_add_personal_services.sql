-- Add columns to task_expert_services
ALTER TABLE task_expert_services
  ALTER COLUMN expert_id DROP NOT NULL;

ALTER TABLE task_expert_services
  ADD COLUMN IF NOT EXISTS service_type VARCHAR(20) NOT NULL DEFAULT 'expert',
  ADD COLUMN IF NOT EXISTS user_id VARCHAR(8) REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS pricing_type VARCHAR(20) NOT NULL DEFAULT 'fixed',
  ADD COLUMN IF NOT EXISTS location_type VARCHAR(20) NOT NULL DEFAULT 'online';

CREATE INDEX IF NOT EXISTS idx_task_expert_services_type_status
  ON task_expert_services(service_type, status);

CREATE INDEX IF NOT EXISTS idx_task_expert_services_user_id
  ON task_expert_services(user_id);

-- Add columns to service_applications
ALTER TABLE service_applications
  ALTER COLUMN expert_id DROP NOT NULL;

ALTER TABLE service_applications
  ADD COLUMN IF NOT EXISTS service_owner_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL;

-- Backfill service_owner_id for existing applications
UPDATE service_applications sa
SET service_owner_id = te.id
FROM task_experts te
WHERE sa.expert_id = te.id AND sa.service_owner_id IS NULL;
