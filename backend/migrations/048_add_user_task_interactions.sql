-- ===========================================
-- 用户任务交互表（用于推荐系统）
-- ===========================================
-- 用于记录用户对任务的浏览、点击、申请等行为
-- 支持任务推荐算法的数据收集

CREATE TABLE IF NOT EXISTS user_task_interactions (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL,  -- view, click, apply, accept, complete, skip
    interaction_time TIMESTAMPTZ DEFAULT NOW(),
    duration_seconds INTEGER,  -- 浏览时长（秒）
    device_type VARCHAR(20),  -- mobile, desktop, tablet
    metadata JSONB,  -- 额外信息（如来源页面、推荐原因等）
    
    CONSTRAINT chk_interaction_type CHECK (interaction_type IN ('view', 'click', 'apply', 'accept', 'complete', 'skip'))
);

-- 创建索引以优化查询性能
CREATE INDEX IF NOT EXISTS idx_interactions_user ON user_task_interactions(user_id, interaction_time DESC);
CREATE INDEX IF NOT EXISTS idx_interactions_task ON user_task_interactions(task_id);
CREATE INDEX IF NOT EXISTS idx_interactions_type ON user_task_interactions(interaction_type);
CREATE INDEX IF NOT EXISTS idx_interactions_user_task ON user_task_interactions(user_id, task_id);
CREATE INDEX IF NOT EXISTS idx_interactions_time ON user_task_interactions(interaction_time DESC);

-- 添加注释
COMMENT ON TABLE user_task_interactions IS '用户任务交互记录表，用于推荐系统数据收集';
COMMENT ON COLUMN user_task_interactions.interaction_type IS '交互类型：view(浏览), click(点击), apply(申请), accept(接受), complete(完成), skip(跳过)';
COMMENT ON COLUMN user_task_interactions.duration_seconds IS '浏览时长（秒），仅用于view类型';
COMMENT ON COLUMN user_task_interactions.device_type IS '设备类型：mobile(手机), desktop(桌面), tablet(平板)';
COMMENT ON COLUMN user_task_interactions.metadata IS '额外信息JSON，如来源页面、推荐原因等';
