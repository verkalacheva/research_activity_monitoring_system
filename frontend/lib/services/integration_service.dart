import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../config.dart';

class IntegrationService {
  static const String baseUrl = AppConfig.apiV1;

  Future<GitHubCheckKeysRegistry> getGithubCheckKeys() async {
    final response = await http.get(Uri.parse('$baseUrl/selectors/github_check_keys'));
    if (response.statusCode == 200) {
      return GitHubCheckKeysRegistry.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load GitHub check keys');
    }
  }

  Future<List<dynamic>> syncPreview({
    String provider = 'orcid',
    String? url,
    int? researcherId,
    int? teamId,
    String? scope,
    http.Client? httpClient,
  }) async {
    var queryParams = 'provider=$provider';
    if (url != null) queryParams += '&url=${Uri.encodeComponent(url)}';
    if (researcherId != null) queryParams += '&researcher_id=$researcherId';
    if (teamId != null) queryParams += '&team_id=$teamId';
    if (scope != null) queryParams += '&scope=$scope';

    final uri = Uri.parse('$baseUrl/integrations/sync_preview?$queryParams');
    final client = httpClient ?? http.Client();
    final closeClient = httpClient == null;
    try {
      final response = await client.get(uri);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['results'];
      } else {
        String errorMsg = 'Ошибка синхронизации (${response.statusCode})';
        bool isRateLimit = false;
        try {
          final body = json.decode(response.body);
          if (body['error'] != null) errorMsg = body['error'].toString();
          isRateLimit = body['rate_limit'] == true;
        } catch (_) {}
        if (isRateLimit) throw Exception('rate_limit:$errorMsg');
        throw Exception(errorMsg);
      }
    } finally {
      if (closeClient) client.close();
    }
  }

  Future<Map<String, dynamic>> saveAchievements(
    List<dynamic> achievements, {
    List<dynamic> researcherDevData = const [],
    List<dynamic> teamDevData = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/integrations/save_achievements'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'achievements': achievements,
        'researcher_dev_data': researcherDevData,
        'team_dev_data': teamDevData,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to save achievements');
    }
  }
}

