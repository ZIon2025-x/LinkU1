CREATE TABLE IF NOT EXISTS newbie_task_config (
    id SERIAL PRIMARY KEY,
    task_key VARCHAR(50) UNIQUE NOT NULL,
    stage INTEGER NOT NULL,
    title_zh VARCHAR(200) NOT NULL,
    title_en VARCHAR(200) NOT NULL,
    description_zh TEXT DEFAULT '',
    description_en TEXT DEFAULT '',
    reward_type VARCHAR(20) NOT NULL DEFAULT 'points',
    reward_amount INTEGER NOT NULL DEFAULT 0,
    coupon_id INTEGER REFERENCES coupons(id),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stage_bonus_config (
    id SERIAL PRIMARY KEY,
    stage INTEGER UNIQUE NOT NULL,
    title_zh VARCHAR(200) NOT NULL,
    title_en VARCHAR(200) NOT NULL,
    reward_type VARCHAR(20) NOT NULL DEFAULT 'points',
    reward_amount INTEGER NOT NULL DEFAULT 0,
    coupon_id INTEGER REFERENCES coupons(id),
    is_active BOOLEAN DEFAULT true,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_tasks_progress (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_key VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    completed_at TIMESTAMP,
    claimed_at TIMESTAMP,
    UNIQUE(user_id, task_key)
);
CREATE INDEX IF NOT EXISTS idx_user_tasks_progress_user_id ON user_tasks_progress(user_id);

CREATE TABLE IF NOT EXISTS stage_bonus_progress (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stage INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    claimed_at TIMESTAMP,
    UNIQUE(user_id, stage)
);

-- Seed default newbie task configs
INSERT INTO newbie_task_config (task_key, stage, title_zh, title_en, description_zh, description_en, reward_type, reward_amount, display_order) VALUES
('upload_avatar', 1, '上传头像', 'Upload Avatar', '上传一张个人头像，让大家认识你', 'Upload a profile photo so others can recognize you', 'points', 50, 1),
('fill_bio', 1, '填写个人简介', 'Write Bio', '填写至少10个字的个人简介', 'Write a bio with at least 10 characters', 'points', 50, 2),
('add_skills', 1, '添加技能标签', 'Add Skills', '添加至少3个技能标签', 'Add at least 3 skill tags', 'points', 100, 3),
('student_verify', 1, '完成学生认证', 'Student Verification', '完成学生邮箱认证', 'Complete student email verification', 'points', 200, 4),
('first_post', 2, '发布第一个帖子', 'First Forum Post', '在论坛发布你的第一个帖子', 'Publish your first forum post', 'points', 200, 5),
('first_flea_item', 2, '发布跳蚤市场商品', 'First Flea Market Item', '在跳蚤市场发布你的第一个商品或服务', 'List your first item or service on the flea market', 'points', 200, 6),
('join_activity', 2, '参加一个活动', 'Join an Activity', '报名参加一个平台活动', 'Sign up for a platform activity', 'points', 200, 7),
('posts_5', 3, '累计发帖5个', '5 Forum Posts', '在论坛累计发布5个帖子', 'Publish 5 forum posts in total', 'points', 300, 8),
('posts_20', 3, '累计发帖20个', '20 Forum Posts', '在论坛累计发布20个帖子', 'Publish 20 forum posts in total', 'points', 500, 9),
('first_assigned_task', 3, '收到第一个指定任务', 'First Assigned Task', '有人向你发布了指定任务', 'Someone assigned a task specifically to you', 'points', 500, 10),
('complete_5_tasks', 3, '完成5个好评任务', '5 Well-Rated Tasks', '完成5个任务并获得好评(评分>=4)', 'Complete 5 tasks with good ratings (>=4)', 'points', 500, 11),
('profile_views_50', 3, '主页被浏览50次', '50 Profile Views', '你的个人主页被浏览了50次', 'Your profile has been viewed 50 times', 'points', 300, 12),
('profile_views_200', 3, '主页被浏览200次', '200 Profile Views', '你的个人主页被浏览了200次', 'Your profile has been viewed 200 times', 'points', 500, 13),
('checkin_7', 3, '连续签到7天', '7-Day Check-in Streak', '连续签到7天', 'Check in for 7 consecutive days', 'points', 200, 14),
('checkin_30', 3, '连续签到30天', '30-Day Check-in Streak', '连续签到30天', 'Check in for 30 consecutive days', 'points', 500, 15)
ON CONFLICT (task_key) DO NOTHING;

INSERT INTO stage_bonus_config (stage, title_zh, title_en, reward_type, reward_amount) VALUES
(1, '第一阶段完成奖励', 'Stage 1 Completion Bonus', 'points', 100),
(2, '第二阶段完成奖励', 'Stage 2 Completion Bonus', 'coupon', 0),
(3, '第三阶段完成奖励', 'Stage 3 Completion Bonus', 'points', 1000)
ON CONFLICT (stage) DO NOTHING;
