FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -ldflags="-s -w" -o integration-service main.go

FROM alpine:3.21
WORKDIR /root/
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/integration-service .
EXPOSE 50052
CMD ["./integration-service"]
