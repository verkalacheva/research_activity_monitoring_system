import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:research_activity_monitoring_system/core/config.dart';

class AppSettings {
  final String? githubToken;
  final String? openrouterApiKey;
  final String? llmModelName;
  final String? llmProvider;

  const AppSettings({
    this.githubToken,
    this.openrouterApiKey,
    this.llmModelName,
    this.llmProvider,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      githubToken: json['github_token'] as String?,
      openrouterApiKey: json['openrouter_api_key'] as String?,
      llmModelName: json['llm_model_name'] as String?,
      llmProvider: json['llm_provider'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'github_token': githubToken,
      'openrouter_api_key': openrouterApiKey,
      'llm_model_name': llmModelName,
      'llm_provider': llmProvider,
    };
  }
}

class SettingsService {
  static const String baseUrl = AppConfig.apiV1;

  Future<AppSettings> getSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/settings'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (json['settings'] as Map<String, dynamic>?) ?? {};
      return AppSettings.fromJson(data);
    } else {
      throw Exception('Ошибка загрузки настроек: ${response.statusCode}');
    }
  }

  Future<AppSettings> updateSettings(Map<String, String?> settings) async {
    final response = await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'settings': settings}),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (json['settings'] as Map<String, dynamic>?) ?? {};
      return AppSettings.fromJson(data);
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Ошибка сохранения настроек');
    }
  }
}
