-- Fix official_activity_applications datetime columns to use TIMESTAMPTZ
-- This resolves "can't subtract offset-naive and offset-aware datetimes" error
-- when asyncpg receives a timezone-aware Python datetime for a TIMESTAMP column.

ALTER TABLE official_activity_applications
    ALTER COLUMN applied_at TYPE TIMESTAMPTZ USING applied_at AT TIME ZONE 'UTC',
    ALTER COLUMN notified_at TYPE TIMESTAMPTZ USING notified_at AT TIME ZONE 'UTC';
