-- 119: Add poster_reply fields to task_applications for public reply feature

-- 1. Add poster_reply column (text, nullable)
ALTER TABLE task_applications ADD COLUMN IF NOT EXISTS poster_reply TEXT;

-- 2. Add poster_reply_at column (timestamptz, nullable)
ALTER TABLE task_applications ADD COLUMN IF NOT EXISTS poster_reply_at TIMESTAMPTZ;
