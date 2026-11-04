// Package middleware provides HTTP request interceptors for JWT authentication,
// security headers, rate limiting, and centralized error handling.
package middleware

import (
	"errors"
	"sync"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/response"
	"github.com/gofiber/fiber/v2"
)

// ErrorHandler intercepts all unhandled Fiber and application errors, ensuring
// responses are always returned as structured JSON in Portuguese (pt-BR).
func ErrorHandler(c *fiber.Ctx, err error) error {
	code := fiber.StatusInternalServerError
	errCode := "INTERNAL_SERVER_ERROR"
	msg := "Ocorreu um erro interno no servidor. Tente novamente em instantes."

	var fiberErr *fiber.Error
	if errors.As(err, &fiberErr) {
		code = fiberErr.Code
		switch code {
		case fiber.StatusBadRequest:
			errCode = "BAD_REQUEST"
			msg = "Os dados enviados na requisição são inválidos."
		case fiber.StatusUnauthorized:
			errCode = "UNAUTHORIZED"
			msg = "Sua sessão expirou ou não está autenticada. Faça login novamente."
		case fiber.StatusForbidden:
			errCode = "FORBIDDEN"
			msg = "Você não tem permissão para realizar esta operação."
		case fiber.StatusNotFound:
			errCode = "NOT_FOUND"
			msg = "O recurso ou endpoint solicitado não foi encontrado."
		case fiber.StatusMethodNotAllowed:
			errCode = "METHOD_NOT_ALLOWED"
			msg = "Método HTTP não permitido para esta rota."
		case fiber.StatusRequestEntityTooLarge:
			errCode = "PAYLOAD_TOO_LARGE"
			msg = "O volume de dados enviado excede o limite permitido pelo servidor."
		case fiber.StatusTooManyRequests:
			errCode = "RATE_LIMIT_EXCEEDED"
			msg = "Muitas requisições em pouco tempo. Aguarde alguns segundos e tente novamente."
		}
	}

	return response.Error(c, code, errCode, msg)
}

// NotFoundHandler returns a structured 404 JSON response for unknown routes.
func NotFoundHandler(c *fiber.Ctx) error {
	return response.NotFound(
		c,
		"ROUTE_NOT_FOUND",
		"Endpoint não encontrado na API do GastoSync. Verifique a URL informada.",
	)
}

// SecurityHeaders injects OWASP recommended HTTP response headers.
func SecurityHeaders() fiber.Handler {
	return func(c *fiber.Ctx) error {
		c.Set("X-Content-Type-Options", "nosniff")
		c.Set("X-Frame-Options", "DENY")
		c.Set("X-XSS-Protection", "1; mode=block")
		c.Set("Referrer-Policy", "no-referrer")
		return c.Next()
	}
}

type ipRateWindow struct {
	count     int
	expiresAt time.Time
}

// AuthRateLimiter protects login and registration endpoints against brute-force
// attacks using a thread-safe sliding window per client IP.
func AuthRateLimiter() fiber.Handler {
	var (
		mu      sync.Mutex
		clients = make(map[string]*ipRateWindow)
	)
	const maxRequests = 20
	const windowDuration = 1 * time.Minute

	return func(c *fiber.Ctx) error {
		ip := c.IP()
		now := time.Now()

		mu.Lock()
		entry, exists := clients[ip]
		if !exists || now.After(entry.expiresAt) {
			clients[ip] = &ipRateWindow{
				count:     1,
				expiresAt: now.Add(windowDuration),
			}
			mu.Unlock()
			return c.Next()
		}

		entry.count++
		if entry.count > maxRequests {
			mu.Unlock()
			return response.Error(
				c,
				fiber.StatusTooManyRequests,
				"AUTH_RATE_LIMIT",
				"Muitas tentativas de acesso seguidas. Aguarde 1 minuto antes de tentar novamente.",
			)
		}
		mu.Unlock()
		return c.Next()
	}
}
