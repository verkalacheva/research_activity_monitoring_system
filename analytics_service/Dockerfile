# syntax=docker/dockerfile:1
FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod \
    go mod tidy && go build -ldflags="-s -w" -o analytics-service main.go

FROM alpine:3.21
WORKDIR /root/
RUN apk add --no-cache ca-certificates curl
COPY --from=builder /app/analytics-service .
EXPOSE 50051 8080
ENV HEALTH_HTTP_PORT=8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD /bin/sh -c 'curl -fsS "http://$HEALTHCHECK_HOST:$HEALTH_HTTP_PORT/health/live" || exit 1'
CMD ["./analytics-service"]
