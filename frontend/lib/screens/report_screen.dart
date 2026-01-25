import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/report_service.dart';
import '../services/socket_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
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
  };

  static const Map<String, List<String>> _reportFilters = {
    'researchers_report': ['submission_date', 'researcher_id', 'team_id', 'status', 'achievement_result_id', 'achievement_participation_id'],
    'teams': ['team_id'],
  };

  static const Map<String, List<String>> _reportSorts = {
    'researchers_report': ['r.surname', 'a.points', 'id'],
    'teams': ['title', 'total_points', 'members_count', 'id'],
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
      'title': 'Лидер',
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
  };

  static const Map<String, String> _sortTitles = {
    'r.surname': 'Фамилия',
    'a.points': 'Баллы',
    'a.created_at': 'Дата создания',
    'id': 'ID',
    'at.title': 'Достижение',
    's.title': 'Статус',
    'title': 'Название',
    'total_points': 'Всего баллов',
    'members_count': 'Участники',
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
    if (!kIsWeb) {
      SocketService().disconnect();
    }
    super.dispose();
  }

  void _initSocket() {
    if (kIsWeb) return;
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
        'type': id == 'points' ? 'number' : (id == 'submission_date' ? 'date' : (meta['url'] != null ? 'select' : 'text')),
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
              appBar: AppBar(
                title: Text(_reportTitles[reportId] ?? 'Отчет'),
                actions: [
                  TextButton.icon(
                    onPressed: () => _exportReport('csv'),
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('ЭКСПОРТ CSV', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: Row(
                children: [
                  // LEFT PANEL: FILTERS
                  Container(
                    width: 300,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.grey[300]!)),
                      color: Colors.grey[50],
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Фильтры', style: AppTextStyles.h3),
                        const Divider(),
                        ..._activeFilters.map((f) => _buildFilterItem(f, (fn) {
                          setModalState(fn);
                        })),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _generateReport().then((_) => setModalState(() {}));
                          },
                          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                          child: const Text('Применить'),
                        ),
                      ],
                    ),
                  ),
                  // RIGHT PANEL: TABLE
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _isGenerating 
                            ? const Center(child: CircularProgressIndicator())
                            : _buildReportTable(setModalState),
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

  void _exportReport(String format) async {
    try {
      final params = {
        'report_type': _selectedReportId,
        'report_format': format,
        'filters': _activeFilters,
        'limit': 1000,
        'offset': 0,
      };
      final result = await _reportService.generateReport(params);
      // In real app: save file
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отчет успешно экспортирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
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
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey[300]!)),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Доступные отчеты', style: AppTextStyles.h2),
                    ),
                    ...((_selectors?['report_types'] as List?) ?? []).map((report) {
                      final reportId = report['id'];
                      return ListTile(
                        leading: const Icon(Icons.analytics_outlined, color: AppColors.primary),
                        title: Text(_reportTitles[reportId] ?? reportId),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => _openReportDetail(reportId),
                      );
                    }).toList(),
                  ],
                ),
        ),
        // RIGHT SIDE: DASHBOARD CHARTS
        Expanded(
          child: Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Обзор активности', style: AppTextStyles.h1),
                    _buildDashboardPeriodSelector(),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.4,
                    children: [
                      _buildDashboardChart(
                        'Распределение по типам', 
                        Icons.pie_chart,
                        _buildTypeDistributionChart(),
                      ),
                      _buildDashboardChart(
                        _dashboardStartDate != null || _dashboardEndDate != null 
                            ? 'Динамика достижений' 
                            : 'Динамика достижений (год)', 
                        Icons.show_chart,
                        _buildDynamicsChart(),
                      ),
                      _buildDashboardChart(
                        _dashboardStartDate != null || _dashboardEndDate != null 
                            ? 'Топ исследователей' 
                            : 'Топ исследователей (3 мес.)', 
                        Icons.leaderboard,
                        _buildTopResearchersList(),
                      ),
                      _buildDashboardChart(
                        'Распределение по статусам', 
                        Icons.donut_large,
                        _buildStatusDistributionChart(),
                      ),
                    ],
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingDashboard 
                ? const Center(child: CircularProgressIndicator())
                : _dashboardData == null
                  ? Center(child: Icon(icon, size: 80, color: Colors.grey[200]))
                  : chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardPeriodSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_dashboardStartDate != null || _dashboardEndDate != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.clear, size: 20, color: Colors.red),
              onPressed: () {
                setState(() {
                  _dashboardStartDate = null;
                  _dashboardEndDate = null;
                  _dashboardPeriodLabel = 'Весь период';
                });
                _loadDashboardData();
              },
              tooltip: 'Сбросить период',
            ),
          ),
        CompositedTransformTarget(
          link: _dashboardPeriodLink,
          child: Builder(
            builder: (context) => OutlinedButton.icon(
              onPressed: () => _showDashboardPeriodDropdown(context),
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(_dashboardPeriodLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  borderRadius: BorderRadius.circular(4),
                  shadowColor: Colors.black.withOpacity(0.3),
                  child: Container(
                    width: showCalendar ? 300 : (button.size.width > 220 ? button.size.width : 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple[100]!),
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
                                  Divider(height: 1, color: Colors.purple[50]),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text(
                                    item['title']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                                      color: isCustom ? AppColors.primary : Colors.black87,
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
                                  hoverColor: Colors.purple[50],
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

    return Row(
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
            padding: const EdgeInsets.only(right: 72.0),
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
                    val.toStringAsFixed(1),
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

    return Row(
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
            padding: const EdgeInsets.only(right: 72.0),
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

  Widget _buildLegendItem(Color color, String label, String value, String percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
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

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text('${index + 1}', 
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              Text('${(item['points'] as num).toDouble().toStringAsFixed(1)} б.', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                  color: Colors.white,
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[300]!)),
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
                              borderRadius: BorderRadius.circular(4),
                              shadowColor: Colors.black.withOpacity(0.3),
                              child: Container(
                                constraints: BoxConstraints(
                                  maxHeight: showAbove 
                                    ? (buttonPosition.dy - 100).clamp(200.0, 400.0) 
                                    : 400, 
                                  maxWidth: button.size.width, 
                                  minWidth: button.size.width,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.purple[100]!),
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
                                              selectedTileColor: Colors.purple[50],
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
                                            selectedTileColor: Colors.purple[50],
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: const OutlineInputBorder(),
                      suffixIcon: filter['isLoadingOptions'] == true 
                        ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
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
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(AppColors.primaryDark),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                columnSpacing: 24,
                horizontalMargin: 12,
                border: TableBorder(
                  verticalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                  horizontalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
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
                      DataCell(Text((item['points'] as num).toDouble().toStringAsFixed(1))),
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
                        DataCell(Text((totals['points'] as num).toDouble().toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
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
    String? lastResearcherName;

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final researcherId = item['researcher_id'];
      final researcherName = item['researcher_name'] ?? '';
      final points = (item['points'] as num).toDouble();

      if (lastResearcherId != null && lastResearcherId != researcherId) {
        // Add subtotal row
        rows.add(DataRow(
          color: MaterialStateProperty.all(Colors.purple.withOpacity(0.05)),
          cells: [
            const DataCell(Text('')),
            const DataCell(Text('Итого по сотруднику', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
            const DataCell(Text('')),
            DataCell(Text(researcherSubtotal.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
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
                color: lastResearcherId == researcherId ? Colors.transparent : Colors.purple[900],
                fontWeight: FontWeight.bold,
              )
            )
          ),
          DataCell(Text(item['achievement'] ?? '')),
          DataCell(Text(points.toStringAsFixed(1))),
          DataCell(Text(item['status'] ?? '')),
          DataCell(Text(item['result'] ?? '')),
          DataCell(Text(item['participation'] ?? '')),
        ],
      ));

      lastResearcherId = researcherId;
      lastResearcherName = researcherName;
      researcherSubtotal += points;
    }

    // Last subtotal
    if (lastResearcherId != null) {
      rows.add(DataRow(
        color: MaterialStateProperty.all(Colors.purple.withOpacity(0.05)),
        cells: [
          const DataCell(Text('')),
          const DataCell(Text('Итого по сотруднику', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
          const DataCell(Text('')),
          DataCell(Text(researcherSubtotal.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
        ],
      ));
    }

    // Grand total
    if (totals != null && totals.containsKey('points')) {
      rows.add(DataRow(
        color: MaterialStateProperty.all(AppColors.primary.withOpacity(0.1)),
        cells: [
          const DataCell(Text('ИТОГО', style: TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          DataCell(Text(totals['points'].toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
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
                headingRowColor: MaterialStateProperty.all(AppColors.primaryDark),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                columnSpacing: 24,
                horizontalMargin: 12,
                border: TableBorder(
                  verticalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                  horizontalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
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
                headingRowColor: MaterialStateProperty.all(AppColors.primaryDark),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                columnSpacing: 24,
                horizontalMargin: 12,
                border: TableBorder(
                  verticalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                  horizontalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                columns: [
                  _buildSortableColumn('ID', 'id', setModalState),
                  _buildSortableColumn('Название команды', 'title', setModalState),
                  const DataColumn(label: Text('Лидер')),
                  _buildSortableColumn('Кол-во участников', 'members_count', setModalState),
                  _buildSortableColumn('Всего баллов', 'total_points', setModalState),
                ],
                rows: [
                  ...data.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item['id'].toString())),
                      DataCell(Text(item['title'] ?? '')),
                      DataCell(Text(item['leader_name'] ?? '')),
                      DataCell(Text(item['members_count'].toString())),
                      DataCell(Text((item['total_points'] as num).toDouble().toStringAsFixed(1))),
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

  DataColumn _buildSortableColumn(String label, String field, Function(VoidCallback) setModalState) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
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
              });
              _generateReport().then((_) => setModalState(() {}));
            },
            child: Icon(
              _sortField == field 
                ? (_sortDescending ? Icons.arrow_downward : Icons.arrow_upward)
                : Icons.sort,
              size: 16,
              color: _sortField == field ? Colors.white : Colors.white70,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: isDashboard ? null : Border.all(color: Colors.grey[300]!),
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
          const SizedBox(height: 12),
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
              ...weekDays.map((d) => Center(child: Text(d, style: const TextStyle(fontSize: 10, color: Colors.grey)))),
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
                            color: (isStart || isEnd) ? Colors.white : Colors.black,
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
              padding: const EdgeInsets.only(top: 12.0),
              child: ElevatedButton(
                onPressed: (start != null && end != null) ? () => onApply?.call(start, end) : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 36),
                  textStyle: const TextStyle(fontSize: 12),
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
                        child: const Text('Сбросить', style: TextStyle(fontSize: 10, color: Colors.red)),
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Страница ${_currentPage + 1} из $totalPages (всего $totalCount)'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0 ? () {
              setModalState(() => _currentPage--);
              _generateReport().then((_) => setModalState(() {}));
            } : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1 ? () {
              setModalState(() => _currentPage++);
              _generateReport().then((_) => setModalState(() {}));
            } : null,
          ),
        ],
      ),
    );
  }
}
