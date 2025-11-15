-- 迁移：初始化积分系统设置
-- 日期：2025-01-XX
-- 说明：为积分系统添加默认设置项

-- 插入或更新任务完成奖励积分设置（默认0）
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, created_at, updated_at)
VALUES ('points_task_complete_bonus', '0', 'number', '任务完成奖励积分（平台赠送，非任务报酬），默认值0表示不奖励', NOW(), NOW())
ON CONFLICT (setting_key) 
DO UPDATE SET 
    setting_value = EXCLUDED.setting_value,
    description = EXCLUDED.description,
    updated_at = NOW();

-- 插入或更新签到基础积分设置（默认0）
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, created_at, updated_at)
VALUES ('checkin_daily_base_points', '0', 'number', '每日签到基础积分奖励，默认值0表示不奖励', NOW(), NOW())
ON CONFLICT (setting_key) 
DO UPDATE SET 
    setting_value = EXCLUDED.setting_value,
    description = EXCLUDED.description,
    updated_at = NOW();

-- 验证设置是否创建成功
SELECT setting_key, setting_value, setting_type, description 
FROM system_settings 
WHERE setting_key IN ('points_task_complete_bonus', 'checkin_daily_base_points');

