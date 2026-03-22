-- 现有用户已经使用过平台，不需要走引导页
-- 只有新注册的用户才需要完成引导（默认 false）
UPDATE users SET onboarding_completed = TRUE WHERE onboarding_completed = FALSE;
