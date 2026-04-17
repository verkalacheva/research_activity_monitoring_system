/// Runtime-configurable base URLs.
///
/// Pass values at build/run time via --dart-define:
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
///   flutter build web --dart-define=API_BASE_URL=https://api.example.com
class AppConfig {
  AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String apiV1 = '$apiBase/api/v1';

  static const String reportsV1 = '$apiBase/api/v1/reports';

  /// WebSocket endpoint derived from apiBase (http→ws, https→wss).
  static String get wsBase {
    return apiBase
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }
}
