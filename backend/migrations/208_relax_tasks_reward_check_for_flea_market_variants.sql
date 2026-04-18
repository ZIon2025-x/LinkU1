-- Migration 208: Extend tasks reward consistency check to all flea_market* task_sources
-- Context:
-- - chk_tasks_reward_type_consistency (after 102) has a free-reward branch only for
--   task_source='flea_market' exactly:
--     (task_source = 'flea_market' AND reward_type = 'cash' AND reward = 0 ...)
-- - But free flea-market RENTALS use task_source='flea_market_rental' and free
--   flea-market CONSULTATIONS use task_source='flea_market_consultation'. Both
--   legitimately produce reward=0 rows and currently trigger 500 IntegrityError
--   when item.price=0 (free rental) or a free consultation is created.
--
-- This migration relaxes the flea-market branch to match all flea_market* sources
-- using a LIKE predicate, keeping the other 4 branches (cash, points, both,
-- reward_to_be_quoted) intact.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'tasks'
    ) THEN
        RAISE NOTICE 'Table "tasks" does not exist, skipping migration 208.';
        RETURN;
    END IF;

    ALTER TABLE tasks DROP CONSTRAINT IF EXISTS chk_tasks_reward_type_consistency;

    ALTER TABLE tasks ADD CONSTRAINT chk_tasks_reward_type_consistency CHECK (
        (reward_type = 'cash'   AND reward > 0 AND (points_reward IS NULL OR points_reward = 0)) OR
        (reward_type = 'points' AND points_reward > 0 AND reward IS NULL) OR
        (reward_type = 'both'   AND reward > 0 AND points_reward > 0) OR
        (task_source LIKE 'flea_market%'
         AND reward_type = 'cash'
         AND (reward = 0 OR reward IS NULL)
         AND (points_reward IS NULL OR points_reward = 0)) OR
        (reward_to_be_quoted = true
         AND reward_type = 'cash'
         AND (reward IS NULL OR reward = 0)
         AND (points_reward IS NULL OR points_reward = 0))
    );
END $$;
