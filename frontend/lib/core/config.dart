/// Runtime-configurable base URLs (сборка: --dart-define=API_BASE_URL=...; в Docker — build-arg).
class AppConfig {
  AppConfig._();

  /// Задаётся только через --dart-define=API_BASE_URL=... (CI/Docker build-arg).
  static const String apiBase = String.fromEnvironment('API_BASE_URL');

  static const String apiV1 = '$apiBase/api/v1';

  static const String reportsV1 = '$apiBase/api/v1/reports';

  /// WebSocket endpoint derived from apiBase (http→ws, https→wss).
  static String get wsBase {
    return apiBase
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }
}
