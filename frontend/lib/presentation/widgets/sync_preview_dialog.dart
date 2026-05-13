import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/services/integration_service.dart';
import 'package:research_activity_monitoring_system/data/services/sync_notification_service.dart';
import 'package:research_activity_monitoring_system/presentation/screens/settings/settings_screen.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';

class SyncPreviewDialog extends StatefulWidget {
  final String provider;
  final int? researcherId;
  final int? teamId;
  final String? url;
  final String? scope;
  /// When provided the dialog skips loading and shows results immediately.
  final List<dynamic>? preloadedResults;
  /// Called after the user successfully saves the selection (background-sync flow).
  final VoidCallback? onResultsSaved;

  const SyncPreviewDialog({
    super.key,
    this.provider = 'orcid',
    this.researcherId,
    this.teamId,
    this.url,
    this.scope,
    this.preloadedResults,
    this.onResultsSaved,
  });

  @override
  State<SyncPreviewDialog> createState() => _SyncPreviewDialogState();
}

class _SyncPreviewDialogState extends State<SyncPreviewDialog> {
  final IntegrationService _service = IntegrationService();
  bool _isLoading = false;
  bool _isSaving = false;
  List<dynamic> _results = [];
  final Set<Map<String, dynamic>> _selectedAchievements = {};

  bool get _isInternetCrawl =>
      widget.provider == 'crawl_search' || widget.provider == 'crawl';

  bool _hasDevData() {
    return _results.any((res) {
      final devActs = res['dev_activities'] as List? ?? [];
      final criteria = res['project_criteria_met'] as List? ?? [];
      final details = res['activity_details'] as List? ?? [];
      return devActs.isNotEmpty ||
          criteria.isNotEmpty ||
          details.isNotEmpty;
    });
  }

  List<Map<String, dynamic>> _allAchievements() {
    return _results
        .expand((res) => (res['achievements'] as List? ?? []))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  void _toggleSelectAllAchievements() {
    final all = _allAchievements();
    if (all.isEmpty) return;

    setState(() {
      if (_selectedAchievements.length == all.length) {
        _selectedAchievements.clear();
      } else {
        _selectedAchievements
          ..clear()
          ..addAll(all);
      }
    });
  }

  /// Закрыть окно без сохранения (для фоновых результатов очистку делает [PopScope.onPopInvokedWithResult]).
  void _closePreviewWithoutSaving() {
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void initState() {
    super.initState();
    if (widget.preloadedResults != null) {
      // Background-sync flow: results are already fetched, show them directly.
      _results = List<dynamic>.from(widget.preloadedResults!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCrawlModelWarnings(_collectWarnings(_results));
      });
    } else {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _isSaving = false;
      _results = [];
      _selectedAchievements.clear();
    });
    
    try {
      final results = await _service.syncPreview(
        provider: widget.provider,
        researcherId: widget.researcherId,
        teamId: widget.teamId,
        scope: widget.scope,
      );
      final enrichedResults = (results as List).map((res) {
        final researcherId = res['researcher_id'];
        final teamId = res['team_id'];
        final achievements = (res['achievements'] as List? ?? []).map((a) {
          final achievement = Map<String, dynamic>.from(a);
          achievement['researcher_id'] = researcherId;
          return achievement;
        }).toList();
        
        return {
          ...res,
          'achievements': achievements,
          'team_id': teamId,
        };
      }).toList();

      setState(() {
        _results = enrichedResults;
        _isLoading = false;
        _isSaving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCrawlModelWarnings(_collectWarnings(enrichedResults));
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSaving = false;
      });
      if (mounted) {
        if (_isRateLimitError(e.toString())) {
          _showRateLimitWarning();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка синхронизации: $e')),
          );
        }
      }
    }
  }

  bool _isRateLimitError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('rate_limit') ||
        lower.contains('rate limit') ||
        lower.contains('429') ||
        lower.contains('quota');
  }

  List<String> _collectWarnings(List<dynamic> results) {
    final out = <String>{};
    for (final res in results) {
      if (res is! Map) continue;
      final w = res['warnings'];
      if (w is List) {
        for (final item in w) {
          if (item is String && item.trim().isNotEmpty) out.add(item.trim());
        }
      }
    }
    return out.toList();
  }

  void _showCrawlModelWarnings(List<String> messages) {
    if (messages.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.settings_suggest_outlined, color: Colors.amber, size: 48),
        title: const Text('Настройки модели LLM'),
        content: SingleChildScrollView(
          child: Text(messages.join('\n\n')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Открыть настройки', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRateLimitWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
        title: const Text('Превышен лимит API'),
        content: const Text(
          'Лимит запросов к API исчерпан. Добавьте или обновите API-ключ в разделе «Настройки», чтобы продолжить синхронизацию.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Открыть настройки', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSelected() async {
    // Сохранение разрешено если выбраны ачивки, или есть dev-данные, или это команда
    if (_selectedAchievements.isEmpty && widget.teamId == null && !_hasDevData()) return;

    setState(() {
      _isLoading = true;
      _isSaving = true;
    });
    try {
      // Собираем dev-данные для всех исследователей из результатов
      final researcherDevData = _results
          .where((res) =>
              res['researcher_id'] != null &&
              ((res['dev_activities'] as List? ?? []).isNotEmpty ||
               (res['project_criteria_met'] as List? ?? []).isNotEmpty ||
               (res['activity_details'] as List? ?? []).isNotEmpty))
          .map((res) => {
                'researcher_id': res['researcher_id'],
                'dev_activities': res['dev_activities'] ?? [],
                'project_criteria_met': res['project_criteria_met'] ?? [],
                'activity_details': res['activity_details'] ?? [],
              })
          .toList();

      // Собираем dev-данные для всех команд из результатов
      final teamDevData = _results
          .where((res) =>
              res['team_id'] != null &&
              ((res['dev_activities'] as List? ?? []).isNotEmpty ||
               (res['project_criteria_met'] as List? ?? []).isNotEmpty))
          .map((res) => {
                'team_id': res['team_id'],
                'dev_activities': res['dev_activities'] ?? [],
                'project_criteria_met': res['project_criteria_met'] ?? [],
              })
          .toList();

      final response = await _service.saveAchievements(
        _selectedAchievements.toList(),
        researcherDevData: researcherDevData,
        teamDevData: teamDevData,
      );
      if (mounted) {
        widget.onResultsSaved?.call();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'])),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName = _isInternetCrawl
        ? 'краулер (интернет)'
        : (widget.provider == 'all'
            ? 'всех источников'
            : (widget.provider == 'background'
                ? 'фоновая синхронизация'
                : (widget.provider == 'github' && widget.scope == 'teams'
                    ? 'GitHub — все проекты'
                    : widget.provider.toUpperCase())));
    
    // Для команд кнопка СОХРАНИТЬ активна всегда (teamId != null); данные всё равно уходят только по нажатию.
    // Для исследователей кнопка активна если выбраны ачивки или есть данные по разработке
    final bool canSave = _selectedAchievements.isNotEmpty || widget.teamId != null || widget.scope == 'teams' || _hasDevData();
    final allAchievements = _allAchievements();
    final hasAchievements = allAchievements.isNotEmpty;
    final allSelected = hasAchievements && _selectedAchievements.length == allAchievements.length;

    return PopScope<bool?>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        if (widget.preloadedResults != null && result != true) {
          SyncNotificationService.instance.dismissCompleted();
        }
      },
      child: Dialog(
        child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Icon(
                        widget.provider == 'orcid'
                            ? Icons.link
                            : (widget.provider == 'openalex'
                                ? Icons.school_outlined
                                : (widget.provider == 'github'
                                    ? Icons.code
                                    : (_isInternetCrawl
                                        ? Icons.travel_explore
                                        : Icons.all_inclusive))),
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Синхронизация: $providerName', style: AppTextStyles.h2),
                        const Text('Выберите данные для импорта в систему', style: AppTextStyles.bodySecondary),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _closePreviewWithoutSaving,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                          Text(
                            _isSaving
                                ? 'Сохраняем результаты синхронизации...'
                                : (_isInternetCrawl
                                    ? 'Краулер ищет информацию в интернете по сотрудникам...'
                                    : 'Запрашиваем данные по API...'),
                            style: AppTextStyles.bodySecondary,
                          ),
                          Text(
                            _isSaving
                                ? 'Пожалуйста, подождите. Идёт массовое сохранение.'
                                : 'Это может занять до минуты',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    )
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : _buildList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: hasAchievements ? _toggleSelectAllAchievements : null,
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                  label: const Text('ВЫБРАТЬ ВСЕ'),
                ),
                if (_selectedAchievements.isNotEmpty)
                  Text(
                    'Выбрано достижений: ${_selectedAchievements.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                OutlinedButton(
                  onPressed: _closePreviewWithoutSaving,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('ОТМЕНА'),
                ),
                ElevatedButton(
                  onPressed: !canSave ? null : _saveSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('СОХРАНИТЬ', style: TextStyle(color: AppColors.textOnPrimary)),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppColors.inactive),
          const SizedBox(height: 16),
          const Text('Новых данных не найдено', style: AppTextStyles.h3),
          if (_isInternetCrawl) ...[
            const SizedBox(height: 8),
            const Text(
              'Проверьте настройки LLM в разделе «Настройки» или повторите позже.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final res = _results[index];
        final name = res['researcher_name'] ?? res['team_title'] ?? 'Неизвестный объект';
        final isTeam = res['team_id'] != null;
        final achievements = (res['achievements'] as List? ?? []);
        final devActivities = res['dev_activities'] as List? ?? [];
        final projectCriteria = res['project_criteria_met'] as List? ?? [];
        final activityDetails = res['activity_details'] as List? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              margin: const EdgeInsets.only(top: 16, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Icon(isTeam ? Icons.groups_outlined : Icons.person_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  if (!isTeam)
                    Text(
                      'Достижений: ${achievements.length}',
                      style: AppTextStyles.caption,
                    ),
                  if (devActivities.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.code, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Активностей: ${devActivities.length}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
            if (devActivities.isNotEmpty || activityDetails.isNotEmpty || (isTeam && projectCriteria.isNotEmpty))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          isTeam
                              ? 'Данные проекта (импорт при нажатии СОХРАНИТЬ)'
                              : 'Активность разработки (импорт при нажатии СОХРАНИТЬ)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    if (devActivities.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final grouped = <String, int>{};
                        for (final da in devActivities) {
                          final type = da['activity_type']?.toString() ?? '';
                          grouped[type] = (grouped[type] ?? 0) + ((da['count'] as num?)?.toInt() ?? 0);
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: grouped.entries.map((e) => Chip(
                            label: Text('${e.key}: ${e.value}',
                                style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                        );
                      }),
                    ],
                    if (activityDetails.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final byType = <String, int>{};
                        for (final d in activityDetails) {
                          final t = d['activity_type']?.toString() ?? '';
                          byType[t] = (byType[t] ?? 0) + 1;
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: byType.entries.map((e) => Chip(
                                avatar: const Icon(Icons.info_outline, size: 12),
                                label: Text('${e.key}: ${e.value}',
                                    style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )).toList(),
                            ),
                            const SizedBox(height: 4),
                            ...activityDetails.take(3).map((d) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      d['title']?.toString() ?? d['external_id']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            if (activityDetails.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 2),
                                child: Text(
                                  '... ещё ${activityDetails.length - 3}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                    if (isTeam && projectCriteria.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: projectCriteria.map((pc) => Chip(
                          avatar: const Icon(Icons.check_circle, size: 14, color: Colors.green),
                          label: Text(pc.toString(), style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ...achievements.map((achievement) {
              final isSelected = _selectedAchievements.contains(achievement);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.02) : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedAchievements.add(achievement);
                      } else {
                        _selectedAchievements.remove(achievement);
                      }
                    });
                  },
                  title: Text(
                    achievement['title'] ?? 'Без названия',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            achievement['type']?.toString().toUpperCase() ?? 'WORK',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          achievement['date'] ?? '—',
                          style: AppTextStyles.caption,
                        ),
                        if (achievement['journal_title'] != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.menu_book_outlined, size: 16, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              achievement['journal_title'],
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

