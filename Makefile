.PHONY: build up down ps logs shell rails-c db-migrate db-setup

DC = DOCKER_HOST=unix:///run/docker.sock docker-compose

build:
	$(DC) build

up:
	$(DC) up -d

down:
	$(DC) down

ps:
	$(DC) ps

logs:
	$(DC) logs -f

logs-web:
	$(DC) logs -f web

logs-frontend:
	$(DC) logs -f frontend

shell:
	$(DC) exec web bash

rails-c:
	$(DC) exec web bundle exec rails c

db-migrate:
	$(DC) exec web bundle exec rails db:migrate

db-setup:
	$(DC) exec web bundle exec rails db:create db:migrate db:seed

