-- 添加任务确认期限相关字段到任务表
-- 迁移文件：072_add_confirmation_deadline_to_tasks.sql
-- 实现任务接单人标记完成后，发布者需在5天内确认，到期自动确认完成的功能

-- 添加确认截止时间字段
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS confirmation_deadline TIMESTAMP WITH TIME ZONE NULL;  -- 确认截止时间（completed_at + 5天）

-- 添加实际确认时间字段
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMP WITH TIME ZONE NULL;  -- 实际确认时间

-- 添加是否自动确认标志
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS auto_confirmed INTEGER DEFAULT 0;  -- 是否自动确认：1=自动确认，0=手动确认

-- 添加提醒状态位（位掩码，用于记录已发送的提醒）
-- 位0: 3天提醒（72小时）
-- 位1: 1天提醒（24小时）
-- 位2: 6小时提醒
-- 位3: 1小时提醒
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS confirmation_reminder_sent INTEGER DEFAULT 0;  -- 提醒状态位掩码

-- 添加索引以优化查询
CREATE INDEX IF NOT EXISTS ix_tasks_confirmation_deadline ON tasks(confirmation_deadline) 
WHERE confirmation_deadline IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_tasks_status_confirmation_deadline ON tasks(status, confirmation_deadline) 
WHERE status = 'pending_confirmation' AND confirmation_deadline IS NOT NULL;

-- 添加注释
COMMENT ON COLUMN tasks.confirmation_deadline IS '确认截止时间（接单人标记完成后5天）';
COMMENT ON COLUMN tasks.confirmed_at IS '实际确认时间（发布者确认或系统自动确认）';
COMMENT ON COLUMN tasks.auto_confirmed IS '是否自动确认：1=自动确认，0=手动确认';
COMMENT ON COLUMN tasks.confirmation_reminder_sent IS '提醒状态位掩码：位0=3天提醒，位1=1天提醒，位2=6小时提醒，位3=1小时提醒';
