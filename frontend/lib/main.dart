import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final strings = await AppStrings.load(const Locale('ru'));
  runApp(ResearchActivityApp(strings: strings));
}
