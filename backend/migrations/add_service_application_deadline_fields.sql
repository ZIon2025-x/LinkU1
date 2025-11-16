-- 为 service_applications 表添加 deadline 和 is_flexible 字段
-- 用于支持用户申请服务时设置任务截至日期或选择灵活模式

-- 添加 deadline 字段（使用 IF NOT EXISTS，PostgreSQL 9.5+ 支持）
ALTER TABLE service_applications ADD COLUMN IF NOT EXISTS deadline TIMESTAMPTZ;

-- 添加 is_flexible 字段（使用 IF NOT EXISTS，PostgreSQL 9.5+ 支持）
ALTER TABLE service_applications ADD COLUMN IF NOT EXISTS is_flexible INTEGER DEFAULT 0;

-- 添加注释
COMMENT ON COLUMN service_applications.deadline IS '任务截至日期（如果is_flexible为0）';
COMMENT ON COLUMN service_applications.is_flexible IS '是否灵活（1=灵活，无截至日期；0=有截至日期）';

