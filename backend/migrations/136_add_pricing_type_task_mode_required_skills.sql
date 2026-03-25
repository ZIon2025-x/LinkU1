-- 136: Add pricing_type, task_mode, required_skills to tasks table
-- For task publish page redesign: pricing types, task mode, skills

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS pricing_type VARCHAR(20) DEFAULT 'fixed';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS task_mode VARCHAR(20) DEFAULT 'online';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS required_skills TEXT;
