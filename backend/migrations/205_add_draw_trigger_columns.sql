-- 205_add_draw_trigger_columns.sql
-- Add draw trigger type and participant count threshold for lottery activities
-- draw_trigger: 'by_time' | 'by_count' | 'both' (NULL for non-auto or non-lottery)
-- draw_participant_count: threshold for by_count / both triggers

ALTER TABLE activities ADD COLUMN IF NOT EXISTS draw_trigger VARCHAR(10) DEFAULT NULL;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS draw_participant_count INTEGER DEFAULT NULL;
