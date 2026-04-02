-- 153_add_view_count_to_activities_and_categories.sql
-- Add view_count to activities and forum_categories for trending search aggregation

ALTER TABLE activities ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE forum_categories ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0;
