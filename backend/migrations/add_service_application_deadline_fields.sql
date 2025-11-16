-- 为 service_applications 表添加 deadline 和 is_flexible 字段
-- 用于支持用户申请服务时设置任务截至日期或选择灵活模式

-- 添加 deadline 字段
-- 如果字段已存在，会报错但会被错误处理逻辑捕获并跳过
ALTER TABLE service_applications ADD COLUMN deadline TIMESTAMPTZ;

-- 添加 is_flexible 字段
-- 如果字段已存在，会报错但会被错误处理逻辑捕获并跳过
ALTER TABLE service_applications ADD COLUMN is_flexible INTEGER DEFAULT 0;

