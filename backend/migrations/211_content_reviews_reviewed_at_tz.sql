-- 211: content_reviews.reviewed_at → TIMESTAMP WITH TIME ZONE
--
-- 背景: ContentReview.reviewed_at 当初建表时漏写了 timezone=True (models.py:2598),
--       而 utils/time_utils.get_utc_time() 返回 tz-aware UTC datetime,且
--       全仓其他 9 个 reviewed_at 列都是 DateTime(timezone=True)。结果 admin panel
--       "内容审核" 页面点"通过/拒绝"时,asyncpg 把 tz-aware datetime 送进
--       TIMESTAMP WITHOUT TIME ZONE 列触发 DataError (can't subtract
--       offset-naive and offset-aware datetimes) → PUT /api/admin/content-moderation/
--       content-reviews/{id} 一直 500。
--
-- 由于该列唯一写入点就是出错的那个路由,历史上几乎所有 PUT 都失败,
-- 现存非 NULL 值极少 (若有)。把裸值按 UTC 解释符合 time_utils 规约。

ALTER TABLE content_reviews
  ALTER COLUMN reviewed_at TYPE TIMESTAMP WITH TIME ZONE
  USING reviewed_at AT TIME ZONE 'UTC';
