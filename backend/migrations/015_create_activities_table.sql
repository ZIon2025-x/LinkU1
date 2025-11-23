-- ===========================================
-- 迁移 015: 创建活动表（Activity表）
-- ===========================================
-- 
-- 此迁移创建 activities 表，用于存储任务达人发布的多人活动
-- 活动表和任务表分开，避免混淆
-- 用户申请活动后，会在任务表中创建对应的任务
--
-- 执行时间: 2025-11-23
-- ===========================================

-- 创建活动表
CREATE TABLE IF NOT EXISTS activities (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    expert_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expert_service_id INTEGER NOT NULL REFERENCES task_expert_services(id) ON DELETE RESTRICT,
    location VARCHAR(100) NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    -- 价格相关
    reward_type VARCHAR(20) NOT NULL DEFAULT 'cash',  -- cash, points, both
    original_price_per_participant DECIMAL(12, 2),
    discount_percentage DECIMAL(5, 2),
    discounted_price_per_participant DECIMAL(12, 2),
    currency VARCHAR(3) DEFAULT 'GBP',
    points_reward BIGINT,
    -- 参与者相关
    max_participants INTEGER NOT NULL DEFAULT 1,
    min_participants INTEGER NOT NULL DEFAULT 1,
    completion_rule VARCHAR(20) DEFAULT 'all',  -- all, min
    reward_distribution VARCHAR(20) DEFAULT 'equal',  -- equal, custom
    -- 活动状态
    status VARCHAR(20) NOT NULL DEFAULT 'open',  -- open, closed, cancelled, completed
    is_public BOOLEAN DEFAULT TRUE,
    visibility VARCHAR(20) DEFAULT 'public',  -- public, private
    -- 截止日期（非时间段服务使用）
    deadline TIMESTAMPTZ,
    -- 活动截至日期（时间段服务使用，可选）
    activity_end_date DATE,
    -- 图片
    images JSONB,
    -- 时间段相关（如果关联时间段服务）
    has_time_slots BOOLEAN DEFAULT FALSE,
    -- 创建时间
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_activity_status CHECK (
        status IN ('open', 'closed', 'cancelled', 'completed')
    ),
    CONSTRAINT chk_activity_reward_type CHECK (
        reward_type IN ('cash', 'points', 'both')
    ),
    CONSTRAINT chk_activity_completion_rule CHECK (
        completion_rule IN ('all', 'min')
    ),
    CONSTRAINT chk_activity_reward_distribution CHECK (
        reward_distribution IN ('equal', 'custom')
    ),
    CONSTRAINT chk_activity_participants CHECK (
        min_participants > 0 AND max_participants >= min_participants
    )
);

-- 创建索引
CREATE INDEX IF NOT EXISTS ix_activities_expert_id ON activities(expert_id);
CREATE INDEX IF NOT EXISTS ix_activities_expert_service_id ON activities(expert_service_id);
CREATE INDEX IF NOT EXISTS ix_activities_status ON activities(status);
CREATE INDEX IF NOT EXISTS ix_activities_deadline ON activities(deadline);
CREATE INDEX IF NOT EXISTS ix_activities_activity_end_date ON activities(activity_end_date);
CREATE INDEX IF NOT EXISTS ix_activities_has_time_slots ON activities(has_time_slots);

-- 添加注释
COMMENT ON TABLE activities IS '活动表 - 存储任务达人发布的多人活动';
COMMENT ON COLUMN activities.expert_id IS '任务达人ID';
COMMENT ON COLUMN activities.expert_service_id IS '关联的服务ID';
COMMENT ON COLUMN activities.has_time_slots IS '是否关联时间段服务';
COMMENT ON COLUMN activities.deadline IS '截止日期（非时间段服务使用）';
COMMENT ON COLUMN activities.activity_end_date IS '活动截至日期（时间段服务使用，可选）';

-- 添加更新时间触发器
CREATE OR REPLACE FUNCTION update_activities_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_activities_updated_at
    BEFORE UPDATE ON activities
    FOR EACH ROW
    EXECUTE FUNCTION update_activities_updated_at();

DO $$
BEGIN
    RAISE NOTICE '迁移 015 执行完成: 已创建活动表';
END $$;

