-- Backfill owner_type/owner_id for personal services created after migration 161.
--
-- Context: migration 161 backfilled owner columns once, but
-- personal_service_routes.create_personal_service was not updated to set them,
-- so every new personal service inserted between 161 and this fix has NULL
-- owner_type/owner_id. This makes them invisible to follow_feed queries that
-- filter on owner_type='user' AND owner_id IN (...).
--
-- Fix going forward: personal_service_routes.py now sets owner_type/owner_id
-- on insert. This migration closes the gap on existing rows.

UPDATE task_expert_services
SET owner_type = 'user',
    owner_id   = user_id
WHERE service_type = 'personal'
  AND owner_type IS NULL
  AND user_id IS NOT NULL;
