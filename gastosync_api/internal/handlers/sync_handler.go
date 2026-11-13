// Package handlers implements the HTTP route controllers for authentication
// and cloud data synchronization.
package handlers

import (
	"context"
	"regexp"
	"strings"
	"time"

	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/middleware"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/models"
	"github.com/TacioMoreira25/GastoSync/gastosync_api/internal/response"
	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5/pgxpool"
)

var uuidRegex = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func normalizeUUIDString(raw string) string {
	trimmed := strings.ToLower(strings.TrimSpace(raw))
	if uuidRegex.MatchString(trimmed) {
		return trimmed
	}
	return ""
}

func normalizeOptionalUUID(raw *string) *string {
	if raw == nil {
		return nil
	}
	norm := normalizeUUIDString(*raw)
	if norm == "" {
		return nil
	}
	return &norm
}

// SyncHandler manages bidirectional synchronization of transactions, bills,
// and budgets scoped strictly to the authenticated user_id.
type SyncHandler struct {
	pool *pgxpool.Pool
}

// NewSyncHandler constructs a new SyncHandler with a PostgreSQL connection pool.
func NewSyncHandler(pool *pgxpool.Pool) *SyncHandler {
	return &SyncHandler{
		pool: pool,
	}
}

// Push receives local transactions, bills, and budgets from the client and upserts them
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
		clientUUID := normalizeUUIDString(item.ClientUUID)
		creditCardUUID := normalizeOptionalUUID(item.CreditCardUUID)
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

		// Caso seja uma exclusão lógica (tombstone) com apenas identificadores preenchidos
		if item.DeletedAt != nil && (desc == "" || item.Amount <= 0 || (txType != "income" && txType != "expense") || category == "") {
			if clientUUID != "" {
				const softDeleteTxByUUID = `
					UPDATE transactions
					SET deleted_at = $3, updated_at = NOW()
					WHERE user_id = $1 AND client_uuid = $2::uuid
				`
				if _, err := tx.Exec(ctx, softDeleteTxByUUID, userID, clientUUID, *item.DeletedAt); err != nil {
					return response.InternalError(
						c,
						"TX_SOFT_DELETE_FAILED",
						"Erro ao propagar exclusão de transação na nuvem.",
					)
				}
				syncedTxCount++
			} else if item.LocalID != nil {
				const softDeleteTxByLocalID = `
					UPDATE transactions
					SET deleted_at = $3, updated_at = NOW()
					WHERE user_id = $1 AND local_id = $2
				`
				if _, err := tx.Exec(ctx, softDeleteTxByLocalID, userID, *item.LocalID, *item.DeletedAt); err != nil {
					return response.InternalError(
						c,
						"TX_SOFT_DELETE_FAILED",
						"Erro ao propagar exclusão de transação na nuvem.",
					)
				}
				syncedTxCount++
			}
			continue
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

		if clientUUID != "" {
			// Se já existir registro legado com o mesmo (user_id, local_id), alinha o client_uuid antes do upsert
			if item.LocalID != nil {
				const alignLegacyTxUUID = `
					UPDATE transactions
					SET client_uuid = $3::uuid
					WHERE user_id = $1 AND local_id = $2 AND client_uuid <> $3::uuid
					  AND NOT EXISTS (
					      SELECT 1 FROM transactions t2
					      WHERE t2.user_id = $1 AND t2.client_uuid = $3::uuid
					  )
				`
				_, _ = tx.Exec(ctx, alignLegacyTxUUID, userID, *item.LocalID, clientUUID)
			}

			const upsertTxByClientUUID = `
				INSERT INTO transactions (
					user_id, client_uuid, local_id, description, amount, tx_date,
					tx_type, category, payment_method, credit_card_uuid, updated_at, deleted_at
				)
				VALUES ($1, $2::uuid, $3, $4, $5, $6, $7, $8, $9, $10::uuid, NOW(), $11)
				ON CONFLICT (user_id, client_uuid)
				DO UPDATE SET
					local_id = COALESCE(EXCLUDED.local_id, transactions.local_id),
					description = EXCLUDED.description,
					amount = EXCLUDED.amount,
					tx_date = EXCLUDED.tx_date,
					tx_type = EXCLUDED.tx_type,
					category = EXCLUDED.category,
					payment_method = EXCLUDED.payment_method,
					credit_card_uuid = EXCLUDED.credit_card_uuid,
					updated_at = NOW(),
					deleted_at = EXCLUDED.deleted_at
			`
			if _, err := tx.Exec(
				ctx,
				upsertTxByClientUUID,
				userID,
				clientUUID,
				item.LocalID,
				desc,
				item.Amount,
				txDate,
				txType,
				category,
				paymentMethod,
				creditCardUUID,
				item.DeletedAt,
			); err != nil {
				return response.InternalError(
					c,
					"TX_UPSERT_FAILED",
					"Erro ao salvar uma de suas transações na nuvem. Nenhuma alteração foi perdida localmente.",
				)
			}
		} else if item.LocalID != nil {
			const upsertTxWithLocalID = `
				INSERT INTO transactions (
					user_id, local_id, description, amount, tx_date, tx_type,
					category, payment_method, credit_card_uuid, updated_at, deleted_at
				)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::uuid, NOW(), $10)
				ON CONFLICT (user_id, local_id)
				DO UPDATE SET
					description = EXCLUDED.description,
					amount = EXCLUDED.amount,
					tx_date = EXCLUDED.tx_date,
					tx_type = EXCLUDED.tx_type,
					category = EXCLUDED.category,
					payment_method = EXCLUDED.payment_method,
					credit_card_uuid = EXCLUDED.credit_card_uuid,
					updated_at = NOW(),
					deleted_at = EXCLUDED.deleted_at
			`
			if _, err := tx.Exec(
				ctx,
				upsertTxWithLocalID,
				userID,
				*item.LocalID,
				desc,
				item.Amount,
				txDate,
				txType,
				category,
				paymentMethod,
				creditCardUUID,
				item.DeletedAt,
			); err != nil {
				return response.InternalError(
					c,
					"TX_UPSERT_FAILED",
					"Erro ao salvar uma de suas transações na nuvem. Nenhuma alteração foi perdida localmente.",
				)
			}
		} else {
			const insertTx = `
				INSERT INTO transactions (
					user_id, description, amount, tx_date, tx_type,
					category, payment_method, credit_card_uuid, updated_at, deleted_at
				)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8::uuid, NOW(), $9)
			`
			if _, err := tx.Exec(
				ctx,
				insertTx,
				userID,
				desc,
				item.Amount,
				txDate,
				txType,
				category,
				paymentMethod,
				creditCardUUID,
				item.DeletedAt,
			); err != nil {
				return response.InternalError(
					c,
					"TX_INSERT_FAILED",
					"Erro ao registrar transação na nuvem. Seus dados continuam salvos localmente.",
				)
			}
		}
		syncedTxCount++
	}

	syncedBillCount := 0
	for _, bill := range req.Bills {
		clientUUID := normalizeUUIDString(bill.ClientUUID)
		creditCardUUID := normalizeOptionalUUID(bill.CreditCardUUID)
		linkedTxUUID := normalizeOptionalUUID(bill.LinkedTxUUID)
		desc := strings.TrimSpace(bill.Description)
		category := strings.TrimSpace(bill.Category)
		barcode := strings.TrimSpace(bill.Barcode)
		status := strings.ToLower(strings.TrimSpace(bill.Status))
		if status != "pending" && status != "paid" && status != "overdue" {
			status = "pending"
		}

		if bill.DeletedAt != nil && (desc == "" || bill.Amount <= 0 || category == "") {
			if clientUUID != "" {
				const softDeleteBillByUUID = `
					UPDATE bills
					SET deleted_at = $3, updated_at = NOW()
					WHERE user_id = $1 AND client_uuid = $2::uuid
				`
				if _, err := tx.Exec(ctx, softDeleteBillByUUID, userID, clientUUID, *bill.DeletedAt); err != nil {
					return response.InternalError(
						c,
						"BILL_SOFT_DELETE_FAILED",
						"Erro ao propagar exclusão de boleto na nuvem.",
					)
				}
				syncedBillCount++
			}
			continue
		}

		if desc == "" || bill.Amount <= 0 || category == "" {
			continue
		}

		dueDate := bill.DueDate
		if dueDate.IsZero() {
			dueDate = time.Now().UTC()
		}

		if clientUUID != "" {
			const upsertBillByClientUUID = `
				INSERT INTO bills (
					user_id, client_uuid, local_id, description, amount, due_date,
					category, barcode, is_recurring, is_credit_card_charge,
					credit_card_uuid, status, paid_at, linked_tx_uuid, updated_at, deleted_at
				)
				VALUES ($1, $2::uuid, $3, $4, $5, $6, $7, $8, $9, $10, $11::uuid, $12, $13, $14::uuid, NOW(), $15)
				ON CONFLICT (user_id, client_uuid)
				DO UPDATE SET
					local_id = COALESCE(EXCLUDED.local_id, bills.local_id),
					description = EXCLUDED.description,
					amount = EXCLUDED.amount,
					due_date = EXCLUDED.due_date,
					category = EXCLUDED.category,
					barcode = EXCLUDED.barcode,
					is_recurring = EXCLUDED.is_recurring,
					is_credit_card_charge = EXCLUDED.is_credit_card_charge,
					credit_card_uuid = EXCLUDED.credit_card_uuid,
					status = EXCLUDED.status,
					paid_at = EXCLUDED.paid_at,
					linked_tx_uuid = EXCLUDED.linked_tx_uuid,
					updated_at = NOW(),
					deleted_at = EXCLUDED.deleted_at
			`
			if _, err := tx.Exec(
				ctx,
				upsertBillByClientUUID,
				userID,
				clientUUID,
				bill.LocalID,
				desc,
				bill.Amount,
				dueDate,
				category,
				barcode,
				bill.IsRecurring,
				bill.IsCreditCardCharge,
				creditCardUUID,
				status,
				bill.PaidAt,
				linkedTxUUID,
				bill.DeletedAt,
			); err != nil {
				return response.InternalError(
					c,
					"BILL_UPSERT_FAILED",
					"Erro ao sincronizar um de seus boletos na nuvem. Seus dados continuam salvos localmente.",
				)
			}
		} else {
			const insertBill = `
				INSERT INTO bills (
					user_id, local_id, description, amount, due_date,
					category, barcode, is_recurring, is_credit_card_charge,
					credit_card_uuid, status, paid_at, linked_tx_uuid, updated_at, deleted_at
				)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::uuid, $11, $12, $13::uuid, NOW(), $14)
			`
			if _, err := tx.Exec(
				ctx,
				insertBill,
				userID,
				bill.LocalID,
				desc,
				bill.Amount,
				dueDate,
				category,
				barcode,
				bill.IsRecurring,
				bill.IsCreditCardCharge,
				creditCardUUID,
				status,
				bill.PaidAt,
				linkedTxUUID,
				bill.DeletedAt,
			); err != nil {
				return response.InternalError(
					c,
					"BILL_INSERT_FAILED",
					"Erro ao registrar boleto na nuvem. Seus dados continuam salvos localmente.",
				)
			}
		}
		syncedBillCount++
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
		SyncedBills:        syncedBillCount,
		SyncedBudgets:      syncedBudgetCount,
		SyncedAt:           time.Now().UTC(),
	})
}

// Pull returns all active (non-deleted) transactions, bills, and budgets
// belonging to the authenticated user.
func (h *SyncHandler) Pull(c *fiber.Ctx) error {
	userID, _ := c.Locals(middleware.UserIDKey).(string)

	ctx, cancel := context.WithTimeout(c.Context(), 15*time.Second)
	defer cancel()

	const txQuery = `
		SELECT id, client_uuid::text, local_id, description, amount, tx_date, tx_type,
		       category, payment_method, credit_card_uuid::text, updated_at, deleted_at
		FROM transactions
		WHERE user_id = $1 AND deleted_at IS NULL
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
			&t.ClientUUID,
			&t.LocalID,
			&t.Description,
			&t.Amount,
			&t.Date,
			&t.Type,
			&t.Category,
			&t.PaymentMethod,
			&t.CreditCardUUID,
			&t.UpdatedAt,
			&t.DeletedAt,
		); err != nil {
			return response.InternalError(
				c,
				"TX_SCAN_FAILED",
				"Erro ao processar o histórico de transações recebido da nuvem.",
			)
		}
		transactions = append(transactions, t)
	}

	const billQuery = `
		SELECT id, client_uuid::text, local_id, description, amount, due_date,
		       category, barcode, is_recurring, is_credit_card_charge,
		       credit_card_uuid::text, status, paid_at, linked_tx_uuid::text,
		       updated_at, deleted_at
		FROM bills
		WHERE user_id = $1 AND deleted_at IS NULL
		ORDER BY due_date ASC, id DESC
	`
	billRows, err := h.pool.Query(ctx, billQuery, userID)
	if err != nil {
		return response.InternalError(
			c,
			"BILL_PULL_QUERY_FAILED",
			"Não foi possível buscar seus boletos na nuvem no momento.",
		)
	}
	defer billRows.Close()

	bills := make([]models.BillDTO, 0)
	for billRows.Next() {
		var b models.BillDTO
		if err := billRows.Scan(
			&b.ID,
			&b.ClientUUID,
			&b.LocalID,
			&b.Description,
			&b.Amount,
			&b.DueDate,
			&b.Category,
			&b.Barcode,
			&b.IsRecurring,
			&b.IsCreditCardCharge,
			&b.CreditCardUUID,
			&b.Status,
			&b.PaidAt,
			&b.LinkedTxUUID,
			&b.UpdatedAt,
			&b.DeletedAt,
		); err != nil {
			return response.InternalError(
				c,
				"BILL_SCAN_FAILED",
				"Erro ao processar a lista de boletos recebida da nuvem.",
			)
		}
		bills = append(bills, b)
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
		Bills:        bills,
		Budgets:      budgets,
		SyncedAt:     time.Now().UTC(),
	})
}
