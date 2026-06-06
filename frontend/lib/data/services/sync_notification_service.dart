import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:research_activity_monitoring_system/data/services/api_client.dart';
import 'package:research_activity_monitoring_system/data/services/token_storage.dart';
import 'package:research_activity_monitoring_system/core/config.dart';
import 'integration_service.dart' show IntegrationService;
import 'sync_preview_exceptions.dart';

class SyncRequest {
  final String provider;
  final int? researcherId;
  final int? teamId;
  final String? url;
  final String? scope;
  final String label;
  final VoidCallback? onSaved;

  /// Три последовательных этапа с экрана «Сотрудники» (ORCID/all, github, crawlall).
  final bool employeesListBulkStages;

  List<dynamic>? results;
  bool isCompleted = false;
  bool hasError = false;
  String? errorMessage;

  SyncRequest({
    required this.provider,
    required this.label,
    this.researcherId,
    this.teamId,
    this.url,
    this.scope,
    this.onSaved,
    this.employeesListBulkStages = false,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'label': label,
        'researcher_id': researcherId,
        'team_id': teamId,
        'url': url,
        'scope': scope,
        'results': results,
        'has_error': hasError,
        'error_message': errorMessage,
        'employees_list_bulk_stages': employeesListBulkStages,
      };

  /// Restores a completed request from Redis. The [onSaved] callback is not
  /// persisted — callers may rely on a manual page refresh after saving.
  factory SyncRequest.fromJson(Map<String, dynamic> json) {
    final req = SyncRequest(
      provider: json['provider'] as String? ?? 'background',
      label: json['label'] as String? ?? '',
      researcherId: json['researcher_id'] as int?,
      teamId: json['team_id'] as int?,
      url: json['url'] as String?,
      scope: json['scope'] as String?,
      employeesListBulkStages: json['employees_list_bulk_stages'] == true,
    );
    req.results = json['results'] as List<dynamic>?;
    req.isCompleted = true;
    req.hasError = json['has_error'] as bool? ?? false;
    req.errorMessage = json['error_message'] as String?;
    return req;
  }
}

class SyncNotificationService extends ChangeNotifier {
  static final SyncNotificationService instance = SyncNotificationService._();

  SyncNotificationService._() {
    _syncUiValueNotifiers();
  }

  bool _redisLoaded = false;

  /// Loads persisted sync results after the user is authenticated.
  Future<void> ensureStarted() async {
    if (_redisLoaded) return;
    final token = await TokenStorage.accessToken();
    if (token == null || token.isEmpty) return;
    final ok = await _loadFromRedis();
    if (ok) _redisLoaded = true;
  }

  void resetForLogout() {
    _redisLoaded = false;
  }

  final IntegrationService _service = IntegrationService();
  final List<SyncRequest> _requests = [];
  bool _isRunning = false;
  bool _cancelRequested = false;
  /// Completes when [cancelSync] is called — wakes [Future.any] waiting on the current request.
  Completer<void>? _cancelCompleter;
  /// Текущая фоновая задача на бэкенде (для DELETE /integration_sync_jobs/:id при «Стоп»).
  String? _activeSyncJobId;

  /// Дубликаты состояния для надёжных перерисовок (в т.ч. web/builder): [ChangeNotifier] иногда теряет кадр.
  final ValueNotifier<bool> uiSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> uiBulkStagesPending =
      ValueNotifier<bool>(false);
  /// Тикает каждые 500 ms, пока идёт «СИНХРОНИЗАЦИЯ ВСЕХ», чтобы подпись/спиннер не «замирали» на одном кадре (web).
  final ValueNotifier<int> employeesBulkUiTick = ValueNotifier<int>(0);

  Timer? _employeesBulkUiTickTimer;

  Listenable? _mergedListenables;

  Listenable get mergedListenables =>
      _mergedListenables ??= Listenable.merge(<Listenable>[
        this,
        uiSyncing,
        uiBulkStagesPending,
      ]);

  void _syncUiValueNotifiers() {
    final sync = _isRunning || _requests.any((r) => !r.isCompleted);
    if (uiSyncing.value != sync) uiSyncing.value = sync;
    final bulk = _requests
        .any((r) => !r.isCompleted && r.employeesListBulkStages);
    if (uiBulkStagesPending.value != bulk) {
      uiBulkStagesPending.value = bulk;
    }
    if (bulk) {
      if (_employeesBulkUiTickTimer == null) {
        _employeesBulkUiTickTimer =
            Timer.periodic(const Duration(milliseconds: 500), (_) {
          final v = employeesBulkUiTick.value;
          employeesBulkUiTick.value =
              v < 2000000000 ? v + 1 : 0; // trigger Listenable
        });
      }
    } else {
      _employeesBulkUiTickTimer?.cancel();
      _employeesBulkUiTickTimer = null;
    }
  }

  @override
  void notifyListeners() {
    _syncUiValueNotifiers();
    super.notifyListeners();
  }

  bool get isSyncing =>
      _isRunning || _requests.any((r) => !r.isCompleted);

  /// Незавершённые этапы «СИНХРОНИЗАЦИЯ ВСЕХ» (учёт нескольких заявок без гонки notify при enqueue подряд).
  bool get hasEmployeesBulkStagesPending =>
      _requests.any((r) => !r.isCompleted && r.employeesListBulkStages);

  /// Текущий незавершённый этап «всех сотрудников» (подпись кнопки AppBar).
  String? get employeesBulkCurrentStageLabel {
    for (final r in _requests) {
      if (!r.isCompleted && r.employeesListBulkStages) {
        return r.label;
      }
    }
    return null;
  }

  /// Сколько этапов из очереди «всех сотрудников» уже завершено / всего (для «2/3» на кнопке).
  ({int done, int total}) get employeesBulkStagesCounts {
    final stages = _requests.where((r) => r.employeesListBulkStages).toList();
    final total = stages.length;
    final done = stages.where((r) => r.isCompleted).length;
    return (done: done, total: total);
  }

  bool get hasPendingResults => _requests.any(
        (r) => r.isCompleted && !r.hasError && (r.results?.isNotEmpty ?? false),
      );

  /// Задача на сервере завершилась без ошибки, но импортировать нечего (часто краулер после дедупликации).
  /// Раньше UI считал это «ничего не происходит» и скрывал колокольчик.
  bool get hasCompletedEmptySuccess => _requests.any(
        (r) => r.isCompleted && !r.hasError && (r.results?.isEmpty ?? true),
      );

  bool get hasActivity => _requests.isNotEmpty;

  List<SyncRequest> get completedRequests =>
      _requests.where((r) => r.isCompleted).toList();

  List<SyncRequest> get pendingRequests =>
      _requests.where((r) => !r.isCompleted).toList();

  List<dynamic> get mergedResults {
    final all = <dynamic>[];
    for (final r in _requests) {
      if (r.isCompleted && !r.hasError && r.results != null) {
        all.addAll(r.results!);
      }
    }
    return all;
  }

  void enqueueBulk(Iterable<SyncRequest> batch) {
    _requests.addAll(batch);
    _processNext();
    notifyListeners();
  }

  void enqueue(SyncRequest request) {
    enqueueBulk([request]);
  }

  /// Stops the current HTTP request (if any) and drops all tasks that are not finished yet.
  void cancelSync() {
    final hasWork =
        _isRunning || _requests.any((r) => !r.isCompleted);
    if (!hasWork) return;
    final jid = _activeSyncJobId;
    if (jid != null && jid.isNotEmpty) {
      unawaited(_notifyServerCancelJob(jid));
    }
    _cancelRequested = true;
    final c = _cancelCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _activeSyncJobId = null;
    notifyListeners();
  }

  Future<void> _notifyServerCancelJob(String jobId) async {
    try {
      final r = await ApiClient.delete(Uri.parse('$_baseUrl/integration_sync_jobs/$jobId'));
      if (r.statusCode != 200 && r.statusCode != 202 && r.statusCode != 204) {
        debugPrint('integration_sync_jobs cancel HTTP ${r.statusCode}: ${r.body}');
      }
    } catch (e) {
      debugPrint('integration_sync_jobs cancel failed: $e');
    }
  }

  void dismissCompleted() {
    _requests.removeWhere((r) => r.isCompleted);
    notifyListeners();
    // После закрытия диалога колокольчик в MaterialApp.builder может не перерисоваться в том же кадре.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    _deleteFromRedis();
  }

  void callAllOnSaved() {
    for (final r in completedRequests) {
      r.onSaved?.call();
    }
  }

  // ── Redis persistence ──────────────────────────────────────────────────────

  static String get _baseUrl => AppConfig.apiV1;

  Future<bool> _loadFromRedis() async {
    try {
      final response = await ApiClient.get(Uri.parse('$_baseUrl/sync_results'));
      if (response.statusCode == 401 || response.statusCode == 403) return false;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final list = body['results'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          final restored = list
              .map((e) => SyncRequest.fromJson(e as Map<String, dynamic>))
              .where((r) => r.results?.isNotEmpty ?? false)
              .toList();
          if (restored.isNotEmpty) {
            _requests.addAll(restored);
            notifyListeners();
          }
        }
        return true;
      }
    } catch (_) {
      // Redis unavailable — silently skip; in-memory state is still usable.
    }
    return false;
  }

  Future<void> _saveToRedis() async {
    final toSave = _requests
        .where((r) => r.isCompleted && !r.hasError && (r.results?.isNotEmpty ?? false))
        .map((r) => r.toJson())
        .toList();
    try {
      await ApiClient.put(
        Uri.parse('$_baseUrl/sync_results'),
        body: jsonEncode({'results': toSave}),
      );
    } catch (_) {}
  }

  Future<void> _deleteFromRedis() async {
    try {
      await ApiClient.delete(Uri.parse('$_baseUrl/sync_results'));
    } catch (_) {}
  }

  // ── Processing ─────────────────────────────────────────────────────────────

  void _removePendingIncomplete() {
    _requests.removeWhere((r) => !r.isCompleted);
  }

  Future<void> _processNext() async {
    if (_isRunning) return;
    if (!_requests.any((r) => !r.isCompleted)) return;

    _isRunning = true;
    _cancelRequested = false;
    notifyListeners();

    try {
      while (!_cancelRequested) {
        SyncRequest? request;
        for (final r in _requests) {
          if (!r.isCompleted) {
            request = r;
            break;
          }
        }
        if (request == null) break;

        _cancelCompleter = Completer<void>();
        final cancelSentinel = Object();

        try {
          final outcome = await Future.any<dynamic>([
            _service.syncPreview(
              provider: request.provider,
              url: request.url,
              researcherId: request.researcherId,
              teamId: request.teamId,
              scope: request.scope,
              shouldAbort: () => _cancelRequested,
              onJobCreated: (id) {
                _activeSyncJobId = id;
                notifyListeners();
              },
            ),
            _cancelCompleter!.future.then((_) => cancelSentinel),
          ]);

          if (identical(outcome, cancelSentinel) || _cancelRequested) {
            _removePendingIncomplete();
            break;
          }

          final results = outcome as List<dynamic>;
          final enriched = results.map((res) {
            final rid = res['researcher_id'];
            final tid = res['team_id'];
            final achievements = (res['achievements'] as List? ?? []).map((a) {
              final ach = Map<String, dynamic>.from(a);
              ach['researcher_id'] = rid;
              return ach;
            }).toList();
            return {...res, 'achievements': achievements, 'team_id': tid};
          }).toList();

          request.results = enriched;
          request.isCompleted = true;
        } catch (e) {
          if (_cancelRequested || e is SyncPreviewAborted) {
            _removePendingIncomplete();
            break;
          }
          request.hasError = true;
          request.errorMessage = e.toString();
          request.isCompleted = true;
        } finally {
          _cancelCompleter = null;
          _activeSyncJobId = null;
        }
        notifyListeners();
      }
    } finally {
      _cancelCompleter = null;
      _isRunning = false;
      _cancelRequested = false;
      notifyListeners();
      await _saveToRedis();
    }

    // Задачи догрузили между итерациями — второй вход (без дырки по _isRunning)
    if (_requests.any((r) => !r.isCompleted)) {
      unawaited(_processNext());
    }
  }
}
