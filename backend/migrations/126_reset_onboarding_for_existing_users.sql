-- 让现有用户也走一遍引导页（可跳过）
-- 撤销 migration 125 的效果
UPDATE users SET onboarding_completed = FALSE WHERE onboarding_completed = TRUE;
