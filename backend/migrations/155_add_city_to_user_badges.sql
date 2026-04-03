-- 155: Add city column to user_badges table
-- Stores the user's primary city for badge display (e.g. "伦敦 · 翻译 · 第1名")

ALTER TABLE user_badges ADD COLUMN IF NOT EXISTS city VARCHAR(50) NOT NULL DEFAULT 'all';
