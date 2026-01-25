FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install git and other build dependencies if needed
RUN apk add --no-cache git

COPY go.mod ./
# go.sum might not exist or be inconsistent, we will regenerate/tidy it
RUN go mod download || true

COPY . .

# Ensure all dependencies are present and compatible with Go 1.23
RUN go mod tidy
RUN go build -o analytics-service main.go

FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/analytics-service .

EXPOSE 50051

CMD ["./analytics-service"]

