-- 添加支付过期时间字段到 tasks 表
-- 用于待支付状态的任务，设置支付过期时间

-- 添加 payment_expires_at 字段
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS payment_expires_at TIMESTAMP WITH TIME ZONE NULL;

-- 添加索引以便快速查询即将过期的待支付任务
CREATE INDEX IF NOT EXISTS ix_tasks_payment_expires_at 
ON tasks(payment_expires_at) 
WHERE status = 'pending_payment' AND payment_expires_at IS NOT NULL;

-- 添加注释
COMMENT ON COLUMN tasks.payment_expires_at IS '支付过期时间（待支付状态的任务，超过此时间未支付则任务自动取消）';
