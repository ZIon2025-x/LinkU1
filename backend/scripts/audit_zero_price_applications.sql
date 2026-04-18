-- Audit: find ServiceApplications that would 500 at owner-approve due to
-- zero-price fall-through (SA#9 class bug, fixed in 25992bb0c).
--
-- After the code-level guard is deployed, these applications will return a
-- clean 400 instead of 500, but they remain stuck in 'pending' status until
-- the service owner (expert) sends a counter-offer.
--
-- Run via Railway psql console or any PG client:
--     \i audit_zero_price_applications.sql
-- Or piped:
--     psql $DATABASE_URL -f audit_zero_price_applications.sql
--
-- Edit the WHERE status clause to match your recovery strategy.

\echo '=== Pending/negotiating SAs whose current effective price is 0 ==='
SELECT
    sa.id               AS application_id,
    sa.status           AS application_status,
    sa.applicant_id,
    sa.service_id,
    sa.created_at,
    s.service_name,
    s.owner_id          AS service_owner_id,
    s.owner_type        AS service_owner_type,
    s.pricing_type,
    s.base_price,
    sa.negotiated_price,
    sa.expert_counter_price,
    sa.final_price,
    sa.time_slot_id,
    slot.price_per_participant AS slot_price
FROM service_applications sa
LEFT JOIN task_expert_services s ON s.id = sa.service_id
LEFT JOIN service_time_slots    slot ON slot.id = sa.time_slot_id
WHERE sa.status IN ('pending', 'negotiating', 'consulting', 'price_agreed')
  AND sa.task_id IS NULL
  AND COALESCE(
        NULLIF(sa.expert_counter_price, 0),
        NULLIF(sa.final_price, 0),
        NULLIF(sa.negotiated_price, 0),
        NULLIF(slot.price_per_participant, 0),
        NULLIF(s.base_price, 0)
      ) IS NULL
ORDER BY sa.created_at ASC;

\echo ''
\echo '=== Summary count by pricing_type ==='
SELECT
    COALESCE(s.pricing_type, 'UNKNOWN') AS pricing_type,
    COUNT(*)                            AS stuck_count
FROM service_applications sa
LEFT JOIN task_expert_services s ON s.id = sa.service_id
LEFT JOIN service_time_slots    slot ON slot.id = sa.time_slot_id
WHERE sa.status IN ('pending', 'negotiating', 'consulting', 'price_agreed')
  AND sa.task_id IS NULL
  AND COALESCE(
        NULLIF(sa.expert_counter_price, 0),
        NULLIF(sa.final_price, 0),
        NULLIF(sa.negotiated_price, 0),
        NULLIF(slot.price_per_participant, 0),
        NULLIF(s.base_price, 0)
      ) IS NULL
GROUP BY s.pricing_type
ORDER BY stuck_count DESC;

\echo ''
\echo '=== Next steps ==='
\echo 'For each stuck application:'
\echo '  - negotiable service -> expert should send counter-offer via /owner-counter-offer'
\echo '  - fixed service with base_price=0 -> data anomaly; update service base_price or cancel app'
\echo ''
\echo 'Automated notification script (optional follow-up): send a'
\echo 'push/email to service owner telling them to counter-offer.'
