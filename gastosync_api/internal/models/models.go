// Package models defines the domain entities and data transfer objects (DTOs)
// used across authentication and synchronization endpoints.
package models

import "time"

// User represents a registered account in the system.
type User struct {
	ID                 string    `json:"id"`
	Name               string    `json:"name"`
	Email              string    `json:"email"`
	MonthlyIncome      float64   `json:"monthly_income"`
	SavingsGoalPercent float64   `json:"savings_goal_percent"`
	CreatedAt          time.Time `json:"created_at"`
}

// RegisterRequest defines the payload required to create a new user account.
type RegisterRequest struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginRequest defines the credentials required to authenticate an existing user.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// AuthResponse is returned upon successful registration or login.
type AuthResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

// TransactionDTO represents a financial transaction exchanged during synchronization.
type TransactionDTO struct {
	ID            int64     `json:"id,omitempty"`
	LocalID       *int64    `json:"local_id,omitempty"`
	Description   string    `json:"description"`
	Amount        float64   `json:"amount"`
	Date          time.Time `json:"date"`
	Type          string    `json:"type"`
	Category      string    `json:"category"`
	PaymentMethod string    `json:"payment_method"`
	UpdatedAt     time.Time `json:"updated_at,omitempty"`
}

// BudgetDTO represents a monthly category spending limit exchanged during synchronization.
type BudgetDTO struct {
	ID          int64     `json:"id,omitempty"`
	Category    string    `json:"category"`
	LimitAmount float64   `json:"limit_amount"`
	Month       int       `json:"month"`
	Year        int       `json:"year"`
	UpdatedAt   time.Time `json:"updated_at,omitempty"`
}

// SyncPushRequest contains local records to be persisted in the cloud database.
type SyncPushRequest struct {
	Transactions []TransactionDTO `json:"transactions"`
	Budgets      []BudgetDTO      `json:"budgets"`
}

// SyncPushResponse summarizes the records processed during a push operation.
type SyncPushResponse struct {
	SyncedTransactions int       `json:"synced_transactions"`
	SyncedBudgets      int       `json:"synced_budgets"`
	SyncedAt           time.Time `json:"synced_at"`
}

// SyncPullResponse contains all cloud records belonging to the authenticated user.
type SyncPullResponse struct {
	Transactions []TransactionDTO `json:"transactions"`
	Budgets      []BudgetDTO      `json:"budgets"`
	SyncedAt     time.Time        `json:"synced_at"`
}
