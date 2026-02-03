-- 迁移 080：优惠券「每用户每周期限领」可配置
-- per_user_per_month_limit: 每用户每月限领次数（兼容旧逻辑，与下方二选一或同时存在时优先用下方）
-- per_user_limit_window: 周期类型 day | week | month | year
-- per_user_per_window_limit: 该周期内每用户限领次数（与 per_user_limit_window 配合使用）

ALTER TABLE coupons
ADD COLUMN IF NOT EXISTS per_user_per_month_limit INTEGER DEFAULT NULL,
ADD COLUMN IF NOT EXISTS per_user_limit_window VARCHAR(20) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS per_user_per_window_limit INTEGER DEFAULT NULL;

COMMENT ON COLUMN coupons.per_user_per_month_limit IS '每用户每月限领次数，NULL 表示不限制；未配置 window 时生效';
COMMENT ON COLUMN coupons.per_user_limit_window IS '每用户限领周期：day=按日, week=按周(ISO周一), month=按月, year=按年；与 per_user_per_window_limit 配合';
COMMENT ON COLUMN coupons.per_user_per_window_limit IS '每个周期内每用户限领次数；与 per_user_limit_window 配合使用';

-- 优化「每周期限领」统计查询：按 user_id + coupon_id + obtained_at 范围计数
CREATE INDEX IF NOT EXISTS ix_user_coupons_user_coupon_obtained
ON user_coupons (user_id, coupon_id, obtained_at);
