-- 迁移 084：用户表添加 stripe_customer_id 字段
-- 用于缓存 Stripe Customer ID，避免每次支付都通过 Search API 查询/创建
-- 解决 Stripe Search API 索引延迟导致的重复创建 Customer 问题

-- 添加新字段
ALTER TABLE users
ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255) DEFAULT NULL;

-- 添加唯一约束（一个用户只能关联一个 Stripe Customer）
CREATE UNIQUE INDEX IF NOT EXISTS ix_users_stripe_customer_id
ON users (stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;

-- 添加字段注释
COMMENT ON COLUMN users.stripe_customer_id IS 'Stripe Customer ID（用于支付），缓存在本地避免重复创建';
