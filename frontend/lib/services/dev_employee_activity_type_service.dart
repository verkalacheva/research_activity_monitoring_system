import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../config.dart';

class DevEmployeeActivityTypeService {
  static const String baseUrl = AppConfig.apiV1;

  Future<PaginatedResponse<DevEmployeeActivityType>> list({int limit = 100, int offset = 0}) async {
    final response = await http.get(Uri.parse('$baseUrl/dev_employee_activity_types/list?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final List itemsJson = jsonResponse['items'];
      final items = itemsJson.map((data) => DevEmployeeActivityType.fromJson(data)).toList();
      final pagination = PaginationMetadata.fromJson(jsonResponse['pagination']);
      return PaginatedResponse(items: items, pagination: pagination);
    } else {
      throw Exception('Failed to load dev activity types list');
    }
  }

  Future<DevEmployeeActivityType> create(DevEmployeeActivityType type) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dev_employee_activity_types'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'dev_employee_activity_type': type.toJson()}),
    );
    if (response.statusCode == 201) {
      return DevEmployeeActivityType.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create dev activity type');
    }
  }

  Future<DevEmployeeActivityType> update(int id, DevEmployeeActivityType type) async {
    final response = await http.put(
      Uri.parse('$baseUrl/dev_employee_activity_types/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'dev_employee_activity_type': type.toJson()}),
    );
    if (response.statusCode == 200) {
      return DevEmployeeActivityType.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update dev activity type');
    }
  }

  Future<void> delete(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/dev_employee_activity_types/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete dev activity type');
    }
  }
}
