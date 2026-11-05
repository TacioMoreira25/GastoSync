// Package response provides standardized JSON response helpers and error
// formatting in Portuguese (pt-BR) for all GastoSync Core API endpoints.
package response

import "github.com/gofiber/fiber/v2"

// ErrorPayload represents the canonical error envelope returned by the API.
type ErrorPayload struct {
	Error      string `json:"error"`
	Message    string `json:"message"`
	Code       string `json:"code"`
	StatusCode int    `json:"status_code"`
}

// Error writes a standardized JSON error response with a user-friendly pt-BR message.
func Error(c *fiber.Ctx, status int, code, message string) error {
	return c.Status(status).JSON(ErrorPayload{
		Error:      message,
		Message:    message,
		Code:       code,
		StatusCode: status,
	})
}

// BadRequest writes a 400 Bad Request JSON error response.
func BadRequest(c *fiber.Ctx, code, message string) error {
	return Error(c, fiber.StatusBadRequest, code, message)
}

// Unauthorized writes a 401 Unauthorized JSON error response.
func Unauthorized(c *fiber.Ctx, code, message string) error {
	return Error(c, fiber.StatusUnauthorized, code, message)
}

// NotFound writes a 404 Not Found JSON error response.
func NotFound(c *fiber.Ctx, code, message string) error {
	return Error(c, fiber.StatusNotFound, code, message)
}

// Conflict writes a 409 Conflict JSON error response.
func Conflict(c *fiber.Ctx, code, message string) error {
	return Error(c, fiber.StatusConflict, code, message)
}

// InternalError writes a 500 Internal Server Error JSON error response.
func InternalError(c *fiber.Ctx, code, message string) error {
	return Error(c, fiber.StatusInternalServerError, code, message)
}
