-- Add is_visible column to tasks table (for content filter review queue)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_visible BOOLEAN NOT NULL DEFAULT TRUE;

-- Add is_visible column to flea_market_items table (for content filter review queue)
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS is_visible BOOLEAN NOT NULL DEFAULT TRUE;
