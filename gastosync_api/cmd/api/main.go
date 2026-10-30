// Package main provides the entrypoint for the GastoSync Go backend API service.
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/config"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/database"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/handlers"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/middleware"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/models"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Fatal: failed to load application configuration: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	log.Printf("[GastoSync API] Initializing PostgreSQL connection pool...")
	dbPool, err := database.ConnectPool(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Fatal: database connection failed: %v", err)
	}
	defer dbPool.Close()

	log.Printf("[GastoSync API] Running database schema migrations...")
	if err := database.RunMigrations(ctx, dbPool); err != nil {
		log.Fatalf("Fatal: database schema migration failed: %v", err)
	}
	log.Printf("[GastoSync API] Database migrations applied successfully.")

	app := fiber.New(fiber.Config{
		AppName:      "GastoSync Cloud API v1.0",
		ServerHeader: "GastoSync",
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			var e *fiber.Error
			if errorsAs(err, &e) {
				code = e.Code
			}
			return c.Status(code).JSON(models.ErrorResponse{
				Error:   err.Error(),
				Details: "Unhandled HTTP server error",
			})
		},
	})

	app.Use(recover.New())
	app.Use(logger.New(logger.Config{
		Format: "[${time}] ${status} - ${latency} ${method} ${path}\n",
	}))
	app.Use(cors.New(cors.Config{
		AllowOrigins: cfg.CORSAllowedOrigins,
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
	}))

	authHandler := handlers.NewAuthHandler(dbPool, cfg)
	syncHandler := handlers.NewSyncHandler(dbPool)

	// Liveness and health probe route
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"status":    "healthy",
			"service":   "gastosync_api",
			"database":  "connected",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	})

	api := app.Group("/api/v1")

	// Public Auth endpoints
	auth := api.Group("/auth")
	auth.Post("/register", authHandler.Register)
	auth.Post("/login", authHandler.Login)
	auth.Get("/me", middleware.Protected(cfg), authHandler.Me)

	// Protected Sync endpoints
	sync := api.Group("/sync", middleware.Protected(cfg))
	sync.Post("/push", syncHandler.Push)
	sync.Get("/pull", syncHandler.Pull)

	// Graceful shutdown channel
	shutdownChan := make(chan os.Signal, 1)
	signal.Notify(shutdownChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		addr := fmt.Sprintf(":%s", cfg.Port)
		log.Printf("[GastoSync API] Server listening on %s (Env: %s)", addr, cfg.AppEnv)
		if err := app.Listen(addr); err != nil {
			log.Printf("[GastoSync API] Server terminated: %v", err)
		}
	}()

	<-shutdownChan
	log.Printf("[GastoSync API] Initiating graceful shutdown...")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := app.ShutdownWithContext(shutdownCtx); err != nil {
		log.Printf("[GastoSync API] Error during server shutdown: %v", err)
	}
	log.Printf("[GastoSync API] Server stopped successfully.")
}

func errorsAs(err error, target **fiber.Error) bool {
	if fe, ok := err.(*fiber.Error); ok {
		*target = fe
		return true
	}
	return false
}
