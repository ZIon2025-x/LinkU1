-- Migration 096: Fix official activity columns
-- Migration 095 combined ALTER COLUMN DROP NOT NULL with ADD COLUMN in one statement.
-- If DROP NOT NULL failed, the entire ALTER TABLE was rolled back and the new columns
-- were never created. This migration re-adds them individually.

-- Step 1: Make expert_service_id nullable (separate statement so failure won't block others)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'activities'
        AND column_name = 'expert_service_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE activities ALTER COLUMN expert_service_id DROP NOT NULL;
    END IF;
END $$;

-- Step 2: Add each column individually so one failure doesn't block others
ALTER TABLE activities ADD COLUMN IF NOT EXISTS activity_type VARCHAR(20) NOT NULL DEFAULT 'standard';
ALTER TABLE activities ADD COLUMN IF NOT EXISTS prize_type VARCHAR(20);
ALTER TABLE activities ADD COLUMN IF NOT EXISTS prize_description TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS prize_description_en TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS prize_count INTEGER;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS voucher_codes JSONB;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS draw_mode VARCHAR(10);
ALTER TABLE activities ADD COLUMN IF NOT EXISTS draw_at TIMESTAMP;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS drawn_at TIMESTAMP;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS winners JSONB;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS is_drawn BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_activities_activity_type ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_draw_at ON activities(draw_at) WHERE is_drawn = FALSE;

-- Step 3: Ensure official_activity_applications table exists
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

-- Step 4: Ensure task_experts official fields exist
ALTER TABLE task_experts ADD COLUMN IF NOT EXISTS is_official BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE task_experts ADD COLUMN IF NOT EXISTS official_badge VARCHAR(50);
CREATE INDEX IF NOT EXISTS idx_task_experts_is_official ON task_experts(is_official);
