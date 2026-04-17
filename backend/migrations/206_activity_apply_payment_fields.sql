-- 206_activity_apply_payment_fields.sql
-- Add payment fields to official_activity_applications
-- and extend status CHECK to include 'payment_pending' and 'refunded'

ALTER TABLE official_activity_applications
    ADD COLUMN IF NOT EXISTS payment_intent_id VARCHAR(255) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS amount_paid INTEGER DEFAULT NULL;

-- Update CHECK constraint to include new statuses
ALTER TABLE official_activity_applications
    DROP CONSTRAINT IF EXISTS ck_official_app_status;
ALTER TABLE official_activity_applications
    ADD CONSTRAINT ck_official_app_status
    CHECK (status IN ('payment_pending', 'pending', 'won', 'lost', 'attending', 'refunded'));
