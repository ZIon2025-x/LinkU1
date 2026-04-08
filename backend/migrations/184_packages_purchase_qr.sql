-- ===========================================
-- 迁移 184: 套餐购买流程 + QR 核销系统
--
-- 背景:
--   Phase 7 引入了 package_type/total_sessions/bundle_service_ids 字段,
--   但没有套餐购买端点 (UserServicePackage 全仓零创建点),也没有 QR 核销。
--   本迁移补齐数据层:
--     - TaskExpertService 加 package_price (owner 自定义套餐总价) + validity_days
--     - UserServicePackage 加 payment_intent_id / paid_amount / currency /
--       bundle_breakdown / last_redeemed_at
--     - PackageUsageLog 加 sub_service_id / redeem_method
--
-- 与代码的对应:
--   models.py TaskExpertService     ← package_price, validity_days
--   models_expert.py UserServicePackage ← payment_intent_id, paid_amount, currency,
--                                          bundle_breakdown, last_redeemed_at
--   models_expert.py PackageUsageLog ← sub_service_id, redeem_method
-- ===========================================
BEGIN;

-- ---------- TaskExpertService ----------

ALTER TABLE task_expert_services
  ADD COLUMN IF NOT EXISTS package_price DECIMAL(12, 2) NULL,
  ADD COLUMN IF NOT EXISTS validity_days INTEGER NULL;

COMMENT ON COLUMN task_expert_services.package_price IS
  'A1: 套餐总价 (owner 自定义,与 base_price * total_sessions 解耦)。NULL 表示非套餐或 fallback 用 base_price * total_sessions';
COMMENT ON COLUMN task_expert_services.validity_days IS
  'A1: 套餐有效天数。NULL = 永不过期。购买后 expires_at = purchased_at + validity_days';

-- ---------- UserServicePackage ----------

ALTER TABLE user_service_packages
  ADD COLUMN IF NOT EXISTS payment_intent_id VARCHAR(255) NULL,
  ADD COLUMN IF NOT EXISTS paid_amount FLOAT NULL,
  ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NULL DEFAULT 'GBP',
  ADD COLUMN IF NOT EXISTS bundle_breakdown JSONB NULL,
  ADD COLUMN IF NOT EXISTS last_redeemed_at TIMESTAMPTZ NULL;

COMMENT ON COLUMN user_service_packages.payment_intent_id IS
  'A1: 关联的 Stripe PaymentIntent ID,用于退款/审计';
COMMENT ON COLUMN user_service_packages.paid_amount IS
  'A1: 实付金额 (主货币单位,如 GBP)';
COMMENT ON COLUMN user_service_packages.bundle_breakdown IS
  'A1: bundle 套餐每个子服务的进度。格式: {"service_id": {"total": N, "used": M}}。multi 套餐为 NULL';
COMMENT ON COLUMN user_service_packages.last_redeemed_at IS
  'A1: 最近一次核销时间,用于"我的客户"列表排序';

-- 加 status 索引(查 active 套餐高频)
CREATE INDEX IF NOT EXISTS ix_user_packages_status
  ON user_service_packages(status)
  WHERE status = 'active';

-- ---------- PackageUsageLog ----------

ALTER TABLE package_usage_logs
  ADD COLUMN IF NOT EXISTS sub_service_id INTEGER NULL,
  ADD COLUMN IF NOT EXISTS redeem_method VARCHAR(20) NULL DEFAULT 'qr';

COMMENT ON COLUMN package_usage_logs.sub_service_id IS
  'A1: bundle 套餐核销时记录是哪个子服务被核销';
COMMENT ON COLUMN package_usage_logs.redeem_method IS
  'A1: 核销方式: qr | otp | manual';

COMMIT;
