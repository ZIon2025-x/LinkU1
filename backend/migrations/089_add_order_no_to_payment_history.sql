-- 迁移 089：payment_history 表添加 order_no 独立业务订单号字段
-- 解决支付记录缺少独立业务订单号的问题，订单号格式: PAY{YYYYMMDDHHmmss}{5位随机字母数字}
-- 同时为存量数据生成回填订单号

-- 1. 添加新字段（先允许 NULL，回填后再设置 NOT NULL）
ALTER TABLE payment_history
ADD COLUMN IF NOT EXISTS order_no VARCHAR(32) DEFAULT NULL;

-- 2. 为已有数据回填订单号（使用 id + 创建时间 生成唯一订单号）
UPDATE payment_history
SET order_no = 'PAY' || TO_CHAR(COALESCE(created_at, NOW()), 'YYYYMMDDHH24MISS') || LPAD(id::TEXT, 5, '0')
WHERE order_no IS NULL;

-- 3. 设置 NOT NULL 约束
ALTER TABLE payment_history
ALTER COLUMN order_no SET NOT NULL;

-- 4. 添加唯一索引
CREATE UNIQUE INDEX IF NOT EXISTS ix_payment_history_order_no
ON payment_history (order_no);

-- 5. 添加字段注释
COMMENT ON COLUMN payment_history.order_no IS '业务订单号（唯一），格式: PAY{YYYYMMDDHHmmss}{5位随机字母数字}';
