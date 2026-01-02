import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
