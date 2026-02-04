-- 允许多个用户的 stripe_account_id 为 NULL（解决换密钥后无法清空旧测试账户的问题）
-- 将原来的 UNIQUE 约束改为「仅对非空值唯一」的部分唯一索引，这样清空时不会报 duplicate key

-- 1. 删除原有唯一约束（PostgreSQL 默认约束名为 表名_列名_key）
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_stripe_account_id_key;

-- 2. 创建部分唯一索引：只对 stripe_account_id 非空的行要求唯一，允许多个 NULL
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_stripe_account_id_unique
ON users (stripe_account_id)
WHERE stripe_account_id IS NOT NULL;
