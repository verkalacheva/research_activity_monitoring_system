# syntax=docker/dockerfile:1
# Stage 1: build gems (needs compiler + libpq headers)
FROM ruby:3.2.2-slim AS builder

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      libyaml-dev \
      libffi-dev \
      pkg-config \
      git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN gem install bundler -v 2.4.22 && \
    bundle config set --local without 'development test' && \
    bundle config set --local path vendor/bundle && \
    bundle config set --local cache_path '/bundle_cache'

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/bundle_cache \
    bundle install --jobs 4 --retry 5

COPY . .

# Stage 2: runtime — only libpq5 (runtime lib), no compiler toolchain
FROM ruby:3.2.2-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libpq5 curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    update-ca-certificates

WORKDIR /app

COPY --from=builder /app .

RUN gem install bundler -v 2.4.22 --no-document

ENV BUNDLE_DEPLOYMENT="true"
ENV BUNDLE_PATH="vendor/bundle"
# Дубль настройки сборки — на случай перезаписи .bundle или старого кеша слоёв
ENV BUNDLE_WITHOUT="development:test"
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_ENV=production

EXPOSE 3000
ENV PORT=3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD /bin/sh -c 'curl -fsS "http://$HEALTHCHECK_HOST:$PORT/health/live" || exit 1'

# Avoid "A server is already running" after unclean exits or image builds that carried tmp/pids.
CMD ["sh", "-c", "rm -f tmp/pids/server.pid && exec bundle exec rails s -p 3000 -b 0.0.0.0 -e production"]
