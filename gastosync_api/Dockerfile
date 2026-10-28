# ==============================================================================
# Stage 1: Build Stage (Compilação do Binário Estático em Go)
# ==============================================================================
FROM golang:1.23-alpine AS builder

# Instala certificados SSL (necessários para conectar ao Neon Postgres via TLS) e git
RUN apk add --no-cache ca-certificates tzdata git

WORKDIR /app

# Copia os arquivos de dependências primeiro para aproveitar cache de camadas Docker
COPY go.mod go.sum* ./
RUN go mod download

# Copia o código-fonte da API
COPY . .

# Compila um binário estático otimizado sem símbolos de debug (-s -w)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /app/bin/gastosync_api ./cmd/api

# ==============================================================================
# Stage 2: Runtime Stage (Imagem Final Ultra-Leve e Segura ~15MB)
# ==============================================================================
FROM alpine:3.20

# Instala certificados raiz para conexões HTTPS/TLS (Neon Postgres)
RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -S gastosync && adduser -S gastosync -G gastosync

WORKDIR /app

# Copia apenas o binário compilado do estágio anterior
COPY --from=builder /app/bin/gastosync_api /app/gastosync_api

# Define usuário não-root por segurança (OWASP / Container Hardening)
USER gastosync

# Porta padrão usada pelo Render (sobrescrita dinamicamente via variável $PORT)
EXPOSE 8080

# Comando de inicialização
ENTRYPOINT ["/app/gastosync_api"]
