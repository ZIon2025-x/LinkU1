-- backend/migrations/192_reviews_add_package.sql
-- Add package_id nullable FK to reviews, enforce mutual exclusivity with task_id.

BEGIN;

ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE reviews
  DROP CONSTRAINT IF EXISTS reviews_target_check;

ALTER TABLE reviews
  ADD CONSTRAINT reviews_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX IF NOT EXISTS ix_reviews_package
  ON reviews(package_id)
  WHERE package_id IS NOT NULL;

COMMIT;
