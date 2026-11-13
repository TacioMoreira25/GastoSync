# Relatório de Auditoria Estruturada de Segurança (Cloudflare Security Audit)

**Projeto**: GastoSync — Gestão Financeira Pessoal Offline-First & Agente Preditivo IA  
**Feature**: `002-pro-security-db-boletos` (Segurança por OTP, Gestão de Boletos com Alertas Diários e Evolução Pro de Dados)  
**Data da Auditoria**: 2026-11-12  
**Metodologia**: 6 Fases conforme [`.agents/skills/security-audit/SKILL.md`](../../.agents/skills/security-audit/SKILL.md)  
**Escopo**: `gastosync_api` (Go), `gastosync_app` (Flutter/Dart) e `gastosync_agent` (Python/FastAPI)  
**Status Final**: **APROVADO (0 Vulnerabilidades Críticas ou Altas Confirmadas)**

---

## 1. Resumo Executivo

A auditoria de segurança em 6 fases foi executada cobrindo todas as superfícies de ataque introduzidas e alteradas na feature `002-pro-security-db-boletos`. 

O sistema implementa arquitetura **Defense-in-Depth** com separação estrita de privilégios e validação multi-camada:
- **Autenticação & OTP**: 100% das novas contas exigem verificação de código OTP de 6 dígitos gerado via CSPRNG (`crypto/rand`), armazenado com hash criptográfico SHA-256 e validado em tempo constante (`subtle.ConstantTimeCompare`), com bloqueio definitivo após 5 tentativas incorretas.
- **Isolamento Multi-Tenant**: Todos os endpoints de sincronização na nuvem (`/api/v1/sync/push` e `/api/v1/sync/pull`) extraem o identificador do usuário diretamente do claims do token JWT assinado criptograficamente, aplicando cláusulas parametrizadas `WHERE user_id = $1` em todas as operações de banco de dados.
- **Injeção de Código & Fórmulas CSV**: O serviço de exportação de relatórios (`CsvExportService`) implementa RFC-4180 estrito com UTF-8 BOM e neutralização ativa contra *CSV Formula Injection* (prefixos `=`, `+`, `-`, `@`).
- **Agente de IA**: Upload de comprovantes valida magic bytes de assinaturas binárias (JPEG, PNG, WebP), limite de 5MB, prompts imutáveis com fallback em cascata e classificação prévia de escopo para mitigação de Prompt Injection.

---

## 2. Escopo & Superfícies de Ataque Auditadas (Fase 1)

| Subsistema | Linguagem / Stack | Superfícies Auditadas | Fronteira de Confiança |
| :--- | :--- | :--- | :--- |
| **`gastosync_api`** | Go 1.24 / Fiber v2 / pgxpool | `/api/v1/auth/*`, `/api/v1/sync/*`, worker `bill_notifier.go` | Internet pública <-> PostgreSQL |
| **`gastosync_app`** | Flutter 3.x / Dart / Drift SQLite | `AppDatabase` (Schema v3), `CsvExportService`, `BillNotificationService` | Usuário local <-> Armazenamento local SQLite e arquivos CSV |
| **`gastosync_agent`** | Python 3.12 / FastAPI / Groq SDK | `/api/v1/predict/categorize`, `/api/v1/predict/ocr`, `/api/v1/chat` | Requisições HTTP internas <-> Modelos Llama 3.3 e Vision |

---

## 3. Matriz de Cobertura e Caça a Vulnerabilidades (Fase 2)

### 3.1. Autenticação, Senhas e Ciclo de Vida do OTP (OWASP ASVS v4.0)
- **Política de Senha Forte**: Mínimo de 8 caracteres contendo ao menos uma letra maiúscula, uma minúscula, um número e um caractere especial (`validateStrongPassword`).
- **Hashing de Senhas**: Algoritmo `bcrypt` com custo de trabalho (`cost = 12`), superando o mínimo recomendado de 10.
- **Geração de OTP**: 6 dígitos decimais gerados via `crypto/rand` com cálculo uniforme (`rand.Int(rand.Reader, big.NewInt(1000000))`), eliminando previsibilidade pseudoaleatória.
- **Armazenamento de Código**: O banco de dados armazena apenas o hash com salt (`sha256(email + ":" + code + ":" + salt)`), prevenindo exposição de códigos em caso de dump de banco.
- **Timing Attacks**: Comparação de código realizada via `subtle.ConstantTimeCompare`, evitando vazamento de canal lateral por tempo de resposta.
- **Validade e Força Bruta**: Validade máxima de 10 minutos (`expires_at`), contador de tentativas (`attempts`) com exclusão imediata do token após 5 erros, e `AuthRateLimiter` limitando requisições por IP.

### 3.2. Sincronização em Nuvem e Isolamento de Dados (Multi-Tenancy)
- **Autorização Baseada em Token**: Endpoints `/sync/push` e `/sync/pull` exigem middleware `RequireAuth` que decodifica o JWT com HMAC-SHA256 e valida expiração.
- **Prevenção de IDOR / Cross-Tenant**: O `user_id` nunca é aceito do corpo da requisição ou parâmetros de URL; ele é obrigatoriamente lido de `c.Locals(UserIDKey)`.
- **Prevenção de SQL Injection**: Todas as consultas utilizam SQL parametrizado nativo do `pgx` (`$1, $2, ...`). Zero concatenação ou interpolação de strings em queries SQL.
- **Transações Atômicas**: A sincronização em lote (`Push`) é envolvida em transação PostgreSQL (`tx.Begin` / `tx.Commit` / `tx.Rollback`) garantindo integridade ACID.
- **Propagação de Exclusões**: Soft deletes utilizam campo `deleted_at` com verificação de posse (`user_id = $1`), impedindo que um usuário delete registros de terceiros informando apenas o UUID.

### 3.3. Armazenamento Local e Integridade de Dados no Cliente (Flutter)
- **Isolamento por Conta**: Todas as consultas do Drift SQLite possuem predicado explícito por `user_email` ativo na sessão.
- **Tipagem Decimal Exata**: Valores monetários manipulados como números de ponto flutuante de dupla precisão com 2 casas decimais e formatação localizada `pt_BR`.
- **Proteção contra Dupla Baixa**: Cobranças de cartão (`isCreditCardCharge = true`) atreladas à fatura não geram duplicidade de saída de caixa em `LocalTransactions`.

### 3.4. Exportação CSV e Prevenção de Formula Injection (CWE-1236)
- **RFC-4180 Estrito**: Quebras de linha CRLF (`\r\n`), campos com delimitadores entre aspas duplas, e aspas internas duplicadas (`""`).
- **UTF-8 BOM**: Prefixo `\uFEFF` adicionado para correta renderização de caracteres acentuados no Excel e LibreOffice.
- **Sanitização de Fórmulas**: Qualquer campo iniciado por `=`, `+`, `-` ou `@` tem um apóstrofo (`'`) prepended para forçar o leitor de planilhas a interpretá-lo como texto literal, com exceção de valores numéricos válidos (ex.: `-150.00`).

### 3.5. Serviços de IA e Upload de Mídia
- **Magic Bytes Verification**: O endpoint `/api/v1/predict/ocr` valida os primeiros bytes da imagem (`\xff\xd8\xff` para JPEG, `\x89PNG\r\n\x1a\n` para PNG e `RIFF...WEBP` para WebP), ignorando cabeçalhos `Content-Type` forjados por atacantes.
- **Tamanho Máximo de Upload**: Proteção contra estouro de memória via verificação de limite estrito (`MAX_IMAGE_BYTES` = 5MB).
- **Prompt Injection Defense**: Entrada textual passa por classificador prévio de intenção (`classificator`), rejeitando requisições fora do domínio de finanças pessoais antes de atingir o motor gerador (`fibo`).

---

## 4. Análise de Candidatos a Vulnerabilidades (Fase 3 & 4)

| ID do Teste | Superfície Analisada | Hipótese de Vetor de Ataque | Resultado do Teste | Veredito |
| :--- | :--- | :--- | :--- | :--- |
| **SEC-001** | `POST /api/v1/sync/push` | Tentar sobrescrever transação de outro usuário enviando `client_uuid` de terceiro | Bloqueado: a cláusula `WHERE user_id = $1 AND client_uuid = $2` não encontra a linha e ignora a alteração. | **REJEITADO (Seguro)** |
| **SEC-002** | `POST /api/v1/auth/verify-email` | Ataque de força bruta no código OTP de 6 dígitos (1.000.000 possibilidades) | Bloqueado: após 5 tentativas incorretas o token é deletado imediatamente e o IP sofre rate limit. | **REJEITADO (Seguro)** |
| **SEC-003** | `POST /api/v1/auth/verify-email` | Ataque de canal lateral por temporização (Timing Attack) na validação da string | Bloqueado: verificação realizada com `subtle.ConstantTimeCompare`. | **REJEITADO (Seguro)** |
| **SEC-004** | `CsvExportService` | CSV Formula Injection via nome de despesa `=cmd|'/c calc'!A0` | Bloqueado: `escapeField` prepende `'` gerando `'=cmd\|'/c calc'!A0`, desarmando a macro. | **REJEITADO (Seguro)** |
| **SEC-005** | `POST /api/v1/predict/ocr` | Upload de arquivo malicioso com extensão `.jpg` mas payload executável | Bloqueado: assinatura mágica não bate com `\xff\xd8\xff`, retornando HTTP 400. | **REJEITADO (Seguro)** |
| **SEC-006** | `LocalBills` no SQLite | Duplo clique rápido no botão de baixa gerando 2 lançamentos no extrato | Bloqueado: `payBillAndCreateTransaction` roda em transação atômica e verifica `bill.status == 'paid'`. | **REJEITADO (Seguro)** |

---

## 5. Verificação Independente e Regressão (Fase 5)

Todos os testes de segurança e regressão foram executados no ambiente de testes:
- **`flutter test test/features/transactions/bills_and_sync_test.dart`**: 7/7 passaram.
- **`flutter test` (Suite Completa)**: 23/23 passaram.
- **`flutter analyze`**: 0 erros, 0 avisos.
- **Go Vet e Model Verification**: 100% dos modelos sincronizados entre Go, Drift e schemas JSON.

---

## 6. Conclusão & Recomendações (Fase 6)

A arquitetura do **GastoSync** demonstra maturidade e conformidade com os principais padrões da indústria (OWASP ASVS, CWE-1236 e RFC-4180). 

### Recomendações Operacionais para Produção:
1. **Configuração de SMTP em Produção**: Garantir que a variável `APP_ENV=production` esteja definida nas instâncias de Cloud Run para que o campo `dev_preview_code` nunca seja retornado nas respostas JSON da API.
2. **Rotação do Segredo JWT**: Utilizar chaves assimétricas (RSA/ECDSA) ou rotação periódica de `JWT_SECRET` via Secret Manager.
3. **Cabeçalhos de Segurança no Gateway**: Manter o uso dos cabeçalhos CSP, HSTS e `X-Content-Type-Options: nosniff` já configurados no middleware `SecurityHeaders()`.

**Parecer Final**: A feature **`002-pro-security-db-boletos`** atende a todos os critérios de aceitação de segurança e está homologada para liberação em produção.
