-- 用户画像系统：创建四维画像表
-- UserCapability, UserProfilePreference, UserReliability, UserDemand

-- 能力画像表
CREATE TABLE IF NOT EXISTS user_capabilities (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES skill_categories(id),
    skill_name VARCHAR(100) NOT NULL,
    proficiency VARCHAR(20) NOT NULL DEFAULT 'beginner',
    verification_source VARCHAR(20) NOT NULL DEFAULT 'self_declared',
    verified_task_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_capability UNIQUE (user_id, skill_name)
);

CREATE INDEX IF NOT EXISTS ix_user_capabilities_user_id ON user_capabilities(user_id);
CREATE INDEX IF NOT EXISTS ix_user_capabilities_category_id ON user_capabilities(category_id);

-- 偏好画像表
CREATE TABLE IF NOT EXISTS user_profile_preferences (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    mode VARCHAR(20) NOT NULL DEFAULT 'both',
    duration_type VARCHAR(20) NOT NULL DEFAULT 'both',
    reward_preference VARCHAR(20) NOT NULL DEFAULT 'no_preference',
    preferred_time_slots JSONB DEFAULT '[]'::jsonb,
    preferred_categories JSONB DEFAULT '[]'::jsonb,
    preferred_helper_types JSONB DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_user_profile_preferences_user_id ON user_profile_preferences(user_id);

-- 可靠度画像表
CREATE TABLE IF NOT EXISTS user_reliability (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    response_speed_avg FLOAT DEFAULT 0.0,
    completion_rate FLOAT DEFAULT 0.0,
    on_time_rate FLOAT DEFAULT 0.0,
    complaint_rate FLOAT DEFAULT 0.0,
    communication_score FLOAT DEFAULT 0.0,
    repeat_rate FLOAT DEFAULT 0.0,
    cancellation_rate FLOAT DEFAULT 0.0,
    reliability_score FLOAT,
    total_tasks_taken INTEGER DEFAULT 0,
    last_calculated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_user_reliability_user_id ON user_reliability(user_id);
CREATE INDEX IF NOT EXISTS ix_user_reliability_score ON user_reliability(reliability_score);

-- 需求画像表
CREATE TABLE IF NOT EXISTS user_demand (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    user_stage VARCHAR(20) NOT NULL DEFAULT 'new_arrival',
    predicted_needs JSONB DEFAULT '[]'::jsonb,
    recent_interests JSONB DEFAULT '{}'::jsonb,
    last_inferred_at TIMESTAMPTZ DEFAULT NOW(),
    inference_version VARCHAR(20) DEFAULT 'v1.0'
);

CREATE INDEX IF NOT EXISTS ix_user_demand_user_id ON user_demand(user_id);
CREATE INDEX IF NOT EXISTS ix_user_demand_user_stage ON user_demand(user_stage);

-- 迁移旧 UserSkill 数据到 UserCapability
-- 将现有 user_skills 表中的记录复制到 user_capabilities
-- 无法匹配 skill_category 的记录使用 category_id = (SELECT id FROM skill_categories ORDER BY id LIMIT 1) 作为兜底
INSERT INTO user_capabilities (user_id, category_id, skill_name, proficiency, verification_source, created_at)
SELECT
    us.user_id,
    COALESCE(
        (SELECT sc.id FROM skill_categories sc WHERE LOWER(sc.name_zh) = LOWER(us.skill_category) OR LOWER(sc.name_en) = LOWER(us.skill_category) LIMIT 1),
        (SELECT sc.id FROM skill_categories sc WHERE sc.is_active = true ORDER BY sc.display_order LIMIT 1)
    ),
    us.skill_name,
    'beginner',
    'self_declared',
    us.created_at
FROM user_skills us
WHERE NOT EXISTS (
    SELECT 1 FROM user_capabilities uc WHERE uc.user_id = us.user_id AND uc.skill_name = us.skill_name
)
AND EXISTS (SELECT 1 FROM skill_categories sc WHERE sc.is_active = true);

-- 初始化 UserReliability：为有任务记录的用户创建可靠度基础数据
INSERT INTO user_reliability (user_id, total_tasks_taken, completion_rate, communication_score)
SELECT
    u.id,
    COALESCE(u.completed_task_count, 0),
    CASE WHEN u.task_count > 0 THEN COALESCE(u.completed_task_count, 0)::float / u.task_count ELSE 0 END,
    COALESCE(u.avg_rating, 0.0)
FROM users u
WHERE u.task_count > 0
AND NOT EXISTS (SELECT 1 FROM user_reliability ur WHERE ur.user_id = u.id);
