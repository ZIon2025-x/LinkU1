-- 085: escrow_amount Float → DECIMAL(12,2) + 自动转账防重复唯一约束
-- 日期: 2026-02-09
-- 目的:
--   1. 将 tasks.escrow_amount 从 Float 改为 DECIMAL(12,2)，消除浮点精度误差（金融合规）
--   2. 为 payment_transfers 增加部分唯一索引，防止自动确认场景下重复转账

-- ========== 1. escrow_amount Float → DECIMAL(12,2) ==========

-- 先将现有数据四舍五入到2位小数，然后修改列类型
ALTER TABLE tasks
    ALTER COLUMN escrow_amount TYPE DECIMAL(12, 2)
    USING ROUND(COALESCE(escrow_amount, 0)::numeric, 2);

-- 设置默认值（DECIMAL 类型）
ALTER TABLE tasks
    ALTER COLUMN escrow_amount SET DEFAULT 0.00;

-- ========== 2. 防重复自动转账唯一约束 ==========

-- 部分唯一索引：同一 task_id 只允许一条 auto_confirm_3days 来源的非失败转账记录
-- 条件：transfer_source = 'auto_confirm_3days' 存储在 extra_metadata JSONB 字段中
-- 只限制 pending / retrying / succeeded 状态的记录（failed / canceled 不计入）
CREATE UNIQUE INDEX IF NOT EXISTS ix_payment_transfer_auto_confirm_unique
    ON payment_transfers (task_id)
    WHERE status IN ('pending', 'retrying', 'succeeded')
      AND extra_metadata->>'transfer_source' = 'auto_confirm_3days';

-- 添加注释说明索引用途
COMMENT ON INDEX ix_payment_transfer_auto_confirm_unique IS
    '防止同一任务重复创建自动确认转账记录（auto_confirm_3days），每个任务最多一条非失败状态的自动转账';
