-- 141: Add stripe_connect_country to users table
-- Stores the country selected during Stripe Connect onboarding (ISO 3166-1 alpha-2)
-- Used to determine default wallet currency for the user

ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_connect_country VARCHAR(2);
