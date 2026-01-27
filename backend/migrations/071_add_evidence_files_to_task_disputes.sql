-- 添加证据文件字段到任务争议表
-- 迁移文件：071_add_evidence_files_to_task_disputes.sql
-- 允许发布者在创建争议时上传证据文件

-- 添加字段
ALTER TABLE task_disputes 
ADD COLUMN IF NOT EXISTS evidence_files TEXT NULL;  -- JSON数组存储证据文件ID列表

-- 添加注释
COMMENT ON COLUMN task_disputes.evidence_files IS '争议证据文件ID列表（JSON数组格式）';
