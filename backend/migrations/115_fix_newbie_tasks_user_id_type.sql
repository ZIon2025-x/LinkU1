-- Fix user_id column type in newbie task progress tables
-- users.id is VARCHAR(8) but these tables were created with INTEGER user_id
-- This causes type mismatch errors when inserting progress rows

-- Fix user_tasks_progress.user_id: INTEGER -> VARCHAR(8)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_tasks_progress'
        AND column_name = 'user_id'
        AND data_type = 'integer'
    ) THEN
        -- Drop existing foreign key constraint first
        ALTER TABLE user_tasks_progress
            DROP CONSTRAINT IF EXISTS user_tasks_progress_user_id_fkey;

        -- Change column type
        ALTER TABLE user_tasks_progress
            ALTER COLUMN user_id TYPE VARCHAR(8) USING user_id::VARCHAR(8);

        -- Re-add foreign key constraint
        ALTER TABLE user_tasks_progress
            ADD CONSTRAINT user_tasks_progress_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Fix stage_bonus_progress.user_id: INTEGER -> VARCHAR(8)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'stage_bonus_progress'
        AND column_name = 'user_id'
        AND data_type = 'integer'
    ) THEN
        -- Drop existing foreign key constraint first
        ALTER TABLE stage_bonus_progress
            DROP CONSTRAINT IF EXISTS stage_bonus_progress_user_id_fkey;

        -- Change column type
        ALTER TABLE stage_bonus_progress
            ALTER COLUMN user_id TYPE VARCHAR(8) USING user_id::VARCHAR(8);

        -- Re-add foreign key constraint
        ALTER TABLE stage_bonus_progress
            ADD CONSTRAINT stage_bonus_progress_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
END $$;
