-- 105: 优惠券增加 distribution_type 字段
-- public: 公开展示（默认，用户可在可用券列表中看到）
-- code_only: 仅限兑换码领取（不在公开列表中展示）

ALTER TABLE coupons ADD COLUMN IF NOT EXISTS distribution_type VARCHAR(20) DEFAULT 'public';
