import 'dart:convert';

import 'package:research_activity_monitoring_system/core/config.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/api_client.dart';

class TeamService {
  static const String baseUrl = AppConfig.apiV1;

  Future<List<Team>> getAll() async {
    final response = await ApiClient.get(Uri.parse('$baseUrl/teams/list?limit=1000'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      List itemsJson = jsonResponse['items'];
      return itemsJson.map((data) => Team.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load projects');
    }
  }

  Future<PaginatedResponse<Team>> list({int limit = 20, int offset = 0}) async {
    final response = await ApiClient.get(Uri.parse('$baseUrl/teams/list?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final List itemsJson = jsonResponse['items'];
      final items = itemsJson.map((data) => Team.fromJson(data)).toList();
      final pagination = PaginationMetadata.fromJson(jsonResponse['pagination']);
      return PaginatedResponse(items: items, pagination: pagination);
    } else {
      throw Exception('Failed to load projects list');
    }
  }

  Future<Team> getById(int id) async {
    final response = await ApiClient.get(Uri.parse('$baseUrl/teams/$id'));
    if (response.statusCode == 200) {
      return Team.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load project');
    }
  }

  Future<Team> create(Team team) async {
    final response = await ApiClient.post(
      Uri.parse('$baseUrl/teams'),
      body: json.encode({'team': team.toJson()}),
    );
    if (response.statusCode == 201) {
      return Team.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create project');
    }
  }

  Future<Team> update(int id, Team team) async {
    final response = await ApiClient.put(
      Uri.parse('$baseUrl/teams/$id'),
      body: json.encode({'team': team.toJson()}),
    );
    if (response.statusCode == 200) {
      return Team.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update project');
    }
  }

  Future<Team> updateCriteria(int id, List<int> criterionIds) async {
    final response = await ApiClient.put(
      Uri.parse('$baseUrl/teams/$id/update_criteria'),
      body: json.encode({'criterion_ids': criterionIds}),
    );
    if (response.statusCode == 200) {
      return Team.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update project criteria');
    }
  }

  Future<void> delete(int id) async {
    final response = await ApiClient.delete(Uri.parse('$baseUrl/teams/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete project');
    }
  }
}
