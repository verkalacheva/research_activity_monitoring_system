import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:research_activity_monitoring_system/core/config.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'integration_sync_job_socket.dart';
import 'sync_preview_exceptions.dart';

export 'sync_preview_exceptions.dart';

class IntegrationService {
  static const String baseUrl = AppConfig.apiV1;
  static const Duration _maxWait = Duration(hours: 2);

  Future<GitHubCheckKeysRegistry> getGithubCheckKeys() async {
    final response = await http.get(Uri.parse('$baseUrl/selectors/github_check_keys'));
    if (response.statusCode == 200) {
      return GitHubCheckKeysRegistry.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load GitHub check keys');
    }
  }

  /// POST задачи + ожидание результата только по WebSocket (Action Cable).
  /// [onJobCreated] — сразу после постановки задачи (до ожидания по сокету), для отмены через DELETE.
  Future<List<dynamic>> syncPreview({
    String provider = 'orcid',
    String? url,
    int? researcherId,
    int? teamId,
    String? scope,
    http.Client? httpClient,
    bool Function()? shouldAbort,
    void Function(String jobId)? onJobCreated,
  }) async {
    final client = httpClient ?? http.Client();
    final closeClient = httpClient == null;
    final deadline = DateTime.now().add(_maxWait);

    try {
      final bodyMap = <String, dynamic>{
        'provider': provider,
        if (url != null && url.isNotEmpty) 'url': url,
        if (researcherId != null) 'researcher_id': researcherId,
        if (teamId != null) 'team_id': teamId,
        if (scope != null && scope.isNotEmpty) 'scope': scope,
      };

      final createResp = await client.post(
        Uri.parse('$baseUrl/integration_sync_jobs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
      );

      if (createResp.statusCode != 202 && createResp.statusCode != 200 && createResp.statusCode != 201) {
        String errorMsg = 'Ошибка постановки задачи (${createResp.statusCode})';
        var isRateLimit = false;
        try {
          final body = json.decode(createResp.body) as Map<String, dynamic>?;
          if (body?['error'] != null) errorMsg = body!['error'].toString();
          isRateLimit = body?['rate_limit'] == true;
        } catch (_) {}
        if (isRateLimit) throw Exception('rate_limit:$errorMsg');
        throw Exception(errorMsg);
      }

      final createJson = json.decode(createResp.body) as Map<String, dynamic>;
      final jobId = createJson['job_id'] as String?;
      if (jobId == null || jobId.isEmpty) {
        throw Exception('Сервер не вернул job_id');
      }

      onJobCreated?.call(jobId);

      final remaining = deadline.difference(DateTime.now());
      final timeout = remaining.isNegative ? Duration.zero : remaining;

      try {
        return await IntegrationSyncJobSocket.waitForCompletion(
          wsUrl: '${AppConfig.wsBase}/cable',
          jobId: jobId,
          timeout: timeout,
          shouldAbort: shouldAbort,
        );
      } on SyncPreviewAborted {
        rethrow;
      } catch (e, st) {
        debugPrint('Integration sync: WebSocket ($e). $st');
        rethrow;
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
