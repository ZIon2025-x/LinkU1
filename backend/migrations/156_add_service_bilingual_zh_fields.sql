-- 156_add_service_bilingual_zh_fields.sql
-- Add Chinese bilingual fields to task_expert_services

ALTER TABLE task_expert_services ADD COLUMN IF NOT EXISTS service_name_zh VARCHAR(200);
ALTER TABLE task_expert_services ADD COLUMN IF NOT EXISTS description_zh TEXT;

-- Backfill: for existing rows where service_name looks Chinese, copy to _zh
UPDATE task_expert_services
SET service_name_zh = service_name
WHERE service_name_zh IS NULL
  AND service_name ~ '[\u4e00-\u9fff]';

UPDATE task_expert_services
SET description_zh = description
WHERE description_zh IS NULL
  AND description ~ '[\u4e00-\u9fff]';

-- Backfill: for existing rows where service_name looks English, copy to _en if _en is null
UPDATE task_expert_services
SET service_name_en = service_name
WHERE service_name_en IS NULL
  AND service_name !~ '[\u4e00-\u9fff]'
  AND length(service_name) > 0;

UPDATE task_expert_services
SET description_en = description
WHERE description_en IS NULL
  AND description !~ '[\u4e00-\u9fff]'
  AND length(description) > 0;
