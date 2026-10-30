// Package middleware provides HTTP middlewares for authentication, security,
// and request context extraction.
package middleware

import (
	"errors"
	"fmt"
	"strings"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/config"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/models"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

const (
	// ContextKeyUserID is the fiber context key where the authenticated user UUID is saved.
	ContextKeyUserID = "user_id"
	// ContextKeyUserEmail is the fiber context key where the authenticated user email is saved.
	ContextKeyUserEmail = "user_email"
)

// AuthClaims represents custom JWT claims containing authenticated user identifiers.
type AuthClaims struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	jwt.RegisteredClaims
}

// Protected returns a Fiber middleware handler that enforces valid JWT Bearer authentication.
func Protected(cfg *config.Config) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
				Error: "Missing Authorization header",
			})
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
				Error: "Invalid Authorization header format. Expected 'Bearer <token>'",
			})
		}

		tokenString := strings.TrimSpace(parts[1])
		if tokenString == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
				Error: "Bearer token cannot be empty",
			})
		}

		claims := &AuthClaims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(cfg.JWTSecret), nil
		})

		if err != nil || !token.Valid || claims.UserID == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
				Error:   "Invalid or expired authorization token",
				Details: "Please log in again to acquire a fresh token",
			})
		}

		c.Locals(ContextKeyUserID, claims.UserID)
		c.Locals(ContextKeyUserEmail, claims.Email)

		return c.Next()
	}
}

// GetUserID extracts the authenticated user's UUID from the Fiber request context.
func GetUserID(c *fiber.Ctx) (string, error) {
	val := c.Locals(ContextKeyUserID)
	if val == nil {
		return "", errors.New("unauthenticated request: user_id missing from context")
	}

	userID, ok := val.(string)
	if !ok || userID == "" {
		return "", errors.New("invalid user_id in request context")
	}

	return userID, nil
}

// GetUserEmail extracts the authenticated user's email from the Fiber request context.
func GetUserEmail(c *fiber.Ctx) (string, error) {
	val := c.Locals(ContextKeyUserEmail)
	if val == nil {
		return "", errors.New("unauthenticated request: user_email missing from context")
	}

	email, ok := val.(string)
	if !ok || email == "" {
		return "", errors.New("invalid user_email in request context")
	}

	return email, nil
}
