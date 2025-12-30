-- 添加 Stripe Connect 账户 ID 字段到 users 表
-- 迁移文件：038_add_stripe_connect_account_id.sql

-- 添加 stripe_account_id 字段
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS stripe_account_id VARCHAR(255) UNIQUE;

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_users_stripe_account_id ON users(stripe_account_id);

-- 添加注释
COMMENT ON COLUMN users.stripe_account_id IS 'Stripe Connect Express Account ID，用于接收任务奖励支付';

