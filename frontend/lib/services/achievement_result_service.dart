import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AchievementResultService {
  static const String baseUrl = 'http://localhost:3000/api/v1';

  Future<List<AchievementResult>> getAll() async {
    final response = await http.get(Uri.parse('$baseUrl/achievement_results/list?limit=100'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      List itemsJson = jsonResponse['items'];
      return itemsJson.map((data) => AchievementResult.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load achievement results');
    }
  }

  Future<PaginatedResponse<AchievementResult>> list({int limit = 20, int offset = 0}) async {
    final response = await http.get(Uri.parse('$baseUrl/achievement_results/list?limit=$limit&offset=$offset'));
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
    final response = await http.post(
      Uri.parse('$baseUrl/achievement_results'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement_result': result.toJson()}),
    );
    if (response.statusCode == 201) {
      return AchievementResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create achievement result');
    }
  }

  Future<AchievementResult> update(int id, AchievementResult result) async {
    final response = await http.put(
      Uri.parse('$baseUrl/achievement_results/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement_result': result.toJson()}),
    );
    if (response.statusCode == 200) {
      return AchievementResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update achievement result');
    }
  }

  Future<void> delete(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/achievement_results/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete achievement result');
    }
  }
}

