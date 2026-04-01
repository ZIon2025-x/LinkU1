-- 147_fix_forum_skill_constraints_and_seed.sql
-- Fix: 146 was marked as executed but INSERT failed due to CHECK constraint.
-- This migration updates the constraints and re-seeds skill categories.

-- 1. Update CHECK constraint to allow 'skill' type
ALTER TABLE forum_categories DROP CONSTRAINT IF EXISTS chk_forum_type;
ALTER TABLE forum_categories ADD CONSTRAINT chk_forum_type
    CHECK (type IN ('general', 'root', 'university', 'skill'));

-- 2. Update type+university_code constraint to also allow skill type
ALTER TABLE forum_categories DROP CONSTRAINT IF EXISTS chk_forum_type_university_code;
ALTER TABLE forum_categories ADD CONSTRAINT chk_forum_type_university_code
    CHECK (
        (type = 'university' AND university_code IS NOT NULL) OR
        (type IN ('general', 'root', 'skill') AND university_code IS NULL)
    );

-- 3. Seed skill categories (is_visible=false, enable via admin after new app is live)
INSERT INTO forum_categories (name, name_en, name_zh, description, description_en, description_zh, icon, sort_order, is_visible, is_admin_only, type, skill_type, post_count, created_at, updated_at)
VALUES
  ('Shopping', 'Shopping', '代购跑腿', 'Discuss shopping and purchasing help', 'Discuss shopping and purchasing help', '讨论代购跑腿相关话题', '🛒', 100, false, false, 'skill', 'shopping', 0, NOW(), NOW()),
  ('Tutoring', 'Tutoring', '课业辅导', 'Discuss tutoring and academic help', 'Discuss tutoring and academic help', '讨论课业辅导相关话题', '📚', 101, false, false, 'skill', 'tutoring', 0, NOW(), NOW()),
  ('Translation', 'Translation', '翻译服务', 'Discuss translation services', 'Discuss translation services', '讨论翻译服务相关话题', '🌐', 102, false, false, 'skill', 'translation', 0, NOW(), NOW()),
  ('Design', 'Design', '设计服务', 'Discuss design services', 'Discuss design services', '讨论设计服务相关话题', '🎨', 103, false, false, 'skill', 'design', 0, NOW(), NOW()),
  ('Programming', 'Programming', '编程开发', 'Discuss programming and development', 'Discuss programming and development', '讨论编程开发相关话题', '💻', 104, false, false, 'skill', 'programming', 0, NOW(), NOW()),
  ('Writing', 'Writing', '写作服务', 'Discuss writing services', 'Discuss writing services', '讨论写作服务相关话题', '✍️', 105, false, false, 'skill', 'writing', 0, NOW(), NOW()),
  ('Photography', 'Photography', '摄影服务', 'Discuss photography services', 'Discuss photography services', '讨论摄影服务相关话题', '📷', 106, false, false, 'skill', 'photography', 0, NOW(), NOW()),
  ('Moving', 'Moving', '搬家服务', 'Discuss moving services', 'Discuss moving services', '讨论搬家服务相关话题', '🚚', 107, false, false, 'skill', 'moving', 0, NOW(), NOW()),
  ('Cleaning', 'Cleaning', '清洁服务', 'Discuss cleaning services', 'Discuss cleaning services', '讨论清洁服务相关话题', '🧹', 108, false, false, 'skill', 'cleaning', 0, NOW(), NOW()),
  ('Repair', 'Repair', '维修服务', 'Discuss repair services', 'Discuss repair services', '讨论维修服务相关话题', '🔧', 109, false, false, 'skill', 'repair', 0, NOW(), NOW()),
  ('Pickup & Dropoff', 'Pickup & Dropoff', '接送服务', 'Discuss pickup and dropoff services', 'Discuss pickup and dropoff services', '讨论接送服务相关话题', '🚗', 110, false, false, 'skill', 'pickup_dropoff', 0, NOW(), NOW()),
  ('Cooking', 'Cooking', '烹饪服务', 'Discuss cooking services', 'Discuss cooking services', '讨论烹饪服务相关话题', '🍳', 111, false, false, 'skill', 'cooking', 0, NOW(), NOW()),
  ('Language Help', 'Language Help', '语言帮助', 'Discuss language help', 'Discuss language help', '讨论语言帮助相关话题', '🗣️', 112, false, false, 'skill', 'language_help', 0, NOW(), NOW()),
  ('Government', 'Government', '政务办理', 'Discuss government service help', 'Discuss government service help', '讨论政务办理相关话题', '🏛️', 113, false, false, 'skill', 'government', 0, NOW(), NOW()),
  ('Pet Care', 'Pet Care', '宠物照顾', 'Discuss pet care services', 'Discuss pet care services', '讨论宠物照顾相关话题', '🐾', 114, false, false, 'skill', 'pet_care', 0, NOW(), NOW()),
  ('Errand', 'Errand', '跑腿服务', 'Discuss errand running', 'Discuss errand running', '讨论跑腿服务相关话题', '🏃', 115, false, false, 'skill', 'errand', 0, NOW(), NOW()),
  ('Accompany', 'Accompany', '陪伴服务', 'Discuss accompaniment services', 'Discuss accompaniment services', '讨论陪伴服务相关话题', '🤝', 116, false, false, 'skill', 'accompany', 0, NOW(), NOW()),
  ('Digital', 'Digital', '数码服务', 'Discuss digital and tech services', 'Discuss digital and tech services', '讨论数码服务相关话题', '📱', 117, false, false, 'skill', 'digital', 0, NOW(), NOW()),
  ('Rental & Housing', 'Rental & Housing', '租房服务', 'Discuss rental and housing help', 'Discuss rental and housing help', '讨论租房服务相关话题', '🏠', 118, false, false, 'skill', 'rental_housing', 0, NOW(), NOW()),
  ('Campus Life', 'Campus Life', '校园生活', 'Discuss campus life services', 'Discuss campus life services', '讨论校园生活相关话题', '🎓', 119, false, false, 'skill', 'campus_life', 0, NOW(), NOW()),
  ('Second Hand', 'Second Hand', '二手交易', 'Discuss second-hand items and trading', 'Discuss second-hand items and trading', '讨论二手交易相关话题', '♻️', 120, false, false, 'skill', 'second_hand', 0, NOW(), NOW()),
  ('Other', 'Other', '其他服务', 'Discuss other services', 'Discuss other services', '讨论其他服务相关话题', '📌', 121, false, false, 'skill', 'other', 0, NOW(), NOW())
ON CONFLICT (name) DO NOTHING;
