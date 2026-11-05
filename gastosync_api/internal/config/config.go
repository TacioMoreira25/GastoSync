// Package config provides application configuration management loaded from
// environment variables with validation for required security parameters.
package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

// Config holds the runtime configuration parameters for the HTTP server,
// database connection pool, JWT authentication layer, and SMTP email dispatch.
type Config struct {
	Port               string
	AppEnv             string
	DatabaseURL        string
	JWTSecret          string
	JWTExpirationHours int
	CORSAllowedOrigins string
	SMTPHost           string
	SMTPPort           string
	SMTPUser           string
	SMTPPass           string
	SMTPFrom           string
	ResendAPIKey       string
	BrevoAPIKey        string
	SenderEmail        string
	SenderName         string
}

// Load reads configuration values from the process environment, optionally
// loading a local .env file when present, and validates required fields.
func Load() (*Config, error) {
	_ = godotenv.Load()

	port := getEnv("PORT", "8080")
	appEnv := getEnv("APP_ENV", "development")
	dbURL := os.Getenv("DATABASE_URL")
	jwtSecret := os.Getenv("JWT_SECRET")
	corsOrigins := getEnv("CORS_ALLOWED_ORIGINS", "*")
	smtpHost := getEnv("SMTP_HOST", "")
	smtpPort := getEnv("SMTP_PORT", "587")
	smtpUser := getEnv("SMTP_USER", "")
	smtpPass := getEnv("SMTP_PASS", "")
	smtpFrom := getEnv("SMTP_FROM", "GastoSync Seguranca <no-reply@gastosync.com>")
	resendAPIKey := getEnv("RESEND_API_KEY", "")
	brevoAPIKey := getEnv("BREVO_API_KEY", "")
	senderEmail := getEnv("SENDER_EMAIL", smtpUser)
	if senderEmail == "" {
		senderEmail = "no-reply@gastosync.com"
	}
	senderName := getEnv("SENDER_NAME", "GastoSync Segurança")

	expHoursStr := getEnv("JWT_EXPIRATION_HOURS", "168")
	expHours, err := strconv.Atoi(expHoursStr)
	if err != nil || expHours <= 0 {
		expHours = 168
	}

	if dbURL == "" {
		return nil, fmt.Errorf("missing required environment variable: DATABASE_URL")
	}

	if len(jwtSecret) < 16 {
		return nil, fmt.Errorf("invalid JWT_SECRET: must be at least 16 characters long")
	}

	return &Config{
		Port:               port,
		AppEnv:             appEnv,
		DatabaseURL:        dbURL,
		JWTSecret:          jwtSecret,
		JWTExpirationHours: expHours,
		CORSAllowedOrigins: corsOrigins,
		SMTPHost:           smtpHost,
		SMTPPort:           smtpPort,
		SMTPUser:           smtpUser,
		SMTPPass:           smtpPass,
		SMTPFrom:           smtpFrom,
		ResendAPIKey:       resendAPIKey,
		BrevoAPIKey:        brevoAPIKey,
		SenderEmail:        senderEmail,
		SenderName:         senderName,
	}, nil
}

// getEnv retrieves the value of the environment variable named by the key,
// returning the provided fallback if the variable is unset or empty.
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists && value != "" {
		return value
	}
	return fallback
}
