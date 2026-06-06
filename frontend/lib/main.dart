import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/auth/auth_notifier.dart';
import 'core/config.dart';
import 'core/l10n/l10n.dart';
import 'data/services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.apiBase.isEmpty) {
    throw StateError(
      'API_BASE_URL is not set. Example: flutter run --dart-define=API_BASE_URL=<your-api-base>',
    );
  }
  final strings = await AppStrings.load(const Locale('ru'));
  final auth = AuthNotifier();
  ApiClient.onUnauthorized = auth.handleSessionExpired;
  await auth.bootstrap();

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: ResearchActivityApp(strings: strings),
    ),
  );
}
