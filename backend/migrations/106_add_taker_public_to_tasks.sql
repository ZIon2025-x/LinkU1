-- 添加 taker_public 列：控制接单者主页中已完成任务的可见性
-- 1=public (默认), 0=private
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS taker_public INTEGER DEFAULT 1;
