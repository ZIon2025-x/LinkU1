-- 148_populate_skill_categories.sql
-- Add task_type bridge column and seed skill_categories table

-- 1. Add task_type column (with temp default for existing rows, if any)
ALTER TABLE skill_categories ADD COLUMN IF NOT EXISTS task_type VARCHAR(50);

-- 2. Seed 22 skill categories matching TASK_TYPES
INSERT INTO skill_categories (task_type, name_zh, name_en, icon, display_order, is_active, created_at)
VALUES
  ('shopping',        '代购跑腿', 'Shopping',         '🛒', 1,  true, NOW()),
  ('tutoring',        '课业辅导', 'Tutoring',         '📚', 2,  true, NOW()),
  ('translation',     '翻译服务', 'Translation',      '🌐', 3,  true, NOW()),
  ('design',          '设计服务', 'Design',           '🎨', 4,  true, NOW()),
  ('programming',     '编程开发', 'Programming',      '💻', 5,  true, NOW()),
  ('writing',         '写作服务', 'Writing',          '✍️', 6,  true, NOW()),
  ('photography',     '摄影服务', 'Photography',      '📷', 7,  true, NOW()),
  ('moving',          '搬家服务', 'Moving',           '🚚', 8,  true, NOW()),
  ('cleaning',        '清洁服务', 'Cleaning',         '🧹', 9,  true, NOW()),
  ('repair',          '维修服务', 'Repair',           '🔧', 10, true, NOW()),
  ('pickup_dropoff',  '接送服务', 'Pickup & Dropoff', '🚗', 11, true, NOW()),
  ('cooking',         '烹饪服务', 'Cooking',          '🍳', 12, true, NOW()),
  ('language_help',   '语言帮助', 'Language Help',    '🗣️', 13, true, NOW()),
  ('government',      '政务办理', 'Government',       '🏛️', 14, true, NOW()),
  ('pet_care',        '宠物照顾', 'Pet Care',         '🐾', 15, true, NOW()),
  ('errand',          '跑腿服务', 'Errand',           '🏃', 16, true, NOW()),
  ('accompany',       '陪伴服务', 'Accompany',        '🤝', 17, true, NOW()),
  ('digital',         '数码服务', 'Digital',          '📱', 18, true, NOW()),
  ('rental_housing',  '租房服务', 'Rental & Housing', '🏠', 19, true, NOW()),
  ('campus_life',     '校园生活', 'Campus Life',      '🎓', 20, true, NOW()),
  ('second_hand',     '二手交易', 'Second Hand',      '♻️', 21, true, NOW()),
  ('other',           '其他服务', 'Other',            '📌', 22, true, NOW())
ON CONFLICT DO NOTHING;

-- 3. Now enforce NOT NULL and UNIQUE on task_type
ALTER TABLE skill_categories ALTER COLUMN task_type SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_skill_categories_task_type ON skill_categories(task_type);
