# frozen_string_literal: true

# gRPC keepalive and deadlines between backend and Go/Python services (see ENV in .env.example).
module ServiceGrpc
  DEADLINE_INTEGRATION = Float(ENV.fetch("GRPC_INTEGRATION_DEADLINE_SECONDS", "120"))
  DEADLINE_ANALYTICS   = Float(ENV.fetch("GRPC_ANALYTICS_DEADLINE_SECONDS", "90"))
  DEADLINE_CRAWL      = Float(ENV.fetch("GRPC_CRAWL_DEADLINE_SECONDS", "600"))

  # Консервативный keepalive: реже PING и без PING на idle-канале.
  # Это снижает риск GOAWAY ENHANCE_YOUR_CALM (too_many_pings) от gRPC-серверов.
  CHANNEL_ARGS = {
    "grpc.keepalive_time_ms" => Integer(ENV.fetch("GRPC_KEEPALIVE_TIME_MS", "300000").delete("_")),
    "grpc.keepalive_timeout_ms" => Integer(ENV.fetch("GRPC_KEEPALIVE_TIMEOUT_MS", "10000").delete("_")),
    "grpc.keepalive_permit_without_calls" => Integer(ENV.fetch("GRPC_KEEPALIVE_PERMIT_WITHOUT_CALLS", "0")),
    # 0 => не ограничивать на клиенте число PING без данных (сервер всё равно может применить свои лимиты).
    "grpc.http2.max_pings_without_data" => Integer(ENV.fetch("GRPC_HTTP2_MAX_PINGS_WITHOUT_DATA", "0"))
  }.freeze
end
