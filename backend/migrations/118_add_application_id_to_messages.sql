-- 118: Add application_id to messages and message_read_cursors for per-application chat channels
-- Also update message_type CHECK constraint to support 'price_proposal'

-- 1. Add application_id column to messages table
ALTER TABLE messages ADD COLUMN IF NOT EXISTS application_id INTEGER REFERENCES task_applications(id) ON DELETE CASCADE;

-- 2. Add composite index on (task_id, application_id)
CREATE INDEX IF NOT EXISTS ix_messages_task_application ON messages(task_id, application_id);

-- 3. Update message_type CHECK constraint to include 'price_proposal'
ALTER TABLE messages DROP CONSTRAINT IF EXISTS ck_messages_type;
ALTER TABLE messages ADD CONSTRAINT ck_messages_type CHECK (message_type IN ('normal', 'system', 'price_proposal'));

-- 4. Add application_id column to message_read_cursors table
ALTER TABLE message_read_cursors ADD COLUMN IF NOT EXISTS application_id INTEGER REFERENCES task_applications(id) ON DELETE CASCADE;

-- 5. Update unique constraint to include application_id
ALTER TABLE message_read_cursors DROP CONSTRAINT IF EXISTS uq_message_read_cursors_task_user;
ALTER TABLE message_read_cursors DROP CONSTRAINT IF EXISTS uq_message_read_cursors_task_user_application;
ALTER TABLE message_read_cursors ADD CONSTRAINT uq_message_read_cursors_task_user_application UNIQUE (task_id, user_id, application_id);

-- 6. Partial unique index for legacy cursors where application_id IS NULL
-- (PostgreSQL treats NULL != NULL in unique constraints)
CREATE UNIQUE INDEX IF NOT EXISTS uq_mrc_task_user_no_app
ON message_read_cursors(task_id, user_id) WHERE application_id IS NULL;
