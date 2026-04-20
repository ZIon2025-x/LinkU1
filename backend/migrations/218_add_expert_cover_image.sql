-- 218: 为达人团队添加封面图字段
-- 场景：首页「发现更多」推荐达人卡片需要封面；达人未设置时前端走类别渐变兜底
-- 安全：单纯加列，可回滚
ALTER TABLE experts
    ADD COLUMN IF NOT EXISTS cover_image TEXT;
