-- Add category column to task_expert_services
ALTER TABLE task_expert_services
ADD COLUMN IF NOT EXISTS category VARCHAR(50);
 