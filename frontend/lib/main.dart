import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config.dart';
import 'core/l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.apiBase.isEmpty) {
    throw StateError(
      'API_BASE_URL is not set. Example: flutter run --dart-define=API_BASE_URL=<your-api-base>',
    );
  }
  final strings = await AppStrings.load(const Locale('ru'));
  runApp(ResearchActivityApp(strings: strings));
}
