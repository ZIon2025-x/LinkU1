-- 帖子支持文件附件（可与图片同时存在）
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT NULL;
COMMENT ON COLUMN forum_posts.attachments IS '文件附件列表 [{url, filename, size, content_type}]，可与图片同时存在';
