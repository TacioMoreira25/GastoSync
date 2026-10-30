// Package models defines domain entities, HTTP payload transfer objects,
// and database serialization structures for the GastoSync API service.
package models

import (
	"time"
)

// User represents a registered user account in the PostgreSQL database.
type User struct {
	ID                 string    `json:"id"`
	Name               string    `json:"name"`
	Email              string    `json:"email"`
	PasswordHash       string    `json:"-"`
	MonthlyIncome      float64   `json:"monthly_income"`
	SavingsGoalPercent float64   `json:"savings_goal_percent"`
	CreatedAt          time.Time `json:"created_at"`
	UpdatedAt          time.Time `json:"updated_at"`
}

// UserResponse represents safe public user data returned by API endpoints.
type UserResponse struct {
	ID                 string  `json:"id"`
	Name               string  `json:"name"`
	Email              string  `json:"email"`
	MonthlyIncome      float64 `json:"monthly_income"`
	SavingsGoalPercent float64 `json:"savings_goal_percent"`
}

// ToResponse maps a User entity to a sanitized UserResponse DTO.
func (u *User) ToResponse() UserResponse {
	return UserResponse{
		ID:                 u.ID,
		Name:               u.Name,
		Email:              u.Email,
		MonthlyIncome:      u.MonthlyIncome,
		SavingsGoalPercent: u.SavingsGoalPercent,
	}
}

// RegisterRequest holds user registration parameters.
type RegisterRequest struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginRequest holds credentials for user authentication.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// AuthResponse returns an issued JWT and authenticated user metadata.
type AuthResponse struct {
	Token string       `json:"token"`
	User  UserResponse `json:"user"`
}

// ErrorResponse represents standard structured API error responses.
type ErrorResponse struct {
	Error   string `json:"error"`
	Details string `json:"details,omitempty"`
}

// Transaction represents a financial income or expense record in PostgreSQL.
type Transaction struct {
	ID            int64     `json:"id"`
	UserID        string    `json:"user_id"`
	LocalID       *int64    `json:"local_id,omitempty"`
	Description   string    `json:"description"`
	Amount        float64   `json:"amount"`
	TxDate        time.Time `json:"tx_date"`
	TxType        string    `json:"tx_type"`
	Category      string    `json:"category"`
	PaymentMethod string    `json:"payment_method"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// Budget represents a monthly category spending threshold in PostgreSQL.
type Budget struct {
	ID          int64     `json:"id"`
	UserID      string    `json:"user_id"`
	Category    string    `json:"category"`
	LimitAmount float64   `json:"limit_amount"`
	Month       int       `json:"month"`
	Year        int       `json:"year"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// SyncTransactionItem represents a local transaction sent from mobile/web during sync push.
type SyncTransactionItem struct {
	LocalID       int64     `json:"local_id"`
	Description   string    `json:"description"`
	Amount        float64   `json:"amount"`
	TxDate        time.Time `json:"tx_date"`
	TxType        string    `json:"tx_type"`
	Category      string    `json:"category"`
	PaymentMethod string    `json:"payment_method"`
}

// SyncBudgetItem represents a local budget category sent during sync push.
type SyncBudgetItem struct {
	Category    string  `json:"category"`
	LimitAmount float64 `json:"limit_amount"`
	Month       int     `json:"month"`
	Year        int     `json:"year"`
}

// SyncPushRequest represents the payload sent by clients to upload pending offline changes.
type SyncPushRequest struct {
	Transactions []SyncTransactionItem `json:"transactions"`
	Budgets      []SyncBudgetItem      `json:"budgets"`
}

// SyncedTransactionMapping maps the local SQLite ID to the authoritative PostgreSQL ID.
type SyncedTransactionMapping struct {
	LocalID  int64 `json:"local_id"`
	ServerID int64 `json:"server_id"`
}

// SyncPushResponse confirms successfully persisted entities.
type SyncPushResponse struct {
	SyncedTransactions []SyncedTransactionMapping `json:"synced_transactions"`
	SyncedBudgetsCount int                        `json:"synced_budgets_count"`
	SyncedAt           time.Time                  `json:"synced_at"`
}

// SyncPullResponse delivers cloud transactions and budgets down to the client.
type SyncPullResponse struct {
	Transactions []Transaction `json:"transactions"`
	Budgets      []Budget      `json:"budgets"`
	PulledAt     time.Time     `json:"pulled_at"`
}
