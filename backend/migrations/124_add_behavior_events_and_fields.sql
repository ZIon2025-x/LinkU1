-- 用户行为事件表
CREATE TABLE IF NOT EXISTS user_behavior_events (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type VARCHAR(32) NOT NULL,
    event_data JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_behavior_events_user_created
    ON user_behavior_events(user_id, created_at);

-- UserDemand 表改动
ALTER TABLE user_demand ALTER COLUMN user_stage TYPE JSONB USING to_jsonb(user_stage);
ALTER TABLE user_demand ADD COLUMN IF NOT EXISTS identity VARCHAR(16);
ALTER TABLE user_demand ADD COLUMN IF NOT EXISTS inferred_skills JSONB DEFAULT '[]';
ALTER TABLE user_demand ADD COLUMN IF NOT EXISTS inferred_preferences JSONB DEFAULT '{}';

-- UserProfilePreference 新增 city
ALTER TABLE user_profile_preferences ADD COLUMN IF NOT EXISTS city VARCHAR(64);

-- User 新增 onboarding_completed
ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;
