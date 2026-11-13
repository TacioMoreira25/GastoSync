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

func TestIsValidReminderTime(t *testing.T) {
	validTimes := []string{"00:00", "09:00", "18:00", "23:59", " 08:30 "}
	for _, ts := range validTimes {
		if !isValidReminderTime(ts) {
			t.Errorf("expected %q to be valid reminder time", ts)
		}
	}

	invalidTimes := []string{"", "9:00", "24:00", "18:60", "abc", "12-30"}
	for _, ts := range invalidTimes {
		if isValidReminderTime(ts) {
			t.Errorf("expected %q to be invalid reminder time", ts)
		}
	}
}

func TestUpdateProfileValidationErrors(t *testing.T) {
	app := fiber.New()
	handler := NewAuthHandler(nil, &config.Config{
		AppEnv:             "test",
		JWTSecret:          "test-jwt-secret-key-2026",
		JWTExpirationHours: 24,
	})

	app.Put("/api/v1/auth/profile-unauth", handler.UpdateProfile)
	app.Put("/api/v1/auth/profile", func(c *fiber.Ctx) error {
		c.Locals(middleware.UserIDKey, "00000000-0000-0000-0000-000000000001")
		return c.Next()
	}, handler.UpdateProfile)

	unauthReq := httptest.NewRequest(http.MethodPut, "/api/v1/auth/profile-unauth", strings.NewReader(`{}`))
	unauthReq.Header.Set("Content-Type", "application/json")
	unauthResp, err := app.Test(unauthReq)
	if err != nil {
		t.Fatalf("unexpected error testing unauthorized UpdateProfile: %v", err)
	}
	defer unauthResp.Body.Close()
	if unauthResp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected status 401 when userID missing, got %d", unauthResp.StatusCode)
	}

	tests := []struct {
		name     string
		body     string
		wantCode string
	}{
		{
			name:     "invalid JSON payload",
			body:     `{invalid-json`,
			wantCode: "INVALID_PAYLOAD",
		},
		{
			name:     "empty name",
			body:     `{"name":"   "}`,
			wantCode: "INVALID_NAME",
		},
		{
			name:     "negative monthly income",
			body:     `{"monthly_income":-10}`,
			wantCode: "INVALID_MONTHLY_INCOME",
		},
		{
			name:     "savings goal out of bounds",
			body:     `{"savings_goal_percent":120}`,
			wantCode: "INVALID_SAVINGS_GOAL",
		},
		{
			name:     "invalid reminder_time_1",
			body:     `{"reminder_time_1":"25:00"}`,
			wantCode: "INVALID_REMINDER_TIME_1",
		},
		{
			name:     "invalid reminder_time_2",
			body:     `{"reminder_time_2":"18:60"}`,
			wantCode: "INVALID_REMINDER_TIME_2",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPut, "/api/v1/auth/profile", strings.NewReader(tc.body))
			req.Header.Set("Content-Type", "application/json")
			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("unexpected error testing UpdateProfile (%s): %v", tc.name, err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusBadRequest {
				t.Fatalf("expected status 400 for %s, got %d", tc.name, resp.StatusCode)
			}
			var payload struct {
				Code string `json:"code"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
				t.Fatalf("failed to decode error payload for %s: %v", tc.name, err)
			}
			if payload.Code != tc.wantCode {
				t.Errorf("expected error code %q, got %q", tc.wantCode, payload.Code)
			}
		})
	}
}
