import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:research_activity_monitoring_system/core/auth/auth_notifier.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/entity_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/researcher/researcher_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/team/team_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_type_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_result_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_status_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_participation_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/dev/dev_activity_type_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/dev/dev_project_criterion_list_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/report/report_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/settings/settings_screen.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/presentation/widgets/custom_nav_button.dart';
import 'package:research_activity_monitoring_system/data/services/achievement_service.dart';
import 'package:research_activity_monitoring_system/core/l10n/l10n.dart';

int _importResultInt(Map<String, dynamic> map, String key) {
  final v = map[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentViewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.primary, width: 1)),
            color: AppColors.surface,
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: CustomNavButton(
                    index: 0,
                    currentIndex: _currentViewIndex,
                    label: s.tr('home.nav.reports'),
                    icon: Icons.analytics,
                    onTap: () => setState(() => _currentViewIndex = 0),
                  ),
                ),
                Expanded(
                  child: CustomNavButton(
                    index: 1,
                    currentIndex: _currentViewIndex,
                    label: s.tr('home.nav.import'),
                    icon: Icons.file_upload,
                    onTap: () => setState(() => _currentViewIndex = 1),
                  ),
                ),
                Expanded(
                  child: CustomNavButton(
                    index: 2,
                    currentIndex: _currentViewIndex,
                    label: s.tr('home.nav.directories'),
                    icon: Icons.menu_book,
                    onTap: () => setState(() => _currentViewIndex = 2),
                  ),
                ),
                IconButton(
                  tooltip: 'Выйти',
                  icon: const Icon(Icons.logout),
                  onPressed: () => context.read<AuthNotifier>().logout(),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildCurrentView(),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentViewIndex) {
      case 0:
        return Consumer<AuthNotifier>(
          builder: (context, auth, _) {
            if (!auth.isAuthenticated) {
              return const SizedBox.shrink();
            }
            return const ReportScreen();
          },
        );
      case 1:
        return _buildImportView();
      case 2:
        return _buildDirectoriesView();
      default:
        return Center(child: Text(context.strings.tr('home.page_not_found')));
    }
  }

  final _achievementService = AchievementService();
  bool _isImporting = false;

  Future<void> _importAchievements() async {
    await _handleImport(
      title: context.strings.tr('home.import.dialog_title_achievements'),
      onImport: (path, bytes, name) => _achievementService.importAchievements(
        filePath: path,
        bytes: bytes,
        fileName: name,
      ),
    );
  }

  Future<void> _importResearchers() async {
    await _handleImport(
      title: context.strings.tr('home.import.dialog_title_researchers'),
      onImport: (path, bytes, name) => _achievementService.importResearchers(
        filePath: path,
        bytes: bytes,
        fileName: name,
      ),
    );
  }

  Future<void> _handleImport({
    required String title,
    required Future<Map<String, dynamic>> Function(String? path, List<int>? bytes, String? name) onImport,
  }) async {
    final loc = context.strings;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'tsv', 'txt'],
      withData: true,
    );

    if (result != null) {
      final file = result.files.single;
      setState(() => _isImporting = true);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      try {
        String? path;
        if (!kIsWeb) {
          path = file.path;
        }

        final importResult = await onImport(path, file.bytes, file.name);

        if (mounted) Navigator.pop(context);

        final skippedDup = _importResultInt(importResult, 'skipped_duplicates');
        final skippedDel = _importResultInt(importResult, 'skipped_deleted_researcher');

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('${loc.tr('home.import.dialog_success')} ${importResult['success']}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('${loc.tr('home.import.dialog_errors')} ${importResult['failure']}'),
                    ],
                  ),
                  if (skippedDup > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.remove_circle_outline, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${loc.tr('home.import.dialog_skipped_duplicates')} $skippedDup'),
                        ),
                      ],
                    ),
                  ],
                  if (skippedDel > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_off, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${loc.tr('home.import.dialog_skipped_deleted_researcher')} $skippedDel'),
                        ),
                      ],
                    ),
                  ],
                  if (importResult['errors'] != null && (importResult['errors'] as List).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(loc.tr('home.import.dialog_error_details'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ... (importResult['errors'] as List).take(5).map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $e', style: const TextStyle(fontSize: 16, color: Colors.red)),
                    )),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.tr('common.ok')),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.tr('home.import.error_import')} $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isImporting = false);
      }
    }
  }

  Widget _buildImportView() {
    final s = context.strings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.tr('home.import.heading'), style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.paddingLarge),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.tr('home.import.achievements_csv_title'), style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Text(
                        s.tr('home.import.achievements_csv_body'),
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 16),
                      if (_isImporting)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton.icon(
                          onPressed: _importAchievements,
                          icon: const Icon(Icons.upload_file),
                          label: Text(s.tr('home.import.achievements_button')),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      const SizedBox(height: AppDimensions.paddingLarge),
                      const Divider(),
                      const SizedBox(height: AppDimensions.paddingLarge),
                      Text(s.tr('home.import.researchers_csv_title'), style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Text(
                        s.tr('home.import.researchers_csv_body'),
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 16),
                      if (_isImporting)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton.icon(
                          onPressed: _importResearchers,
                          icon: const Icon(Icons.people),
                          label: Text(s.tr('home.import.researchers_button')),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: AppColors.background,
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectoriesView() {
    final s = context.strings;
    final List<Map<String, dynamic>> directories = [
      {'key': 'employees', 'icon': Icons.people, 'data': ['Иванов И.И.', 'Петров П.П.', 'Сидоров С.С.']},
      {'key': 'projects', 'icon': Icons.assignment, 'data': ['Грант РФФИ 2024', 'Госзадание 1.1', 'Проект Приоритет 2030']},
      {'key': 'achievement_types', 'icon': Icons.category, 'data': ['Статья ВАК', 'Статья Scopus', 'Патент', 'Монография']},
      {'key': 'achievement_results', 'icon': Icons.emoji_events, 'data': ['Опубликовано', 'Принято в печать', 'Заявка подана']},
      {'key': 'achievement_statuses', 'icon': Icons.flag, 'data': ['В работе', 'На проверке', 'Завершено']},
      {'key': 'participation_types', 'icon': Icons.handshake, 'data': ['Руководитель', 'Исполнитель', 'Консультант']},
      {'key': 'dev_activity_types', 'icon': Icons.developer_mode, 'data': []},
      {'key': 'dev_project_criteria', 'icon': Icons.checklist, 'data': []},
      {'key': 'settings', 'icon': Icons.settings, 'data': []},
    ];

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: GridView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppDimensions.paddingMedium,
            mainAxisSpacing: AppDimensions.paddingMedium,
            childAspectRatio: 1.5,
          ),
          itemCount: directories.length,
          itemBuilder: (context, index) {
            final dir = directories[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final key = dir['key'] as String;
                  switch (key) {
                    case 'employees':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ResearcherListScreen(),
                        ),
                      );
                      return;
                    case 'projects':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TeamListScreen(),
                        ),
                      );
                      return;
                    case 'achievement_types':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementTypeListScreen(),
                        ),
                      );
                      return;
                    case 'achievement_results':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementResultListScreen(),
                        ),
                      );
                      return;
                    case 'achievement_statuses':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementStatusListScreen(),
                        ),
                      );
                      return;
                    case 'participation_types':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementParticipationListScreen(),
                        ),
                      );
                      return;
                    case 'dev_activity_types':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DevActivityTypeListScreen(),
                        ),
                      );
                      return;
                    case 'dev_project_criteria':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DevProjectCriterionListScreen(),
                        ),
                      );
                      return;
                    case 'settings':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                      return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EntityListScreen(
                        title: s.tr('home.directories.$key'),
                        items: List<String>.from(dir['data'] as List),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(dir['icon'], size: 32, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        s.tr('home.directories.${dir['key']}'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h3.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderView(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 64, color: AppColors.warning),
          const SizedBox(height: AppDimensions.paddingMedium),
          Text(text, style: AppTextStyles.h3),
        ],
      ),
    );
  }
}
