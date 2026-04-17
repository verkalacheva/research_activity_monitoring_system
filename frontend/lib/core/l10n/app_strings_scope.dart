import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Provides [AppStrings] to the widget tree (loaded from YAML).
class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    assert(scope != null, 'AppStringsScope not found');
    return scope!.strings;
  }

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) => oldWidget.strings != strings;
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStringsScope.of(this);
}
