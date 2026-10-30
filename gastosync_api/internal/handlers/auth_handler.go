// Package handlers provides HTTP request controllers for authentication,
// synchronization, and health inspection endpoints.
package handlers

import (
	"context"
	"errors"
	"net/mail"
	"strings"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/config"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/middleware"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/models"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// AuthHandler coordinates authentication endpoints including registration, login, and profile lookup.
type AuthHandler struct {
	db  *pgxpool.Pool
	cfg *config.Config
}

// NewAuthHandler creates an initialized AuthHandler instance.
func NewAuthHandler(db *pgxpool.Pool, cfg *config.Config) *AuthHandler {
	return &AuthHandler{
		db:  db,
		cfg: cfg,
	}
}

// HashPassword derives a secure salted Bcrypt hash from a plaintext password.
func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

// CheckPassword verifies whether a plaintext candidate password matches an existing Bcrypt hash.
func CheckPassword(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}

// GenerateToken generates and signs a new JWT token containing user identity claims.
func (h *AuthHandler) GenerateToken(user *models.User) (string, error) {
	expTime := time.Now().Add(time.Duration(h.cfg.JWTExpirationHours) * time.Hour)
	claims := middleware.AuthClaims{
		UserID: user.ID,
		Email:  user.Email,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   user.ID,
			ExpiresAt: jwt.NewNumericDate(expTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(h.cfg.JWTSecret))
}

// Register handles user account creation (POST /api/v1/auth/register).
func (h *AuthHandler) Register(c *fiber.Ctx) error {
	var req models.RegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Error:   "Invalid JSON payload",
			Details: err.Error(),
		})
	}

	req.Name = strings.TrimSpace(req.Name)
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.Password = strings.TrimSpace(req.Password)

	if req.Name == "" || len(req.Name) > 120 {
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Error: "Name is required and cannot exceed 120 characters",
		})
	}

	if _, err := mail.ParseAddress(req.Email); err != nil || len(req.Email) > 255 {
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Error: "A valid email address is required",
		})
	}

	if len(req.Password) < 8 || len(req.Password) > 128 {
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Error: "Password must be between 8 and 128 characters long",
		})
	}

	hash, err := HashPassword(req.Password)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error: "Failed to securely hash password",
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 5*time.Second)
	defer cancel()

	const insertSQL = `
		INSERT INTO users (name, email, password_hash)
		VALUES ($1, $2, $3)
		RETURNING id, name, email, monthly_income, savings_goal_percent, created_at, updated_at;
	`

	var user models.User
	err = h.db.QueryRow(ctx, insertSQL, req.Name, req.Email, hash).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return c.Status(fiber.StatusConflict).JSON(models.ErrorResponse{
				Error: "An account with this email address already exists",
			})
		}

		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error:   "Database error during user registration",
			Details: err.Error(),
		})
	}

	token, err := h.GenerateToken(&user)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error: "Failed to generate authentication token",
		})
	}

	return c.Status(fiber.StatusCreated).JSON(models.AuthResponse{
		Token: token,
		User:  user.ToResponse(),
	})
}

// Login handles user authentication (POST /api/v1/auth/login).
func (h *AuthHandler) Login(c *fiber.Ctx) error {
	var req models.LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Error:   "Invalid JSON payload",
			Details: err.Error(),
		})
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.Password = strings.TrimSpace(req.Password)

	if req.Email == "" || req.Password == "" {
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Error: "Email and password are both required",
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 5*time.Second)
	defer cancel()

	const selectSQL = `
		SELECT id, name, email, password_hash, monthly_income, savings_goal_percent, created_at, updated_at
		FROM users
		WHERE email = $1;
	`

	var user models.User
	err := h.db.QueryRow(ctx, selectSQL, req.Email).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.PasswordHash,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
				Error: "Invalid email or password",
			})
		}

		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error:   "Database error during user lookup",
			Details: err.Error(),
		})
	}

	if !CheckPassword(user.PasswordHash, req.Password) {
		return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
			Error: "Invalid email or password",
		})
	}

	token, err := h.GenerateToken(&user)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error: "Failed to generate authentication token",
		})
	}

	return c.Status(fiber.StatusOK).JSON(models.AuthResponse{
		Token: token,
		User:  user.ToResponse(),
	})
}

// Me retrieves the authenticated user's profile metadata (GET /api/v1/auth/me).
func (h *AuthHandler) Me(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
			Error: "Unauthorized request",
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 5*time.Second)
	defer cancel()

	const selectSQL = `
		SELECT id, name, email, monthly_income, savings_goal_percent
		FROM users
		WHERE id = $1;
	`

	var user models.UserResponse
	err = h.db.QueryRow(ctx, selectSQL, userID).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return c.Status(fiber.StatusNotFound).JSON(models.ErrorResponse{
				Error: "User not found",
			})
		}

		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error:   "Database error retrieving profile",
			Details: err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(user)
}
