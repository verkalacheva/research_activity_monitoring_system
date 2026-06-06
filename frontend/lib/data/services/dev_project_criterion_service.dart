import 'dart:convert';
import 'package:research_activity_monitoring_system/data/services/api_client.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/core/config.dart';

class DevProjectCriterionService {
  static const String baseUrl = AppConfig.apiV1;

  Future<PaginatedResponse<DevProjectCriterion>> list({int limit = 100, int offset = 0}) async {
    final response = await ApiClient.get(Uri.parse('$baseUrl/dev_project_criteria/list?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final List itemsJson = jsonResponse['items'];
      final items = itemsJson.map((data) => DevProjectCriterion.fromJson(data)).toList();
      final pagination = PaginationMetadata.fromJson(jsonResponse['pagination']);
      return PaginatedResponse(items: items, pagination: pagination);
    } else {
      throw Exception('Failed to load dev project criteria list');
    }
  }

  Future<DevProjectCriterion> create(DevProjectCriterion criterion) async {
    final response = await ApiClient.post(
      Uri.parse('$baseUrl/dev_project_criteria'),
      body: json.encode({'dev_project_criterion': criterion.toJson()}),
    );
    if (response.statusCode == 201) {
      return DevProjectCriterion.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create dev project criterion');
    }
  }

  Future<DevProjectCriterion> update(int id, DevProjectCriterion criterion) async {
    final response = await ApiClient.put(
      Uri.parse('$baseUrl/dev_project_criteria/$id'),
      body: json.encode({'dev_project_criterion': criterion.toJson()}),
    );
    if (response.statusCode == 200) {
      return DevProjectCriterion.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update dev project criterion');
    }
  }

  Future<void> delete(int id) async {
    final response = await ApiClient.delete(Uri.parse('$baseUrl/dev_project_criteria/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete dev project criterion');
    }
  }
}
