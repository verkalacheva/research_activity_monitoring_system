import 'dart:convert';
import 'package:research_activity_monitoring_system/data/services/api_client.dart';
import 'package:research_activity_monitoring_system/core/config.dart';

class AppSettings {
  final String? githubToken;
  final String? llmApiKey;
  final String? llmModelName;
  final String? llmProvider;
  final String? llmApiBase;

  const AppSettings({
    this.githubToken,
    this.llmApiKey,
    this.llmModelName,
    this.llmProvider,
    this.llmApiBase,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final llm = json['llm_api_key'] as String?;
    final legacy = json['openrouter_api_key'] as String?;
    return AppSettings(
      githubToken: json['github_token'] as String?,
      llmApiKey: (llm != null && llm.isNotEmpty) ? llm : legacy,
      llmModelName: json['llm_model_name'] as String?,
      llmProvider: json['llm_provider'] as String?,
      llmApiBase: json['llm_api_base'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'github_token': githubToken,
      'llm_api_key': llmApiKey,
      'llm_model_name': llmModelName,
      'llm_provider': llmProvider,
      'llm_api_base': llmApiBase,
    };
  }
}

class SettingsService {
  static const String baseUrl = AppConfig.apiV1;

  Future<AppSettings> getSettings() async {
    final response = await ApiClient.get(Uri.parse('$baseUrl/settings'));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (json['settings'] as Map<String, dynamic>?) ?? {};
      return AppSettings.fromJson(data);
    } else {
      throw Exception('Ошибка загрузки настроек: ${response.statusCode}');
    }
  }

  Future<AppSettings> updateSettings(Map<String, String?> settings) async {
    final response = await ApiClient.put(
      Uri.parse('$baseUrl/settings'),
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
