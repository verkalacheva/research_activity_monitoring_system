# Stage 1: build gems (needs compiler + libpq headers)
FROM ruby:3.2.2-slim AS builder

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.4.22 && \
    bundle config set --local without 'development test' && \
    bundle config set --local path vendor/bundle && \
    bundle install --jobs 4 --retry 3

COPY . .

# Stage 2: runtime — only libpq5 (runtime lib), no compiler toolchain
FROM ruby:3.2.2-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libpq5 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app .

ENV BUNDLE_PATH=vendor/bundle

EXPOSE 3000

CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0", "-e", "production"]
