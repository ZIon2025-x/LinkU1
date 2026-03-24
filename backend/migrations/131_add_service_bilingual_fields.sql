-- Add bilingual fields to task_expert_services
ALTER TABLE task_expert_services
ADD COLUMN IF NOT EXISTS service_name_en VARCHAR(200),
ADD COLUMN IF NOT EXISTS description_en TEXT;
