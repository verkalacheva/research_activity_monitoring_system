# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

WORKDIR /app

# Enable web support
RUN flutter config --enable-web

# Copy only pubspec.yaml first to leverage caching for pub get
COPY pubspec.yaml ./
RUN flutter pub get

COPY . .
RUN flutter create . --platforms web
RUN flutter build web --release

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

