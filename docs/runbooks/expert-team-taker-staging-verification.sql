-- ===========================================
-- Pre-deployment sanity checks for expert-team-as-task-taker
-- spec: 2026-04-06-expert-team-as-task-taker-design.md
--
-- Run these on STAGING in order. Each should return 0 rows / 0 problems.
-- Migrations 176-180 should NOT be run until all checks pass.
-- ===========================================

-- Check 1: task_expert_services polymorphism is sane
SELECT
    owner_type,
    COUNT(*) AS n,
    COUNT(*) FILTER (WHERE owner_id IS NULL) AS n_null_owner,
    COUNT(*) FILTER (WHERE owner_type='expert' AND NOT EXISTS (
        SELECT 1 FROM experts e WHERE e.id = owner_id
    )) AS n_orphan_expert,
    COUNT(*) FILTER (WHERE owner_type='user' AND NOT EXISTS (
        SELECT 1 FROM users u WHERE u.id = owner_id
    )) AS n_orphan_user
FROM task_expert_services
GROUP BY owner_type;
-- Expected: all orphan/null counts = 0

-- Check 2: experts that have services but no Stripe Connect setup
SELECT e.id, e.name, COUNT(s.id) AS service_count
FROM experts e
JOIN task_expert_services s ON s.owner_type='expert' AND s.owner_id = e.id AND s.status = 'active'
WHERE e.stripe_account_id IS NULL OR e.stripe_onboarding_complete = false
GROUP BY e.id, e.name;
-- Expected: 0 rows. If non-zero, those teams need to complete onboarding before launch.

-- Check 3: in-flight tasks that need backfilling (preview before migration 180)
SELECT COUNT(*) AS inflight_team_unmapped_tasks
FROM tasks t
WHERE t.status IN ('pending', 'pending_payment', 'in_progress', 'disputed')
  AND t.taker_expert_id IS NULL
  AND (t.expert_service_id IS NOT NULL OR t.parent_activity_id IS NOT NULL)
  AND COALESCE(t.currency, 'GBP') = 'GBP'
  AND EXISTS (
      SELECT 1 FROM expert_members em
      WHERE em.user_id = t.taker_id
        AND em.role IN ('owner', 'admin')
        AND em.status = 'active'
  );
-- Expected: any non-zero count is the number that migration 180 will backfill.

-- Check 4: multi-team conflict tasks (must be resolved manually before migration 180)
SELECT t.id, t.taker_id, array_agg(em.expert_id) AS candidate_experts
FROM tasks t
JOIN expert_members em ON em.user_id = t.taker_id
WHERE t.status IN ('pending', 'pending_payment', 'in_progress', 'disputed')
  AND t.taker_expert_id IS NULL
  AND em.status = 'active'
GROUP BY t.id, t.taker_id
HAVING COUNT(DISTINCT em.expert_id) > 1;
-- Expected: 0 rows. If non-zero, decide manually before migration 180.

-- Check 5: payment_transfers idempotency_key uniqueness baseline
SELECT idempotency_key, COUNT(*)
FROM payment_transfers
WHERE idempotency_key IS NOT NULL
GROUP BY idempotency_key
HAVING COUNT(*) > 1;
-- Expected: 0 rows. UNIQUE constraint will be enforced after migration 178.

-- Check 6: payment_transfers status values are valid
SELECT status, COUNT(*)
FROM payment_transfers
GROUP BY status;
-- Expected: only values in ('pending', 'succeeded', 'failed', 'retrying', 'reversed').
-- Migration 178 adds the 'reversed' value to the CHECK constraint.
