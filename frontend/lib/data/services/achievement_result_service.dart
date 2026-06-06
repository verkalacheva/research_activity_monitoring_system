import 'dart:convert';
import 'package:research_activity_monitoring_system/data/services/api_client.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/core/config.dart';

class AchievementResultService {
  static const String baseUrl = AppConfig.apiV1;

  Future<List<AchievementResult>> getAll() async {
    final response = await ApiClient.get(Uri.parse('$baseUrl/achievement_results/list?limit=100'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      List itemsJson = jsonResponse['items'];
      return itemsJson.map((data) => AchievementResult.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load achievement results');
    }
  }

  Future<PaginatedResponse<AchievementResult>> list({int limit = 20, int offset = 0}) async {
    final response = await ApiClient.get(Uri.parse('$baseUrl/achievement_results/list?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final List itemsJson = jsonResponse['items'];
      final items = itemsJson.map((data) => AchievementResult.fromJson(data)).toList();
      final pagination = PaginationMetadata.fromJson(jsonResponse['pagination']);
      return PaginatedResponse(items: items, pagination: pagination);
    } else {
      throw Exception('Failed to load achievement results list');
    }
  }

  Future<AchievementResult> create(AchievementResult result) async {
    final response = await ApiClient.post(
      Uri.parse('$baseUrl/achievement_results'),
      body: json.encode({'achievement_result': result.toJson()}),
    );
    if (response.statusCode == 201) {
      return AchievementResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create achievement result');
    }
  }

  Future<AchievementResult> update(int id, AchievementResult result) async {
    final response = await ApiClient.put(
      Uri.parse('$baseUrl/achievement_results/$id'),
      body: json.encode({'achievement_result': result.toJson()}),
    );
    if (response.statusCode == 200) {
      return AchievementResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update achievement result');
    }
  }

  Future<void> delete(int id) async {
    final response = await ApiClient.delete(Uri.parse('$baseUrl/achievement_results/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete achievement result');
    }
  }
}

