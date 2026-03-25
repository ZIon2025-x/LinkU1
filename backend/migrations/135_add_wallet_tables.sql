-- 135_add_wallet_tables.sql
CREATE TABLE wallet_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) UNIQUE,
    balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    total_earned DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_withdrawn DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_spent DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'GBP',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE wallet_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id),
    type VARCHAR(20) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    balance_after DECIMAL(12, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'completed',
    source VARCHAR(50) NOT NULL,
    related_id VARCHAR(255),
    related_type VARCHAR(50),
    description TEXT,
    fee_amount DECIMAL(12, 2),
    gross_amount DECIMAL(12, 2),
    idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_wallet_tx_user_id ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_tx_type ON wallet_transactions(type);
CREATE INDEX idx_wallet_tx_status ON wallet_transactions(status);
CREATE INDEX idx_wallet_tx_created_at ON wallet_transactions(created_at);
CREATE INDEX idx_wallet_tx_related ON wallet_transactions(related_type, related_id);
