-- 087: 修复自动转账防重复唯一约束（transfer_source 值不匹配）
-- 日期: 2026-02-09
-- 原因:
--   代码重构将 transfer_source 从 'auto_confirm_3days' 改为 'auto_confirm_expired'，
--   但 085 迁移创建的唯一约束仍匹配旧值，导致防重复安全网完全失效。
--   本迁移删除旧约束，创建新约束匹配当前代码使用的值。

-- ========== 1. 删除旧的唯一约束 ==========
DROP INDEX IF EXISTS ix_payment_transfer_auto_confirm_unique;

-- ========== 2. 创建新的唯一约束（匹配新的 transfer_source 值）==========
-- 部分唯一索引：同一 task_id 只允许一条自动转账来源的非失败转账记录
-- 条件：transfer_source = 'auto_confirm_expired' 存储在 extra_metadata JSONB 字段中
-- 只限制 pending / retrying / succeeded 状态的记录（failed / canceled 不计入）
CREATE UNIQUE INDEX IF NOT EXISTS ix_payment_transfer_auto_confirm_unique
    ON payment_transfers (task_id)
    WHERE status IN ('pending', 'retrying', 'succeeded')
      AND extra_metadata->>'transfer_source' = 'auto_confirm_expired';

-- 添加注释说明索引用途
COMMENT ON INDEX ix_payment_transfer_auto_confirm_unique IS
    '防止同一任务重复创建自动转账记录（auto_confirm_expired），每个任务最多一条非失败状态的自动转账';
