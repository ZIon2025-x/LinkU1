-- 196: 达人团队营业时间 (开门关门 + 周几营业)
-- business_hours JSONB: {"mon": {"open": "09:00", "close": "18:00"}, "sun": null, ...}
-- key 缺失或 value=null 表示休息日

ALTER TABLE experts ADD COLUMN IF NOT EXISTS business_hours JSONB DEFAULT NULL;
