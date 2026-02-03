-- 迁移 081：OAuth 2.0 / OIDC Provider 表
-- oauth_client: 第三方应用（RP）注册信息
-- oauth_refresh_token: refresh_token 持久化与撤销（授权码仅存 Redis，不建表）

CREATE TABLE oauth_client (
    id SERIAL PRIMARY KEY,
    client_id VARCHAR(64) NOT NULL UNIQUE,
    client_secret_hash VARCHAR(128),
    client_name VARCHAR(255) NOT NULL,
    client_uri VARCHAR(512),
    logo_uri VARCHAR(512),
    redirect_uris JSONB NOT NULL DEFAULT '[]',
    scope_default VARCHAR(512),
    allowed_grant_types JSONB NOT NULL DEFAULT '["authorization_code"]',
    is_confidential BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_oauth_client_client_id ON oauth_client(client_id);
CREATE INDEX idx_oauth_client_is_active ON oauth_client(is_active);

CREATE TABLE oauth_refresh_token (
    id SERIAL PRIMARY KEY,
    token VARCHAR(256) NOT NULL UNIQUE,
    client_id VARCHAR(64) NOT NULL,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scope VARCHAR(512) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_oauth_refresh_token_token ON oauth_refresh_token(token);
CREATE INDEX idx_oauth_refresh_token_client_id ON oauth_refresh_token(client_id);
CREATE INDEX idx_oauth_refresh_token_expires_at ON oauth_refresh_token(expires_at);
