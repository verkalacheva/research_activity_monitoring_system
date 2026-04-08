import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../config.dart';

class ResearcherDevActivityService {
  static const String baseUrl = AppConfig.apiV1;

  Future<ResearcherDevActivity> update(
    int researcherId,
    int activityId, {
    required int count,
    String? date,
  }) async {
    final body = <String, dynamic>{'count': count};
    if (date != null) body['date'] = date;

    final response = await http.put(
      Uri.parse('$baseUrl/researchers/$researcherId/dev_activities/$activityId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'dev_activity': body}),
    );
    if (response.statusCode == 200) {
      return ResearcherDevActivity.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update activity: ${response.body}');
    }
  }

  Future<void> delete(int researcherId, int activityId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/researchers/$researcherId/dev_activities/$activityId'),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete activity: ${response.body}');
    }
  }
}
