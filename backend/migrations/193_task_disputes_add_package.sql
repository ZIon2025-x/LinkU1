-- backend/migrations/193_task_disputes_add_package.sql
-- Add package_id nullable FK to task_disputes, enforce mutual exclusivity with task_id.

BEGIN;

ALTER TABLE task_disputes
  ADD COLUMN IF NOT EXISTS package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE task_disputes
  DROP CONSTRAINT IF EXISTS task_disputes_target_check;

ALTER TABLE task_disputes
  ADD CONSTRAINT task_disputes_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX IF NOT EXISTS ix_task_disputes_package
  ON task_disputes(package_id)
  WHERE package_id IS NOT NULL;

COMMIT;
