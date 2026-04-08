# Expert Team As Task Taker — Pre-Launch Checklist

Generated: 2026-04-08
Plan: `docs/superpowers/plans/2026-04-07-expert-team-as-task-taker.md`
Spec: `docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md`

## Migration validation

- [ ] **Requires staging — Run sanity check SQL on staging** (`docs/runbooks/expert-team-taker-staging-verification.sql`)
  - All 6 checks should return 0 unexpected rows / orphans
  - If Check 4 (multi-team conflicts) returns rows, manually resolve before migration 180

- [ ] **Requires staging — Run migrations 176-179 on staging in order**
  - 176: tasks add taker_expert_id
  - 177: activities polymorphic owner
  - 178: extend payment_transfers (extends existing table — see spec §1.3)
  - 179: tasks add payment_completed_at
  - Verify each completes without error and `\d` shows the new columns

- [ ] **Requires staging — Run migration 180 backfill on staging** (after manual conflict resolution from Check 4)
  - Note the RAISE NOTICE output for backfill count
  - Verify with: `SELECT COUNT(*) FROM tasks WHERE taker_expert_id IS NOT NULL AND status IN ('pending','pending_payment','in_progress','disputed');`

## Stripe configuration

- [ ] **Requires staging — Subscribe `account.updated` webhook event in Stripe Dashboard**
  - Required for the team Stripe Connect status sync (see Phase 3)
  - Endpoint already receives `charge.dispute.*` events — confirm it also receives `account.updated`

- [ ] **Requires staging — Confirm `STRIPE_WEBHOOK_SECRET` env var is set on staging**
  - Used for webhook signature verification

## Celery beat schedule

- [ ] **Requires staging — Verify `warn-long-running-team-tasks` is registered in Celery beat schedule**
  - Added in Phase 6.4
  - Should run daily

- [ ] **Requires staging — Verify the 16 hotfixed tasks are now discovered by Celery worker**
  - Phase 6 hotfix moved them out of dead code (commits 4ee427712 + 3a059c591)
  - Use `celery inspect registered` on staging to confirm

## Code-level verification

- [x] **Verified — All 44 existing tests pass** (`cd backend && python -m pytest tests/test_*team*.py tests/test_*resolver*.py tests/test_*payout*.py tests/test_taker_display_serializer.py`)
- [x] **Verified — Imports clean for all modified files** (verified via `python -c "import ..."` in earlier phases)
- [x] **Verified — E2E mock smoke test passes** (Task 10.1, 3 tests in `backend/tests/test_e2e_team_task_money_flow.py`)

## Functional verification (require staging)

- [ ] **Requires staging — Publish a team service via the new endpoint** (`POST /api/experts/{id}/services`)
  - Confirm 409 if Stripe not onboarded
  - Confirm 422 if currency != GBP
  - Confirm 200 + service row created with `owner_type='expert'`

- [ ] **Requires staging — Customer orders the team service**
  - Confirm Task is created with `taker_expert_id` set
  - Confirm `taker_id` is the team owner's user_id

- [ ] **Requires staging — Customer confirms task completion → payout flow**
  - Confirm `stripe.Transfer.create` is called with `destination=experts.stripe_account_id`
  - Confirm `payment_transfers` row has `taker_expert_id` set
  - Confirm money lands in team Stripe Dashboard

- [ ] **Requires staging — Customer disputes the task → reversal flow**
  - Confirm `payment_transfers.status = 'reversed'`, `stripe_reversal_id` filled

- [ ] **Requires staging — Admin force-payouts a team task** (admin endpoint)
  - Same destination check

- [ ] **Requires staging — Auto-confirm expired team task** (scheduled_tasks.py auto_transfer)
  - Same destination check; verify NO wallet fallback for team task on Stripe failure

## UI verification

- [ ] **Requires staging — Flutter app's task detail page shows team display** (via `taker_display` field)
  - Team name + team avatar instead of owner's individual info
  - Requires Flutter Phase 8 client work to consume the new field

## Documentation

- [x] **Verified — Spec marked as Implemented** (Task 10.3)
- [x] **Verified — Runbook written** (Task 10.4: `docs/runbooks/expert-team-stripe-transfers.md`)
- [x] **Verified — Pre-audit SQL documented** (Phase 9 + Task 10.2: `docs/runbooks/expert-team-taker-staging-verification.sql`)

## Rollback plan

If anything goes wrong on staging:

1. Run `git revert` on the merge commit (drops all team-as-taker changes)
2. The schema columns added by migrations 176-179 are non-destructive (only add columns, set NOT NULL only on backfilled fields) — they can be left in place
3. Migration 180 backfill data can be undone with: `UPDATE tasks SET taker_expert_id = NULL WHERE taker_expert_id IS NOT NULL AND status IN ('pending', 'pending_payment', 'in_progress', 'disputed');`
4. The 16 Celery hotfix tasks are independent of team-as-taker — they should remain fixed regardless
