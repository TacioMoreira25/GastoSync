// Package middleware provides HTTP request interceptors for JWT authentication,
// security headers, rate limiting, and centralized error handling.
package middleware

import (
	"fmt"
	"strings"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/response"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

// UserIDKey is the context local key used to store the authenticated user's UUID.
const UserIDKey = "user_id"

// RequireAuth validates the Bearer JWT token from the Authorization header
// and injects the authenticated user_id into the Fiber request context.
func RequireAuth(jwtSecret string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := strings.TrimSpace(c.Get("Authorization"))
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			return response.Unauthorized(
				c,
				"MISSING_AUTH_TOKEN",
				"Token de autenticação ausente ou em formato inválido. Faça login novamente.",
			)
		}

		tokenStr := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
		if tokenStr == "" {
			return response.Unauthorized(
				c,
				"EMPTY_AUTH_TOKEN",
				"Token de autenticação vazio. Faça login para continuar.",
			)
		}

		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
			}
			return []byte(jwtSecret), nil
		})
		if err != nil || !token.Valid {
			return response.Unauthorized(
				c,
				"INVALID_OR_EXPIRED_TOKEN",
				"Sua sessão expirou ou o token é inválido. Por favor, faça login novamente.",
			)
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			return response.Unauthorized(
				c,
				"INVALID_TOKEN_CLAIMS",
				"Não foi possível validar as credenciais da sua sessão. Faça login novamente.",
			)
		}

		userID, ok := claims["sub"].(string)
		if !ok || strings.TrimSpace(userID) == "" {
			return response.Unauthorized(
				c,
				"MISSING_TOKEN_SUBJECT",
				"Identificador do usuário ausente no token de sessão. Faça login novamente.",
			)
		}

		c.Locals(UserIDKey, strings.TrimSpace(userID))
		return c.Next()
	}
}
