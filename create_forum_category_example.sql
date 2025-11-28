-- 创建论坛板块示例
-- 注意：此文件仅作为参考示例
-- 实际部署时会自动执行 backend/migrations/025_insert_default_forum_categories.sql 迁移文件
-- 如果需要手动执行，可以直接在数据库中执行这些SQL语句来创建板块

-- 示例1：创建一个"技术讨论"板块
INSERT INTO forum_categories (name, description, icon, sort_order, is_visible, is_admin_only)
VALUES ('技术讨论', '分享技术经验和解决方案', '💻', 1, true, false);

-- 示例2：创建一个"新手求助"板块
INSERT INTO forum_categories (name, description, icon, sort_order, is_visible, is_admin_only)
VALUES ('新手求助', '新手用户提问和求助', '❓', 2, true, false);

-- 示例3：创建一个"活动公告"板块（仅管理员可发帖）
INSERT INTO forum_categories (name, description, icon, sort_order, is_visible, is_admin_only)
VALUES ('活动公告', '平台活动和重要通知', '📢', 0, true, true);

-- 示例4：创建一个"闲聊灌水"板块
INSERT INTO forum_categories (name, description, icon, sort_order, is_visible, is_admin_only)
VALUES ('闲聊灌水', '轻松话题和日常交流', '💬', 3, true, false);

-- 示例5：创建一个"经验分享"板块
INSERT INTO forum_categories (name, description, icon, sort_order, is_visible, is_admin_only)
VALUES ('经验分享', '分享成功经验、失败教训、心得体会', '💡', 4, true, false);

-- 示例6：创建一个"产品反馈"板块
INSERT INTO forum_categories (name, description, icon, sort_order, is_visible, is_admin_only)
VALUES ('产品反馈', '功能建议、问题反馈、使用体验', '📝', 5, true, false);

-- 示例7：创建一个"兴趣爱好"板块
INSERT INTO forum_categories (name, description, icon, sort_order, is_visible, is_admin_only)
VALUES ('兴趣爱好', '摄影、旅行、运动、音乐等兴趣爱好交流', '🎨', 6, true, false);

-- 查看所有板块
SELECT * FROM forum_categories ORDER BY sort_order, id;

