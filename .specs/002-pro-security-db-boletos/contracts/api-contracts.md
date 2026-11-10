# Phase 1 API Contracts: GastoSync Core API (`gastosync_api`)

**Feature**: `002-pro-security-db-boletos`
**Base Path**: `/api/v1`

---

## 1. Autenticação, Verificação de E-mail e Perfil (`/api/v1/auth`)

### 1.1 `POST /api/v1/auth/register`
Registra um novo usuário com validação de senha forte OWASP, define `email_verified = false`, gera um OTP de 6 dígitos válido por 10 minutos e envia por e-mail.

- **Rate Limit**: 20 req/min por IP (`AuthRateLimiter`)
- **Request Body**:
  ```json
  {
    "name": "Maria Oliveira",
    "email": "maria@exemplo.com",
    "password": "SenhaForte@2026"
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "requires_verification": true,
    "message": "Conta criada! Enviamos um código de verificação de 6 dígitos para o seu e-mail.",
    "expires_in_seconds": 600,
    "delivery_mode": "smtp",
    "dev_preview_code": "482910",
    "user": {
      "id": "b3d7f6a2-9c12-4a8e-8f11-2a3b4c5d6e7f",
      "name": "Maria Oliveira",
      "email": "maria@exemplo.com",
      "email_verified": false,
      "monthly_income": 0,
      "savings_goal_percent": 20,
      "reminder_time_1": "09:00",
      "reminder_time_2": "18:00",
      "email_bill_notifications": true,
      "created_at": "2026-11-06T20:00:00Z"
    }
  }
  ```
  *(Nota: `dev_preview_code` é retornado apenas quando `APP_ENV != "production"` ou quando nenhum provedor SMTP externo está configurado).*

---

### 1.2 `POST /api/v1/auth/verify-email`
Valida o código OTP de 6 dígitos enviado para o e-mail do usuário, ativa a conta (`email_verified = true`) e retorna o JWT assinado.

- **Rate Limit**: 20 req/min por IP (`AuthRateLimiter`)
- **Request Body**:
  ```json
  {
    "email": "maria@exemplo.com",
    "code": "482910"
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "verified": true,
    "message": "E-mail verificado com sucesso!",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "b3d7f6a2-9c12-4a8e-8f11-2a3b4c5d6e7f",
      "name": "Maria Oliveira",
      "email": "maria@exemplo.com",
      "email_verified": true,
      "monthly_income": 0,
      "savings_goal_percent": 20,
      "reminder_time_1": "09:00",
      "reminder_time_2": "18:00",
      "email_bill_notifications": true,
      "created_at": "2026-11-06T20:00:00Z"
    }
  }
  ```

---

### 1.3 `POST /api/v1/auth/resend-verification`
Gera e envia um novo código OTP de 6 dígitos para uma conta cujo e-mail ainda não foi verificado.

- **Rate Limit**: 20 req/min por IP (`AuthRateLimiter`)
- **Request Body**:
  ```json
  {
    "email": "maria@exemplo.com"
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "message": "Um novo código de verificação de 6 dígitos foi enviado para o seu e-mail.",
    "expires_in_seconds": 600,
    "delivery_mode": "smtp",
    "dev_preview_code": "918273"
  }
  ```

---

### 1.4 `POST /api/v1/auth/login`
Autentica o usuário. Se `email_verified == false`, envia automaticamente um novo código OTP e retorna `403 Forbidden` para que o cliente abra o modal de verificação.

- **Response `403 Forbidden` (quando e-mail não verificado)**:
  ```json
  {
    "code": "EMAIL_NOT_VERIFIED",
    "message": "Seu e-mail ainda não foi verificado. Enviamos um novo código de 6 dígitos para concluir a ativação.",
    "requires_verification": true,
    "dev_preview_code": "918273"
  }
  ```

---

### 1.5 `PUT /api/v1/auth/profile`
Atualiza dados financeiros e preferências de lembretes de boletos do usuário autenticado.

- **Auth**: `Bearer <JWT>`
- **Request Body**:
  ```json
  {
    "name": "Maria Oliveira",
    "monthly_income": 6500.00,
    "savings_goal_percent": 25.00,
    "reminder_time_1": "08:30",
    "reminder_time_2": "19:00",
    "email_bill_notifications": true
  }
  ```
- **Response `200 OK`**: Objeto `User` atualizado.

---

## 2. Sincronização Bidirecional de Transações, Boletos e Orçamentos (`/api/v1/sync`)

### 2.1 `POST /api/v1/sync/push`
Faz *upsert* transacional de `transactions`, `bills` e `budgets` pertencentes ao `user_id` do token JWT, incluindo propagação de `deleted_at` (exclusão lógica).

- **Auth**: `Bearer <JWT>`
- **Request Body**:
  ```json
  {
    "transactions": [
      {
        "client_uuid": "550e8400-e29b-41d4-a716-446655440000",
        "local_id": 12,
        "description": "Supermercado",
        "amount": 245.90,
        "date": "2026-11-06T14:30:00Z",
        "type": "expense",
        "category": "Alimentação",
        "payment_method": "Crédito",
        "updated_at": "2026-11-06T14:30:00Z",
        "deleted_at": null
      }
    ],
    "bills": [
      {
        "client_uuid": "770e8400-e29b-41d4-a716-446655440111",
        "local_id": 3,
        "description": "Conta de Energia CEMIG",
        "amount": 189.40,
        "due_date": "2026-11-10T00:00:00Z",
        "category": "Moradia",
        "barcode": "83640000001894000000000000000000000000000000",
        "is_recurring": true,
        "is_credit_card_charge": false,
        "status": "pending",
        "paid_at": null,
        "linked_tx_uuid": null,
        "updated_at": "2026-11-06T15:00:00Z",
        "deleted_at": null
      }
    ],
    "budgets": [
      {
        "category": "Alimentação",
        "limit_amount": 1200.00,
        "month": 11,
        "year": 2026
      }
    ],
    "credit_cards": [
      {
        "client_uuid": "990e8400-e29b-41d4-a716-446655440999",
        "name": "Nubank Principal",
        "limit_amount": 1500.00,
        "target_min_percent": 50.0,
        "target_max_percent": 80.0,
        "due_day": 10,
        "is_primary": true
      }
    ]
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "synced_transactions": 1,
    "synced_bills": 1,
    "synced_budgets": 1,
    "synced_credit_cards": 1,
    "synced_at": "2026-11-06T20:05:00Z"
  }
  ```

---

### 2.2 `GET /api/v1/sync/pull`
Retorna todas as transações ativas (`deleted_at IS NULL`), boletos ativos (`deleted_at IS NULL`), cartões de crédito ativos (`deleted_at IS NULL`) e metas de orçamento do usuário autenticado.

- **Auth**: `Bearer <JWT>`
- **Response `200 OK`**:
  ```json
  {
    "transactions": [...],
    "bills": [...],
    "credit_cards": [...],
    "budgets": [...],
    "synced_at": "2026-11-06T20:05:00Z"
  }
  ```
