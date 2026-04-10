-- backend/migrations/191_refund_requests_add_package.sql
-- Add package_id nullable FK to refund_requests, enforce mutual exclusivity.

BEGIN;

ALTER TABLE refund_requests
  ADD COLUMN IF NOT EXISTS package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE refund_requests
  DROP CONSTRAINT IF EXISTS refund_requests_target_check;

ALTER TABLE refund_requests
  ADD CONSTRAINT refund_requests_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX IF NOT EXISTS ix_refund_requests_package
  ON refund_requests(package_id)
  WHERE package_id IS NOT NULL;

COMMIT;
