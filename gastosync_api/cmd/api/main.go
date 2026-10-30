// Package main is the entrypoint for the GastoSync Core HTTP API server.
package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/config"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/database"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/handlers"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/middleware"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("configuration error: %v", err)
	}

	ctx := context.Background()
	pool, err := database.ConnectPool(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database connection error: %v", err)
	}
	defer pool.Close()

	if err := database.RunMigrations(ctx, pool); err != nil {
		log.Fatalf("database migration error: %v", err)
	}

	app := fiber.New(fiber.Config{
		AppName:      "GastoSync Core API",
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	})

	app.Use(recover.New())
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: cfg.CORSAllowedOrigins,
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
	}))

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"status":  "ok",
			"service": "gastosync_api",
			"env":     cfg.AppEnv,
		})
	})

	authHandler := handlers.NewAuthHandler(pool, cfg)
	syncHandler := handlers.NewSyncHandler(pool)

	apiV1 := app.Group("/api/v1")

	authGroup := apiV1.Group("/auth")
	authGroup.Post("/register", authHandler.Register)
	authGroup.Post("/login", authHandler.Login)
	authGroup.Get("/me", middleware.RequireAuth(cfg.JWTSecret), authHandler.Me)

	syncGroup := apiV1.Group("/sync", middleware.RequireAuth(cfg.JWTSecret))
	syncGroup.Post("/push", syncHandler.Push)
	syncGroup.Get("/pull", syncHandler.Pull)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("GastoSync Core API listening on port %s (%s)", cfg.Port, cfg.AppEnv)
		if err := app.Listen("0.0.0.0:" + cfg.Port); err != nil {
			log.Fatalf("server listen error: %v", err)
		}
	}()

	<-quit
	log.Println("shutting down GastoSync Core API gracefully...")
	_ = app.ShutdownWithTimeout(10 * time.Second)
}
