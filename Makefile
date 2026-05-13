.PHONY: build up down ps logs logs-web logs-frontend shell rails-c db-migrate db-setup db-seed db-drop db-reset db-dump db-restore bundle db-create \
        test-backend test-crawler test-integration test-analytics test-all serve-coverage

DC      = COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 DOCKER_HOST=unix:///run/docker.sock DOCKER_CONFIG=$(CURDIR)/.docker/make-build docker-compose
DC_TEST = COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 DOCKER_HOST=unix:///run/docker.sock docker-compose --profile test
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

## ─── Tests & Coverage ────────────────────────────────────────────────────────

# После тестов убираем только контейнеры профиля test. НЕ использовать здесь
# «docker compose down -v»: без списка сервисов compose гасит весь проект и с
# ключом -v удаляет тома pgdata/redis_data — это стирает основную БД и валит приложение.
.PHONY: test-compose-teardown
test-compose-teardown:
	-$(DC_TEST) rm -f -s db-test redis-test test-db-schema 2>/dev/null || true

# Run RSpec in an isolated test environment (own postgres + redis, ephemeral).
# Does NOT require the main stack to be running and does NOT need .env.
# Coverage report: backend/coverage/index.html (HTML) and backend/coverage/coverage.json (JSON).
test-backend:
	@mkdir -p backend/coverage
	$(DC_TEST) build backend-test
	$(DC_TEST) run --rm backend-test
	@$(MAKE) --no-print-directory test-compose-teardown

# Run pytest for crawler_service locally.
# Coverage report: crawler_service/coverage/html/index.html and crawler_service/coverage/coverage.xml.
test-crawler:
	cd crawler_service && \
	  pip install -q -r requirements.txt pytest pytest-cov pytest-asyncio anyio 2>/dev/null; \
	  python3 -m pytest

# Run Go tests for integration_service (общая БД db-test + схема из test-db-schema, см. docker-compose).
# Отчёт: integration_service/coverage/coverage.html. В контейнере: go test ./... ; coverpkg без сгенерированных pb/proto.
# Локально: схема Rails в БД (docker compose --profile test up test-db-schema, или из backend: rails db:schema:load), затем TEST_DATABASE_URL=... go test -p 1 -tags go1.21 ./...
test-integration:
	$(DC_TEST) run --rm integration-test
	@$(MAKE) --no-print-directory test-compose-teardown

# Run Go tests for analytics_service (та же общая тестовая БД, что и у integration_service / backend-test).
# Отчёт: analytics_service/coverage/coverage.html. В Docker: go test -p 1 (общая БД, без параллельных пакетов).
test-analytics:
	$(DC_TEST) run --rm analytics-test
	@$(MAKE) --no-print-directory test-compose-teardown

# Run all test suites sequentially and collect every coverage artifact.
# Summary is written to coverage_summary.txt in the project root.
test-all: test-backend test-crawler test-integration test-analytics
	@echo ""
	@echo "=== Coverage Summary ===" | tee coverage_summary.txt
	@echo "--- backend (Rails/RSpec) ---" | tee -a coverage_summary.txt
	@if [ -f backend/coverage/coverage.json ]; then \
	  python3 -c "\
	import json; \
	d = json.load(open('backend/coverage/coverage.json')); \
	pct = d.get('metrics', {}).get('covered_percent', 'N/A'); \
	print('Line coverage: ' + ('{:.1f}%'.format(pct) if isinstance(pct, float) else str(pct))); \
	" 2>/dev/null | tee -a coverage_summary.txt; \
	else \
	  echo "(no report yet)" | tee -a coverage_summary.txt; \
	fi
	@echo "--- crawler_service ---" | tee -a coverage_summary.txt
	@if [ -f crawler_service/coverage/coverage.xml ]; then \
	  python3 -c "\
	import xml.etree.ElementTree as ET; \
	t = ET.parse('crawler_service/coverage/coverage.xml').getroot(); \
	rate = float(t.get('line-rate', 0)) * 100; \
	print('Line coverage: {:.1f}%'.format(rate)); \
	" 2>/dev/null | tee -a coverage_summary.txt; \
	else \
	  echo "(no report yet)" | tee -a coverage_summary.txt; \
	fi
	@echo "--- integration_service ---" | tee -a coverage_summary.txt
	@if [ -f integration_service/coverage/coverage.txt ]; then \
	  awk '/^total:/{print "Line coverage: " $$NF}' integration_service/coverage/coverage.txt | tee -a coverage_summary.txt; \
	else \
	  echo "(no report yet)" | tee -a coverage_summary.txt; \
	fi
	@echo "--- analytics_service ---" | tee -a coverage_summary.txt
	@if [ -f analytics_service/coverage/coverage.txt ]; then \
	  awk '/^total:/{print "Line coverage: " $$NF}' analytics_service/coverage/coverage.txt | tee -a coverage_summary.txt; \
	else \
	  echo "(no report yet)" | tee -a coverage_summary.txt; \
	fi
	@echo ""
	@echo "Coverage artifacts:"
	@echo "  backend          → backend/coverage/index.html"
	@echo "  backend          → backend/coverage/coverage.json"
	@echo "  crawler_service  → crawler_service/coverage/html/index.html"
	@echo "  crawler_service  → crawler_service/coverage/coverage.xml"
	@echo "  integration_svc  → integration_service/coverage/coverage.html"
	@echo "  analytics_svc    → analytics_service/coverage/coverage.html"
	@echo ""
	@echo "Full summary: coverage_summary.txt"

# Просмотр всех HTML-отчётов покрытия одной вкладкой: http://127.0.0.1:8765/
serve-coverage:
	@python3 "$(CURDIR)/scripts/serve_coverage.py"

## ─────────────────────────────────────────────────────────────────────────────

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
