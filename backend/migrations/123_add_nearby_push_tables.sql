-- 用户位置表
CREATE TABLE IF NOT EXISTS user_locations (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_user_locations_user_id ON user_locations(user_id);

-- 附近任务推送记录（防重复）
CREATE TABLE IF NOT EXISTS nearby_task_pushes (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    pushed_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_nearby_push_user_task UNIQUE (user_id, task_id)
);

CREATE INDEX IF NOT EXISTS ix_nearby_task_pushes_user_pushed ON nearby_task_pushes(user_id, pushed_at);

-- 偏好表新增字段
ALTER TABLE user_profile_preferences ADD COLUMN IF NOT EXISTS nearby_push_enabled BOOLEAN NOT NULL DEFAULT FALSE;
