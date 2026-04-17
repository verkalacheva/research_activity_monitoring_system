import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// Loads UI strings from `assets/l10n/<languageCode>.yaml`.
class AppStrings {
  AppStrings._(this._root);

  final Map<String, dynamic> _root;

  /// Loads YAML for [locale]. Tries [languageCode], then falls back to `ru`.
  static Future<AppStrings> load(Locale locale) async {
    final candidates = <String>{locale.languageCode, 'ru'};
    for (final lang in candidates) {
      try {
        final raw = await rootBundle.loadString('assets/l10n/$lang.yaml');
        final doc = loadYaml(raw);
        final map = _toPlain(doc);
        if (map is Map<String, dynamic>) {
          return AppStrings._(map);
        }
      } catch (_) {
        continue;
      }
    }
    throw StateError('No l10n YAML found for locale $locale');
  }

  /// For tests: in-memory strings.
  factory AppStrings.test(Map<String, dynamic> root) => AppStrings._(root);

  static dynamic _toPlain(dynamic y) {
    if (y is YamlMap) {
      final m = <String, dynamic>{};
      y.forEach((k, v) {
        m[k.toString()] = _toPlain(v);
      });
      return m;
    }
    if (y is YamlList) {
      return y.map(_toPlain).toList();
    }
    return y;
  }

  /// Resolves a nested path like `home.nav.reports`.
  String tr(String path, [Map<String, String>? args]) {
    final segments = path.split('.').where((s) => s.isNotEmpty).toList();
    dynamic node = _root;
    for (final s in segments) {
      if (node is! Map) return path;
      node = node[s];
      if (node == null) return path;
    }
    String out = node.toString();
    if (args != null) {
      args.forEach((k, v) => out = out.replaceAll('{$k}', v));
    }
    return out;
  }

  String get appTitle => tr('app.title');

  String get reportDefaultTitle => tr('report.default_title');

  Map<String, String> _stringMapAt(String path) {
    final segments = path.split('.');
    dynamic node = _root;
    for (final s in segments) {
      if (node is! Map) return {};
      node = node[s];
    }
    if (node is! Map) return {};
    return node.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Map<String, Map<String, String>> _nestedStringMapAt(String path) {
    final segments = path.split('.');
    dynamic node = _root;
    for (final s in segments) {
      if (node is! Map) return {};
      node = node[s];
    }
    if (node is! Map) return {};
    final out = <String, Map<String, String>>{};
    node.forEach((k, v) {
      if (v is Map) {
        out[k.toString()] = v.map((k2, v2) => MapEntry(k2.toString(), v2.toString()));
      }
    });
    return out;
  }

  Map<String, String> get reportTitles => _stringMapAt('report.titles');

  Map<String, Map<String, String>> get reportFilterMetadata => _nestedStringMapAt('report.filter_metadata');

  Map<String, String> get reportSortTitles => _stringMapAt('report.sort_titles');
}
