# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

WORKDIR /app

RUN flutter config --enable-web

COPY pubspec.yaml ./
RUN flutter pub get

COPY . .

ARG API_BASE_URL=http://localhost:3000
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
