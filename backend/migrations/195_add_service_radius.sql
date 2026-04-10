-- 195_add_service_radius.sql
-- Expert team: base address + default radius
ALTER TABLE experts ADD COLUMN latitude DECIMAL(10, 8) DEFAULT NULL;
ALTER TABLE experts ADD COLUMN longitude DECIMAL(11, 8) DEFAULT NULL;
ALTER TABLE experts ADD COLUMN service_radius_km INTEGER DEFAULT NULL;

-- Service: per-service radius override (lat/lng already exist)
ALTER TABLE task_expert_services ADD COLUMN service_radius_km INTEGER DEFAULT NULL;

-- Activity: coordinates + radius (only has text location today)
ALTER TABLE activities ADD COLUMN latitude DECIMAL(10, 8) DEFAULT NULL;
ALTER TABLE activities ADD COLUMN longitude DECIMAL(11, 8) DEFAULT NULL;
ALTER TABLE activities ADD COLUMN service_radius_km INTEGER DEFAULT NULL;
