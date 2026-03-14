-- Migration 111 failed to create these tables because user_id was INTEGER
-- but users.id is VARCHAR(8). Migration 115 only did ALTER (tables didn't exist).
-- This migration actually creates the missing tables.

CREATE TABLE IF NOT EXISTS user_tasks_progress (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_key VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    completed_at TIMESTAMP,
    claimed_at TIMESTAMP,
    UNIQUE(user_id, task_key)
);
CREATE INDEX IF NOT EXISTS idx_user_tasks_progress_user_id ON user_tasks_progress(user_id);

CREATE TABLE IF NOT EXISTS stage_bonus_progress (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stage INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    claimed_at TIMESTAMP,
    UNIQUE(user_id, stage)
);
