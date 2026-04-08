FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -ldflags="-s -w" -o analytics-service main.go

FROM alpine:3.21
WORKDIR /root/
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/analytics-service .
EXPOSE 50051
CMD ["./analytics-service"]
