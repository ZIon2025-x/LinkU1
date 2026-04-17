-- 204_add_nearby_btree_indexes.sql
-- Add B-tree indexes for latitude/longitude range queries used by nearby sort
-- The existing GiST index (037) uses point() which doesn't help BETWEEN queries

-- tasks table: composite B-tree for bounding box (lat BETWEEN x AND y AND lng BETWEEN x AND y)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_lat_lng_btree
  ON tasks (latitude, longitude)
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND status IN ('open', 'in_progress')
    AND is_visible = true;

-- task_expert_services table: composite B-tree for nearby service browse
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_services_lat_lng_btree
  ON task_expert_services (latitude, longitude)
  WHERE latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND status = 'active'
    AND location_type IN ('in_person', 'both');

-- experts table: for COALESCE fallback when service inherits team coordinates
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_experts_lat_lng_btree
  ON experts (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
