-- 138_add_flea_market_rental_support.sql
-- Add rental support to flea market: listing_type, deposit, rental_price, rental_unit

-- Add rental fields to flea_market_items
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS listing_type VARCHAR(20) NOT NULL DEFAULT 'sale';
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS deposit DECIMAL(12,2);
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS rental_price DECIMAL(12,2);
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS rental_unit VARCHAR(20);

-- Index for listing_type filter
CREATE INDEX IF NOT EXISTS idx_flea_market_items_listing_type ON flea_market_items (listing_type);

-- Check constraint for listing_type values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_listing_type_valid'
    ) THEN
        ALTER TABLE flea_market_items ADD CONSTRAINT check_listing_type_valid
            CHECK (listing_type IN ('sale', 'rental'));
    END IF;
END $$;
