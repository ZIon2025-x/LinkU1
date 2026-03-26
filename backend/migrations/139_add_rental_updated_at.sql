-- Add updated_at column to flea_market_rentals
ALTER TABLE flea_market_rentals
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

UPDATE flea_market_rentals SET updated_at = created_at WHERE updated_at IS NULL;
