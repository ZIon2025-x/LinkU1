-- Add consulting support to task_applications and flea_market_purchase_requests

-- 1. task_applications.status is VARCHAR(20) with no CHECK constraint,
--    so 'consulting', 'negotiating', 'price_agreed' are already valid.

-- 2. flea_market_purchase_requests: drop old CHECK and add new statuses
ALTER TABLE flea_market_purchase_requests
    DROP CONSTRAINT IF EXISTS check_status_valid;

ALTER TABLE flea_market_purchase_requests
    ADD CONSTRAINT check_status_valid
    CHECK (status IN ('pending', 'seller_negotiating', 'accepted', 'rejected',
                      'consulting', 'negotiating', 'price_agreed', 'cancelled'));

-- 3. Add task_id column for message routing (placeholder task)
ALTER TABLE flea_market_purchase_requests
    ADD COLUMN IF NOT EXISTS task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL;

-- 4. Add final_price column for agreed negotiation price
ALTER TABLE flea_market_purchase_requests
    ADD COLUMN IF NOT EXISTS final_price DECIMAL(12,2);

-- 5. Index for consulting lookups
CREATE INDEX IF NOT EXISTS ix_task_applications_consulting
    ON task_applications (applicant_id, task_id, status)
    WHERE status IN ('consulting', 'negotiating', 'price_agreed');

CREATE INDEX IF NOT EXISTS ix_flea_purchase_consulting
    ON flea_market_purchase_requests (buyer_id, item_id, status)
    WHERE status IN ('consulting', 'negotiating', 'price_agreed');
