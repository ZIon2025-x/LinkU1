-- 热搜榜快照表 - 持久化 Top N，让老词在没有新搜索时也能"挂着"
-- 用于实现 sticky trending：老词权重被冻结，只有新词权重更高才能挤下去

CREATE TABLE IF NOT EXISTS trending_snapshot (
    rank            INT PRIMARY KEY,              -- 1..N，主键即排名
    keyword         VARCHAR(200) NOT NULL,
    tokens          JSONB NOT NULL DEFAULT '[]'::jsonb,
    view_count      INT NOT NULL DEFAULT 0,
    heat_display    VARCHAR(50) NOT NULL DEFAULT '',
    tag             VARCHAR(20),                  -- hot/new/up/NULL
    weighted_count  DOUBLE PRECISION NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trending_snapshot_keyword
    ON trending_snapshot (keyword);
