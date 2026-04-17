-- 205_add_nearby_btree_indexes_fix.sql
-- Re-create indexes from 204 without CONCURRENTLY (which fails inside transactions).
-- 204 was recorded as success but all 3 indexes failed to create.

-- tasks table: composite B-tree for bounding box queries
CREATE INDEX IF NOT EXISTS idx_tasks_lat_lng_btree
  ON tasks (latitude, longitude)
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND status IN ('open', 'in_progress')
    AND is_visible = true;

-- task_expert_services table: composite B-tree for nearby service browse
CREATE INDEX IF NOT EXISTS idx_services_lat_lng_btree
  ON task_expert_services (latitude, longitude)
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND status = 'active'
    AND location_type IN ('in_person', 'both');

-- experts table: for COALESCE fallback when service inherits team coordinates
CREATE INDEX IF NOT EXISTS idx_experts_lat_lng_btree
  ON experts (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
