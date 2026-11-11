// Package handlers implements the HTTP route controllers for authentication,
// account email verification, password recovery via email OTP, and cloud data synchronization.
package handlers

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"net/smtp"
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

var (
	emailPattern       = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)
	uppercasePattern   = regexp.MustCompile(`[A-ZÁÀÂÃÉÊÍÓÔÕÚÇ]`)
	lowercasePattern   = regexp.MustCompile(`[a-záàâãéêíóôõúç]`)
	digitPattern       = regexp.MustCompile(`[0-9]`)
	specialCharPattern = regexp.MustCompile(`[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];~` + "`" + `]`)
)

// validateStrongPassword enforces OWASP ASVS password complexity rules:
// minimum 8 characters, maximum 128 characters, at least 1 uppercase letter,
// 1 lowercase letter, 1 digit, and 1 special character.
func validateStrongPassword(password string) error {
	trimmed := strings.TrimSpace(password)
	if len(trimmed) < 8 {
		return errors.New("A senha deve conter no mínimo 8 caracteres.")
	}
	if len(trimmed) > 128 {
		return errors.New("A senha deve conter no máximo 128 caracteres.")
	}
	if !uppercasePattern.MatchString(trimmed) {
		return errors.New("A senha deve incluir pelo menos 1 letra maiúscula (A-Z).")
	}
	if !lowercasePattern.MatchString(trimmed) {
		return errors.New("A senha deve incluir pelo menos 1 letra minúscula (a-z).")
	}
	if !digitPattern.MatchString(trimmed) {
		return errors.New("A senha deve incluir pelo menos 1 número (0-9).")
	}
	if !specialCharPattern.MatchString(trimmed) {
		return errors.New("A senha deve incluir pelo menos 1 caractere especial (ex: !@#$%&*).")
	}
	return nil
}

// AuthHandler manages user registration, login, email verification, password reset, and profile management.
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

// Register creates a new user account with OWASP strong password validation, sets email_verified = false,
// and dispatches a 6-digit OTP verification code via email_verification_tokens.
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

	if err := validateStrongPassword(req.Password); err != nil {
		return response.BadRequest(
			c,
			"WEAK_PASSWORD",
			err.Error(),
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
		INSERT INTO users (name, email, password_hash, email_verified)
		VALUES ($1, $2, $3, FALSE)
		RETURNING id, name, email, email_verified, email_verified_at, monthly_income, savings_goal_percent, reminder_time_1, reminder_time_2, email_bill_notifications, created_at
	`
	err = h.pool.QueryRow(ctx, insertQuery, req.Name, req.Email, string(hashedBytes)).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.EmailVerified,
		&user.EmailVerifiedAt,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.ReminderTime1,
		&user.ReminderTime2,
		&user.EmailBillNotifications,
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

	otpCode, deliveryMode, devPreviewCode, _ := h.issueAndDispatchVerificationOTP(ctx, user.Email, user.Name)

	_ = otpCode
	return c.Status(fiber.StatusCreated).JSON(models.RegisterResponse{
		RequiresVerification: true,
		Message:              "Conta criada! Enviamos um código de verificação de 6 dígitos para o seu e-mail.",
		ExpiresInSeconds:     600,
		DeliveryMode:         deliveryMode,
		DevPreviewCode:       devPreviewCode,
		User:                 user,
	})
}

// Login verifies user credentials against the stored Bcrypt hash.
// If the account's email is not verified yet, it automatically dispatches a new 6-digit OTP
// and returns HTTP 403 Forbidden (EMAIL_NOT_VERIFIED).
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
		SELECT id, name, email, email_verified, email_verified_at, password_hash, monthly_income, savings_goal_percent, reminder_time_1, reminder_time_2, email_bill_notifications, created_at
		FROM users
		WHERE email = $1
	`
	err := h.pool.QueryRow(ctx, selectQuery, email).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.EmailVerified,
		&user.EmailVerifiedAt,
		&passwordHash,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.ReminderTime1,
		&user.ReminderTime2,
		&user.EmailBillNotifications,
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

	if !user.EmailVerified {
		_, deliveryMode, devPreviewCode, _ := h.issueAndDispatchVerificationOTP(ctx, user.Email, user.Name)
		resp := fiber.Map{
			"code":                  "EMAIL_NOT_VERIFIED",
			"error":                 "Seu e-mail ainda não foi verificado. Enviamos um novo código de 6 dígitos para concluir a ativação.",
			"message":               "Seu e-mail ainda não foi verificado. Enviamos um novo código de 6 dígitos para concluir a ativação.",
			"requires_verification": true,
			"delivery_mode":         deliveryMode,
		}
		if devPreviewCode != "" {
			resp["dev_preview_code"] = devPreviewCode
		}
		return c.Status(fiber.StatusForbidden).JSON(resp)
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

func (h *AuthHandler) issueAndDispatchVerificationOTP(ctx context.Context, email, userName string) (string, string, string, error) {
	if strings.TrimSpace(userName) == "" {
		userName = strings.Split(email, "@")[0]
	}

	otpCode, err := generateNumericOTP(6)
	if err != nil {
		return "", "dev_inbox_preview", "", err
	}

	codeHash := hashVerificationCode(email, otpCode)
	expiresAt := time.Now().UTC().Add(10 * time.Minute)

	const upsertVerificationQuery = `
		INSERT INTO email_verification_tokens (email, code_hash, expires_at, attempts, created_at)
		VALUES ($1, $2, $3, 0, NOW())
		ON CONFLICT (email) DO UPDATE
		SET code_hash = EXCLUDED.code_hash,
		    expires_at = EXCLUDED.expires_at,
		    attempts = 0,
		    created_at = NOW()
	`
	if _, err := h.pool.Exec(ctx, upsertVerificationQuery, email, codeHash, expiresAt); err != nil {
		return "", "dev_inbox_preview", "", err
	}

	subject := "GastoSync - Confirme seu E-mail"
	htmlBody := buildVerificationEmailHTML(userName, otpCode)
	emailDelivered, providerUsed := h.dispatchTransactionalEmail(email, userName, subject, htmlBody)

	deliveryMode := providerUsed
	if !emailDelivered {
		deliveryMode = "dev_inbox_preview"
	}

	devPreviewCode := ""
	if h.cfg.AppEnv != "production" && (!emailDelivered || h.cfg.SMTPHost == "mailpit") {
		devPreviewCode = otpCode
	}

	return otpCode, deliveryMode, devPreviewCode, nil
}

// ResendVerification generates a new 6-digit CSPRNG OTP valid for 10 minutes and sends an account
// verification email via Brevo/Resend/SMTP.
func (h *AuthHandler) ResendVerification(c *fiber.Ctx) error {
	var req models.ResendVerificationRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Payload inválido.",
		})
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" || !emailPattern.MatchString(email) {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Informe um endereço de e-mail válido.",
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	userName := strings.TrimSpace(req.Name)
	if userName == "" {
		_ = h.pool.QueryRow(ctx, `SELECT name FROM users WHERE email = $1`, email).Scan(&userName)
	}

	_, deliveryMode, devPreviewCode, err := h.issueAndDispatchVerificationOTP(ctx, email, userName)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao registrar token de verificação de e-mail.",
		})
	}

	resp := fiber.Map{
		"message":            "Um novo código de verificação de 6 dígitos foi enviado para o seu e-mail.",
		"expires_in_seconds": 600,
		"delivery_mode":      deliveryMode,
	}
	if devPreviewCode != "" {
		resp["dev_preview_code"] = devPreviewCode
	}

	return c.Status(fiber.StatusOK).JSON(resp)
}

// SendVerification is an alias for ResendVerification to maintain compatibility with /send-verification.
func (h *AuthHandler) SendVerification(c *fiber.Ctx) error {
	return h.ResendVerification(c)
}

// VerifyEmail validates the 6-digit verification OTP code, marks the user's email as verified,
// and returns a signed JWT and User profile.
func (h *AuthHandler) VerifyEmail(c *fiber.Ctx) error {
	var req models.VerifyEmailRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Payload inválido.",
		})
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	code := strings.TrimSpace(req.Code)
	if email == "" || len(code) != 6 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Informe o e-mail e o código de 6 dígitos.",
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	var storedHash string
	var expiresAt time.Time
	var attempts int

	err := h.pool.QueryRow(
		ctx,
		`SELECT code_hash, expires_at, attempts FROM email_verification_tokens WHERE email = $1`,
		email,
	).Scan(&storedHash, &expiresAt, &attempts)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Nenhum código de verificação ativo para este e-mail. Solicite um novo código.",
			})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao validar código de verificação.",
		})
	}

	if attempts >= 5 {
		_, _ = h.pool.Exec(ctx, `DELETE FROM email_verification_tokens WHERE email = $1`, email)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Código bloqueado por excesso de tentativas incorretas. Solicite um novo código.",
		})
	}

	if time.Now().UTC().After(expiresAt) {
		_, _ = h.pool.Exec(ctx, `DELETE FROM email_verification_tokens WHERE email = $1`, email)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "O código de verificação expirou (validade de 10 minutos). Solicite um novo código.",
		})
	}

	candidateVerifyHash := hashVerificationCode(email, code)
	candidateResetHash := hashResetCode(email, code)
	matchesVerify := subtle.ConstantTimeCompare([]byte(storedHash), []byte(candidateVerifyHash)) == 1
	matchesReset := subtle.ConstantTimeCompare([]byte(storedHash), []byte(candidateResetHash)) == 1

	if !matchesVerify && !matchesReset {
		_, _ = h.pool.Exec(ctx, `UPDATE email_verification_tokens SET attempts = attempts + 1 WHERE email = $1`, email)
		remaining := 5 - (attempts + 1)
		if remaining <= 0 {
			_, _ = h.pool.Exec(ctx, `DELETE FROM email_verification_tokens WHERE email = $1`, email)
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Código bloqueado após 5 tentativas incorretas. Solicite um novo código.",
			})
		}
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": fmt.Sprintf("Código de verificação incorreto (%d tentativa(s) restante(s)).", remaining),
		})
	}

	_, _ = h.pool.Exec(ctx, `DELETE FROM email_verification_tokens WHERE email = $1`, email)

	var user models.User
	const updateVerifyQuery = `
		UPDATE users
		SET email_verified = TRUE,
		    email_verified_at = NOW(),
		    updated_at = NOW()
		WHERE email = $1
		RETURNING id, name, email, email_verified, email_verified_at, monthly_income, savings_goal_percent, reminder_time_1, reminder_time_2, email_bill_notifications, created_at
	`
	err = h.pool.QueryRow(ctx, updateVerifyQuery, email).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.EmailVerified,
		&user.EmailVerifiedAt,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.ReminderTime1,
		&user.ReminderTime2,
		&user.EmailBillNotifications,
		&user.CreatedAt,
	)

	resp := fiber.Map{
		"verified": true,
		"message":  "E-mail verificado com sucesso!",
	}
	if err == nil && user.ID != "" {
		if token, jwtErr := h.generateJWT(user.ID, user.Email); jwtErr == nil {
			resp["token"] = token
		}
		resp["user"] = user
	}

	return c.Status(fiber.StatusOK).JSON(resp)
}

// ForgotPassword generates a 6-digit CSPRNG OTP valid for 10 minutes, hashes it with SHA-256,
// persists it in PostgreSQL, and sends the verification email via SMTP/Brevo.
func (h *AuthHandler) ForgotPassword(c *fiber.Ctx) error {
	var req models.ForgotPasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Payload inválido.",
		})
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" || !strings.Contains(email, "@") {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Informe um endereço de e-mail válido.",
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	var userName string
	err := h.pool.QueryRow(ctx, `SELECT name FROM users WHERE email = $1`, email).Scan(&userName)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			parts := strings.Split(email, "@")
			userName = parts[0]
		} else {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Falha ao consultar conta de usuário.",
			})
		}
	}

	otpCode, err := generateNumericOTP(6)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao gerar código criptográfico de segurança.",
		})
	}

	codeHash := hashResetCode(email, otpCode)
	expiresAt := time.Now().UTC().Add(10 * time.Minute)

	const upsertTokenQuery = `
		INSERT INTO password_reset_tokens (email, code_hash, expires_at, attempts, created_at)
		VALUES ($1, $2, $3, 0, NOW())
		ON CONFLICT (email) DO UPDATE
		SET code_hash = EXCLUDED.code_hash,
		    expires_at = EXCLUDED.expires_at,
		    attempts = 0,
		    created_at = NOW()
	`
	if _, err := h.pool.Exec(ctx, upsertTokenQuery, email, codeHash, expiresAt); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao registrar token de recuperação.",
		})
	}

	emailDelivered, providerUsed := h.dispatchResetEmail(email, userName, otpCode)

	resp := fiber.Map{
		"message":            "Enviamos um código de segurança de 6 dígitos para o seu e-mail.",
		"expires_in_seconds": 600,
		"delivery_mode":      providerUsed,
	}
	if !emailDelivered {
		resp["delivery_mode"] = "dev_inbox_preview"
	}
	if h.cfg.AppEnv != "production" && (!emailDelivered || h.cfg.SMTPHost == "mailpit") {
		resp["dev_preview_code"] = otpCode
	}

	return c.Status(fiber.StatusOK).JSON(resp)
}

// VerifyResetCode checks whether the 6-digit OTP code is valid and not expired without consuming it yet.
func (h *AuthHandler) VerifyResetCode(c *fiber.Ctx) error {
	var req models.VerifyResetCodeRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Payload inválido.",
		})
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	code := strings.TrimSpace(req.Code)
	if email == "" || len(code) != 6 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Informe o e-mail e o código de 6 dígitos.",
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	if err := h.validateStoredOTP(ctx, email, code); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"verified": true,
		"message":  "Código verificado com sucesso.",
	})
}

// ResetPassword validates the 6-digit OTP code, updates the user's Bcrypt password hash, and invalidates the token.
func (h *AuthHandler) ResetPassword(c *fiber.Ctx) error {
	var req models.ResetPasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Payload inválido.",
		})
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	code := strings.TrimSpace(req.Code)
	newPassword := strings.TrimSpace(req.NewPassword)

	if email == "" || len(code) != 6 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "E-mail e código de 6 dígitos são obrigatórios.",
		})
	}

	if err := validateStrongPassword(newPassword); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	if err := h.validateStoredOTP(ctx, email, code); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	var currentHash string
	err := h.pool.QueryRow(ctx, `SELECT password_hash FROM users WHERE email = $1`, email).Scan(&currentHash)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao consultar conta de usuário.",
		})
	}

	if currentHash != "" && bcrypt.CompareHashAndPassword([]byte(currentHash), []byte(newPassword)) == nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "A nova senha deve ser diferente da sua senha atual.",
		})
	}

	newHashedBytes, err := bcrypt.GenerateFromPassword([]byte(newPassword), 12)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao criptografar nova senha.",
		})
	}

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao iniciar transação de segurança.",
		})
	}
	defer func() { _ = tx.Rollback(ctx) }()

	defaultName := strings.Split(email, "@")[0]
	const upsertUserPasswordQuery = `
		INSERT INTO users (name, email, password_hash, email_verified, email_verified_at, updated_at)
		VALUES ($1, $2, $3, TRUE, NOW(), NOW())
		ON CONFLICT (email) DO UPDATE
		SET password_hash = EXCLUDED.password_hash,
		    email_verified = TRUE,
		    email_verified_at = COALESCE(users.email_verified_at, NOW()),
		    updated_at = NOW()
	`
	if _, err := tx.Exec(ctx, upsertUserPasswordQuery, defaultName, email, string(newHashedBytes)); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao atualizar senha.",
		})
	}

	if _, err := tx.Exec(ctx, `DELETE FROM password_reset_tokens WHERE email = $1`, email); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao invalidar token de uso único.",
		})
	}

	if err := tx.Commit(ctx); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao confirmar redefinição de senha.",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Senha redefinida com sucesso! Você já pode entrar com a nova senha.",
	})
}

func (h *AuthHandler) validateStoredOTP(ctx context.Context, email, code string) error {
	var storedHash string
	var expiresAt time.Time
	var attempts int

	err := h.pool.QueryRow(
		ctx,
		`SELECT code_hash, expires_at, attempts FROM password_reset_tokens WHERE email = $1`,
		email,
	).Scan(&storedHash, &expiresAt, &attempts)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("Nenhum código de recuperação ativo para este e-mail. Solicite um novo código.")
		}
		return errors.New("Falha ao validar código de recuperação.")
	}

	if attempts >= 5 {
		_, _ = h.pool.Exec(ctx, `DELETE FROM password_reset_tokens WHERE email = $1`, email)
		return errors.New("Código bloqueado por excesso de tentativas incorretas. Solicite um novo código.")
	}

	if time.Now().UTC().After(expiresAt) {
		_, _ = h.pool.Exec(ctx, `DELETE FROM password_reset_tokens WHERE email = $1`, email)
		return errors.New("O código de verificação expirou (validade de 10 minutos). Solicite um novo código.")
	}

	candidateHash := hashResetCode(email, code)
	if subtle.ConstantTimeCompare([]byte(storedHash), []byte(candidateHash)) != 1 {
		_, _ = h.pool.Exec(ctx, `UPDATE password_reset_tokens SET attempts = attempts + 1 WHERE email = $1`, email)
		remaining := 5 - (attempts + 1)
		if remaining <= 0 {
			_, _ = h.pool.Exec(ctx, `DELETE FROM password_reset_tokens WHERE email = $1`, email)
			return errors.New("Código bloqueado após 5 tentativas incorretas. Solicite um novo código.")
		}
		return fmt.Errorf("Código de verificação incorreto (%d tentativa(s) restante(s)).", remaining)
	}

	return nil
}

func generateNumericOTP(length int) (string, error) {
	digits := make([]byte, length)
	for i := 0; i < length; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}
		digits[i] = byte('0' + n.Int64())
	}
	return string(digits), nil
}

func hashResetCode(email, code string) string {
	sum := sha256.Sum256([]byte("GastoSync::OTP::" + email + "::" + code))
	return hex.EncodeToString(sum[:])
}

func hashVerificationCode(email, code string) string {
	sum := sha256.Sum256([]byte("GastoSync::VerifyEmail::" + email + "::" + code))
	return hex.EncodeToString(sum[:])
}

func buildResetEmailHTML(userName, otpCode string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f8fafc; padding: 24px;">
  <div style="max-width: 480px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px; border: 1px solid #e2e8f0;">
    <h2 style="color: #0f172a; margin-top: 0;">Recuperação de Senha — GastoSync</h2>
    <p style="color: #475569; font-size: 14px;">Olá, <strong>%s</strong>.</p>
    <p style="color: #475569; font-size: 14px;">Recebemos uma solicitação para redefinir a senha da sua conta GastoSync. Utilize o código de verificação de 6 dígitos abaixo:</p>
    <div style="background: #ecfdf5; border: 1px solid #10b981; border-radius: 12px; padding: 16px; text-align: center; margin: 24px 0;">
      <span style="font-size: 28px; font-weight: 800; letter-spacing: 6px; color: #047857;">%s</span>
    </div>
    <p style="color: #64748b; font-size: 12px;">Este código é de uso único e expira em <strong>10 minutos</strong>. Se você não solicitou esta alteração, ignore este e-mail com segurança.</p>
  </div>
</body>
</html>`, userName, otpCode)
}

func buildVerificationEmailHTML(userName, otpCode string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f8fafc; padding: 24px;">
  <div style="max-width: 480px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px; border: 1px solid #e2e8f0;">
    <h2 style="color: #0f172a; margin-top: 0;">Confirme seu E-mail — GastoSync</h2>
    <p style="color: #475569; font-size: 14px;">Olá, <strong>%s</strong>! Bem-vindo(a) ao GastoSync.</p>
    <p style="color: #475569; font-size: 14px;">Para ativar o selo de conta verificada e sincronizar seus dados financeiros com segurança na nuvem, digite o código de 6 dígitos abaixo no aplicativo:</p>
    <div style="background: #ecfdf5; border: 1px solid #10b981; border-radius: 12px; padding: 16px; text-align: center; margin: 24px 0;">
      <span style="font-size: 28px; font-weight: 800; letter-spacing: 6px; color: #047857;">%s</span>
    </div>
    <p style="color: #64748b; font-size: 12px;">Este código é válido por <strong>10 minutos</strong>.</p>
  </div>
</body>
</html>`, userName, otpCode)
}

func (h *AuthHandler) dispatchResetEmail(toEmail, userName, otpCode string) (bool, string) {
	subject := "GastoSync - Código de Recuperação de Senha"
	htmlBody := buildResetEmailHTML(userName, otpCode)
	return h.dispatchTransactionalEmail(toEmail, userName, subject, htmlBody)
}

func (h *AuthHandler) dispatchTransactionalEmail(toEmail, userName, subject, htmlBody string) (bool, string) {
	// 1. Produção Cloud (Render/Vercel/Railway): Brevo HTTP API (porta 443 HTTPS)
	if h.cfg.BrevoAPIKey != "" {
		if err := h.sendTransactionalEmailBrevo(toEmail, userName, subject, htmlBody); err != nil {
			log.Printf("[BREVO ERROR] Falha ao enviar e-mail para %s: %v", toEmail, err)
		} else {
			log.Printf("[BREVO OK] E-mail (%s) enviado por HTTPS para %s", subject, toEmail)
			return true, "smtp"
		}
	}

	// 2. Produção Cloud: Resend HTTP API (porta 443 HTTPS)
	if h.cfg.ResendAPIKey != "" {
		if err := h.sendTransactionalEmailResend(toEmail, subject, htmlBody); err != nil {
			log.Printf("[RESEND ERROR] Falha ao enviar e-mail para %s: %v", toEmail, err)
		} else {
			log.Printf("[RESEND OK] E-mail (%s) enviado por HTTPS para %s", subject, toEmail)
			return true, "smtp"
		}
	}

	// 3. SMTP tradicional (Mailpit local / Gmail / VPS)
	if h.cfg.SMTPHost != "" {
		if err := h.sendTransactionalEmailSMTP(toEmail, subject, htmlBody); err != nil {
			log.Printf("[SMTP ERROR] Falha ao enviar e-mail para %s via %s:%s: %v", toEmail, h.cfg.SMTPHost, h.cfg.SMTPPort, err)
		} else {
			log.Printf("[SMTP OK] E-mail (%s) enviado para %s via %s:%s", subject, toEmail, h.cfg.SMTPHost, h.cfg.SMTPPort)
			return true, "smtp"
		}
	}

	return false, "dev_inbox_preview"
}

func (h *AuthHandler) sendTransactionalEmailBrevo(toEmail, userName, subject, htmlBody string) error {
	payload := map[string]interface{}{
		"sender": map[string]string{
			"name":  h.cfg.SenderName,
			"email": h.cfg.SenderEmail,
		},
		"to": []map[string]string{
			{
				"email": toEmail,
				"name":  userName,
			},
		},
		"subject":     subject,
		"htmlContent": htmlBody,
	}
	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", "https://api.brevo.com/v3/smtp/email", bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	req.Header.Set("accept", "application/json")
	req.Header.Set("content-type", "application/json")
	req.Header.Set("api-key", h.cfg.BrevoAPIKey)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return fmt.Errorf("Brevo API returned status %d", resp.StatusCode)
	}
	return nil
}

func (h *AuthHandler) sendTransactionalEmailResend(toEmail, subject, htmlBody string) error {
	fromField := fmt.Sprintf("%s <%s>", h.cfg.SenderName, h.cfg.SenderEmail)
	if h.cfg.SenderEmail == "no-reply@gastosync.com" {
		fromField = "GastoSync Seguranca <onboarding@resend.dev>"
	}

	payload := map[string]interface{}{
		"from":    fromField,
		"to":      []string{toEmail},
		"subject": subject,
		"html":    htmlBody,
	}
	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", "https://api.resend.com/emails", bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+h.cfg.ResendAPIKey)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return fmt.Errorf("Resend API returned status %d", resp.StatusCode)
	}
	return nil
}

func (h *AuthHandler) sendTransactionalEmailSMTP(toEmail, subject, htmlBody string) error {
	addr := fmt.Sprintf("%s:%s", h.cfg.SMTPHost, h.cfg.SMTPPort)
	var auth smtp.Auth
	if h.cfg.SMTPUser != "" && h.cfg.SMTPPass != "" {
		auth = smtp.PlainAuth("", h.cfg.SMTPUser, h.cfg.SMTPPass, h.cfg.SMTPHost)
	}

	envelopeFrom := h.cfg.SMTPUser
	if envelopeFrom == "" {
		envelopeFrom = "no-reply@gastosync.com"
	}

	displayFrom := h.cfg.SMTPFrom
	if h.cfg.SMTPUser != "" && strings.Contains(h.cfg.SMTPHost, "gmail") {
		displayFrom = fmt.Sprintf("GastoSync Seguranca <%s>", h.cfg.SMTPUser)
	}

	subjectHeader := fmt.Sprintf("Subject: %s\r\n", subject)
	headers := "MIME-Version: 1.0\r\nContent-Type: text/html; charset=\"UTF-8\"\r\n"
	fromHeader := fmt.Sprintf("From: %s\r\nTo: %s\r\n", displayFrom, toEmail)

	msg := []byte(fromHeader + subjectHeader + headers + "\r\n" + htmlBody)
	return smtp.SendMail(addr, auth, envelopeFrom, []string{toEmail}, msg)
}

// Me returns the profile of the currently authenticated user.
func (h *AuthHandler) Me(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	var user models.User
	const query = `
		SELECT id, name, email, email_verified, email_verified_at, monthly_income, savings_goal_percent, reminder_time_1, reminder_time_2, email_bill_notifications, created_at
		FROM users
		WHERE id = $1
	`
	err := h.pool.QueryRow(ctx, query, userID).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.EmailVerified,
		&user.EmailVerifiedAt,
		&user.MonthlyIncome,
		&user.SavingsGoalPercent,
		&user.ReminderTime1,
		&user.ReminderTime2,
		&user.EmailBillNotifications,
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
