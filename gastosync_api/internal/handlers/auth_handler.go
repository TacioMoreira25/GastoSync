// Package handlers implements the HTTP route controllers for authentication
// and cloud data synchronization.
package handlers

import (
	"context"
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/config"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/middleware"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/models"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/response"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

var emailPattern = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

// AuthHandler manages user registration, login, and profile retrieval.
type AuthHandler struct {
	pool *pgxpool.Pool
	cfg  *config.Config
}

// NewAuthHandler constructs a new AuthHandler with database and configuration dependencies.
func NewAuthHandler(pool *pgxpool.Pool, cfg *config.Config) *AuthHandler {
	return &AuthHandler{
		pool: pool,
		cfg:  cfg,
	}
}

// Register creates a new user account with a Bcrypt password hash and returns a signed JWT.
func (h *AuthHandler) Register(c *fiber.Ctx) error {
	var req models.RegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(
			c,
			"INVALID_JSON_PAYLOAD",
			"Não foi possível ler os dados enviados. Verifique o preenchimento do formulário.",
		)
	}

	req.Name = strings.TrimSpace(req.Name)
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	if len(req.Name) < 3 {
		return response.BadRequest(
			c,
			"INVALID_NAME",
			"Informe seu nome completo (mínimo de 3 caracteres).",
		)
	}

	if req.Email == "" || !emailPattern.MatchString(req.Email) {
		return response.BadRequest(
			c,
			"INVALID_EMAIL",
			"Informe um endereço de e-mail válido.",
		)
	}

	if len(req.Password) < 6 {
		return response.BadRequest(
			c,
			"WEAK_PASSWORD",
			"A senha deve conter pelo menos 6 caracteres.",
		)
	}

	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return response.InternalError(
			c,
			"PASSWORD_HASH_ERROR",
			"Não foi possível processar sua senha com segurança. Tente novamente.",
		)
	}

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	var user models.User
	const insertQuery = `
		INSERT INTO users (name, email, password_hash)
		VALUES ($1, $2, $3)
		RETURNING id, name, email, monthly_income, savings_goal_percent, created_at
	`
	err = h.pool.QueryRow(ctx, insertQuery, req.Name, req.Email, string(hashedBytes)).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.CreatedAt,
	)
	if err != nil {
		if strings.Contains(err.Error(), "23505") || strings.Contains(strings.ToLower(err.Error()), "unique") {
			return response.Conflict(
				c,
				"EMAIL_ALREADY_EXISTS",
				"Este e-mail já está cadastrado. Acesse a aba Entrar para fazer login.",
			)
		}
		return response.InternalError(
			c,
			"USER_CREATION_FAILED",
			"Não foi possível concluir o cadastro no momento. Tente novamente em instantes.",
		)
	}

	token, err := h.generateJWT(user.ID, user.Email)
	if err != nil {
		return response.InternalError(
			c,
			"TOKEN_GENERATION_FAILED",
			"Sua conta foi criada, mas houve um erro ao iniciar a sessão. Faça login na aba Entrar.",
		)
	}

	return c.Status(fiber.StatusCreated).JSON(models.AuthResponse{
		Token: token,
		User:  user,
	})
}

// Login verifies user credentials against the stored Bcrypt hash and returns a signed JWT.
func (h *AuthHandler) Login(c *fiber.Ctx) error {
	var req models.LoginRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(
			c,
			"INVALID_JSON_PAYLOAD",
			"Não foi possível ler os dados de login enviados.",
		)
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" || req.Password == "" {
		return response.BadRequest(
			c,
			"MISSING_CREDENTIALS",
			"Por favor, informe seu e-mail e sua senha para entrar.",
		)
	}

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	var user models.User
	var passwordHash string
	const selectQuery = `
		SELECT id, name, email, password_hash, monthly_income, savings_goal_percent, created_at
		FROM users
		WHERE email = $1
	`
	err := h.pool.QueryRow(ctx, selectQuery, email).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&passwordHash,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return response.Unauthorized(
				c,
				"INVALID_CREDENTIALS",
				"E-mail ou senha incorretos. Verifique seus dados e tente novamente.",
			)
		}
		return response.InternalError(
			c,
			"AUTH_QUERY_FAILED",
			"Serviço de autenticação temporariamente indisponível. Tente novamente em instantes.",
		)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		return response.Unauthorized(
			c,
			"INVALID_CREDENTIALS",
			"E-mail ou senha incorretos. Verifique seus dados e tente novamente.",
		)
	}

	token, err := h.generateJWT(user.ID, user.Email)
	if err != nil {
		return response.InternalError(
			c,
			"TOKEN_GENERATION_FAILED",
			"Não foi possível gerar seu token de acesso. Tente novamente.",
		)
	}

	return c.Status(fiber.StatusOK).JSON(models.AuthResponse{
		Token: token,
		User:  user,
	})
}

// Me returns the profile of the currently authenticated user.
func (h *AuthHandler) Me(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	var user models.User
	const query = `
		SELECT id, name, email, monthly_income, savings_goal_percent, created_at
		FROM users
		WHERE id = $1
	`
	err := h.pool.QueryRow(ctx, query, userID).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return response.NotFound(
				c,
				"USER_NOT_FOUND",
				"Perfil de usuário não encontrado no servidor.",
			)
		}
		return response.InternalError(
			c,
			"PROFILE_FETCH_FAILED",
			"Não foi possível carregar os dados do seu perfil no momento.",
		)
	}

	return c.Status(fiber.StatusOK).JSON(user)
}

func (h *AuthHandler) generateJWT(userID, email string) (string, error) {
	now := time.Now().UTC()
	claims := jwt.MapClaims{
		"sub":   userID,
		"email": email,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Duration(h.cfg.JWTExpirationHours) * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(h.cfg.JWTSecret))
}
