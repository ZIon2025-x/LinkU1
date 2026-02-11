-- Migration 090: Add images and linked item support to forum posts
-- For Discovery Feed feature: posts can now include images and link to other content

-- 帖子图片（JSON数组，最多5张）
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS images JSON DEFAULT NULL;

-- 帖子关联内容类型（service/expert/activity/product/ranking/forum_post）
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS linked_item_type VARCHAR(30) DEFAULT NULL;

-- 帖子关联内容ID
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS linked_item_id VARCHAR(50) DEFAULT NULL;

-- 索引：方便按关联类型查询
CREATE INDEX IF NOT EXISTS idx_forum_posts_linked_item 
    ON forum_posts (linked_item_type, linked_item_id) 
    WHERE linked_item_type IS NOT NULL;
