-- Migration 097: Relax tasks reward consistency check for free flea-market tasks
-- Context:
-- - chk_tasks_reward_type_consistency currently enforces:
--     (reward_type = 'cash'  AND reward > 0 AND (points_reward IS NULL OR points_reward = 0)) OR
--     (reward_type = 'points' AND points_reward > 0 AND reward IS NULL) OR
--     (reward_type = 'both'  AND reward > 0 AND points_reward > 0)
-- - For flea-market direct purchase, free items (price = 0) create tasks with:
--     task_source = 'flea_market', reward = 0, points_reward = 0, reward_type = 'cash'
--   which violates the existing CHECK.
--
-- This migration updates the CHECK constraint to allow this specific case:
--   - task_source = 'flea_market'
--   - reward = 0
--   - points_reward IS NULL OR points_reward = 0
--   - reward_type = 'cash'

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'tasks'
    ) THEN
        RAISE NOTICE 'Table "tasks" does not exist, skipping migration 097.';
        RETURN;
    END IF;

    -- Drop old constraint (unconditional; IF EXISTS makes it safe to re-run)
    ALTER TABLE tasks DROP CONSTRAINT IF EXISTS chk_tasks_reward_type_consistency;

    -- Recreate with an additional branch for free flea-market tasks
    ALTER TABLE tasks ADD CONSTRAINT chk_tasks_reward_type_consistency CHECK (
        (reward_type = 'cash'   AND reward > 0 AND (points_reward IS NULL OR points_reward = 0)) OR
        (reward_type = 'points' AND points_reward > 0 AND reward IS NULL) OR
        (reward_type = 'both'   AND reward > 0 AND points_reward > 0) OR
        (task_source = 'flea_market'
         AND reward_type = 'cash'
         AND (reward = 0 OR reward IS NULL)
         AND (points_reward IS NULL OR points_reward = 0))
    );
END $$;

