# ==============================================================================
# Stage 1: Build Stage
# Compiles a statically linked Go binary with stripped debug symbols.
# ==============================================================================
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache ca-certificates tzdata git

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go mod tidy && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /app/bin/gastosync_api ./cmd/api

# ==============================================================================
# Stage 2: Runtime Stage
# Minimal Alpine image running under an unprivileged system user.
# ==============================================================================
FROM alpine:3.20

RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -S gastosync && adduser -S gastosync -G gastosync

WORKDIR /app

COPY --from=builder /app/bin/gastosync_api /app/gastosync_api

USER gastosync

EXPOSE 8080

ENTRYPOINT ["/app/gastosync_api"]
