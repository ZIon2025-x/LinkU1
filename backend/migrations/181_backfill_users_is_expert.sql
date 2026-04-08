-- 181_backfill_users_is_expert.sql
-- 把所有已经在 expert_members 表里的活跃用户回填为 is_expert = true
-- 背景：fix(profile) add1de328 只让"新加入"的成员获得 is_expert，
--      历史成员未回填，导致 Flutter 端达人入口（依赖 user.is_expert）不显示。

UPDATE users
SET is_expert = TRUE
WHERE is_expert = FALSE
  AND id IN (
    SELECT DISTINCT user_id
    FROM expert_members
    WHERE status = 'active'
  );
