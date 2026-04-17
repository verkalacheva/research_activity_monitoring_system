import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:js' as js;
import '../services/report_service.dart';
import '../services/socket_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../utils/clipboard_helper.dart';
import 'dart:convert';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportService _reportService = ReportService();

  static const Map<String, String> _reportTitles = {
    'researchers_report': 'Сотрудники',
    'teams': 'Команды',
    'dev_teams_report': 'Разработка: Команды',
    'dev_researchers_report': 'Разработка: Сотрудники',
  };

  static const Map<String, List<String>> _reportFilters = {
    'researchers_report': ['submission_date', 'researcher_id', 'team_id', 'status', 'achievement_result_id', 'achievement_participation_id'],
    'teams': ['submission_date', 'team_id'],
    'dev_teams_report': ['activity_date', 'team_id'],
    'dev_researchers_report': ['activity_date', 'researcher_id', 'team_id'],
  };

  static const Map<String, List<String>> _reportSorts = {
    'researchers_report': ['r.surname', 'a.points', 'dev_points', 'combined_points', 'id'],
    'teams': ['title', 'total_points', 'dev_points', 'combined_points', 'members_count', 'id'],
    'dev_teams_report': ['team', 'total_score', 'criteria_sum', 'criteria_list', 'activity_sum'],
    'dev_researchers_report': ['researcher', 'team', 'dev_points', 'criteria_sum', 'activity_type', 'activity_points'],
  };

  static const Map<String, Map<String, String>> _filterMetadata = {
    'status': {
      'title': 'Статус',
      'url': '/api/v1/selectors/achievement_statuses',
    },
    'achievement_type': {
      'title': 'Тип достижения',
      'url': '/api/v1/selectors/achievement_types',
    },
    'researcher_id': {
      'title': 'Исследователь',
      'url': '/api/v1/selectors/researchers',
    },
    'leader_id': {
      'title': 'Руководитель',
      'url': '/api/v1/selectors/researchers',
    },
    'team_id': {
      'title': 'Команда',
      'url': '/api/v1/selectors/teams',
    },
    'achievement_result_id': {
      'title': 'Результат',
      'url': '/api/v1/selectors/achievement_results',
    },
    'achievement_participation_id': {
      'title': 'Роль',
      'url': '/api/v1/selectors/achievement_participations',
    },
    'degree_level': {
      'title': 'Ученая степень',
    },
    'points': {
      'title': 'Баллы',
    },
    'submission_date': {
      'title': 'Дата подачи',
    },
    'activity_date': {
      'title': 'Период активности',
    },
  };

  static const Map<String, String> _sortTitles = {
    'r.surname': 'Фамилия',
    'a.points': 'Баллы',
    'a.created_at': 'Дата создания',
    'id': 'ID',
    'at.title': 'Достижение',
    's.title': 'Статус',
    'title': 'Название',
    'total_points': 'Баллы достижений',
    'combined_points': 'Итоговые баллы',
    'members_count': 'Участники',
    'team': 'Команда',
    'researcher': 'Сотрудник',
    'total_score': 'Общий балл',
    'criteria_sum': 'Критерии проекта',
    'criteria_list': 'Выполненные критерии',
    'activity_list': 'Подробности активности',
    'activity_sum': 'Активность сотрудника',
    'activity_type': 'Тип активности',
    'activity_points': 'Баллы по активности',
    'dev_points': 'Баллы разработки',
  };

  Map<String, dynamic>? _selectors;
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  bool _isLoadingDashboard = true;
  String? _selectedReportId;
  DateTime? _dashboardStartDate;
  DateTime? _dashboardEndDate;
  String _dashboardPeriodLabel = 'Весь период';
  final LayerLink _dashboardPeriodLink = LayerLink();
  
  // Report Generation State
  bool _isGenerating = false;
  Map<String, dynamic>? _reportResult;
  final List<Map<String, dynamic>> _activeFilters = [];
  int _currentPage = 0;
  final int _pageSize = 20;
  String _sortField = 'id';
  bool _sortDescending = false;
  DateTime _currentCalendarMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSelectors();
    _loadDashboardData();
    _initSocket();
  }

  @override
  void dispose() {
    unawaited(SocketService().disconnect());
    super.dispose();
  }

  void _initSocket() {
    SocketService().connect(
      channel: 'ReportsChannel',
      onMessage: (data) {
        if (data['report_type'] == 'dashboard_overview') {
          final reportData = data['data'];
          if (reportData is Map) {
            setState(() {
              _dashboardData = Map<String, dynamic>.from(reportData);
              _isLoadingDashboard = false;
            });
          }
        }
      },
    );
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingDashboard = true);
    try {
      final data = await _reportService.getDashboardData(
        startDate: _dashboardStartDate,
        endDate: _dashboardEndDate,
      );
      setState(() {
        _dashboardData = data;
        _isLoadingDashboard = false;
      });
    } catch (e, stack) {
      debugPrint('Error loading dashboard: $e');
      debugPrint(stack.toString());
      setState(() => _isLoadingDashboard = false);
    }
  }

  Future<void> _loadSelectors() async {
    try {
      final selectors = await _reportService.getSelectors();
      setState(() {
        _selectors = selectors;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading selectors: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки настроек: $e')),
        );
      }
    }
  }

  Future<void> _generateReport({VoidCallback? onComplete}) async {
    if (_selectedReportId == null) return;
    setState(() => _isGenerating = true);
    if (onComplete != null) onComplete();

    // Filter out empty filter values before sending to backend
    final nonPagedFilters = _activeFilters
        .where((f) => f['value'] != null && f['value'].toString().trim().isNotEmpty)
        .map((f) => {
              'field': f['field'],
              'operator': f['operator'],
              'value': f['value'].toString(),
            })
        .toList();

    try {
      final params = {
        'report_type': _selectedReportId,
        'report_format': 'json',
        'filters': nonPagedFilters,
        'sorts': [
          {'field': _sortField, 'descending': _sortDescending}
        ],
        'limit': _pageSize,
        'offset': _currentPage * _pageSize,
      };
      final result = await _reportService.generateReport(params);
      setState(() {
        _reportResult = result;
        _isGenerating = false;
      });
      if (onComplete != null) onComplete();
    } catch (e) {
      setState(() => _isGenerating = false);
      if (onComplete != null) onComplete();
    }
  }

  void _openReportDetail(String reportId) {
    // Initialize active filters from frontend-defined filters for this report
    final reportFilterIds = _reportFilters[reportId] ?? [];
    final filters = reportFilterIds.map((id) {
      final meta = _filterMetadata[id] ?? {};
      return {
        'field': id,
        'operator': 'eq',
        'value': '',
        'title': meta['title'] ?? id,
        'type': id == 'points' ? 'number' : ((id == 'submission_date' || id == 'activity_date') ? 'date' : (meta['url'] != null ? 'select' : 'text')),
        'selector_url': meta['url'],
        'options': [], // To be loaded on demand
        'isLoadingOptions': false,
        'isLoaded': false,
        'totalCount': 0,
        'offset': 0,
        'layerLink': LayerLink(),
      };
    }).toList();

    setState(() {
      _selectedReportId = reportId;
      _reportResult = null;
      _isGenerating = false;
      _activeFilters.clear();
      _activeFilters.addAll(filters);
      _currentPage = 0;
      // Default sort for the report
      final availableSorts = _reportSorts[reportId] ?? ['id'];
      _sortField = availableSorts[0];
      _sortDescending = false;
    });
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Trigger initial report generation if needed
          if (_reportResult == null && !_isGenerating) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _generateReport().then((_) {
                if (context.mounted) setModalState(() {});
              });
            });
          }
          return Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.surface,
                elevation: 0,
                iconTheme: const IconThemeData(color: AppColors.textPrimary),
                title: Text(
                  _reportTitles[reportId] ?? 'Отчет', 
                  style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis
                ),
                actions: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = MediaQuery.of(context).size.width < 700;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () => _handlePrint(),
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: isNarrow ? const SizedBox.shrink() : const Text('Печать'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _exportReport('csv'),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: isNarrow ? const SizedBox.shrink() : const Text('Экспорт CSV'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      );
                    },
                  ),
                ],
              ),
              body: Row(
                children: [
                  // LEFT PANEL: FILTERS
                  Container(
                    width: 320,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(right: BorderSide(color: AppColors.divider, width: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.tune, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  const Text('Фильтры', style: AppTextStyles.h3),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ..._activeFilters.map((f) => _buildFilterItem(f, (fn) {
                                setModalState(fn);
                              })),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              setModalState(() => _currentPage = 0);
                              _generateReport().then((_) => setModalState(() {}));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Применить фильтры', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // RIGHT PANEL: TABLE
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _isGenerating 
                              ? const Center(child: CircularProgressIndicator())
                              : _buildReportTable(setModalState),
                          ),
                        ),
                        _buildPagination(setModalState),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _handlePrint() async {
    if (_selectedReportId == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Подготовка данных для печати...'), duration: Duration(seconds: 1)),
    );

    try {
      final nonPagedFilters = _activeFilters
          .where((f) => f['value'] != null && f['value'].toString().trim().isNotEmpty)
          .map((f) => {
                'field': f['field'],
                'operator': f['operator'],
                'value': f['value'].toString(),
              })
          .toList();

      final params = {
        'report_type': _selectedReportId,
        'report_format': 'json',
        'filters': nonPagedFilters,
        'sorts': [
          {'field': _sortField, 'descending': _sortDescending}
        ],
        'limit': 10000,
        'offset': 0,
      };
      
      final result = await _reportService.generateReport(params);
      if (mounted) {
        _printNative(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подготовки данных: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  (List<String>, List<List<String>>) _buildReportRowsAndHeaders(
      String reportType, Map<String, dynamic> reportData) {
    final data = reportData['data'] as List? ?? [];
    final totals = reportData['column_totals'] as Map? ?? {};
    List<String> headers = [];
    List<List<String>> rows = [];

    if (reportType == 'teams') {
      headers = ['ID', 'Название команды', 'Руководитель', 'Кол-во участников', 'Баллы достижений', 'Баллы разработки', 'Итоговые баллы'];
      for (var item in data) {
        rows.add([
          item['id'].toString(),
          (item['title'] ?? '').toString(),
          (item['leader_name'] ?? '').toString(),
          (item['members_count']?.toString() ?? '0'),
          (item['total_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
          (item['dev_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
          (item['combined_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
        ]);
      }
      if (totals.isNotEmpty) {
        rows.add([
          'ИТОГО',
          '',
          '',
          (totals['members_count']?.toString() ?? ''),
          (totals['total_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '',
          (totals['dev_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '',
          (totals['combined_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '',
        ]);
      }
    } else if (reportType == 'dev_teams_report') {
      headers = ['Команда', 'Критерии проекта', 'Выполненные критерии', 'Активность', 'Общий балл'];
      for (var item in data) {
        rows.add([
          (item['team'] ?? '').toString(),
          (item['criteria_sum'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
          (item['criteria_list'] ?? '').toString(),
          (item['activity_sum'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
          (item['total_score'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
        ]);
      }
      if (totals.isNotEmpty) {
        rows.add([
          'ИТОГО',
          (totals['criteria_sum'] as num?)?.toDouble().toStringAsFixed(1) ?? '',
          '',
          (totals['activity_sum'] as num?)?.toDouble().toStringAsFixed(1) ?? '',
          '',
        ]);
      }
    } else if (reportType == 'dev_researchers_report') {
      headers = ['Сотрудник', 'Команда', 'Тип активности', 'Кол-во', 'Баллы / ед.', 'Баллы', 'Критерии проекта', 'Итого баллов'];

      // Regroup by (researcher_id, team) preserving backend sort order of groups
      final Map<String, List<dynamic>> exportGroupMap = {};
      final List<String> exportGroupKeys = [];
      for (var item in data) {
        final key = '${item['researcher_id']}|${item['team'] ?? ''}';
        if (!exportGroupMap.containsKey(key)) {
          exportGroupMap[key] = [];
          exportGroupKeys.add(key);
        }
        exportGroupMap[key]!.add(item);
      }

      for (final key in exportGroupKeys) {
        final groupItems = exportGroupMap[key]!;
        double exportGroupActivitySum = 0;
        double exportGroupDevPoints = 0;
        double exportGroupCriteriaSum = 0;

        for (var i = 0; i < groupItems.length; i++) {
          final item = groupItems[i];
          final team = (item['team'] ?? '').toString();
          rows.add([
            i == 0 ? (item['researcher'] ?? '').toString() : '',
            i == 0 ? team : '',
            (item['activity_type'] ?? '').toString(),
            (item['count'] as num?)?.toInt().toString() ?? '0',
            (item['type_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
            (item['activity_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
            '',
            '',
          ]);
          exportGroupActivitySum += (item['activity_points'] as num?)?.toDouble() ?? 0.0;
          exportGroupDevPoints = (item['dev_points'] as num?)?.toDouble() ?? 0.0;
          exportGroupCriteriaSum = (item['criteria_sum'] as num?)?.toDouble() ?? 0.0;
        }

        rows.add(['', '', 'Итого по сотруднику', '', '', exportGroupActivitySum.toStringAsFixed(1), exportGroupCriteriaSum.toStringAsFixed(1), exportGroupDevPoints.toStringAsFixed(1)]);
      }

      if (totals.isNotEmpty) {
        rows.add(['ИТОГО', '', '', '', '', '', '', (totals['dev_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '']);
      }
    } else if (reportType == 'researchers_report') {
      headers = ['ID', 'Исследователь', 'Достижение', 'Баллы достижений', 'Статус', 'Результат', 'Роль', 'Баллы разработки', 'Итоговые баллы'];

      int? lastResearcherId;
      double researcherSubtotal = 0;
      double lastDevPts = 0;

      for (var item in data) {
        final researcherId = item['researcher_id'];
        final points = (item['points'] as num?)?.toDouble() ?? 0.0;
        final devPts = (item['dev_points'] as num?)?.toDouble() ?? 0.0;

        if (lastResearcherId != null && lastResearcherId != researcherId) {
          final combined = researcherSubtotal + lastDevPts;
          rows.add(['', 'Итого по сотруднику', '', researcherSubtotal.toStringAsFixed(1), '', '', '', lastDevPts.toStringAsFixed(1), combined.toStringAsFixed(1)]);
          researcherSubtotal = 0;
        }

        rows.add([
          item['id'].toString(),
          (lastResearcherId == researcherId ? '' : (item['researcher_name'] ?? item['researcher'] ?? '')).toString(),
          (item['achievement'] ?? '').toString(),
          points.toStringAsFixed(1),
          (item['status'] ?? '').toString(),
          (item['result'] ?? '').toString(),
          (item['participation'] ?? '').toString(),
          '',
          '',
        ]);

        lastResearcherId = researcherId;
        lastDevPts = devPts;
        researcherSubtotal += points;
      }

      if (lastResearcherId != null) {
        final combined = researcherSubtotal + lastDevPts;
        rows.add(['', 'Итого по сотруднику', '', researcherSubtotal.toStringAsFixed(1), '', '', '', lastDevPts.toStringAsFixed(1), combined.toStringAsFixed(1)]);
      }

      if (totals.isNotEmpty && totals.containsKey('points')) {
        final totalAch = (totals['points'] as num?)?.toDouble() ?? 0.0;
        final totalDev = (totals['dev_points'] as num?)?.toDouble() ?? 0.0;
        final totalCombined = totalAch + totalDev;
        rows.add(['ИТОГО', '', '', totalAch.toStringAsFixed(1), '', '', '', totalDev.toStringAsFixed(1), totalCombined.toStringAsFixed(1)]);
      }
    } else {
      headers = ['ID', 'Исследователь', 'Достижение', 'Баллы', 'Статус', 'Результат', 'Роль'];

      for (var item in data) {
        rows.add([
          item['id'].toString(),
          (item['researcher_name'] ?? item['researcher'] ?? '').toString(),
          (item['achievement'] ?? '').toString(),
          (item['points'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0',
          (item['status'] ?? '').toString(),
          (item['result'] ?? '').toString(),
          (item['participation'] ?? '').toString(),
        ]);
      }

      if (totals.isNotEmpty && totals.containsKey('points')) {
        rows.add([
          'ИТОГО',
          '',
          '',
          (totals['points'] as num?)?.toDouble().toStringAsFixed(1) ?? '',
          '',
          '',
          '',
        ]);
      }
    }

    return (headers, rows);
  }

  String _escapeCsvCell(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n') || cell.contains('\r')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }

  void _printNative(Map<String, dynamic> reportData) {
    final reportType = _selectedReportId;
    final title = _reportTitles[reportType] ?? 'Отчет';
    final (headers, rows) = _buildReportRowsAndHeaders(reportType!, reportData);

    if (kIsWeb) {
      js.context.callMethod('eval', ["""
        (function(title, headers, rows) {
          var win = window.open('', '_blank');
          var html = '<html><head><title>' + title + '</title>';
          html += '<style>';
          html += 'body { font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Helvetica, Arial, sans-serif; padding: 20px; color: #333; }';
          html += 'table { width: 100%; border-collapse: collapse; table-layout: auto; }';
          html += 'th, td { border: 1px solid #000; padding: 8px; text-align: left; font-size: 11px; word-wrap: break-word; }';
          html += 'th { background-color: #f5f5f5; font-weight: bold; }';
          html += '@media print { body { padding: 0; } .no-print { display: none; } }';
          html += '</style></head><body>';
          
          html += '<table><thead><tr>';
          headers.forEach(function(h) { html += '<th>' + h + '</th>'; });
          html += '</tr></thead><tbody>';
          
          rows.forEach(function(row) {
            var isTotal = row[0] === 'ИТОГО' || row.some(function(c) { return c === 'Итого по сотруднику'; });
            html += '<tr' + (isTotal ? ' style=\"font-weight: bold; background-color: #f9f9f9;\"' : '') + '>';
            row.forEach(function(cell) { html += '<td>' + (cell || '') + '</td>'; });
            html += '</tr>';
          });
          
          html += '</tbody></table>';
          html += '<script>window.onload = function() { window.print(); setTimeout(function() { window.close(); }, 100); };</script>';
          html += '</body></html>';
          
          win.document.write(html);
          win.document.close();
        })(${jsonEncode(title)}, ${jsonEncode(headers)}, ${jsonEncode(rows)})
      """]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Печать доступна только в веб-версии')),
      );
    }
  }

  void _showPrintPreview(Map<String, dynamic> reportData) {
    // This function is no longer used but kept for backward compatibility or can be removed
  }

  Widget _buildPrintTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  void _exportReport(String format) async {
    try {
      final nonPagedFilters = _activeFilters
          .where((f) => f['value'] != null && f['value'].toString().trim().isNotEmpty)
          .map((f) => {
                'field': f['field'],
                'operator': f['operator'],
                'value': f['value'].toString(),
              })
          .toList();

      final params = {
        'report_type': _selectedReportId,
        'report_format': format,
        'filters': nonPagedFilters,
        'limit': 10000,
        'offset': 0,
      };
      
      final result = await _reportService.generateReport(params);
      
      if (mounted) {
        if (format == 'csv' && result['data'] != null) {
          final String csvData;
          if (result['format'] == 'csv') {
            // Backend already produced CSV (e.g. researchers_report)
            csvData = result['data'].toString();
          } else {
            // Backend returned JSON — build CSV client-side
            final (csvHeaders, csvRows) = _buildReportRowsAndHeaders(_selectedReportId!, result);
            final buf = StringBuffer();
            buf.writeln(csvHeaders.map(_escapeCsvCell).join(','));
            for (final row in csvRows) {
              buf.writeln(row.map(_escapeCsvCell).join(','));
            }
            csvData = buf.toString();
          }
          if (kIsWeb) {
            // Триггерим скачивание CSV через JS
            final base64Data = base64Encode(utf8.encode(csvData));
            final filename = 'report_${_selectedReportId}_${DateTime.now().millisecondsSinceEpoch}.csv';
            
            js.context.callMethod('eval', ["""
              (function(base64, filename) {
                var element = document.createElement('a');
                element.setAttribute('href', 'data:text/csv;base64,' + base64);
                element.setAttribute('download', filename);
                element.style.display = 'none';
                document.body.appendChild(element);
                element.click();
                document.body.removeChild(element);
              })('$base64Data', '$filename')
            """]);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Отчет успешно экспортирован в формате $format'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // LEFT SIDE: LIST OF REPORTS
        Container(
          width: 280,
          decoration: const BoxDecoration(
            color: AppColors.surfaceSecondary,
            // Border is replaced by a subtle shadow or just nothing for a more modern look
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 32, bottom: 16),
                child: const Text('Отчеты', style: AppTextStyles.h2),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          ...((_selectors?['report_types'] as List?) ?? []).map((report) {
                            final reportId = report['id'];
                            final isSelected = _selectedReportId == reportId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                              ),
                              child: ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                leading: Icon(
                                  Icons.analytics_outlined, 
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  size: 20,
                                ),
                                title: Text(
                                  _reportTitles[reportId] ?? reportId,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () => _openReportDetail(reportId),
                                hoverColor: AppColors.primary.withOpacity(0.04),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
              ),
            ],
          ),
        ),
        // RIGHT SIDE: DASHBOARD CHARTS
        Expanded(
          child: Container(
            color: AppColors.surface, // Main area is white
            child: Column(
              children: [
                Container(
                  height: 80, // Slightly taller header
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Обзор активности', 
                          style: AppTextStyles.h1, // Use h1 for main title
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(child: _buildDashboardPeriodSelector()),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth < 1000 ? 1 : 2;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: crossAxisCount == 1 ? 1.8 : 1.5,
                          children: [
                            _buildDashboardChart(
                              'Распределение по типам', 
                              Icons.pie_chart_outline,
                              _buildTypeDistributionChart(),
                            ),
                            _buildDashboardChart(
                              _dashboardStartDate != null || _dashboardEndDate != null 
                                  ? 'Динамика достижений' 
                                  : 'Динамика достижений (год)', 
                              Icons.insights,
                              _buildDynamicsChart(),
                            ),
                            _buildDashboardChart(
                              _dashboardStartDate != null || _dashboardEndDate != null 
                                  ? 'Топ исследователей' 
                                  : 'Топ исследователей (3 мес.)', 
                              Icons.workspace_premium_outlined,
                              _buildTopResearchersList(),
                            ),
                            _buildDashboardChart(
                              'Распределение по статусам', 
                              Icons.donut_large_outlined,
                              _buildStatusDistributionChart(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardChart(String title, IconData icon, Widget chart) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title, 
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoadingDashboard 
              ? const Center(child: CircularProgressIndicator())
              : _dashboardData == null
                ? Center(child: Icon(icon, size: 80, color: AppColors.divider))
                : chart,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardPeriodSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_dashboardStartDate != null || _dashboardEndDate != null)
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Сбросить'),
              onPressed: () {
                setState(() {
                  _dashboardStartDate = null;
                  _dashboardEndDate = null;
                  _dashboardPeriodLabel = 'Весь период';
                });
                _loadDashboardData();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: AppColors.error.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        CompositedTransformTarget(
          link: _dashboardPeriodLink,
          child: Builder(
            builder: (context) => ElevatedButton.icon(
              onPressed: () => _showDashboardPeriodDropdown(context),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(_dashboardPeriodLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primary,
                elevation: 0,
                side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDashboardPeriodDropdown(BuildContext context) {
    OverlayEntry? overlayEntry;
    bool showCalendar = false;
    
    // Persistent state for the dashboard date picker within the overlay
    final dashboardFilter = {
      'value': '${_dashboardStartDate?.toIso8601String().split('T')[0] ?? ''},${_dashboardEndDate?.toIso8601String().split('T')[0] ?? ''}'
    };
    
    final periods = [
      {'id': 'this_year', 'title': 'Этот год'},
      {'id': 'last_year', 'title': 'Прошлый год'},
      {'id': 'this_month', 'title': 'Этот месяц'},
      {'id': 'prev_month', 'title': 'Предыдущий месяц'},
      {'id': '7_days', 'title': '7 дней'},
      {'id': 'custom', 'title': 'Произвольный период'},
    ];

    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final double screenHeight = MediaQuery.of(context).size.height;
    final double spaceBelow = screenHeight - buttonPosition.dy - button.size.height;
    
    // For calendar we need more space
    final bool showAbove = spaceBelow < 350;

    overlayEntry = OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setOverlayState) {
          return Stack(
            children: [
              GestureDetector(
                onTap: () {
                  overlayEntry?.remove();
                  overlayEntry = null;
                },
                child: Container(color: Colors.transparent),
              ),
              CompositedTransformFollower(
                link: _dashboardPeriodLink,
                showWhenUnlinked: false,
                followerAnchor: showAbove ? Alignment.bottomRight : Alignment.topRight,
                targetAnchor: showAbove ? Alignment.topRight : Alignment.bottomRight,
                offset: Offset(0, showAbove ? -8 : 8),
                child: Material(
                  elevation: 16,
                  borderRadius: BorderRadius.circular(16),
                  shadowColor: AppColors.textPrimary.withOpacity(0.3),
                  child: Container(
                    width: showCalendar ? 300 : (button.size.width > 220 ? button.size.width : 220),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: showCalendar 
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, size: 18),
                                    onPressed: () => setOverlayState(() => showCalendar = false),
                                  ),
                                  const Text('Произвольный период', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                            _buildInlineDateRangePicker(dashboardFilter, (fn) {
                              setOverlayState(() {
                                fn();
                              });
                            }, isDashboard: true, onApply: (start, end) {
                              setState(() {
                                _dashboardStartDate = start;
                                _dashboardEndDate = end;
                                _dashboardPeriodLabel = '${start.toIso8601String().split('T')[0]} - ${end.toIso8601String().split('T')[0]}';
                              });
                              overlayEntry?.remove();
                              overlayEntry = null;
                              _loadDashboardData();
                            }),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: periods.asMap().entries.map((entry) {
                            final item = entry.value;
                            final isCustom = item['id'] == 'custom';
                            
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCustom) 
                                  Divider(height: 1, color: AppColors.divider),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text(
                                    item['title']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                                      color: isCustom ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  onTap: () {
                                    if (item['id'] == 'custom') {
                                      setOverlayState(() => showCalendar = true);
                                    } else {
                                      overlayEntry?.remove();
                                      overlayEntry = null;
                                      _handleDashboardPeriodSelection(item['id']!);
                                    }
                                  },
                                  hoverColor: AppColors.primaryLight,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  void _handleDashboardPeriodSelection(String value) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    String label = '';

    switch (value) {
      case 'this_year':
        start = DateTime(now.year, 1, 1);
        end = now;
        label = 'Этот год';
        break;
      case 'last_year':
        start = DateTime(now.year - 1, 1, 1);
        end = DateTime(now.year - 1, 12, 31);
        label = 'Прошлый год';
        break;
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        end = now;
        label = 'Этот месяц';
        break;
      case 'prev_month':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0);
        label = 'Предыдущий месяц';
        break;
      case '7_days':
        start = now.subtract(const Duration(days: 7));
        end = now;
        label = '7 дней';
        break;
      case 'custom':
        return;
    }

    if (start != null && end != null) {
      setState(() {
        _dashboardStartDate = start;
        _dashboardEndDate = end;
        _dashboardPeriodLabel = label;
      });
      _loadDashboardData();
    }
  }

  Widget _buildTypeDistributionChart() {
    final rawData = _dashboardData?['type_distribution'] as List?;
    if (rawData == null || rawData.isEmpty) return const Center(child: Text('Нет данных'));

    // Sort data by value in descending order
    final data = List.from(rawData);
    data.sort((a, b) => (b['value'] as num).compareTo(a['value'] as num));

    final total = data.fold<double>(0, (sum, item) => sum + (item['value'] as num).toDouble());

    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, 
      Colors.red, Colors.teal, Colors.indigo, Colors.pink, 
      Colors.amber, Colors.cyan, Colors.deepPurple, Colors.lime,
      Colors.brown, Colors.blueGrey, Colors.deepOrange, Colors.lightGreen
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 450;
        return useColumn 
          ? Column(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
                      sections: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final val = (item['value'] as num).toDouble();
                        final percentage = (val / total * 100).toStringAsFixed(0);
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: val,
                          title: '$percentage%',
                          showTitle: val / total > 0.05,
                          radius: 70,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final val = (item['value'] as num).toDouble();
                        final percentage = (val / total * 100).toStringAsFixed(1);
                        return _buildLegendItem(
                          colors[index % colors.length],
                          item['name'],
                          val.toInt().toString(),
                          percentage,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 45,
                      sections: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final val = (item['value'] as num).toDouble();
                        final percentage = (val / total * 100).toStringAsFixed(0);
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: val,
                          title: '$percentage%',
                          showTitle: val / total > 0.05,
                          radius: 80,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: data.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final val = (item['value'] as num).toDouble();
                          final percentage = (val / total * 100).toStringAsFixed(1);
                          return _buildLegendItem(
                            colors[index % colors.length],
                            item['name'],
                            val.toInt().toString(),
                            percentage,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            );
      }
    );
  }

  Widget _buildStatusDistributionChart() {
    final rawData = _dashboardData?['status_distribution'] as List?;
    if (rawData == null || rawData.isEmpty) return const Center(child: Text('Нет данных'));

    // Sort data by value in descending order
    final data = List.from(rawData);
    data.sort((a, b) => (b['value'] as num).compareTo(a['value'] as num));

    final total = data.fold<double>(0, (sum, item) => sum + (item['value'] as num).toDouble());

    final colors = [
      Colors.amber, Colors.lightBlue, Colors.lightGreen, Colors.deepOrange,
      Colors.indigoAccent, Colors.pinkAccent, Colors.tealAccent, Colors.purpleAccent
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < 450;
        return useColumn
          ? Column(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final val = (item['value'] as num).toDouble();
                        final percentage = (val / total * 100).toStringAsFixed(0);
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: val,
                          title: '$percentage%',
                          showTitle: val / total > 0.05,
                          radius: 75,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final val = (item['value'] as num).toDouble();
                        final percentage = (val / total * 100).toStringAsFixed(1);
                        return _buildLegendItem(
                          colors[index % colors.length],
                          item['name'],
                          val.toInt().toString(),
                          percentage,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final val = (item['value'] as num).toDouble();
                        final percentage = (val / total * 100).toStringAsFixed(0);
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: val,
                          title: '$percentage%',
                          showTitle: val / total > 0.05,
                          radius: 85,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: data.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final val = (item['value'] as num).toDouble();
                          final percentage = (val / total * 100).toStringAsFixed(1);
                          return _buildLegendItem(
                            colors[index % colors.length],
                            item['name'],
                            val.toInt().toString(),
                            percentage,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            );
      }
    );
  }

  Widget _buildLegendItem(Color color, String label, String value, String percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$value ($percentage%)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTopResearchersList() {
    final data = _dashboardData?['top_researchers'] as List?;
    if (data == null || data.isEmpty) return const Center(child: Text('Нет данных'));

    return ListView.separated(
      itemCount: data.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = data[index];
        final totalPoints = ((item['total_points'] as num?)?.toDouble() ?? (item['points'] as num?)?.toDouble() ?? 0.0);
        final achPoints = (item['achievement_points'] as num?)?.toDouble() ?? 0.0;
        final devPoints = (item['dev_points'] as num?)?.toDouble() ?? 0.0;
        final hasBreakdown = achPoints > 0 || devPoints > 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: index < 3 ? AppColors.primary : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}', 
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: index < 3 ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'], 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (hasBreakdown) ...[
                      const SizedBox(height: 3),
                      Text(
                        'дост.: ${achPoints.toStringAsFixed(1)}  разр.: ${devPoints.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                totalPoints.toStringAsFixed(1), 
                style: const TextStyle(
                  fontWeight: FontWeight.w800, 
                  color: AppColors.primary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'б.', 
                style: TextStyle(
                  fontSize: 12, 
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicsChart() {
    final data = _dashboardData?['dynamics'] as List?;
    if (data == null || data.isEmpty) return const Center(child: Text('Нет данных'));

    final maxVal = data.fold<double>(0, (max, item) {
      final val = (item['value'] as num).toDouble();
      return val > max ? val : max;
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal > 0 ? maxVal * 1.2 : 10,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: AppColors.primary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toInt().toString(),
                const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (item['value'] as num).toDouble(),
                color: AppColors.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  final dateParts = data[index]['date'].toString().split('-');
                  final monthNum = dateParts.length > 1 ? dateParts[1] : dateParts[0];
                  
                  const monthNames = {
                    '01': 'Янв', '02': 'Фев', '03': 'Мар', '04': 'Апр',
                    '05': 'Май', '06': 'Июн', '07': 'Июл', '08': 'Авг',
                    '09': 'Сен', '10': 'Окт', '11': 'Ноя', '12': 'Дек',
                  };
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      monthNames[monthNum] ?? monthNum,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true, border: Border.all(color: AppColors.divider)),
      ),
    );
  }

  String _getFilterDisplayValue(Map<String, dynamic> filter) {
    if (filter['value'] == null || filter['value'].toString().isEmpty) {
      return 'Все';
    }
    final options = filter['options'] as List?;
    if (options == null || options.isEmpty) {
      return filter['value'].toString();
    }
    try {
      final selected = options.firstWhere(
        (opt) => opt['id'].toString() == filter['value'].toString(),
        orElse: () => null,
      );
      return selected != null ? (selected['title'] ?? selected['name'] ?? filter['value'].toString()) : filter['value'].toString();
    } catch (_) {
      return filter['value'].toString();
    }
  }

  Widget _buildFilterItem(Map<String, dynamic> filter, Function(VoidCallback) setModalState) {
    final LayerLink layerLink = filter['layerLink'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(filter['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (filter['type'] == 'select')
            CompositedTransformTarget(
              link: layerLink,
              child: Builder(
                builder: (context) => InkWell(
                  onTap: () async {
                    if (filter['isLoaded'] == false && filter['isLoadingOptions'] == false && filter['selector_url'] != null) {
                      setModalState(() => filter['isLoadingOptions'] = true);
                      try {
                        final response = await _reportService.getSelectorOptions(filter['selector_url'], limit: 10, offset: 0);
                        if (mounted) {
                          setModalState(() {
                            filter['options'] = response['items'];
                            filter['totalCount'] = response['pagination']['total'];
                            filter['offset'] = 0;
                            filter['isLoadingOptions'] = false;
                            filter['isLoaded'] = true;
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          setModalState(() => filter['isLoadingOptions'] = false);
                        }
                        return;
                      }
                    }

                    if (filter['isLoadingOptions'] == true) return;

                    final RenderBox button = context.findRenderObject() as RenderBox;
                    final Offset buttonPosition = button.localToGlobal(Offset.zero);
                    final double screenHeight = MediaQuery.of(context).size.height;
                    final double spaceBelow = screenHeight - buttonPosition.dy - button.size.height;
                    final bool showAbove = spaceBelow < 350; // threshold for showing above

                    // Show custom dropdown as an OverlayEntry
                    OverlayEntry? overlayEntry;
                    
                    final scrollController = ScrollController();
                    scrollController.addListener(() async {
                      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 50) {
                        final options = filter['options'] as List;
                        final total = filter['totalCount'] as int;
                        final offset = filter['offset'] as int;
                        
                        if (options.length < total && filter['isLoadingOptions'] == false) {
                          setModalState(() => filter['isLoadingOptions'] = true);
                          overlayEntry?.markNeedsBuild();
                          try {
                            final nextOffset = offset + 10;
                            final response = await _reportService.getSelectorOptions(
                              filter['selector_url'], 
                              limit: 10, 
                              offset: nextOffset
                            );
                            if (mounted) {
                              setModalState(() {
                                filter['options'].addAll(response['items']);
                                filter['offset'] = nextOffset;
                                filter['isLoadingOptions'] = false;
                              });
                              overlayEntry?.markNeedsBuild();
                            }
                          } catch (e) {
                            if (mounted) {
                              setModalState(() => filter['isLoadingOptions'] = false);
                              overlayEntry?.markNeedsBuild();
                            }
                          }
                        }
                      }
                    });

                    overlayEntry = OverlayEntry(
                      builder: (context) => Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              overlayEntry?.remove();
                              overlayEntry = null;
                            },
                            child: Container(color: Colors.transparent),
                          ),
                          CompositedTransformFollower(
                            link: layerLink,
                            showWhenUnlinked: false,
                            followerAnchor: showAbove ? Alignment.bottomLeft : Alignment.topLeft,
                            targetAnchor: showAbove ? Alignment.topLeft : Alignment.bottomLeft,
                            offset: Offset(0, showAbove ? -8 : 8),
                            child: Material(
                              elevation: 16,
                              borderRadius: BorderRadius.circular(16),
                              shadowColor: AppColors.textPrimary.withOpacity(0.3),
                              child: Container(
                                constraints: BoxConstraints(
                                  maxHeight: showAbove 
                                    ? (buttonPosition.dy - 100).clamp(200.0, 400.0) 
                                    : 400, 
                                  maxWidth: button.size.width, 
                                  minWidth: button.size.width,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textOnPrimary,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primaryLight),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        controller: scrollController,
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: (filter['options'] as List).length + 1,
                                        itemBuilder: (context, index) {
                                          if (index == 0) {
                                            return ListTile(
                                              dense: true,
                                              visualDensity: VisualDensity.compact,
                                              title: const Text('Все', style: TextStyle(fontWeight: FontWeight.bold)),
                                              onTap: () {
                                                setModalState(() => filter['value'] = '');
                                                overlayEntry?.remove();
                                                overlayEntry = null;
                                              },
                                              selected: filter['value'] == '',
                                              selectedTileColor: AppColors.primaryLight,
                                            );
                                          }
                                          final opt = filter['options'][index - 1];
                                          return ListTile(
                                            dense: true,
                                            visualDensity: VisualDensity.compact,
                                            title: Text(
                                              opt['title'] ?? opt['name'] ?? '',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                            onTap: () {
                                              setModalState(() => filter['value'] = opt['id'].toString());
                                              overlayEntry?.remove();
                                              overlayEntry = null;
                                            },
                                            selected: filter['value'] == opt['id'].toString(),
                                            selectedTileColor: AppColors.primaryLight,
                                          );
                                        },
                                      ),
                                    ),
                                    if (filter['isLoadingOptions'] == true)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: SizedBox(
                                            width: 16, 
                                            height: 16, 
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    Overlay.of(context).insert(overlayEntry!);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: const OutlineInputBorder(),
                      suffixIcon: filter['isLoadingOptions'] == true 
                        ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                        : const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(_getFilterDisplayValue(filter), style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            )
          else if (filter['type'] == 'date')
            _buildInlineDateRangePicker(filter, setModalState)
          else
            TextField(
              decoration: const InputDecoration(
                hintText: 'Введите значение...', 
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => filter['value'] = val,
            ),
        ],
      ),
    );
  }

  void _addFilter() {
    if (_selectedReportId == null) return;
    final reportFilterIds = _reportFilters[_selectedReportId] ?? [];
    if (reportFilterIds.isNotEmpty) {
      final filterId = reportFilterIds[0];
      final meta = _filterMetadata[filterId] ?? {};
      _activeFilters.add({
        'field': filterId,
        'operator': 'eq',
        'value': '',
        'title': meta['title'] ?? filterId,
        'type': filterId == 'points' ? 'number' : (filterId == 'submission_date' ? 'date' : (meta['url'] != null ? 'select' : 'text')),
        'selector_url': meta['url'],
        'options': [],
        'isLoadingOptions': false,
        'isLoaded': false,
        'totalCount': 0,
        'offset': 0,
        'layerLink': LayerLink(),
      });
    }
  }

  Widget _buildReportTable(Function(VoidCallback) setModalState) {
    final data = _reportResult?['data'] as List?;
    final totals = _reportResult?['column_totals'] as Map?;

    if (data == null || data.isEmpty) {
      return const Center(child: Text('Нет данных для отображения'));
    }

    if (_selectedReportId == 'researchers_report') {
      return _buildGroupedResearchersTable(data, totals, setModalState);
    }

    if (_selectedReportId == 'teams') {
      return _buildTeamsTable(data, totals, setModalState);
    }

    if (_selectedReportId == 'dev_teams_report') {
      return _buildDevTeamsTable(data, totals, setModalState);
    }

    if (_selectedReportId == 'dev_researchers_report') {
      return _buildDevResearchersTable(data, totals, setModalState);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 56,
                headingTextStyle: const TextStyle(
                  color: AppColors.textPrimary, 
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                columnSpacing: 24,
                horizontalMargin: 24,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.divider, width: 0.5),
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                ),
                columns: [
                  _buildSortableColumn('ID', 'id', setModalState),
                  _buildSortableColumn('Исследователь', 'r.surname', setModalState),
                  const DataColumn(label: Text('Достижение')),
                  _buildSortableColumn('Баллы', 'a.points', setModalState),
                  const DataColumn(label: Text('Статус')),
                  const DataColumn(label: Text('Результат')),
                  const DataColumn(label: Text('Роль')),
                ],
                rows: [
                  ...data.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item['id'].toString())),
                      DataCell(Text(item['researcher'] ?? item['researcher_name'] ?? '')),
                      DataCell(Text(item['achievement'] ?? '')),
                      DataCell(Text(((item['points'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1))),
                      DataCell(Text(item['status'] ?? '')),
                      DataCell(Text(item['result'] ?? '')),
                      DataCell(Text(item['participation'] ?? '')),
                    ]);
                  }).toList(),
                  if (totals != null && totals.containsKey('points'))
                    DataRow(
                      color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.05)),
                      cells: [
                        const DataCell(Text('ИТОГО', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        DataCell(Text(((totals['points'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildGroupedResearchersTable(List data, Map? totals, Function(VoidCallback) setModalState) {
    List<DataRow> rows = [];
    int? lastResearcherId;
    double researcherSubtotal = 0;
    double lastDevPoints = 0;

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final researcherId = item['researcher_id'];
      final researcherName = item['researcher_name'] ?? '';
      final points = (item['points'] as num?)?.toDouble() ?? 0.0;
      final devPoints = (item['dev_points'] as num?)?.toDouble() ?? 0.0;

      if (lastResearcherId != null && lastResearcherId != researcherId) {
        final combined = researcherSubtotal + lastDevPoints;
        rows.add(DataRow(
          color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.05)),
          cells: [
            const DataCell(Text('')),
            const DataCell(Text('Итого по сотруднику', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
            const DataCell(Text('')),
            DataCell(Text(researcherSubtotal.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            DataCell(Text(lastDevPoints.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
            DataCell(Text(combined.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
          ],
        ));
        researcherSubtotal = 0;
      }

      rows.add(DataRow(
        cells: [
          DataCell(Text(item['id'].toString())),
          DataCell(
            Text(
              researcherName, 
              style: TextStyle(
                color: lastResearcherId == researcherId ? Colors.transparent : AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              )
            )
          ),
          DataCell(Text(item['achievement'] ?? '')),
          DataCell(Text(points.toStringAsFixed(1))),
          DataCell(Text(item['status'] ?? '')),
          DataCell(Text(item['result'] ?? '')),
          DataCell(Text(item['participation'] ?? '')),
          const DataCell(Text('')),
          const DataCell(Text('')),
        ],
      ));

      lastResearcherId = researcherId;
      lastDevPoints = devPoints;
      researcherSubtotal += points;
    }

    // Last subtotal
    if (lastResearcherId != null) {
      final combined = researcherSubtotal + lastDevPoints;
      rows.add(DataRow(
        color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.05)),
        cells: [
          const DataCell(Text('')),
          const DataCell(Text('Итого по сотруднику', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
          const DataCell(Text('')),
          DataCell(Text(researcherSubtotal.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          DataCell(Text(lastDevPoints.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
          DataCell(Text(combined.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
        ],
      ));
    }

    // Grand total
    if (totals != null && totals.containsKey('points')) {
      final totalDev = (totals['dev_points'] as num?)?.toDouble() ?? 0.0;
      final totalAch = (totals['points'] as num?)?.toDouble() ?? 0.0;
      final totalCombined = totalAch + totalDev;
      rows.add(DataRow(
        color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.1)),
        cells: [
          const DataCell(Text('ИТОГО', style: TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          DataCell(Text(totalAch.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          DataCell(Text(totalDev.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          DataCell(Text(totalCombined.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary))),
        ],
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 56,
                headingTextStyle: const TextStyle(
                  color: AppColors.textPrimary, 
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                columnSpacing: 24,
                horizontalMargin: 24,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.divider, width: 0.5),
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                ),
                columns: [
                  _buildSortableColumn('ID', 'id', setModalState),
                  _buildSortableColumn('Исследователь', 'r.surname', setModalState),
                  const DataColumn(label: Text('Достижение')),
                  _buildSortableColumn('Баллы достижений', 'a.points', setModalState),
                  const DataColumn(label: Text('Статус')),
                  const DataColumn(label: Text('Результат')),
                  const DataColumn(label: Text('Роль')),
                  _buildSortableColumn('Баллы разработки', 'dev_points', setModalState),
                  _buildSortableColumn('Итоговые баллы', 'combined_points', setModalState),
                ],
                rows: rows,
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildTeamsTable(List data, Map? totals, Function(VoidCallback) setModalState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 56,
                headingTextStyle: const TextStyle(
                  color: AppColors.textPrimary, 
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                columnSpacing: 24,
                horizontalMargin: 24,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.divider, width: 0.5),
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                ),
                columns: [
                  _buildSortableColumn('ID', 'id', setModalState),
                  _buildSortableColumn('Название команды', 'title', setModalState),
                  const DataColumn(label: Text('Руководитель')),
                  _buildSortableColumn('Кол-во участников', 'members_count', setModalState),
                  _buildSortableColumn('Баллы достижений', 'total_points', setModalState),
                  _buildSortableColumn('Баллы разработки', 'dev_points', setModalState),
                  _buildSortableColumn('Итоговые баллы', 'combined_points', setModalState),
                ],
                rows: [
                  ...data.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item['id'].toString())),
                      DataCell(Text(item['title'] ?? '')),
                      DataCell(Text(item['leader_name'] ?? '')),
                      DataCell(Text(item['members_count'].toString())),
                      DataCell(Text(((item['total_points'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1))),
                      DataCell(Text(((item['dev_points'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1))),
                      DataCell(Text(((item['combined_points'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
                    ]);
                  }).toList(),
                  if (totals != null)
                    DataRow(
                      color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.05)),
                      cells: [
                        const DataCell(Text('ИТОГО', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        DataCell(Text(totals['members_count']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text((totals['total_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text((totals['dev_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text((totals['combined_points'] as num?)?.toDouble().toStringAsFixed(1) ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildDevTeamsTable(List data, Map? totals, Function(VoidCallback) setModalState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 56,
                headingTextStyle: const TextStyle(
                  color: AppColors.textPrimary, 
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                columnSpacing: 24,
                horizontalMargin: 24,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.divider, width: 0.5),
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                ),
                columns: [
                  _buildSortableColumn('Название команды', 'team', setModalState),
                  _buildSortableColumn('Критерии проекта', 'criteria_sum', setModalState),
                  const DataColumn(label: Text('Выполненные критерии')),
                  _buildSortableColumn('Активность (сумма)', 'activity_sum', setModalState),
                  _buildSortableColumn('Общий балл', 'total_score', setModalState),
                ],
                rows: [
                  ...data.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item['team'] ?? '')),
                      DataCell(Text(((item['criteria_sum'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1))),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            item['criteria_list'] ?? '',
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        onTap: (item['criteria_list'] ?? '').toString().isNotEmpty ? () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Критерии: ${item['team']}'),
                              content: SingleChildScrollView(
                                child: Text(item['criteria_list'] ?? ''),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
                              ],
                            ),
                          );
                        } : null,
                      ),
                      DataCell(Text(((item['activity_sum'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1))),
                      DataCell(Text(((item['total_score'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
                    ]);
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildDevResearchersTable(List data, Map? totals, Function(VoidCallback) setModalState) {
    // Group rows by (researcher_id, team) to guarantee grouping regardless of backend sort order
    final Map<String, List<dynamic>> groupMap = {};
    final List<String> groupKeys = [];
    for (var item in data) {
      final key = '${item['researcher_id']}|${item['team'] ?? ''}';
      if (!groupMap.containsKey(key)) {
        groupMap[key] = [];
        groupKeys.add(key);
      }
      groupMap[key]!.add(item);
    }

    // Sort groups by aggregate field so the user's chosen sort applies to researchers, not rows
    groupKeys.sort((a, b) {
      final aFirst = groupMap[a]!.first;
      final bFirst = groupMap[b]!.first;
      int cmp;
      switch (_sortField) {
        case 'dev_points':
          cmp = ((aFirst['dev_points'] as num?)?.toDouble() ?? 0.0)
              .compareTo((bFirst['dev_points'] as num?)?.toDouble() ?? 0.0);
          break;
        case 'criteria_sum':
          cmp = ((aFirst['criteria_sum'] as num?)?.toDouble() ?? 0.0)
              .compareTo((bFirst['criteria_sum'] as num?)?.toDouble() ?? 0.0);
          break;
        case 'team':
          cmp = (aFirst['team'] ?? '').toString()
              .compareTo((bFirst['team'] ?? '').toString());
          break;
        case 'researcher':
        default:
          cmp = (aFirst['researcher'] ?? '').toString()
              .compareTo((bFirst['researcher'] ?? '').toString());
      }
      return _sortDescending ? -cmp : cmp;
    });

    final List<DataRow> rows = [];

    void _flushGroupRow(double groupActivitySum, double groupDevPoints, double groupCriteriaSum) {
      rows.add(DataRow(
        color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.05)),
        cells: [
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('Итого по сотруднику', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          DataCell(Text(groupActivitySum.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(groupCriteriaSum.toStringAsFixed(1))),
          DataCell(Text(groupDevPoints.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
        ],
      ));
    }

    for (final key in groupKeys) {
      final groupItems = groupMap[key]!;
      double groupActivitySum = 0;
      double groupDevPoints = 0;
      double groupCriteriaSum = 0;

      for (var i = 0; i < groupItems.length; i++) {
        final item = groupItems[i];
        final researcherName = (item['researcher'] ?? '').toString();
        final team = (item['team'] ?? '').toString();
        final activityType = (item['activity_type'] ?? '').toString();
        final count = (item['count'] as num?)?.toInt() ?? 0;
        final typePoints = (item['type_points'] as num?)?.toDouble() ?? 0.0;
        final activityPoints = (item['activity_points'] as num?)?.toDouble() ?? 0.0;
        final criteriaSum = (item['criteria_sum'] as num?)?.toDouble() ?? 0.0;
        final devPoints = (item['dev_points'] as num?)?.toDouble() ?? 0.0;

        rows.add(DataRow(
          cells: [
            DataCell(Text(
              researcherName,
              style: TextStyle(
                color: i == 0 ? AppColors.primaryDark : Colors.transparent,
                fontWeight: FontWeight.bold,
              ),
            )),
            DataCell(Text(i == 0 ? team : '')),
            DataCell(Text(activityType)),
            DataCell(Text(count.toString())),
            DataCell(Text(typePoints.toStringAsFixed(1))),
            DataCell(Text(activityPoints.toStringAsFixed(1))),
            const DataCell(Text('')),
            const DataCell(Text('')),
          ],
        ));

        groupActivitySum += activityPoints;
        groupDevPoints = devPoints;
        groupCriteriaSum = criteriaSum;
      }

      _flushGroupRow(groupActivitySum, groupDevPoints, groupCriteriaSum);
    }

    if (totals != null && totals.containsKey('dev_points')) {
      rows.add(DataRow(
        color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.1)),
        cells: [
          const DataCell(Text('ИТОГО', style: TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          DataCell(Text(
            (totals['dev_points'] as num).toDouble().toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          )),
        ],
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 56,
                headingTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                columnSpacing: 24,
                horizontalMargin: 24,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: AppColors.divider, width: 0.5),
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                ),
                columns: [
                  _buildSortableColumn('Сотрудник', 'researcher', setModalState),
                  _buildSortableColumn('Команда', 'team', setModalState),
                  _buildSortableColumn('Тип активности', 'activity_type', setModalState),
                  const DataColumn(label: Text('Кол-во')),
                  const DataColumn(label: Text('Баллы / ед.')),
                  _buildSortableColumn('Баллы', 'activity_points', setModalState),
                  _buildSortableColumn('Критерии проекта', 'criteria_sum', setModalState),
                  _buildSortableColumn('Итого баллов', 'dev_points', setModalState),
                ],
                rows: rows,
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _buildSortableColumn(String label, String field, Function(VoidCallback) setModalState) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              setModalState(() {
                if (_sortField == field) {
                  _sortDescending = !_sortDescending;
                } else {
                  _sortField = field;
                  _sortDescending = false;
                }
                _currentPage = 0;
              });
              _generateReport().then((_) => setModalState(() {}));
            },
            child: Icon(
              _sortField == field 
                ? (_sortDescending ? Icons.arrow_downward : Icons.arrow_upward)
                : Icons.sort,
              size: 16,
              color: _sortField == field ? AppColors.primary : AppColors.primary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineDateRangePicker(Map<String, dynamic> filter, Function(VoidCallback) setModalState, {bool isDashboard = false, Function(DateTime, DateTime)? onApply}) {
    final parts = filter['value'].toString().split(',');
    final startStr = parts[0];
    final endStr = (parts.length > 1) ? parts[1] : '';
    
    final start = startStr.isEmpty ? null : DateTime.tryParse(startStr);
    final end = endStr.isEmpty ? null : DateTime.tryParse(endStr);

    final viewMonth = _currentCalendarMonth;
    final firstDayOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun

    const weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const monthNames = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDashboard ? null : Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Manual Entry
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: startStr)..selection = TextSelection.fromPosition(TextPosition(offset: startStr.length)),
                  decoration: const InputDecoration(
                    labelText: 'От',
                    hintText: 'ГГГГ-ММ-ДД',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 11),
                  onSubmitted: (val) {
                    final date = DateTime.tryParse(val);
                    if (date != null) {
                      setModalState(() {
                        filter['value'] = '${date.toIso8601String().split('T')[0]},$endStr';
                        _currentCalendarMonth = DateTime(date.year, date.month);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: endStr)..selection = TextSelection.fromPosition(TextPosition(offset: endStr.length)),
                  decoration: const InputDecoration(
                    labelText: 'До',
                    hintText: 'ГГГГ-ММ-ДД',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 11),
                  onSubmitted: (val) {
                    final date = DateTime.tryParse(val);
                    if (date != null) {
                      setModalState(() {
                        filter['value'] = '$startStr,${date.toIso8601String().split('T')[0]}';
                        _currentCalendarMonth = DateTime(date.year, date.month);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Month/Year Picker Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 16),
                onPressed: () => setModalState(() => _currentCalendarMonth = DateTime(viewMonth.year, viewMonth.month - 1)),
                visualDensity: VisualDensity.compact,
              ),
              // Month Dropdown
              DropdownButton<int>(
                value: viewMonth.month,
                isDense: true,
                underline: const SizedBox(),
                items: List.generate(12, (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(monthNames[index], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )),
                onChanged: (m) => setModalState(() => _currentCalendarMonth = DateTime(viewMonth.year, m!)),
              ),
              // Year Dropdown
              DropdownButton<int>(
                value: viewMonth.year,
                isDense: true,
                underline: const SizedBox(),
                items: List.generate(21, (index) => DropdownMenuItem(
                  value: 2020 + index,
                  child: Text('${2020 + index}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )),
                onChanged: (y) => setModalState(() => _currentCalendarMonth = DateTime(y!, viewMonth.month)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 16),
                onPressed: () => setModalState(() => _currentCalendarMonth = DateTime(viewMonth.year, viewMonth.month + 1)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...weekDays.map((d) => Center(child: Text(d, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
              for (int i = 1; i < firstWeekday; i++) const SizedBox(),
              for (int day = 1; day <= daysInMonth; day++) 
                (() {
                  final date = DateTime(viewMonth.year, viewMonth.month, day);
                  bool isStart = start != null && date.year == start.year && date.month == start.month && date.day == start.day;
                  bool isEnd = end != null && date.year == end.year && date.month == end.month && date.day == end.day;
                  bool inRange = start != null && end != null && date.isAfter(start) && date.isBefore(end);

                  return InkWell(
                    onTap: () {
                      final dateStr = date.toIso8601String().split('T')[0];
                      if (start == null || (start != null && end != null)) {
                        setModalState(() => filter['value'] = '$dateStr,');
                      } else {
                        if (date.isBefore(start)) {
                          setModalState(() => filter['value'] = '$dateStr,');
                        } else {
                          setModalState(() => filter['value'] = '${start.toIso8601String().split('T')[0]},$dateStr');
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isStart || isEnd) ? AppColors.primary : (inRange ? AppColors.primary.withOpacity(0.1) : null),
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular((isStart || !inRange) ? 4 : 0),
                          right: Radius.circular((isEnd || !inRange) ? 4 : 0),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$day', 
                          style: TextStyle(
                            fontSize: 11, 
                            color: (isStart || isEnd) ? AppColors.textOnPrimary : AppColors.textPrimary,
                            fontWeight: (isStart || isEnd) ? FontWeight.bold : FontWeight.normal,
                          )
                        ),
                      ),
                    ),
                  );
                })(),
            ],
          ),
          if (isDashboard)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton(
                onPressed: (start != null && end != null) ? () => onApply?.call(start, end) : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 36),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('Применить'),
              ),
            ),
          if (!isDashboard && filter['value'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                children: [
                  const Divider(height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setModalState(() => filter['value'] = ''),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                        child: const Text('Сбросить', style: TextStyle(fontSize: 10, color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagination(Function(VoidCallback) setModalState) {
    final totalCount = _reportResult?['total_count'] ?? 0;
    final totalPages = (totalCount / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Страница ${_currentPage + 1} из $totalPages', 
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)
          ),
          const SizedBox(width: 8),
          Text(
            '(всего $totalCount записей)', 
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)
          ),
          const SizedBox(width: 32),
          _paginationButton(
            Icons.chevron_left, 
            _currentPage > 0 ? () {
              setModalState(() => _currentPage--);
              _generateReport().then((_) => setModalState(() {}));
            } : null
          ),
          const SizedBox(width: 8),
          _paginationButton(
            Icons.chevron_right, 
            _currentPage < totalPages - 1 ? () {
              setModalState(() => _currentPage++);
              _generateReport().then((_) => setModalState(() {}));
            } : null
          ),
        ],
      ),
    );
  }

  Widget _paginationButton(IconData icon, VoidCallback? onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: onPressed == null ? Colors.transparent : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: onPressed == null ? AppColors.divider : AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        color: onPressed == null ? AppColors.textTertiary : AppColors.primary,
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }
}
