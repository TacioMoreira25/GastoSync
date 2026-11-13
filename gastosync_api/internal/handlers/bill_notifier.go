package handlers

import (
	"context"
	"fmt"
	"html"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// BillReminderItem represents a single due, overdue, or upcoming bill included in the twice-daily email digest.
type BillReminderItem struct {
	ID                 int64
	Description        string
	Category           string
	Amount             float64
	DueDate            time.Time
	Status             string
	IsCreditCardCharge bool
	Barcode            string
}

type userReminderTarget struct {
	UserID        string
	Name          string
	Email         string
	ReminderTime1 string
	ReminderTime2 string
}

var (
	dispatchedShiftsMu sync.Mutex
	dispatchedShifts   = make(map[string]time.Time)
)

// StartBillReminderWorker launches a background goroutine that checks due/overdue bills every minute
// against each user's configured twice-daily reminder times (reminder_time_1 and reminder_time_2)
// and dispatches HTML reminder emails via Brevo / Resend / SMTP.
func StartBillReminderWorker(ctx context.Context, pool *pgxpool.Pool, authHandler *AuthHandler) {
	if pool == nil || authHandler == nil {
		return
	}

	go func() {
		log.Println("[BILL NOTIFIER] Twice-daily bill reminder worker started")
		ticker := time.NewTicker(1 * time.Minute)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				log.Println("[BILL NOTIFIER] Stopping bill reminder worker...")
				return
			case now := <-ticker.C:
				processTwiceDailyBillReminders(ctx, pool, authHandler, now)
			}
		}
	}()
}

func brazilLocation() *time.Location {
	loc, err := time.LoadLocation("America/Sao_Paulo")
	if err != nil {
		return time.FixedZone("BRT", -3*3600)
	}
	return loc
}

// isWithinReminderWindow returns true if currentHHMM is within [targetHHMM, targetHHMM + 4 minutes].
func isWithinReminderWindow(currentNow time.Time, targetHHMM string) bool {
	trimmed := strings.TrimSpace(targetHHMM)
	if !isValidReminderTime(trimmed) {
		return false
	}
	parsed, err := time.Parse("15:04", trimmed)
	if err != nil {
		return false
	}

	targetMinutes := parsed.Hour()*60 + parsed.Minute()
	currentMinutes := currentNow.Hour()*60 + currentNow.Minute()
	diff := currentMinutes - targetMinutes
	return diff >= 0 && diff <= 4
}

func hasDispatchedShift(shiftKey string) bool {
	dispatchedShiftsMu.Lock()
	defer dispatchedShiftsMu.Unlock()

	// Prune entries older than 36 hours to keep memory bounded
	cutoff := time.Now().UTC().Add(-36 * time.Hour)
	for k, ts := range dispatchedShifts {
		if ts.Before(cutoff) {
			delete(dispatchedShifts, k)
		}
	}

	_, exists := dispatchedShifts[shiftKey]
	return exists
}

func markDispatchedShift(shiftKey string) {
	dispatchedShiftsMu.Lock()
	defer dispatchedShiftsMu.Unlock()
	dispatchedShifts[shiftKey] = time.Now().UTC()
}

func processTwiceDailyBillReminders(
	ctx context.Context,
	pool *pgxpool.Pool,
	authHandler *AuthHandler,
	nowUTC time.Time,
) {
	loc := brazilLocation()
	localNow := nowUTC.In(loc)
	dateKey := localNow.Format("2006-01-02")

	queryCtx, cancel := context.WithTimeout(ctx, 25*time.Second)
	defer cancel()

	// 1. Mark any pending bills with past due_date as 'overdue'
	_, _ = pool.Exec(queryCtx, `
		UPDATE bills
		SET status = 'overdue', updated_at = NOW()
		WHERE deleted_at IS NULL
		  AND status = 'pending'
		  AND due_date < CURRENT_DATE
	`)

	// 2. Find verified users with email_bill_notifications enabled
	rows, err := pool.Query(queryCtx, `
		SELECT id, name, email, reminder_time_1, reminder_time_2
		FROM users
		WHERE email_verified = TRUE
		  AND email_bill_notifications = TRUE
	`)
	if err != nil {
		log.Printf("[BILL NOTIFIER] Failed to query users: %v", err)
		return
	}

	var targets []userReminderTarget
	for rows.Next() {
		var u userReminderTarget
		if scanErr := rows.Scan(&u.UserID, &u.Name, &u.Email, &u.ReminderTime1, &u.ReminderTime2); scanErr == nil {
			targets = append(targets, u)
		}
	}
	rows.Close()

	for _, u := range targets {
		slot := ""
		slotTime := ""
		if isWithinReminderWindow(localNow, u.ReminderTime1) {
			slot = "turno_1"
			slotTime = strings.TrimSpace(u.ReminderTime1)
		} else if isWithinReminderWindow(localNow, u.ReminderTime2) {
			slot = "turno_2"
			slotTime = strings.TrimSpace(u.ReminderTime2)
		}

		if slot == "" {
			continue
		}

		shiftKey := fmt.Sprintf("%s::%s::%s::%s", u.UserID, dateKey, slot, slotTime)
		if hasDispatchedShift(shiftKey) {
			continue
		}

		bills, err := fetchDueAndUpcomingBillsForUser(queryCtx, pool, u.UserID)
		if err != nil || len(bills) == 0 {
			continue
		}

		subject := fmt.Sprintf("GastoSync • Lembrete de Boletos (%d pendente(s) — %s)", len(bills), slotTime)
		htmlBody := buildBillReminderEmailHTML(u.Name, bills, slotTime, localNow)

		delivered, mode := authHandler.dispatchTransactionalEmail(u.Email, u.Name, subject, htmlBody)
		log.Printf("[BILL NOTIFIER] Dispatched %s reminder (%s) to %s for %d bill(s) [delivered=%v, mode=%s]",
			slot, slotTime, u.Email, len(bills), delivered, mode)

		markDispatchedShift(shiftKey)

		// Update last_notified_at on notified bills
		billIDs := make([]int64, 0, len(bills))
		for _, b := range bills {
			billIDs = append(billIDs, b.ID)
		}
		_, _ = pool.Exec(queryCtx, `
			UPDATE bills
			SET last_notified_at = NOW()
			WHERE user_id = $1
			  AND id = ANY($2)
		`, u.UserID, billIDs)
	}
}

func fetchDueAndUpcomingBillsForUser(
	ctx context.Context,
	pool *pgxpool.Pool,
	userID string,
) ([]BillReminderItem, error) {
	const q = `
		SELECT id, description, category, amount::DOUBLE PRECISION, due_date, status, is_credit_card_charge, barcode
		FROM bills
		WHERE user_id = $1
		  AND deleted_at IS NULL
		  AND status IN ('pending', 'overdue')
		  AND due_date <= (CURRENT_DATE + INTERVAL '3 days')
		  AND (last_notified_at IS NULL OR last_notified_at < NOW() - INTERVAL '3 hours')
		ORDER BY due_date ASC, id ASC
	`
	rows, err := pool.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []BillReminderItem
	for rows.Next() {
		var item BillReminderItem
		if err := rows.Scan(
			&item.ID,
			&item.Description,
			&item.Category,
			&item.Amount,
			&item.DueDate,
			&item.Status,
			&item.IsCreditCardCharge,
			&item.Barcode,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, nil
}

func buildBillReminderEmailHTML(
	userName string,
	bills []BillReminderItem,
	slotTime string,
	referenceNow time.Time,
) string {
	var totalCashOutflow float64
	var totalCardReminders float64
	var rowsHTML strings.Builder

	todayMidnight := time.Date(referenceNow.Year(), referenceNow.Month(), referenceNow.Day(), 0, 0, 0, 0, referenceNow.Location())

	for _, b := range bills {
		if b.IsCreditCardCharge {
			totalCardReminders += b.Amount
		} else {
			totalCashOutflow += b.Amount
		}

		dueMidnight := time.Date(b.DueDate.Year(), b.DueDate.Month(), b.DueDate.Day(), 0, 0, 0, 0, referenceNow.Location())
		daysDiff := int(dueMidnight.Sub(todayMidnight).Hours() / 24)

		statusBadge := "A vencer"
		badgeColor := "#d97706"
		badgeBg := "#fef3c7"
		if daysDiff < 0 || strings.ToLower(b.Status) == "overdue" {
			statusBadge = "Vencido"
			badgeColor = "#dc2626"
			badgeBg = "#fee2e2"
		} else if daysDiff == 0 {
			statusBadge = "Vence hoje"
			badgeColor = "#d97706"
			badgeBg = "#fef3c7"
		} else {
			statusBadge = fmt.Sprintf("Vence em %dd", daysDiff)
		}

		cardTag := ""
		if b.IsCreditCardCharge {
			cardTag = ` <span style="background:#d1fae5;color:#047857;padding:2px 6px;border-radius:999px;font-size:10px;font-weight:700;">Incluso na Fatura</span>`
		}

		rowsHTML.WriteString(fmt.Sprintf(`
		<tr>
		  <td style="padding: 10px 8px; border-bottom: 1px solid #e2e8f0;">
		    <strong style="color: #0f172a; font-size: 13px;">%s</strong>%s<br/>
		    <span style="color: #64748b; font-size: 11px;">%s · Vencimento: %s</span>
		  </td>
		  <td style="padding: 10px 8px; border-bottom: 1px solid #e2e8f0; text-align: center;">
		    <span style="background: %s; color: %s; padding: 3px 8px; border-radius: 999px; font-size: 11px; font-weight: 700;">%s</span>
		  </td>
		  <td style="padding: 10px 8px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: 700; color: #0f172a; font-size: 13px;">
		    R$ %.2f
		  </td>
		</tr>`,
			html.EscapeString(b.Description),
			cardTag,
			html.EscapeString(b.Category),
			b.DueDate.Format("02/01/2006"),
			badgeBg,
			badgeColor,
			statusBadge,
			b.Amount,
		))
	}

	safeName := html.EscapeString(strings.TrimSpace(userName))
	if safeName == "" {
		safeName = "Usuário"
	}

	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f8fafc; padding: 24px;">
  <div style="max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 28px; border: 1px solid #e2e8f0;">
    <h2 style="color: #0f172a; margin-top: 0;">Lembrete de Boletos (%s) — GastoSync</h2>
    <p style="color: #475569; font-size: 14px;">Olá, <strong>%s</strong>. Você possui <strong>%d compromisso(s)</strong> vencendo em breve ou em atraso:</p>
    <div style="background: #f1f5f9; border-radius: 12px; padding: 14px; margin: 16px 0;">
      <div style="font-size: 12px; color: #475569;">Total Real a Pagar (Caixa): <strong style="color: #0f172a;">R$ %.2f</strong></div>
      <div style="font-size: 12px; color: #475569; margin-top: 4px;">Lembretes no Cartão (Inclusos na Fatura): <strong style="color: #047857;">R$ %.2f</strong></div>
    </div>
    <table style="width: 100%%; border-collapse: collapse; margin-top: 12px;">
      <thead>
        <tr style="text-align: left; border-bottom: 2px solid #e2e8f0; color: #64748b; font-size: 11px;">
          <th style="padding: 8px;">CONTA / BOLETO</th>
          <th style="padding: 8px; text-align: center;">STATUS</th>
          <th style="padding: 8px; text-align: right;">VALOR</th>
        </tr>
      </thead>
      <tbody>
        %s
      </tbody>
    </table>
    <p style="color: #64748b; font-size: 12px; margin-top: 20px;">Abra o aplicativo GastoSync em <strong>Transações &gt; Boletos a Pagar</strong> para copiar o código PIX/linha digitável e dar baixa em 1 toque.</p>
  </div>
</body>
</html>`,
		html.EscapeString(slotTime),
		safeName,
		len(bills),
		totalCashOutflow,
		totalCardReminders,
		rowsHTML.String(),
	)
}
