-- 228_backfill_user_avg_rating_received.sql
--
-- 历史 bug 回填:User.avg_rating 之前由 6 处代码用
-- `Review.user_id == user_id` 聚合,但 Review.user_id 是评价**作者**
-- (`models.py:179, 309: foreign_keys=Review.user_id`)。语义应当是"该 user
-- *收到*的评价均分",必须经 Task 反查对方写的评价。
-- 代码层修复见: app/crud/review.py:_received_avg_rating_select +
-- get_user_received_avg_rating;6 处调用方都已切到 helper。
-- 此 migration 把存量 User.avg_rating 一次性回填到正确语义。

UPDATE users u
SET avg_rating = COALESCE((
  SELECT AVG(r.rating)
  FROM reviews r
  JOIN tasks t ON r.task_id = t.id
  WHERE r.is_deleted = false
    AND (
      (t.poster_id = u.id AND r.user_id = t.taker_id)
      OR (t.taker_id = u.id AND r.user_id = t.poster_id)
    )
), 0.0);
