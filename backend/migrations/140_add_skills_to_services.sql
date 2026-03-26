-- 为个人服务/达人服务添加技能标签字段
ALTER TABLE task_expert_services ADD COLUMN IF NOT EXISTS skills JSONB DEFAULT NULL;

COMMENT ON COLUMN task_expert_services.skills IS '技能标签 JSON数组，如 ["Python", "Flutter"]';
