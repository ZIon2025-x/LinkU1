-- 添加接单者反驳功能到退款申请表
-- 迁移文件：068_add_rebuttal_to_refund_requests.sql
-- 允许接单者对退款申请进行反驳，上传完成证据和文字说明

-- 添加反驳相关字段
ALTER TABLE refund_requests 
ADD COLUMN IF NOT EXISTS rebuttal_text TEXT NULL,  -- 接单者反驳文字说明
ADD COLUMN IF NOT EXISTS rebuttal_evidence_files TEXT NULL,  -- 接单者反驳证据文件ID列表（JSON数组）
ADD COLUMN IF NOT EXISTS rebuttal_submitted_at TIMESTAMP WITH TIME ZONE NULL,  -- 反驳提交时间
ADD COLUMN IF NOT EXISTS rebuttal_submitted_by VARCHAR(8) NULL REFERENCES users(id) ON DELETE SET NULL;  -- 提交反驳的接单者ID

-- 添加索引
CREATE INDEX IF NOT EXISTS ix_refund_requests_rebuttal_submitted_at ON refund_requests(rebuttal_submitted_at);

-- 添加注释
COMMENT ON COLUMN refund_requests.rebuttal_text IS '接单者反驳文字说明';
COMMENT ON COLUMN refund_requests.rebuttal_evidence_files IS '接单者反驳证据文件ID列表（JSON数组格式）';
COMMENT ON COLUMN refund_requests.rebuttal_submitted_at IS '反驳提交时间';
COMMENT ON COLUMN refund_requests.rebuttal_submitted_by IS '提交反驳的接单者ID';
