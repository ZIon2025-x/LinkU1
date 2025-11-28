-- 为论坛搜索添加 pg_trgm 扩展支持
-- 创建时间: 2025-01-27
-- 说明: 启用 pg_trgm 扩展并创建相似度搜索索引，优化中文搜索体验

-- 1. 启用 pg_trgm 扩展
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. 为论坛帖子创建 pg_trgm GIN 索引（用于相似度搜索）
-- 注意：如果已有旧的全文搜索索引，可以保留作为备用
-- pg_trgm 索引对中文搜索效果更好

-- 为标题创建 pg_trgm 索引
CREATE INDEX IF NOT EXISTS idx_forum_posts_title_trgm 
ON forum_posts USING gin(title gin_trgm_ops);

-- 为内容创建 pg_trgm 索引（注意：内容字段较大，索引也会较大）
CREATE INDEX IF NOT EXISTS idx_forum_posts_content_trgm 
ON forum_posts USING gin(content gin_trgm_ops);

-- 3. 可选：创建组合索引（标题+内容），提升搜索性能
-- 注意：这个索引会比较大，如果数据量很大，可以考虑只使用上面的单列索引
-- CREATE INDEX IF NOT EXISTS idx_forum_posts_title_content_trgm 
-- ON forum_posts USING gin((title || ' ' || content) gin_trgm_ops);

-- 4. 说明：
-- - pg_trgm 使用三元组（trigram）进行相似度匹配
-- - similarity(text1, text2) 返回 0-1 之间的相似度值
-- - 通常使用阈值 0.2-0.3 进行过滤
-- - 对中文、英文、数字都有良好的支持
-- - 相比 simple 配置的 tsvector，对中文分词效果更好

