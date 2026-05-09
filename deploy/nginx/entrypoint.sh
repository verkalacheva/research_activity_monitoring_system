#!/bin/sh
set -e
# shellcheck disable=SC2016
# Renders app-server*.conf.template with envsubst; only listed vars are expanded so nginx $host etc. stay intact.
# Usage: ./entrypoint.sh          — write config then exec nginx
#         ./entrypoint.sh render  — write config only (NGINX_CONF_OUT, default /tmp/app-server-rendered.conf)

render_only=0
if [ "${1:-}" = "render" ]; then
  render_only=1
  shift
fi

export NGINX_UPSTREAM_FRONTEND="${NGINX_UPSTREAM_FRONTEND:-127.0.0.1:8080}"
export NGINX_UPSTREAM_BACKEND="${NGINX_UPSTREAM_BACKEND:-127.0.0.1:3000}"
export NGINX_UPSTREAM_KEEPALIVE="${NGINX_UPSTREAM_KEEPALIVE:-8}"
export NGINX_HTTP_PORT="${NGINX_HTTP_PORT:-80}"
export NGINX_HTTPS_PORT="${NGINX_HTTPS_PORT:-443}"
export NGINX_SERVER_NAME="${NGINX_SERVER_NAME:-_}"
export NGINX_ACME_WEBROOT="${NGINX_ACME_WEBROOT:-/var/www/certbot}"
export NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-50m}"
export NGINX_PROXY_READ_TIMEOUT_API="${NGINX_PROXY_READ_TIMEOUT_API:-120s}"
export NGINX_PROXY_READ_TIMEOUT_CABLE="${NGINX_PROXY_READ_TIMEOUT_CABLE:-600s}"
export DOLLAR='$'

tpl_dir="${NGINX_TEMPLATE_DIR:-/etc/nginx/templates}"
if [ "$render_only" = "1" ] && [ -z "${NGINX_CONF_OUT+x}" ]; then
  export NGINX_CONF_OUT="/tmp/app-server-rendered.conf"
fi
out="${NGINX_CONF_OUT:-/etc/nginx/conf.d/default.conf}"

vars='${DOLLAR}${NGINX_UPSTREAM_FRONTEND}${NGINX_UPSTREAM_BACKEND}${NGINX_UPSTREAM_KEEPALIVE}${NGINX_HTTP_PORT}${NGINX_HTTPS_PORT}${NGINX_SERVER_NAME}${NGINX_ACME_WEBROOT}${NGINX_CLIENT_MAX_BODY_SIZE}${NGINX_PROXY_READ_TIMEOUT_API}${NGINX_PROXY_READ_TIMEOUT_CABLE}${NGINX_SSL_CERTIFICATE}${NGINX_SSL_CERTIFICATE_KEY}${NGINX_SSL_OPTIONS_CONF}'

if [ "${NGINX_HTTP_ONLY:-0}" = "1" ]; then
  envsubst "$vars" <"$tpl_dir/app-server-http.conf.template" >"$out"
else
  : "${NGINX_SSL_CERTIFICATE:?NGINX_SSL_CERTIFICATE is required unless NGINX_HTTP_ONLY=1}"
  : "${NGINX_SSL_CERTIFICATE_KEY:?NGINX_SSL_CERTIFICATE_KEY is required unless NGINX_HTTP_ONLY=1}"
  export NGINX_SSL_OPTIONS_CONF="${NGINX_SSL_OPTIONS_CONF:-$tpl_dir/options-ssl-stub.conf}"
  envsubst "$vars" <"$tpl_dir/app-server.conf.template" >"$out"
fi

if [ "$render_only" = "1" ]; then
  echo "Wrote $out"
  exit 0
fi

exec nginx -g 'daemon off;'
