// Package handlers implements the HTTP route controllers for authentication
// and cloud data synchronization.
package handlers

import (
	"context"
	"strings"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/middleware"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/models"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/response"
	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SyncHandler manages bidirectional synchronization of transactions and budgets
// scoped strictly to the authenticated user_id.
type SyncHandler struct {
	pool *pgxpool.Pool
}

// NewSyncHandler constructs a new SyncHandler with a PostgreSQL connection pool.
func NewSyncHandler(pool *pgxpool.Pool) *SyncHandler {
	return &SyncHandler{
		pool: pool,
	}
}

// Push receives local transactions and budgets from the client and upserts them
// into the PostgreSQL database within a transactional boundary.
func (h *SyncHandler) Push(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)

	var req models.SyncPushRequest
	if err := c.BodyParser(&req); err != nil {
		return response.BadRequest(
			c,
			"INVALID_SYNC_PAYLOAD",
			"Formato de dados de sincronização inválido.",
		)
	}

	ctx, cancel := context.WithTimeout(c.Context(), 15*time.Second)
	defer cancel()

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return response.InternalError(
			c,
			"DB_TRANSACTION_START_FAILED",
			"Não foi possível iniciar a sincronização com o banco na nuvem.",
		)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	syncedTxCount := 0
	for _, item := range req.Transactions {
		desc := strings.TrimSpace(item.Description)
		rawType := item.Type
		if strings.TrimSpace(rawType) == "" {
			rawType = item.TxTypeAlias
		}
		txType := strings.ToLower(strings.TrimSpace(rawType))
		category := strings.TrimSpace(item.Category)
		paymentMethod := strings.TrimSpace(item.PaymentMethod)
		if paymentMethod == "" {
			paymentMethod = "PIX"
		}

		if desc == "" || item.Amount <= 0 || (txType != "income" && txType != "expense") || category == "" {
			continue
		}

		txDate := item.Date
		if txDate.IsZero() && !item.TxDateAlias.IsZero() {
			txDate = item.TxDateAlias
		}
		if txDate.IsZero() {
			txDate = time.Now().UTC()
		}

		if item.LocalID != nil {
			const upsertTxWithLocalID = `
				INSERT INTO transactions (user_id, local_id, description, amount, tx_date, tx_type, category, payment_method, updated_at)
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
			`
			if _, err := tx.Exec(ctx, upsertTxWithLocalID, userID, *item.LocalID, desc, item.Amount, txDate, txType, category, paymentMethod); err != nil {
				return response.InternalError(
					c,
					"TX_UPSERT_FAILED",
					"Erro ao salvar uma de suas transações na nuvem. Nenhuma alteração foi perdida localmente.",
				)
			}
		} else {
			const insertTx = `
				INSERT INTO transactions (user_id, description, amount, tx_date, tx_type, category, payment_method, updated_at)
				VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
			`
			if _, err := tx.Exec(ctx, insertTx, userID, desc, item.Amount, txDate, txType, category, paymentMethod); err != nil {
				return response.InternalError(
					c,
					"TX_INSERT_FAILED",
					"Erro ao registrar transação na nuvem. Seus dados continuam salvos localmente.",
				)
			}
		}
		syncedTxCount++
	}

	syncedBudgetCount := 0
	for _, b := range req.Budgets {
		category := strings.TrimSpace(b.Category)
		if category == "" || b.LimitAmount < 0 || b.Month < 1 || b.Month > 12 || b.Year < 2020 {
			continue
		}

		const upsertBudget = `
			INSERT INTO budgets (user_id, category, limit_amount, month, year, updated_at)
			VALUES ($1, $2, $3, $4, $5, NOW())
			ON CONFLICT (user_id, category, month, year)
			DO UPDATE SET
				limit_amount = EXCLUDED.limit_amount,
				updated_at = NOW()
		`
		if _, err := tx.Exec(ctx, upsertBudget, userID, category, b.LimitAmount, b.Month, b.Year); err != nil {
			return response.InternalError(
				c,
				"BUDGET_UPSERT_FAILED",
				"Erro ao sincronizar suas metas de orçamento na nuvem.",
			)
		}
		syncedBudgetCount++
	}

	if err := tx.Commit(ctx); err != nil {
		return response.InternalError(
			c,
			"SYNC_COMMIT_FAILED",
			"Não foi possível finalizar a sincronização com o servidor. Tente novamente.",
		)
	}

	return c.Status(fiber.StatusOK).JSON(models.SyncPushResponse{
		SyncedTransactions: syncedTxCount,
		SyncedBudgets:      syncedBudgetCount,
		SyncedAt:           time.Now().UTC(),
	})
}

// Pull returns all transactions and budgets belonging to the authenticated user.
func (h *SyncHandler) Pull(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)

	ctx, cancel := context.WithTimeout(c.Context(), 15*time.Second)
	defer cancel()

	const txQuery = `
		SELECT id, local_id, description, amount, tx_date, tx_type, category, payment_method, updated_at
		FROM transactions
		WHERE user_id = $1
		ORDER BY tx_date DESC, id DESC
	`
	rows, err := h.pool.Query(ctx, txQuery, userID)
	if err != nil {
		return response.InternalError(
			c,
			"TX_PULL_QUERY_FAILED",
			"Não foi possível buscar suas transações na nuvem no momento.",
		)
	}
	defer rows.Close()

	transactions := make([]models.TransactionDTO, 0)
	for rows.Next() {
		var t models.TransactionDTO
		if err := rows.Scan(
			&t.ID,
			&t.LocalID,
			&t.Description,
			&t.Amount,
			&t.Date,
			&t.Type,
			&t.Category,
			&t.PaymentMethod,
			&t.UpdatedAt,
		); err != nil {
			return response.InternalError(
				c,
				"TX_SCAN_FAILED",
				"Erro ao processar o histórico de transações recebido da nuvem.",
			)
		}
		transactions = append(transactions, t)
	}

	const budgetQuery = `
		SELECT id, category, limit_amount, month, year, updated_at
		FROM budgets
		WHERE user_id = $1
		ORDER BY year DESC, month DESC, category ASC
	`
	budgetRows, err := h.pool.Query(ctx, budgetQuery, userID)
	if err != nil {
		return response.InternalError(
			c,
			"BUDGET_PULL_QUERY_FAILED",
			"Não foi possível buscar suas metas orçamentárias na nuvem no momento.",
		)
	}
	defer budgetRows.Close()

	budgets := make([]models.BudgetDTO, 0)
	for budgetRows.Next() {
		var b models.BudgetDTO
		if err := budgetRows.Scan(
			&b.ID,
			&b.Category,
			&b.LimitAmount,
			&b.Month,
			&b.Year,
			&b.UpdatedAt,
		); err != nil {
			return response.InternalError(
				c,
				"BUDGET_SCAN_FAILED",
				"Erro ao processar suas metas orçamentárias recebidas da nuvem.",
			)
		}
		budgets = append(budgets, b)
	}

	return c.Status(fiber.StatusOK).JSON(models.SyncPullResponse{
		Transactions: transactions,
		Budgets:      budgets,
		SyncedAt:     time.Now().UTC(),
	})
}
