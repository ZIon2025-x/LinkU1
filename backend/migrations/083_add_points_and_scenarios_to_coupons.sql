-- 迁移 083：优惠券表添加积分兑换和适用场景字段
-- points_required: 积分兑换所需积分（0表示不支持积分兑换）
-- applicable_scenarios: 适用场景列表（JSON数组，如 ["task", "activity", "service", "flea_market"]）

-- 添加新字段
ALTER TABLE coupons
ADD COLUMN IF NOT EXISTS points_required INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS applicable_scenarios JSONB DEFAULT NULL;

-- 添加字段注释
COMMENT ON COLUMN coupons.points_required IS '积分兑换所需积分，0表示不支持积分兑换';
COMMENT ON COLUMN coupons.applicable_scenarios IS '适用场景列表，JSON数组格式，如 ["task", "activity", "service", "flea_market"]';

-- 创建GIN索引以优化场景查询
CREATE INDEX IF NOT EXISTS ix_coupons_scenarios ON coupons USING gin (applicable_scenarios);

-- 创建普通索引以优化积分筛选
CREATE INDEX IF NOT EXISTS ix_coupons_points ON coupons (points_required);

-- 注意：usage_conditions JSONB字段用于存储详细的使用条件（如task_types, locations, excluded_task_types等）
-- applicable_scenarios 用于高层场景分类，usage_conditions 用于场景内的细粒度限制
