import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AchievementTypeService {
  static const String baseUrl = 'http://localhost:3000/api/v1';

  Future<List<AchievementType>> getAll() async {
    final response = await http.get(Uri.parse('$baseUrl/achievement_types/list?limit=100'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      List itemsJson = jsonResponse['items'];
      return itemsJson.map((data) => AchievementType.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load achievement types');
    }
  }

  Future<PaginatedResponse<AchievementType>> list({int limit = 20, int offset = 0}) async {
    final response = await http.get(Uri.parse('$baseUrl/achievement_types/list?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final List itemsJson = jsonResponse['items'];
      final items = itemsJson.map((data) => AchievementType.fromJson(data)).toList();
      final pagination = PaginationMetadata.fromJson(jsonResponse['pagination']);
      return PaginatedResponse(items: items, pagination: pagination);
    } else {
      throw Exception('Failed to load achievement types list');
    }
  }

  Future<AchievementType> create(AchievementType type) async {
    final response = await http.post(
      Uri.parse('$baseUrl/achievement_types'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement_type': type.toJson()}),
    );
    if (response.statusCode == 201) {
      return AchievementType.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create achievement type');
    }
  }

  Future<AchievementType> update(int id, AchievementType type) async {
    final response = await http.put(
      Uri.parse('$baseUrl/achievement_types/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'achievement_type': type.toJson()}),
    );
    if (response.statusCode == 200) {
      return AchievementType.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update achievement type');
    }
  }

  Future<void> delete(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/achievement_types/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete achievement type');
    }
  }
}

