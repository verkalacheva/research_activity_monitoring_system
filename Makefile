.PHONY: build up down ps logs logs-web logs-frontend shell rails-c db-migrate db-setup db-seed db-drop db-reset db-dump db-restore bundle db-create

export DOCKER_CONFIG := $(CURDIR)/.docker/make-build

DC = COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 DOCKER_HOST=unix:///run/docker.sock docker-compose
ENV_FILE := $(shell if [ -f .env ]; then echo .env; fi)
PG_DB = research_activity_monitoring_system_production

build:
ifeq ($(strip $(ENV_FILE)),)
	@echo >&2 "Missing .env. Create: cp .env.example .env and set variables."
	@exit 1
endif
	$(DC) --env-file $(ENV_FILE) build

up:
ifeq ($(strip $(ENV_FILE)),)
	@echo >&2 "Missing .env. Create: cp .env.example .env"
	@exit 1
endif
	$(DC) --env-file $(ENV_FILE) up -d
	@$(MAKE) --no-print-directory db-create

down:
ifeq ($(strip $(ENV_FILE)),)
	$(DC) down
else
	$(DC) --env-file $(ENV_FILE) down
endif

ps:
ifeq ($(strip $(ENV_FILE)),)
	@echo >&2 "Missing .env."
	@exit 1
endif
	$(DC) --env-file $(ENV_FILE) ps

logs:
ifeq ($(strip $(ENV_FILE)),)
	@echo >&2 "Missing .env."
	@exit 1
endif
	$(DC) --env-file $(ENV_FILE) logs -f

logs-web:
	$(DC) --env-file $(ENV_FILE) logs -f backend

logs-frontend:
	$(DC) --env-file $(ENV_FILE) logs -f frontend

shell:
	$(DC) --env-file $(ENV_FILE) exec backend bash

rails-c:
	$(DC) --env-file $(ENV_FILE) exec backend bundle exec rails c

db-migrate:
	$(DC) --env-file $(ENV_FILE) exec backend bundle exec rails db:migrate

db-setup:
	$(DC) --env-file $(ENV_FILE) exec backend bundle exec rails db:create db:migrate db:seed

db-seed:
	$(DC) --env-file $(ENV_FILE) exec backend bundle exec rails db:seed

db-drop:
	$(DC) --env-file $(ENV_FILE) exec backend bundle exec rails db:drop

db-reset:
	$(DC) --env-file $(ENV_FILE) exec backend bundle exec rails db:drop db:create db:migrate db:seed

db-dump:
	$(DC) --env-file $(ENV_FILE) exec -T db pg_dump -U postgres $(PG_DB) > dump.sql

db-restore:
	$(DC) --env-file $(ENV_FILE) exec -T db dropdb -U postgres --if-exists $(PG_DB)
	$(DC) --env-file $(ENV_FILE) exec -T db createdb -U postgres $(PG_DB)
	cat dump.sql | $(DC) --env-file $(ENV_FILE) exec -T db psql -U postgres $(PG_DB)

bundle:
	$(DC) --env-file $(ENV_FILE) run --rm backend bundle install

db-create:
ifeq ($(strip $(ENV_FILE)),)
	@echo >&2 "Missing .env."
	@exit 1
endif
	@echo "Waiting for PostgreSQL to accept connections..."
	@attempts=0; max=60; \
	until $(DC) --env-file $(ENV_FILE) exec db pg_isready -U postgres; do \
	  attempts=$$((attempts + 1)); \
	  test $$attempts -ge $$max && echo >&2 "Postgres did not become ready in time." && exit 1; \
	  sleep 2; \
	done
	@if $(DC) --env-file $(ENV_FILE) exec db psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$(PG_DB)'" | grep -qx 1; then \
		echo "Database $(PG_DB) already exists."; \
	else \
		echo "Creating database $(PG_DB)..."; \
		$(DC) --env-file $(ENV_FILE) exec db psql -U postgres -c "CREATE DATABASE $(PG_DB);"; \
		echo "Run: make db-migrate && make db-seed"; \
	fi
