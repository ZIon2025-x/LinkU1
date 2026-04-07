-- ===========================================
-- Pre-audit query for migration 180
-- spec §6.2 — Lists in-flight tasks whose taker_id could map to MULTIPLE
-- expert teams. These tasks need human decision before backfill (the
-- backfill will silently choose the team with earliest joined_at owner).
--
-- USAGE: run this on staging BEFORE running 180_backfill_tasks_taker_expert.sql
-- If the result set is non-empty, manually decide for each conflict task
-- and either:
--   (a) update tasks.taker_expert_id manually, OR
--   (b) accept the auto-pick (earliest owner first; oldest membership first)
-- ===========================================

SELECT
    t.id AS task_id,
    t.taker_id,
    t.status,
    t.task_source,
    t.created_at,
    array_agg(em.expert_id ORDER BY em.role DESC, em.joined_at ASC) AS candidate_experts,
    COUNT(DISTINCT em.expert_id) AS num_teams
FROM tasks t
JOIN expert_members em ON em.user_id = t.taker_id
WHERE t.status IN ('pending', 'pending_payment', 'in_progress', 'disputed')
  AND t.taker_expert_id IS NULL
  AND (t.expert_service_id IS NOT NULL OR t.parent_activity_id IS NOT NULL)
  AND COALESCE(t.currency, 'GBP') = 'GBP'
  AND em.status = 'active'
GROUP BY t.id, t.taker_id, t.status, t.task_source, t.created_at
HAVING COUNT(DISTINCT em.expert_id) > 1
ORDER BY t.created_at DESC;
