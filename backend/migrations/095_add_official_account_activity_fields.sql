-- Migration 095: Add official account and activity fields
-- Run this on Railway PostgreSQL before deploying the updated backend

-- 1. Add official account fields to task_experts
ALTER TABLE task_experts
  ADD COLUMN IF NOT EXISTS is_official BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS official_badge VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_task_experts_is_official ON task_experts(is_official);

-- 2. Add official activity fields to activities
ALTER TABLE activities
  ALTER COLUMN expert_service_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS activity_type VARCHAR(20) NOT NULL DEFAULT 'standard',
  ADD COLUMN IF NOT EXISTS prize_type VARCHAR(20),
  ADD COLUMN IF NOT EXISTS prize_description TEXT,
  ADD COLUMN IF NOT EXISTS prize_description_en TEXT,
  ADD COLUMN IF NOT EXISTS prize_count INTEGER,
  ADD COLUMN IF NOT EXISTS voucher_codes JSONB,
  ADD COLUMN IF NOT EXISTS draw_mode VARCHAR(10),
  ADD COLUMN IF NOT EXISTS draw_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS drawn_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS winners JSONB,
  ADD COLUMN IF NOT EXISTS is_drawn BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_activities_activity_type ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_draw_at ON activities(draw_at) WHERE is_drawn = FALSE;

-- 3. Create official_activity_applications table
CREATE TABLE IF NOT EXISTS official_activity_applications (
    id SERIAL PRIMARY KEY,
    activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    applied_at TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','won','lost','attending')),
    prize_index INTEGER,
    notified_at TIMESTAMP,
    CONSTRAINT uq_official_app_activity_user UNIQUE (activity_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_official_apps_activity_id ON official_activity_applications(activity_id);
CREATE INDEX IF NOT EXISTS idx_official_apps_user_id ON official_activity_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_official_apps_status ON official_activity_applications(activity_id, status);
