-- Migration 203: Fix consultation tasks missing taker_id
-- Sets taker_id for historical service/team consultation tasks so both parties
-- can see the consultation chat in their messages list.

-- 1. Personal service consultations: set taker_id to service_owner_id (user_id)
UPDATE tasks
SET taker_id = sa.service_owner_id
FROM service_applications sa
WHERE tasks.id = sa.task_id
  AND tasks.task_source = 'consultation'
  AND tasks.taker_id IS NULL
  AND sa.service_owner_id IS NOT NULL;

-- 2. Team service consultations: set taker_id to team owner's user_id
UPDATE tasks
SET taker_id = em.user_id
FROM service_applications sa
JOIN expert_members em ON em.expert_id = sa.new_expert_id
  AND em.role = 'owner'
  AND em.status = 'active'
WHERE tasks.id = sa.task_id
  AND tasks.task_source = 'consultation'
  AND tasks.taker_id IS NULL
  AND sa.new_expert_id IS NOT NULL;
