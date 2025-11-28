-- 插入默认论坛板块
-- 创建时间: 2025-01-27
-- 说明: 自动插入默认的论坛板块，如果板块已存在则跳过（基于 name 唯一约束）

-- 使用 ON CONFLICT 确保幂等性，如果板块名称已存在则跳过
INSERT INTO forum_categories (name, description, icon, sort_order, is_visible, is_admin_only)
VALUES 
    ('活动公告', '平台活动和重要通知', '📢', 0, true, true),
    ('技术讨论', '分享技术经验和解决方案', '💻', 1, true, false),
    ('新手求助', '新手用户提问和求助', '❓', 2, true, false),
    ('闲聊灌水', '轻松话题和日常交流', '💬', 3, true, false),
    ('经验分享', '分享成功经验、失败教训、心得体会', '💡', 4, true, false),
    ('产品反馈', '功能建议、问题反馈、使用体验', '📝', 5, true, false),
    ('兴趣爱好', '摄影、旅行、运动、音乐等兴趣爱好交流', '🎨', 6, true, false)
ON CONFLICT (name) DO NOTHING;

