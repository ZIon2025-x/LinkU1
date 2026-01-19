-- 添加奖励申请者相关字段到 activities 表
-- 用于支持任务达人给予申请者额外奖励的功能

-- 添加 reward_applicants 字段（是否奖励申请者）
ALTER TABLE activities 
ADD COLUMN IF NOT EXISTS reward_applicants BOOLEAN NOT NULL DEFAULT FALSE;

-- 添加 applicant_reward_amount 字段（申请者奖励金额）
ALTER TABLE activities 
ADD COLUMN IF NOT EXISTS applicant_reward_amount DECIMAL(12, 2) NULL;

-- 添加 applicant_points_reward 字段（申请者积分奖励）
ALTER TABLE activities 
ADD COLUMN IF NOT EXISTS applicant_points_reward BIGINT NULL;

-- 添加 reserved_points_total 字段（预扣积分总额）
ALTER TABLE activities 
ADD COLUMN IF NOT EXISTS reserved_points_total BIGINT NULL DEFAULT 0;

-- 添加 distributed_points_total 字段（已发放积分总额）
ALTER TABLE activities 
ADD COLUMN IF NOT EXISTS distributed_points_total BIGINT NULL DEFAULT 0;

-- 添加索引以便快速查询奖励申请者的活动
CREATE INDEX IF NOT EXISTS ix_activities_reward_applicants 
ON activities(reward_applicants);

-- 添加注释
COMMENT ON COLUMN activities.reward_applicants IS '是否奖励申请者（完成任务后给予申请者额外奖励，而不是申请者付费）';
COMMENT ON COLUMN activities.applicant_reward_amount IS '申请者奖励金额（当 reward_applicants=TRUE 且 reward_type 包含 cash 时使用）';
COMMENT ON COLUMN activities.applicant_points_reward IS '申请者积分奖励（当 reward_applicants=TRUE 且 reward_type 包含 points 时使用）';
COMMENT ON COLUMN activities.reserved_points_total IS '预扣积分总额（创建活动时从达人账户预扣的积分，用于后续返还计算）';
COMMENT ON COLUMN activities.distributed_points_total IS '已发放积分总额（已奖励给申请者的积分）';
