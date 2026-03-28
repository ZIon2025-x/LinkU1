-- 142_add_consulting_status.sql
-- Add consulting status to service_applications and new message types

-- 1. Update message_type CHECK constraint to include negotiation types
-- Drop old constraint
ALTER TABLE messages DROP CONSTRAINT IF EXISTS ck_messages_type;

-- Add new constraint with negotiation message types
ALTER TABLE messages ADD CONSTRAINT ck_messages_type
    CHECK (message_type IN ('normal', 'system', 'price_proposal', 'negotiation', 'quote', 'counter_offer', 'negotiation_accepted', 'negotiation_rejected'));

-- 2. service_applications.status is a VARCHAR(20) with no CHECK constraint,
--    so 'consulting' is already valid without schema changes.

-- 3. Add index for consulting applications lookup (unique active consulting per user+service)
CREATE INDEX IF NOT EXISTS ix_service_applications_consulting
    ON service_applications (applicant_id, service_id, status)
    WHERE status = 'consulting';
