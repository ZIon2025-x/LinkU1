-- 扩大 location 字段长度：100 → 255
-- 原因：Google Places 返回的地址可能超过 100 字符
-- 例如：'Hilton Birmingham Metropole - Dining and drinks, The NEC Birmingham, Pendigo Way, Birmingham, B40 1PP, England, B40 1PP' (156 chars)

ALTER TABLE tasks ALTER COLUMN location TYPE VARCHAR(255);
ALTER TABLE flea_market_items ALTER COLUMN location TYPE VARCHAR(255);
ALTER TABLE activities ALTER COLUMN location TYPE VARCHAR(255);
ALTER TABLE task_expert_services ALTER COLUMN location TYPE VARCHAR(255);
