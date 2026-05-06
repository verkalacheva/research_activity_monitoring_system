# Прод: один сервер, Docker Compose + Nginx (TLS)

## Роли

1. **Nginx на хосте** — `443`/`80`, Let’s Encrypt, проксирование на loopback.
2. **Контейнеры** — БД, Redis, сервисы, backend, worker, frontend; снаружи не торчат, кроме портов, проксированных Nginx (обычно только `3000` и `8080` на `127.0.0.1`).

## Порты

Чтобы Nginx на хосте слушал `80`/`443`, не занимайте `80` контейнером фронтенда.

- В `.env` для прод: `FRONTEND_PUBLISH_PORT=8080`, `BACKEND_PUBLISH_PORT=3000` (или другие свободные порты) и **привязка к localhost** в `docker-compose.prod.yml` при необходимости, например:

  ```yaml
  ports:
    - "127.0.0.1:8080:80"
  ```

  (аналогично backend — `127.0.0.1:3000:3000`).

- В [nginx/app-server.conf](nginx/app-server.conf) согласовать `upstream` с этими портами.

## Сборка фронтенда

`API_BASE_URL` задаёт публичный origin **с тем же хостом**, с которого открывается SPA (one origin):

```bash
API_BASE_URL=https://ваш.домен
```

С хвоста `/` лучше не ставить. Тогда `api/v1` и `wss://.../cable` окажутся на одном домене за Nginx.

## TLS (Certbot, nginx plugin)

```bash
sudo certbot --nginx -d ваш.домен
```

Раскомментируйте блоки `ssl_certificate` в копии [nginx/app-server.conf](nginx/app-server.conf) или перенесите `server` в snippet, который правит `certbot`.

Первичная выдача на «голом» 80: можно временно отдать только `location /.well-known/...` и `proxy_pass` на фронт, либо использовать webroot, как в примере (`root /var/www/certbot`).

## Порядок деплоя

1. `docker compose --env-file .env -f docker-compose.prod.yml build`
2. `docker compose --env-file .env -f docker-compose.prod.yml up -d`
3. Миграции:  
   `docker compose --env-file .env -f docker-compose.prod.yml run --rm backend bundle exec rails db:migrate`
4. `sudo nginx -t && sudo systemctl reload nginx`

## Проверка

- `curl -fsS https://ваш.домен/health/ready`
- В браузере: загрузка SPA, запросы к `/api/v1/...` и (при необходимости) WebSocket на `/cable`.

## Заметки

- Rails за reverse proxy: передавайте `X-Forwarded-Proto` (в примере есть); при странностях с URL/cookies см. `config.action_dispatch.trusted_proxies` / документацию Rails к вашей версии.
