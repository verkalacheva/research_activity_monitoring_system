import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../config.dart';

class AchievementStatusService {
  static const String baseUrl = AppConfig.apiV1;

  Future<List<AchievementStatus>> getAll() async {
    final response = await http.get(Uri.parse('$baseUrl/achievement_statuses/list?limit=100'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      List itemsJson = jsonResponse['items'];
      return itemsJson.map((data) => AchievementStatus.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load achievement statuses');
    }
  }

  Future<PaginatedResponse<AchievementStatus>> list({int limit = 20, int offset = 0}) async {
    final response = await http.get(Uri.parse('$baseUrl/achievement_statuses/list?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final List itemsJson = jsonResponse['items'];
      final items = itemsJson.map((data) => AchievementStatus.fromJson(data)).toList();
      final pagination = PaginationMetadata.fromJson(jsonResponse['pagination']);
      return PaginatedResponse(items: items, pagination: pagination);
    } else {
      throw Exception('Failed to load achievement statuses list');
    }
  }

  Future<AchievementStatus> create(AchievementStatus status) async {
    final response = await http.post(
      Uri.parse('$baseUrl/achievement_statuses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement_status': status.toJson()}),
    );
    if (response.statusCode == 201) {
      return AchievementStatus.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create achievement status');
    }
  }

  Future<AchievementStatus> update(int id, AchievementStatus status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/achievement_statuses/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement_status': status.toJson()}),
    );
    if (response.statusCode == 200) {
      return AchievementStatus.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update achievement status');
    }
  }

  Future<void> delete(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/achievement_statuses/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete achievement status');
    }
  }
}

