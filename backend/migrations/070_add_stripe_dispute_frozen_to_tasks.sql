-- 添加Stripe争议冻结字段到任务表
-- 迁移文件：070_add_stripe_dispute_frozen_to_tasks.sql
-- 当Stripe争议发生时，冻结任务状态，防止资金继续流出

-- 添加字段
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS stripe_dispute_frozen INTEGER DEFAULT 0;  -- 1=冻结，0=未冻结

-- 添加索引
CREATE INDEX IF NOT EXISTS ix_tasks_stripe_dispute_frozen ON tasks(stripe_dispute_frozen);

-- 添加注释
COMMENT ON COLUMN tasks.stripe_dispute_frozen IS 'Stripe争议冻结状态：1=已冻结（防止资金流出），0=未冻结';
