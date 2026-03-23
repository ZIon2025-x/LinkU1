ALTER TABLE task_expert_services
  ADD COLUMN IF NOT EXISTS location VARCHAR(100),
  ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
  ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);

CREATE INDEX IF NOT EXISTS idx_task_expert_services_location_type_coords
  ON task_expert_services(location_type)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
