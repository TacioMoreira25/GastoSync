package handlers

import (
	"context"
	"strings"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/middleware"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/models"
	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SyncHandler manages bidirectional data synchronization between client devices and cloud storage.
type SyncHandler struct {
	db *pgxpool.Pool
}

// NewSyncHandler creates an initialized SyncHandler instance.
func NewSyncHandler(db *pgxpool.Pool) *SyncHandler {
	return &SyncHandler{db: db}
}

// Push receives pending offline transactions and budgets from clients (POST /api/v1/sync/push).
func (h *SyncHandler) Push(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
			Error: "Unauthorized sync request",
		})
	}

	var req models.SyncPushRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(models.ErrorResponse{
			Error:   "Invalid sync payload format",
			Details: err.Error(),
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 15*time.Second)
	defer cancel()

	tx, err := h.db.Begin(ctx)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error:   "Failed to initiate sync transaction",
			Details: err.Error(),
		})
	}
	defer func() { _ = tx.Rollback(ctx) }()

	const upsertTxSQL = `
		INSERT INTO transactions (
			user_id, local_id, description, amount, tx_date, tx_type, category, payment_method, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
		ON CONFLICT (user_id, local_id)
		DO UPDATE SET
			description = EXCLUDED.description,
			amount = EXCLUDED.amount,
			tx_date = EXCLUDED.tx_date,
			tx_type = EXCLUDED.tx_type,
			category = EXCLUDED.category,
			payment_method = EXCLUDED.payment_method,
			updated_at = NOW()
		RETURNING id, local_id;
	`

	syncedMappings := make([]models.SyncedTransactionMapping, 0, len(req.Transactions))

	for _, item := range req.Transactions {
		desc := strings.TrimSpace(item.Description)
		cat := strings.TrimSpace(item.Category)
		method := strings.TrimSpace(item.PaymentMethod)
		if method == "" {
			method = "PIX"
		}
		txType := strings.ToLower(strings.TrimSpace(item.TxType))
		if txType != "income" && txType != "expense" {
			txType = "expense"
		}
		if item.Amount <= 0 || desc == "" || cat == "" {
			continue // Skip invalid offline transactions
		}

		var serverID int64
		var returnedLocalID int64
		err := tx.QueryRow(
			ctx,
			upsertTxSQL,
			userID,
			item.LocalID,
			desc,
			item.Amount,
			item.TxDate,
			txType,
			cat,
			method,
		).Scan(&serverID, &returnedLocalID)

		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
				Error:   "Failed to synchronize transaction batch",
				Details: err.Error(),
			})
		}

		syncedMappings = append(syncedMappings, models.SyncedTransactionMapping{
			LocalID:  returnedLocalID,
			ServerID: serverID,
		})
	}

	const upsertBudgetSQL = `
		INSERT INTO budgets (
			user_id, category, limit_amount, month, year, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, NOW())
		ON CONFLICT (user_id, category, month, year)
		DO UPDATE SET
			limit_amount = EXCLUDED.limit_amount,
			updated_at = NOW();
	`

	syncedBudgetsCount := 0
	for _, item := range req.Budgets {
		cat := strings.TrimSpace(item.Category)
		if cat == "" || item.Month < 1 || item.Month > 12 || item.Year < 2020 {
			continue
		}

		_, err := tx.Exec(ctx, upsertBudgetSQL, userID, cat, item.LimitAmount, item.Month, item.Year)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
				Error:   "Failed to synchronize budget limits",
				Details: err.Error(),
			})
		}
		syncedBudgetsCount++
	}

	if err := tx.Commit(ctx); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error:   "Failed to commit synchronization transaction",
			Details: err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(models.SyncPushResponse{
		SyncedTransactions: syncedMappings,
		SyncedBudgetsCount: syncedBudgetsCount,
		SyncedAt:           time.Now().UTC(),
	})
}

// Pull retrieves all cloud transactions and budgets belonging to the authenticated user (GET /api/v1/sync/pull).
func (h *SyncHandler) Pull(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(models.ErrorResponse{
			Error: "Unauthorized sync request",
		})
	}

	ctx, cancel := context.WithTimeout(c.Context(), 10*time.Second)
	defer cancel()

	const selectTxSQL = `
		SELECT id, user_id, local_id, description, amount, tx_date, tx_type, category, payment_method, created_at, updated_at
		FROM transactions
		WHERE user_id = $1
		ORDER BY tx_date DESC;
	`

	rows, err := h.db.Query(ctx, selectTxSQL, userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error:   "Failed to query user transactions",
			Details: err.Error(),
		})
	}
	defer rows.Close()

	transactions := make([]models.Transaction, 0)
	for rows.Next() {
		var tx models.Transaction
		if err := rows.Scan(
			&tx.ID,
			&tx.UserID,
			&tx.LocalID,
			&tx.Description,
			&tx.Amount,
			&tx.TxDate,
			&tx.TxType,
			&tx.Category,
			&tx.PaymentMethod,
			&tx.CreatedAt,
			&tx.UpdatedAt,
		); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
				Error:   "Failed to read transaction rows",
				Details: err.Error(),
			})
		}
		transactions = append(transactions, tx)
	}

	const selectBudgetSQL = `
		SELECT id, user_id, category, limit_amount, month, year, updated_at
		FROM budgets
		WHERE user_id = $1
		ORDER BY year DESC, month DESC, category ASC;
	`

	budgetRows, err := h.db.Query(ctx, selectBudgetSQL, userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
			Error:   "Failed to query user budgets",
			Details: err.Error(),
		})
	}
	defer budgetRows.Close()

	budgets := make([]models.Budget, 0)
	for budgetRows.Next() {
		var b models.Budget
		if err := budgetRows.Scan(
			&b.ID,
			&b.UserID,
			&b.Category,
			&b.LimitAmount,
			&b.Month,
			&b.Year,
			&b.UpdatedAt,
		); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(models.ErrorResponse{
				Error:   "Failed to read budget rows",
				Details: err.Error(),
			})
		}
		budgets = append(budgets, b)
	}

	return c.Status(fiber.StatusOK).JSON(models.SyncPullResponse{
		Transactions: transactions,
		Budgets:      budgets,
		PulledAt:     time.Now().UTC(),
	})
}
