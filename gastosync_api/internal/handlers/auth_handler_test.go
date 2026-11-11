package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/config"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/middleware"
	"github.com/gofiber/fiber/v2"
)

func TestValidateStrongPassword(t *testing.T) {
	tests := []struct {
		name      string
		password  string
		wantError bool
	}{
		{
			name:      "too short (< 8 chars)",
			password:  "Ab1!xyz",
			wantError: true,
		},
		{
			name:      "too long (> 128 chars)",
			password:  "Ab1!" + strings.Repeat("a", 130),
			wantError: true,
		},
		{
			name:      "missing uppercase",
			password:  "gastosync2026!",
			wantError: true,
		},
		{
			name:      "missing lowercase",
			password:  "GASTOSYNC2026!",
			wantError: true,
		},
		{
			name:      "missing digit",
			password:  "GastoSyncStrong!",
			wantError: true,
		},
		{
			name:      "missing special character",
			password:  "GastoSync2026",
			wantError: true,
		},
		{
			name:      "compliant standard password",
			password:  "Gasto@2026!",
			wantError: false,
		},
		{
			name:      "compliant password with accented letters",
			password:  "Sénha#Forte9",
			wantError: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			err := validateStrongPassword(tc.password)
			if tc.wantError && err == nil {
				t.Errorf("expected error for password %q, got nil", tc.password)
			}
			if !tc.wantError && err != nil {
				t.Errorf("expected no error for password %q, got %v", tc.password, err)
			}
		})
	}
}

func TestGenerateNumericOTP(t *testing.T) {
	code, err := generateNumericOTP(6)
	if err != nil {
		t.Fatalf("unexpected error generating OTP: %v", err)
	}
	if len(code) != 6 {
		t.Fatalf("expected 6-digit OTP, got %q (len=%d)", code, len(code))
	}
	for _, ch := range code {
		if ch < '0' || ch > '9' {
			t.Errorf("expected numeric digit, got %q in %q", ch, code)
		}
	}
}

func TestHashVerificationAndResetCodeDomainSeparation(t *testing.T) {
	email := "maria@exemplo.com"
	code := "482910"

	verifyHash := hashVerificationCode(email, code)
	resetHash := hashResetCode(email, code)

	if len(verifyHash) != 64 {
		t.Errorf("expected 64-char SHA-256 hex digest, got len=%d", len(verifyHash))
	}
	if verifyHash == resetHash {
		t.Errorf("expected domain separation between verification hash and reset hash")
	}
	if hashVerificationCode(email, code) != verifyHash {
		t.Errorf("expected deterministic hashVerificationCode output")
	}
	if hashVerificationCode(email, "000000") == verifyHash {
		t.Errorf("expected different OTP codes to produce distinct hashes")
	}
}

func TestRegisterWeakPasswordAndRateLimiter(t *testing.T) {
	app := fiber.New()
	handler := NewAuthHandler(nil, &config.Config{
		AppEnv:             "test",
		JWTSecret:          "test-jwt-secret-key-2026",
		JWTExpirationHours: 24,
	})

	app.Post("/api/v1/auth/register", middleware.AuthRateLimiter(), handler.Register)

	payload, _ := json.Marshal(map[string]string{
		"name":     "Maria Oliveira",
		"email":    "maria@exemplo.com",
		"password": "weak",
	})

	// 1. Validate weak password rejection (400 WEAK_PASSWORD)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("unexpected error testing register endpoint: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected status 400 for weak password, got %d", resp.StatusCode)
	}

	// 2. Validate rate limiter blocks after 20 requests in the 1-minute window
	var lastStatus int
	for i := 0; i < 21; i++ {
		r := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(payload))
		r.Header.Set("Content-Type", "application/json")
		res, err := app.Test(r)
		if err != nil {
			t.Fatalf("unexpected error on request %d: %v", i, err)
		}
		lastStatus = res.StatusCode
	}
	if lastStatus != http.StatusTooManyRequests {
		t.Fatalf("expected status 429 after exceeding rate limit, got %d", lastStatus)
	}
}
