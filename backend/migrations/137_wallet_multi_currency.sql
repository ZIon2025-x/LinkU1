-- 137_wallet_multi_currency.sql
-- Support multiple currency wallets per user (GBP + EUR)

-- Remove the old unique constraint on user_id only
ALTER TABLE wallet_accounts DROP CONSTRAINT IF EXISTS wallet_accounts_user_id_key;

-- Drop the old unique index (created as Index with unique=True)
DROP INDEX IF EXISTS uq_wallet_user_currency;

-- Add composite unique constraint (user_id, currency)
ALTER TABLE wallet_accounts ADD CONSTRAINT uq_wallet_user_currency UNIQUE (user_id, currency);

-- Add currency column to wallet_transactions (if not already present)
ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NOT NULL DEFAULT 'GBP';

-- Fix idempotency_key column length (from 64 to 128) for longer keys
ALTER TABLE wallet_transactions ALTER COLUMN idempotency_key TYPE VARCHAR(128);
