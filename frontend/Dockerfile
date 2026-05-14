# syntax=docker/dockerfile:1
# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

WORKDIR /app

RUN flutter config --enable-web

COPY pubspec.yaml ./
RUN --mount=type=cache,target=/root/.pub-cache \
    flutter pub get

COPY . .

ARG API_BASE_URL
RUN test -n "$API_BASE_URL" || (echo "build-arg API_BASE_URL is required" && exit 1)

RUN flutter pub get && flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# Stage 2: Serve
FROM nginx:alpine
RUN apk add --no-cache curl

RUN rm -rf /etc/nginx/templates
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
ENV FRONTEND_INTERNAL_HTTP_PORT=80
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD /bin/sh -c 'curl -fsS "http://$HEALTHCHECK_HOST:$FRONTEND_INTERNAL_HTTP_PORT/" || exit 1'
CMD ["nginx", "-g", "daemon off;"]
