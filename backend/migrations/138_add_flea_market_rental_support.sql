-- 138_add_flea_market_rental_support.sql
-- Add rental support to flea market

-- 1. Add rental fields to flea_market_items
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS listing_type VARCHAR(20) NOT NULL DEFAULT 'sale';
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS deposit DECIMAL(12,2);
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS rental_price DECIMAL(12,2);
ALTER TABLE flea_market_items ADD COLUMN IF NOT EXISTS rental_unit VARCHAR(20);

CREATE INDEX IF NOT EXISTS idx_flea_market_items_listing_type ON flea_market_items (listing_type);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_listing_type_valid'
    ) THEN
        ALTER TABLE flea_market_items ADD CONSTRAINT check_listing_type_valid
            CHECK (listing_type IN ('sale', 'rental'));
    END IF;
END $$;

-- 2. Create flea_market_rental_requests table
CREATE TABLE IF NOT EXISTS flea_market_rental_requests (
    id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES flea_market_items(id) ON DELETE CASCADE,
    renter_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rental_duration INTEGER NOT NULL,
    desired_time TEXT,
    usage_description TEXT,
    proposed_rental_price DECIMAL(12,2),
    counter_rental_price DECIMAL(12,2),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    payment_expires_at TIMESTAMP WITH TIME ZONE,
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT check_rental_request_status_valid
        CHECK (status IN ('pending', 'approved', 'rejected', 'counter_offer', 'expired'))
);

CREATE INDEX IF NOT EXISTS idx_flea_market_rental_requests_item_id ON flea_market_rental_requests (item_id);
CREATE INDEX IF NOT EXISTS idx_flea_market_rental_requests_renter_id ON flea_market_rental_requests (renter_id);

-- 3. Create flea_market_rentals table
CREATE TABLE IF NOT EXISTS flea_market_rentals (
    id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES flea_market_items(id) ON DELETE CASCADE,
    renter_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    request_id INTEGER REFERENCES flea_market_rental_requests(id) ON DELETE SET NULL,
    rental_duration INTEGER NOT NULL,
    rental_unit VARCHAR(20) NOT NULL,
    total_rent DECIMAL(12,2) NOT NULL,
    deposit_amount DECIMAL(12,2) NOT NULL,
    total_paid DECIMAL(12,2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'GBP',
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    deposit_status VARCHAR(20) NOT NULL DEFAULT 'held',
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    stripe_refund_id VARCHAR(255),
    returned_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT check_rental_status_valid
        CHECK (status IN ('active', 'returned', 'overdue', 'disputed')),
    CONSTRAINT check_deposit_status_valid
        CHECK (deposit_status IN ('held', 'refunded', 'forfeited'))
);

CREATE INDEX IF NOT EXISTS idx_flea_market_rentals_item_id ON flea_market_rentals (item_id);
CREATE INDEX IF NOT EXISTS idx_flea_market_rentals_renter_id ON flea_market_rentals (renter_id);
