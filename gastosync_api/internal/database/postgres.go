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

// RunMigrations applies the core relational schema (users, transactions, and
// budgets) idempotently, ensuring all tables and indexes exist before serving traffic.
func RunMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	const schemaDDL = `
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    monthly_income DOUBLE PRECISION NOT NULL DEFAULT 0,
    savings_goal_percent DOUBLE PRECISION NOT NULL DEFAULT 20,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    local_id BIGINT,
    description VARCHAR(255) NOT NULL,
    amount DOUBLE PRECISION NOT NULL CHECK (amount > 0),
    tx_date TIMESTAMPTZ NOT NULL,
    tx_type VARCHAR(20) NOT NULL CHECK (tx_type IN ('income', 'expense')),
    category VARCHAR(100) NOT NULL,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'PIX',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, local_id)
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions(user_id, tx_date DESC);

CREATE TABLE IF NOT EXISTS budgets (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL,
    limit_amount DOUBLE PRECISION NOT NULL CHECK (limit_amount >= 0),
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INT NOT NULL CHECK (year >= 2020),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, category, month, year)
);

CREATE INDEX IF NOT EXISTS idx_budgets_user_period ON budgets(user_id, year, month);
`
	migCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	if _, err := pool.Exec(migCtx, schemaDDL); err != nil {
		return fmt.Errorf("failed to execute database schema migrations: %w", err)
	}

	return nil
}
