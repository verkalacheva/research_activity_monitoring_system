import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_gate.dart';
import '../core/auth/auth_notifier.dart';
import '../core/l10n/l10n.dart';
import '../core/theme/theme.dart';
import '../presentation/widgets/sync_notification_bell.dart';

/// Global navigator key so widgets outside the Navigator tree (e.g. the
/// sync notification bell placed in MaterialApp.builder) can open dialogs.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class ResearchActivityApp extends StatelessWidget {
  const ResearchActivityApp({super.key, required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return AppStringsScope(
      strings: strings,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: strings.appTitle,
        navigatorKey: appNavigatorKey,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ru', 'RU'),
        ],
        locale: const Locale('ru', 'RU'),
        home: const AuthGate(),
        builder: (context, child) {
          final auth = context.watch<AuthNotifier>();
          return Stack(
            children: [
              child!,
              if (auth.isAuthenticated) const SyncNotificationBell(),
            ],
          );
        },
      ),
    );
  }
}
