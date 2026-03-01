-- 支持任务发布时“待报价”：不填金额时任务显示为待报价，接单者可议价
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS reward_to_be_quoted BOOLEAN DEFAULT false;
COMMENT ON COLUMN tasks.reward_to_be_quoted IS '是否待报价：true 表示发布时未填金额，由接单者报价/议价';
