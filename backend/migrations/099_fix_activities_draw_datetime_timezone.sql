-- Fix activities draw_at/drawn_at to TIMESTAMPTZ (same issue as 098 for official_activity_applications).
-- Resolves: can't subtract offset-naive and offset-aware datetimes when saving drawn_at via admin draw.

ALTER TABLE activities
    ALTER COLUMN draw_at TYPE TIMESTAMPTZ USING draw_at AT TIME ZONE 'UTC',
    ALTER COLUMN drawn_at TYPE TIMESTAMPTZ USING drawn_at AT TIME ZONE 'UTC';
