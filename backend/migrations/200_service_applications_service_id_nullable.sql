-- 200: Allow service_id to be NULL in service_applications
-- 团队咨询（team consultation）不关联具体服务，service_id 为 NULL
ALTER TABLE service_applications ALTER COLUMN service_id DROP NOT NULL;
