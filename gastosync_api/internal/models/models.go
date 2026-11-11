// Package models defines the domain entities and data transfer objects (DTOs)
// used across authentication and synchronization endpoints.
package models

import "time"

// User represents a registered account in the system.
type User struct {
	ID                     string     `json:"id"`
	Name                   string     `json:"name"`
	Email                  string     `json:"email"`
	EmailVerified          bool       `json:"email_verified"`
	EmailVerifiedAt        *time.Time `json:"email_verified_at,omitempty"`
	MonthlyIncome          float64    `json:"monthly_income"`
	SavingsGoalPercent     float64    `json:"savings_goal_percent"`
	ReminderTime1          string     `json:"reminder_time_1"`
	ReminderTime2          string     `json:"reminder_time_2"`
	EmailBillNotifications bool       `json:"email_bill_notifications"`
	CreatedAt              time.Time  `json:"created_at"`
}

// RegisterRequest defines the payload required to create a new user account.
type RegisterRequest struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

// RegisterResponse is returned upon account creation when email OTP verification is initiated.
type RegisterResponse struct {
	RequiresVerification bool   `json:"requires_verification"`
	Message              string `json:"message"`
	ExpiresInSeconds     int    `json:"expires_in_seconds"`
	DeliveryMode         string `json:"delivery_mode"`
	DevPreviewCode       string `json:"dev_preview_code,omitempty"`
	Token                string `json:"token,omitempty"`
	User                 User   `json:"user"`
}

// LoginRequest defines the credentials required to authenticate an existing user.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// AuthResponse is returned upon successful login or verification.
type AuthResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

// ForgotPasswordRequest defines the payload to request a 6-digit password reset code via email.
type ForgotPasswordRequest struct {
	Email string `json:"email"`
}

// VerifyResetCodeRequest defines the payload to validate a 6-digit password reset code.
type VerifyResetCodeRequest struct {
	Email string `json:"email"`
	Code  string `json:"code"`
}

// ResetPasswordRequest defines the payload to complete a password reset with a verified 6-digit code.
type ResetPasswordRequest struct {
	Email       string `json:"email"`
	Code        string `json:"code"`
	NewPassword string `json:"new_password"`
}

// SendVerificationRequest defines the payload to send a 6-digit account verification code via email.
type SendVerificationRequest struct {
	Email string `json:"email"`
	Name  string `json:"name,omitempty"`
}

// ResendVerificationRequest defines the payload to resend a 6-digit account verification code.
type ResendVerificationRequest struct {
	Email string `json:"email"`
	Name  string `json:"name,omitempty"`
}

// VerifyEmailRequest defines the payload to verify a user's email address with a 6-digit code.
type VerifyEmailRequest struct {
	Email string `json:"email"`
	Code  string `json:"code"`
}

// UpdateProfileRequest defines the payload to update user financial settings and bill reminder preferences.
type UpdateProfileRequest struct {
	Name                   *string  `json:"name,omitempty"`
	MonthlyIncome          *float64 `json:"monthly_income,omitempty"`
	SavingsGoalPercent     *float64 `json:"savings_goal_percent,omitempty"`
	ReminderTime1          *string  `json:"reminder_time_1,omitempty"`
	ReminderTime2          *string  `json:"reminder_time_2,omitempty"`
	EmailBillNotifications *bool    `json:"email_bill_notifications,omitempty"`
}

// TransactionDTO represents a financial transaction exchanged during synchronization.
// Supports both canonical (`date`, `type`) and legacy/alias (`tx_date`, `tx_type`) JSON keys.
type TransactionDTO struct {
	ID             int64      `json:"id,omitempty"`
	ClientUUID     string     `json:"client_uuid,omitempty"`
	LocalID        *int64     `json:"local_id,omitempty"`
	Description    string     `json:"description"`
	Amount         float64    `json:"amount"`
	Date           time.Time  `json:"date"`
	TxDateAlias    time.Time  `json:"tx_date,omitempty"`
	Type           string     `json:"type"`
	TxTypeAlias    string     `json:"tx_type,omitempty"`
	Category       string     `json:"category"`
	PaymentMethod  string     `json:"payment_method"`
	CreditCardUUID *string    `json:"credit_card_uuid,omitempty"`
	UpdatedAt      time.Time  `json:"updated_at,omitempty"`
	DeletedAt      *time.Time `json:"deleted_at,omitempty"`
}

// BillDTO represents a payable bill or recurring obligation exchanged during synchronization.
type BillDTO struct {
	ID                 int64      `json:"id,omitempty"`
	ClientUUID         string     `json:"client_uuid"`
	LocalID            *int64     `json:"local_id,omitempty"`
	Description        string     `json:"description"`
	Amount             float64    `json:"amount"`
	DueDate            time.Time  `json:"due_date"`
	Category           string     `json:"category"`
	Barcode            string     `json:"barcode"`
	IsRecurring        bool       `json:"is_recurring"`
	IsCreditCardCharge bool       `json:"is_credit_card_charge"`
	CreditCardUUID     *string    `json:"credit_card_uuid,omitempty"`
	Status             string     `json:"status"`
	PaidAt             *time.Time `json:"paid_at,omitempty"`
	LinkedTxUUID       *string    `json:"linked_tx_uuid,omitempty"`
	UpdatedAt          time.Time  `json:"updated_at,omitempty"`
	DeletedAt          *time.Time `json:"deleted_at,omitempty"`
}

// CreditCardDTO represents a credit card and its healthy utilization limits exchanged during synchronization.
type CreditCardDTO struct {
	ID               int64      `json:"id,omitempty"`
	ClientUUID       string     `json:"client_uuid"`
	Name             string     `json:"name"`
	LimitAmount      float64    `json:"limit_amount"`
	TargetMinPercent float64    `json:"target_min_percent"`
	TargetMaxPercent float64    `json:"target_max_percent"`
	DueDay           int        `json:"due_day"`
	IsPrimary        bool       `json:"is_primary"`
	UpdatedAt        time.Time  `json:"updated_at,omitempty"`
	DeletedAt        *time.Time `json:"deleted_at,omitempty"`
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
	Bills        []BillDTO        `json:"bills"`
	CreditCards  []CreditCardDTO  `json:"credit_cards"`
	Budgets      []BudgetDTO      `json:"budgets"`
}

// SyncPushResponse summarizes the records processed during a push operation.
type SyncPushResponse struct {
	SyncedTransactions int       `json:"synced_transactions"`
	SyncedBills        int       `json:"synced_bills"`
	SyncedCreditCards  int       `json:"synced_credit_cards"`
	SyncedBudgets      int       `json:"synced_budgets"`
	SyncedAt           time.Time `json:"synced_at"`
}

// SyncPullResponse contains all cloud records belonging to the authenticated user.
type SyncPullResponse struct {
	Transactions []TransactionDTO `json:"transactions"`
	Bills        []BillDTO        `json:"bills"`
	CreditCards  []CreditCardDTO  `json:"credit_cards"`
	Budgets      []BudgetDTO      `json:"budgets"`
	SyncedAt     time.Time        `json:"synced_at"`
}
