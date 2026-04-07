# Expert Team Stripe Transfers — Operational Runbook

**Audience:** on-call backend engineers and finance ops
**Related spec:** `docs/superpowers/specs/2026-04-06-expert-team-as-task-taker-design.md`
**Related plan:** `docs/superpowers/plans/2026-04-07-expert-team-as-task-taker.md`

---

## 1. Architecture summary

When a customer orders a service owned by an expert **team** (`task_expert_services.owner_type='expert'`), the resulting `tasks` row gets two taker fields populated:

- `taker_id` — the team **owner**'s `users.id` (legal payee identity for non-team operations)
- `taker_expert_id` — the `experts.id` (the actual economic taker)

When the task is paid out, `payment_transfer_service.execute_transfer()` calls `resolve_payout_destination(db, task)`, which checks `task.taker_expert_id`:

- If set → returns `experts.stripe_account_id` (team's Stripe Connect account)
- If null (legacy individual task) → falls back to `users.stripe_account_id`

The `payment_transfers` row carries `taker_expert_id` for auditability so finance ops can trace any payout back to the team that received it. Disputes auto-reverse via `stripe.Transfer.create_reversal` and update `payment_transfers.status='reversed'`.

---

## 2. Failure modes & recovery procedures

### 2.1 Team Stripe Transfer failed (`payment_transfers.status='failed'`)

**Symptoms:**
- Sentry alert from `payment_transfer_service.execute_transfer`
- Customer reports task confirmed but team didn't receive payout
- `payment_transfers.status='failed'`, `last_error` contains a Stripe error code

**Investigation:**
```sql
SELECT id, task_id, taker_id, taker_expert_id, amount_minor, currency,
       status, last_error, retry_count, created_at, updated_at
FROM payment_transfers
WHERE task_id = <task_id>
ORDER BY created_at DESC;
```

Common `last_error` values:
- `account_invalid` / `account_charges_disabled` — team's Stripe Connect onboarding is broken (see §2.4)
- `insufficient_funds` — Link2Ur platform balance is empty; finance ops must top up before retry
- `transfer_window_expired` — original charge is more than 90 days old (see §2.2)

**Recovery:**
1. Fix the root cause (top-up platform balance, ask team to redo onboarding, etc.)
2. Use the admin force-payout endpoint:
   ```
   POST /admin/tasks/{task_id}/force-payout
   ```
3. Verify `payment_transfers.status` flips to `succeeded` and `stripe_transfer_id` is filled.

### 2.2 90-day Transfer window approaching

Stripe only allows transfers from a charge for 90 days after the charge was created. The Celery beat task `warn-long-running-team-tasks` (in `app/scheduled_tasks.py`) fires daily and creates an admin notification when a team task is **60 days** since `payment_completed_at` and still not confirmed.

**When the warning fires:**
1. Look up the task: `SELECT id, taker_id, taker_expert_id, payment_completed_at, status FROM tasks WHERE id = <id>;`
2. Contact the team owner — either confirm the task immediately or ask the customer to confirm
3. If neither happens by day 88, finance ops must **manually** transfer outside the automated flow:
   - Use Stripe Dashboard to issue a Transfer from a fresh charge
   - Then `UPDATE payment_transfers SET status='succeeded', stripe_transfer_id='<manual>', notes='manual transfer at day 88, see ticket #...' WHERE task_id = <id>;`

### 2.3 Dispute auto-reversal failed

`charge.dispute.created` webhook handler attempts `stripe.Transfer.create_reversal`. If Stripe responds with `balance_insufficient` (because the team has already withdrawn the funds), the handler logs an error and leaves `payment_transfers.status='succeeded'` with `dispute_reversal_failed_at` set.

**Recovery:**
1. Look at `experts.stripe_account_id` and check the team's Stripe Express dashboard balance
2. If the team has positive balance, manually issue the reversal via Stripe Dashboard
3. If the team has zero balance, escalate to finance: a debit balance recovery process is required (Stripe's Negative Balance Recovery)
4. After resolution, update the row:
   ```sql
   UPDATE payment_transfers
   SET status='reversed',
       stripe_reversal_id='<id from Stripe>',
       reversal_reason='dispute_manual_recovery',
       reversed_at=NOW()
   WHERE id = <pt_id>;
   ```

### 2.4 Team Stripe onboarding broken (`charges_enabled=False`)

The `account.updated` webhook handler watches for `charges_enabled` flipping to false. When that happens, all of the team's `task_expert_services` rows get auto-suspended (`status='suspended'`) so no new orders can come in.

**Recovery:**
1. Ask the team owner to log into their Stripe Express account and complete any required action items (KYC, document upload, etc.)
2. Stripe will fire `account.updated` again with `charges_enabled=true`
3. The webhook handler restores services to `status='active'` automatically
4. Verify with:
   ```sql
   SELECT id, name, status FROM task_expert_services
   WHERE owner_type='expert' AND owner_id='<expert_id>';
   ```

If the webhook didn't fire or restore the services for some reason:
```sql
UPDATE task_expert_services
SET status='active'
WHERE owner_type='expert' AND owner_id='<expert_id>'
  AND status='suspended';
```

---

## 3. Stripe Dashboard cross-reference

To find a team's payouts in Stripe Dashboard given a `taker_expert_id`:

1. Get the Connect account ID:
   ```sql
   SELECT id, name, stripe_account_id FROM experts WHERE id='<taker_expert_id>';
   ```
2. In Stripe Dashboard → Connect → Accounts → search for `stripe_account_id`
3. Click into the account → "Payouts" tab shows all transfers landed in that team's balance

Reverse direction (Stripe → DB): given a `tr_xxx` transfer ID:
```sql
SELECT * FROM payment_transfers WHERE stripe_transfer_id='tr_xxx';
```

---

## 4. Common SQL queries

### Find all failed team transfers in the last 7 days
```sql
SELECT pt.id, pt.task_id, pt.taker_expert_id, e.name AS team_name,
       pt.amount_minor, pt.currency, pt.last_error, pt.retry_count, pt.updated_at
FROM payment_transfers pt
JOIN experts e ON e.id = pt.taker_expert_id
WHERE pt.status='failed'
  AND pt.updated_at > NOW() - INTERVAL '7 days'
ORDER BY pt.updated_at DESC;
```

### Find tasks approaching the 90-day Stripe window
```sql
SELECT t.id, t.title, t.taker_expert_id, e.name AS team_name,
       t.payment_completed_at,
       EXTRACT(DAY FROM NOW() - t.payment_completed_at) AS days_old,
       t.status
FROM tasks t
JOIN experts e ON e.id = t.taker_expert_id
WHERE t.taker_expert_id IS NOT NULL
  AND t.status IN ('in_progress', 'pending_confirmation')
  AND t.payment_completed_at < NOW() - INTERVAL '60 days'
ORDER BY t.payment_completed_at ASC;
```

### Find a specific task's payment_transfers history
```sql
SELECT id, status, amount_minor, currency, stripe_transfer_id, stripe_reversal_id,
       retry_count, last_error, created_at, updated_at
FROM payment_transfers
WHERE task_id = <task_id>
ORDER BY created_at ASC;
```

### Audit a team's lifetime payouts
```sql
SELECT COUNT(*) AS n_transfers,
       SUM(amount_minor) FILTER (WHERE status='succeeded') AS total_succeeded_minor,
       SUM(amount_minor) FILTER (WHERE status='reversed') AS total_reversed_minor,
       SUM(amount_minor) FILTER (WHERE status='failed') AS total_failed_minor
FROM payment_transfers
WHERE taker_expert_id = '<expert_id>';
```

---

## 5. When to escalate

| Situation | Action |
|-----------|--------|
| Single failed transfer with retry-able error | Auto-retry handles it; no escalation |
| `account_invalid` for one team | Contact team owner; no engineering escalation needed |
| `insufficient_funds` (platform balance empty) | **Page finance immediately** — all team payouts are stuck |
| Dispute reversal failed with negative balance | **Page finance + on-call engineer** — manual Stripe recovery required |
| Multiple teams' onboarding broken simultaneously | **Page on-call engineer** — likely a Stripe API outage or webhook handler bug |
| `payment_transfers` row in `pending` for >24h with no `stripe_transfer_id` | **Page on-call engineer** — Celery worker may be stuck |
| `taker_expert_id` set but `resolve_payout_destination` returned a user account | **Page on-call engineer** — data integrity issue, do NOT retry until investigated |

**Always include in escalation:**
- The `tasks.id` and `payment_transfers.id`
- The team's `experts.id` and `stripe_account_id`
- Sentry/log link with the `last_error` value
- Whether you've already tried the admin force-payout endpoint
