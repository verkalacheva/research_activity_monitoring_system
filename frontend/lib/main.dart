import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/sync_notification_bell.dart';

/// Global navigator key so widgets outside the Navigator tree (e.g. the
/// sync notification bell placed in MaterialApp.builder) can open dialogs.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const ResearchActivityApp());
}

class ResearchActivityApp extends StatelessWidget {
  const ResearchActivityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Мониторинг НИР',
      navigatorKey: appNavigatorKey,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
      ],
      home: const HomeScreen(),
      builder: (context, child) => Stack(
        children: [
          child!,
          const SyncNotificationBell(),
        ],
      ),
    );
  }
}
