// Package database manages the PostgreSQL connection pool lifecycle and
// executes idempotent schema migrations on startup.
package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ConnectPool initializes and validates a concurrent connection pool to the
// PostgreSQL database using the provided connection URI.
func ConnectPool(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	poolConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse DATABASE_URL: %w", err)
	}

	poolConfig.MaxConns = 10
	poolConfig.MinConns = 0
	poolConfig.MaxConnLifetime = 30 * time.Minute
	poolConfig.MaxConnIdleTime = 5 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create PostgreSQL connection pool: %w", err)
	}

	pingCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping PostgreSQL database: %w", err)
	}

	return pool, nil
}

// RunMigrations applies the core relational schema (users, transactions,
// budgets, bills, credit_cards, password_reset_tokens, and
// email_verification_tokens) idempotently, including NUMERIC(14,2) monetary
// precision and UUID/soft-delete columns.
func RunMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	const schemaDDL = `
-- 1. Tabela users e evolução idempotente de perfil/notificações/verificação
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT TRUE,
    email_verified_at TIMESTAMPTZ,
    monthly_income NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    savings_goal_percent NUMERIC(5, 2) NOT NULL DEFAULT 20.00,
    reminder_time_1 VARCHAR(5) NOT NULL DEFAULT '09:00',
    reminder_time_2 VARCHAR(5) NOT NULL DEFAULT '18:00',
    email_bill_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS reminder_time_1 VARCHAR(5) NOT NULL DEFAULT '09:00';
ALTER TABLE users ADD COLUMN IF NOT EXISTS reminder_time_2 VARCHAR(5) NOT NULL DEFAULT '18:00';
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_bill_notifications BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE users
    ALTER COLUMN monthly_income TYPE NUMERIC(14, 2) USING ROUND(monthly_income::numeric, 2),
    ALTER COLUMN savings_goal_percent TYPE NUMERIC(5, 2) USING ROUND(savings_goal_percent::numeric, 2);

-- 2. Tabela transactions com client_uuid, credit_card_uuid, deleted_at e NUMERIC(14, 2)
CREATE TABLE IF NOT EXISTS transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    local_id BIGINT,
    description VARCHAR(255) NOT NULL,
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    tx_date TIMESTAMPTZ NOT NULL,
    tx_type VARCHAR(20) NOT NULL CHECK (tx_type IN ('income', 'expense')),
    category VARCHAR(100) NOT NULL,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'PIX',
    credit_card_uuid UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE (user_id, client_uuid),
    UNIQUE (user_id, local_id)
);

ALTER TABLE transactions ADD COLUMN IF NOT EXISTS client_uuid UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS credit_card_uuid UUID;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE transactions ALTER COLUMN amount TYPE NUMERIC(14, 2) USING ROUND(amount::numeric, 2);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'transactions_user_id_client_uuid_key'
    ) THEN
        ALTER TABLE transactions ADD CONSTRAINT transactions_user_id_client_uuid_key UNIQUE (user_id, client_uuid);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions(user_id, tx_date DESC) WHERE deleted_at IS NULL;

-- 3. Tabela budgets com NUMERIC(14, 2)
CREATE TABLE IF NOT EXISTS budgets (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL,
    limit_amount NUMERIC(14, 2) NOT NULL CHECK (limit_amount >= 0),
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INT NOT NULL CHECK (year >= 2020),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, category, month, year)
);

ALTER TABLE budgets ALTER COLUMN limit_amount TYPE NUMERIC(14, 2) USING ROUND(limit_amount::numeric, 2);

CREATE INDEX IF NOT EXISTS idx_budgets_user_period ON budgets(user_id, year, month);

-- 4. Tabelas de OTP (password_reset_tokens e email_verification_tokens)
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    email VARCHAR(255) PRIMARY KEY,
    code_hash VARCHAR(128) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE password_reset_tokens DROP CONSTRAINT IF EXISTS password_reset_tokens_email_fkey;

CREATE TABLE IF NOT EXISTS email_verification_tokens (
    email VARCHAR(255) PRIMARY KEY,
    code_hash VARCHAR(128) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Tabela bills (Boletos e Contas a Pagar com recorrência e vínculo de cartão)
CREATE TABLE IF NOT EXISTS bills (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    local_id BIGINT,
    description VARCHAR(255) NOT NULL,
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    due_date DATE NOT NULL,
    category VARCHAR(100) NOT NULL,
    barcode VARCHAR(255) NOT NULL DEFAULT '',
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    is_credit_card_charge BOOLEAN NOT NULL DEFAULT FALSE,
    credit_card_uuid UUID,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue')),
    paid_at TIMESTAMPTZ,
    linked_tx_uuid UUID,
    last_notified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE (user_id, client_uuid)
);

ALTER TABLE bills ADD COLUMN IF NOT EXISTS is_credit_card_charge BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS credit_card_uuid UUID;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS linked_tx_uuid UUID;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS last_notified_at TIMESTAMPTZ;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_bills_user_due ON bills(user_id, status, due_date ASC) WHERE deleted_at IS NULL;

-- 6. Tabela credit_cards (Gestão de Limite e Teto Saudável de Relacionamento Bancário)
CREATE TABLE IF NOT EXISTS credit_cards (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_uuid UUID NOT NULL DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    limit_amount NUMERIC(14, 2) NOT NULL CHECK (limit_amount > 0),
    target_min_percent NUMERIC(5, 2) NOT NULL DEFAULT 50.00,
    target_max_percent NUMERIC(5, 2) NOT NULL DEFAULT 80.00,
    due_day INT NOT NULL DEFAULT 10 CHECK (due_day BETWEEN 1 AND 31),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE (user_id, client_uuid)
);

CREATE INDEX IF NOT EXISTS idx_credit_cards_user ON credit_cards(user_id, is_primary DESC) WHERE deleted_at IS NULL;
`
	migCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	if _, err := pool.Exec(migCtx, schemaDDL); err != nil {
		return fmt.Errorf("failed to execute database schema migrations: %w", err)
	}

	return nil
}
