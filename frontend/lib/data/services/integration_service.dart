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

  /// POST задачи + ожидание результата по WebSocket (Action Cable).
  /// При обрыве сокета (перезагрузка прокси, sleep ноутбука и т.п.) повторно опрашивается
  /// [GET /integration_sync_jobs/:id], пока задача на Sidekiq не перейдёт в терминальный статус.
  ///
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
        debugPrint('Integration sync: WebSocket lost ($e). Falling back to HTTP polling. $st');
        return await _pollIntegrationSyncJob(
          client: client,
          jobId: jobId,
          deadline: deadline,
          shouldAbort: shouldAbort,
        );
      }
    } finally {
      if (closeClient) client.close();
    }
  }

  /// Ожидание завершения задачи по Redis-снимку (та же модель, что отдаётся по Action Cable).
  Future<List<dynamic>> _pollIntegrationSyncJob({
    required http.Client client,
    required String jobId,
    required DateTime deadline,
    bool Function()? shouldAbort,
  }) async {
    const interval = Duration(seconds: 2);
    while (true) {
      if (shouldAbort?.call() == true) {
        throw SyncPreviewAborted();
      }
      if (!DateTime.now().isBefore(deadline)) {
        throw TimeoutException(
          'integration_sync_job HTTP poll exceeded ${_maxWait.inHours}h deadline',
        );
      }

      http.Response resp;
      try {
        resp = await client.get(Uri.parse('$baseUrl/integration_sync_jobs/$jobId'));
      } catch (e) {
        debugPrint('Integration sync poll GET failed: $e');
        await Future<void>.delayed(interval);
        continue;
      }

      if (resp.statusCode == 404) {
        throw Exception(
          'Задача синхронизации не найдена на сервере (истёк срок хранения или неверный id)',
        );
      }
      if (resp.statusCode != 200) {
        debugPrint('Integration sync poll HTTP ${resp.statusCode}: ${resp.body}');
        await Future<void>.delayed(interval);
        continue;
      }

      final Map<String, dynamic> map;
      try {
        final decoded = json.decode(resp.body);
        if (decoded is! Map<String, dynamic>) {
          await Future<void>.delayed(interval);
          continue;
        }
        map = decoded;
      } catch (_) {
        await Future<void>.delayed(interval);
        continue;
      }

      final status = map['status']?.toString();
      switch (status) {
        case 'complete':
          final results = map['results'];
          return results is List ? List<dynamic>.from(results) : <dynamic>[];
        case 'cancelled':
          return <dynamic>[];
        case 'failed':
          final err = map['error']?.toString() ?? 'Неизвестная ошибка';
          final isRateLimit = map['rate_limit'] == true;
          throw Exception(isRateLimit ? 'rate_limit:$err' : err);
        default:
          await Future<void>.delayed(interval);
          continue;
      }
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
