ALTER TABLE task_expert_services
  ADD COLUMN IF NOT EXISTS location VARCHAR(100),
  ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
  ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);

-- Only create this index if location_type column exists (it might not if 125 ran before the column was added)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'task_expert_services' AND column_name = 'location_type'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_task_expert_services_location_type_coords
      ON task_expert_services(location_type)
      WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
  END IF;
END $$;
