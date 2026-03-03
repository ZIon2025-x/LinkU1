-- Migration 102: Allow reward_to_be_quoted (待报价) tasks with reward 0 or NULL
-- Context:
-- - chk_tasks_reward_type_consistency (after 097) allows:
--   - cash + reward > 0, or points, or both, or flea_market + reward 0/NULL
-- - User can create a task with "待报价" (reward_to_be_quoted = true) and no reward;
--   backend inserts reward=0, base_reward=0, which violates the cash branch (reward > 0).
--
-- This migration adds a branch: reward_to_be_quoted = true AND reward_type = 'cash'
-- AND (reward IS NULL OR reward = 0) AND (points_reward IS NULL OR points_reward = 0).

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'tasks'
    ) THEN
        RAISE NOTICE 'Table "tasks" does not exist, skipping migration 102.';
        RETURN;
    END IF;

    ALTER TABLE tasks DROP CONSTRAINT IF EXISTS chk_tasks_reward_type_consistency;

    ALTER TABLE tasks ADD CONSTRAINT chk_tasks_reward_type_consistency CHECK (
        (reward_type = 'cash'   AND reward > 0 AND (points_reward IS NULL OR points_reward = 0)) OR
        (reward_type = 'points' AND points_reward > 0 AND reward IS NULL) OR
        (reward_type = 'both'   AND reward > 0 AND points_reward > 0) OR
        (task_source = 'flea_market'
         AND reward_type = 'cash'
         AND (reward = 0 OR reward IS NULL)
         AND (points_reward IS NULL OR points_reward = 0)) OR
        (reward_to_be_quoted = true
         AND reward_type = 'cash'
         AND (reward IS NULL OR reward = 0)
         AND (points_reward IS NULL OR points_reward = 0))
    );
END $$;
