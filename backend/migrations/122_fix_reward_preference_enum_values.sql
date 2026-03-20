-- 修复 reward_preference 枚举值：后端使用 frequent_low/rare_high 但 Flutter 使用 high_freq_low_amount/low_freq_high_amount
-- 统一为 Flutter 命名（更直观）

-- 加宽列以容纳更长的枚举值名称
ALTER TABLE user_profile_preferences ALTER COLUMN reward_preference TYPE VARCHAR(30);

-- 修正已有的旧值
UPDATE user_profile_preferences SET reward_preference = 'high_freq_low_amount' WHERE reward_preference = 'frequent_low';
UPDATE user_profile_preferences SET reward_preference = 'low_freq_high_amount' WHERE reward_preference = 'rare_high';
