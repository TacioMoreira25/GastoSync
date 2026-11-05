// Package handlers implements the HTTP route controllers for authentication,
// password recovery via email OTP, and cloud data synchronization.
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

var emailPattern = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

// AuthHandler manages user registration, login, password reset, and profile retrieval.
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

// ForgotPassword generates a 6-digit CSPRNG OTP valid for 10 minutes, hashes it with SHA-256,
// persists it in PostgreSQL, and sends the verification email via SMTP (or returns a dev preview code).
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
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
				"error": "Nenhuma conta encontrada com este endereço de e-mail.",
			})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Falha ao consultar conta de usuário.",
		})
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

	if email == "" || len(code) != 6 || len(newPassword) < 8 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "E-mail, código de 6 dígitos e nova senha forte (mín. 8 caracteres) são obrigatórios.",
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
	if err := h.pool.QueryRow(ctx, `SELECT password_hash FROM users WHERE email = $1`, email).Scan(&currentHash); err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Conta não encontrada.",
		})
	}

	if bcrypt.CompareHashAndPassword([]byte(currentHash), []byte(newPassword)) == nil {
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

	if _, err := tx.Exec(ctx, `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE email = $2`, string(newHashedBytes), email); err != nil {
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

func (h *AuthHandler) dispatchResetEmail(toEmail, userName, otpCode string) (bool, string) {
	// 1. Produção Cloud (Render/Vercel/Railway): Brevo HTTP API (porta 443 HTTPS, não bloqueada por firewall)
	if h.cfg.BrevoAPIKey != "" {
		if err := h.sendResetEmailBrevo(toEmail, userName, otpCode); err != nil {
			log.Printf("[BREVO ERROR] Falha ao enviar e-mail para %s: %v", toEmail, err)
		} else {
			log.Printf("[BREVO OK] Código enviado por HTTPS para %s", toEmail)
			return true, "smtp"
		}
	}

	// 2. Produção Cloud: Resend HTTP API (porta 443 HTTPS)
	if h.cfg.ResendAPIKey != "" {
		if err := h.sendResetEmailResend(toEmail, userName, otpCode); err != nil {
			log.Printf("[RESEND ERROR] Falha ao enviar e-mail para %s: %v", toEmail, err)
		} else {
			log.Printf("[RESEND OK] Código enviado por HTTPS para %s", toEmail)
			return true, "smtp"
		}
	}

	// 3. SMTP tradicional (Mailpit local / Gmail / VPS)
	if h.cfg.SMTPHost != "" {
		if err := h.sendResetEmailSMTP(toEmail, userName, otpCode); err != nil {
			log.Printf("[SMTP ERROR] Falha ao enviar e-mail para %s via %s:%s: %v", toEmail, h.cfg.SMTPHost, h.cfg.SMTPPort, err)
		} else {
			log.Printf("[SMTP OK] Código enviado para %s via %s:%s", toEmail, h.cfg.SMTPHost, h.cfg.SMTPPort)
			return true, "smtp"
		}
	}

	return false, "dev_inbox_preview"
}

func (h *AuthHandler) sendResetEmailBrevo(toEmail, userName, otpCode string) error {
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
		"subject":     "GastoSync - Código de Recuperação de Senha",
		"htmlContent": buildResetEmailHTML(userName, otpCode),
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

func (h *AuthHandler) sendResetEmailResend(toEmail, userName, otpCode string) error {
	fromField := fmt.Sprintf("%s <%s>", h.cfg.SenderName, h.cfg.SenderEmail)
	if h.cfg.SenderEmail == "no-reply@gastosync.com" {
		fromField = "GastoSync Seguranca <onboarding@resend.dev>"
	}

	payload := map[string]interface{}{
		"from":    fromField,
		"to":      []string{toEmail},
		"subject": "GastoSync - Código de Recuperação de Senha",
		"html":    buildResetEmailHTML(userName, otpCode),
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

func (h *AuthHandler) sendResetEmailSMTP(toEmail, userName, otpCode string) error {
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

	subject := "Subject: =?UTF-8?B?R2FzdG9TeW5jIC0gQ8OzZGlnbyBkZSBSZWN1cGVyYcOnw6NvIGRlIFNlbmhh?=\r\n"
	headers := "MIME-Version: 1.0\r\nContent-Type: text/html; charset=\"UTF-8\"\r\n"
	fromHeader := fmt.Sprintf("From: %s\r\nTo: %s\r\n", displayFrom, toEmail)

	body := buildResetEmailHTML(userName, otpCode)

	msg := []byte(fromHeader + subject + headers + "\r\n" + body)
	return smtp.SendMail(addr, auth, envelopeFrom, []string{toEmail}, msg)
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
