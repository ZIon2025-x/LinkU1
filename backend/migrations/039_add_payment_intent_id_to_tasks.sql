-- 添加 payment_intent_id 字段到 tasks 表
-- 迁移文件：039_add_payment_intent_id_to_tasks.sql

-- 添加 payment_intent_id 字段
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS payment_intent_id VARCHAR(255) NULL;

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_tasks_payment_intent_id ON tasks(payment_intent_id) WHERE payment_intent_id IS NOT NULL;

-- 添加注释
COMMENT ON COLUMN tasks.payment_intent_id IS 'Stripe Payment Intent ID，用于关联任务与支付记录';

