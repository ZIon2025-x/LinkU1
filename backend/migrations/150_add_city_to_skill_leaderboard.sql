-- 150_add_city_to_skill_leaderboard.sql
-- Add city column to skill_leaderboard for city-based ranking

ALTER TABLE skill_leaderboard ADD COLUMN IF NOT EXISTS city VARCHAR(50) NOT NULL DEFAULT 'all';

-- Index for city-filtered queries
CREATE INDEX IF NOT EXISTS idx_skill_leaderboard_city ON skill_leaderboard(skill_category, city, score DESC);
