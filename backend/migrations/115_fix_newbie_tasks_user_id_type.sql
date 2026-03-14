-- Fix: user_tasks_progress and stage_bonus_progress tables were never created
-- because migration 111 used INTEGER for user_id, but users.id is VARCHAR(8).
-- The type mismatch caused CREATE TABLE to fail silently.
--
-- This migration:
-- 1. Creates the tables with correct VARCHAR(8) user_id (IF NOT EXISTS)
-- 2. Also handles the unlikely case where tables exist with wrong type (ALTER)

-- Step 1: Create user_tasks_progress if it doesn't exist (with correct type)
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

-- Step 2: Create stage_bonus_progress if it doesn't exist (with correct type)
CREATE TABLE IF NOT EXISTS stage_bonus_progress (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stage INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    claimed_at TIMESTAMP,
    UNIQUE(user_id, stage)
);

-- Step 3: Safety net - if tables somehow exist with INTEGER user_id, fix them
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_tasks_progress'
        AND column_name = 'user_id'
        AND data_type = 'integer'
    ) THEN
        ALTER TABLE user_tasks_progress
            DROP CONSTRAINT IF EXISTS user_tasks_progress_user_id_fkey;
        ALTER TABLE user_tasks_progress
            ALTER COLUMN user_id TYPE VARCHAR(8) USING user_id::VARCHAR(8);
        ALTER TABLE user_tasks_progress
            ADD CONSTRAINT user_tasks_progress_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'stage_bonus_progress'
        AND column_name = 'user_id'
        AND data_type = 'integer'
    ) THEN
        ALTER TABLE stage_bonus_progress
            DROP CONSTRAINT IF EXISTS stage_bonus_progress_user_id_fkey;
        ALTER TABLE stage_bonus_progress
            ALTER COLUMN user_id TYPE VARCHAR(8) USING user_id::VARCHAR(8);
        ALTER TABLE stage_bonus_progress
            ADD CONSTRAINT stage_bonus_progress_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
END $$;
