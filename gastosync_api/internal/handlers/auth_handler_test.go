package handlers

import (
	"testing"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/config"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/models"
)

func TestHashPasswordAndCheck(t *testing.T) {
	password := "SenhaForte123!"

	hash, err := HashPassword(password)
	if err != nil {
		t.Fatalf("unexpected error hashing password: %v", err)
	}

	if hash == "" || hash == password {
		t.Fatalf("expected valid bcrypt hash, got %s", hash)
	}

	if !CheckPassword(hash, password) {
		t.Fatalf("expected password verification to succeed")
	}

	if CheckPassword(hash, "WrongPassword") {
		t.Fatalf("expected password verification to fail for wrong password")
	}
}

func TestGenerateToken(t *testing.T) {
	cfg := &config.Config{
		JWTSecret:          "very-secure-secret-key-at-least-32-chars",
		JWTExpirationHours: 24,
	}

	handler := NewAuthHandler(nil, cfg)

	user := &models.User{
		ID:        "550e8400-e29b-41d4-a716-446655440000",
		Name:      "Test User",
		Email:     "test@gastosync.local",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	token, err := handler.GenerateToken(user)
	if err != nil {
		t.Fatalf("failed to generate JWT token: %v", err)
	}

	if token == "" {
		t.Fatalf("expected non-empty JWT token")
	}
}
