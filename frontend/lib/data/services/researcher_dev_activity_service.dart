import 'dart:convert';
import 'package:research_activity_monitoring_system/data/services/api_client.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/core/config.dart';

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

    final response = await ApiClient.put(
      Uri.parse('$baseUrl/researchers/$researcherId/dev_activities/$activityId'),
      body: json.encode({'dev_activity': body}),
    );
    if (response.statusCode == 200) {
      return ResearcherDevActivity.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update activity: ${response.body}');
    }
  }

  Future<void> delete(int researcherId, int activityId) async {
    final response = await ApiClient.delete(
      Uri.parse('$baseUrl/researchers/$researcherId/dev_activities/$activityId'),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete activity: ${response.body}');
    }
  }
}
