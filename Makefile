.PHONY: build up down ps logs shell rails-c db-migrate db-setup db-dump db-restore bundle

DC = COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 DOCKER_HOST=unix:///run/docker.sock docker-compose
DB_NAME = research_activity_monitoring_system_development

build:
	$(DC) build

up:
	$(DC) up -d --remove-orphans

down:
	$(DC) down --remove-orphans

ps:
	$(DC) ps

logs:
	$(DC) logs -f

logs-web:
	$(DC) logs -f backend

logs-frontend:
	$(DC) logs -f frontend

shell:
	$(DC) exec backend bash

rails-c:
	$(DC) exec backend bundle exec rails c

db-migrate:
	$(DC) exec backend bundle exec rails db:migrate

db-setup:
	$(DC) exec backend bundle exec rails db:create db:migrate db:seed

db-seed:
	$(DC) exec backend bundle exec rails db:seed

db-drop:
	$(DC) exec backend bundle exec rails db:drop

db-reset:
	$(DC) exec backend bundle exec rails db:drop db:create db:migrate db:seed

db-dump:
	$(DC) exec -T db pg_dump -U postgres $(DB_NAME) > dump.sql

db-restore:
	$(DC) exec -T db dropdb -U postgres --if-exists $(DB_NAME)
	$(DC) exec -T db createdb -U postgres $(DB_NAME)
	cat dump.sql | $(DC) exec -T db psql -U postgres $(DB_NAME)

bundle:
	$(DC) run --rm backend bundle install
