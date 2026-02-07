FROM golang:1.24-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod ./
# RUN go mod download || true

COPY . .

RUN go mod tidy
RUN go build -o integration-service main.go

FROM alpine:latest

WORKDIR /root/

RUN apk add --no-cache ca-certificates

COPY --from=builder /app/integration-service .

EXPOSE 50052

CMD ["./integration-service"]

