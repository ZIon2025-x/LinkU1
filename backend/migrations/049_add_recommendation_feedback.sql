-- ===========================================
-- 推荐反馈表（用于优化推荐算法）
-- ===========================================
-- 记录用户对推荐任务的反馈（喜欢/不喜欢）
-- 用于持续优化推荐算法

CREATE TABLE IF NOT EXISTS recommendation_feedback (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    recommendation_id VARCHAR(100),  -- 推荐批次ID（可选，用于追踪）
    feedback_type VARCHAR(20) NOT NULL,  -- like, dislike, not_interested, helpful
    feedback_time TIMESTAMPTZ DEFAULT NOW(),
    algorithm VARCHAR(50),  -- 使用的推荐算法
    match_score FLOAT,  -- 推荐时的匹配分数
    metadata JSONB,  -- 额外信息
    
    CONSTRAINT chk_feedback_type CHECK (feedback_type IN ('like', 'dislike', 'not_interested', 'helpful'))
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_user ON recommendation_feedback(user_id, feedback_time DESC);
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_task ON recommendation_feedback(task_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_type ON recommendation_feedback(feedback_type);
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_algorithm ON recommendation_feedback(algorithm);

-- 添加注释
COMMENT ON TABLE recommendation_feedback IS '推荐反馈表，用于优化推荐算法';
COMMENT ON COLUMN recommendation_feedback.feedback_type IS '反馈类型：like(喜欢), dislike(不喜欢), not_interested(不感兴趣), helpful(有帮助)';
COMMENT ON COLUMN recommendation_feedback.recommendation_id IS '推荐批次ID，用于追踪同一批推荐的效果';
