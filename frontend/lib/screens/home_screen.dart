import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'entity_list_screen.dart';
import 'researcher_list_screen.dart';
import 'team_list_screen.dart';
import 'achievement_type_list_screen.dart';
import 'achievement_result_list_screen.dart';
import 'achievement_status_list_screen.dart';
import 'achievement_participation_list_screen.dart';
import 'dev_activity_type_list_screen.dart';
import 'dev_project_criterion_list_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../widgets/custom_nav_button.dart';
import '../services/achievement_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentViewIndex = 0;

  final List<String> _viewTitles = ['Отчеты', 'Импорт', 'Справочники'];

  @override
  Widget build(BuildContext context) {
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
                    label: 'Отчеты',
                    icon: Icons.analytics,
                    onTap: () => setState(() => _currentViewIndex = 0),
                  ),
                ),
                Expanded(
                  child: CustomNavButton(
                    index: 1,
                    currentIndex: _currentViewIndex,
                    label: 'Импорт',
                    icon: Icons.file_upload,
                    onTap: () => setState(() => _currentViewIndex = 1),
                  ),
                ),
                Expanded(
                  child: CustomNavButton(
                    index: 2,
                    currentIndex: _currentViewIndex,
                    label: 'Справочники',
                    icon: Icons.menu_book,
                    onTap: () => setState(() => _currentViewIndex = 2),
                  ),
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
        return const ReportScreen();
      case 1:
        return _buildImportView();
      case 2:
        return _buildDirectoriesView();
      default:
        return const Center(child: Text('Страница не найдена'));
    }
  }

  final _achievementService = AchievementService();
  bool _isImporting = false;

  Future<void> _importAchievements() async {
    await _handleImport(
      title: 'Импорт достижений',
      onImport: (path, bytes, name) => _achievementService.importAchievements(
        filePath: path,
        bytes: bytes,
        fileName: name,
      ),
    );
  }

  Future<void> _importResearchers() async {
    await _handleImport(
      title: 'Импорт сотрудников',
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
                      Text('Успешно: ${importResult['success']}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Ошибок: ${importResult['failure']}'),
                    ],
                  ),
                  if (importResult['errors'] != null && (importResult['errors'] as List).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Детали ошибок (первые 5):', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: const Text('OK'),
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
              content: Text('Ошибка импорта: $e'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Импорт данных', style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.paddingLarge),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Импорт достижений из CSV', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      const Text(
                        'Загрузите файл CSV с достижениями для автоматического создания '
                        'сотрудников, сопоставления типов достижений и их полей.',
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 16),
                      if (_isImporting)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton.icon(
                          onPressed: _importAchievements,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Выбрать файл и импортировать достижения'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      const SizedBox(height: AppDimensions.paddingLarge),
                      const Divider(),
                      const SizedBox(height: AppDimensions.paddingLarge),
                      const Text('Импорт сотрудников из CSV', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      const Text(
                        'Загрузите файл CSV со списком сотрудников (ФИО, Руководитель, Факультет и др.) '
                        'для массового обновления базы данных.',
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 16),
                      if (_isImporting)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton.icon(
                          onPressed: _importResearchers,
                          icon: const Icon(Icons.people),
                          label: const Text('Выбрать файл и импортировать сотрудников'),
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
    final List<Map<String, dynamic>> directories = [
      {'title': 'Сотрудники', 'icon': Icons.people, 'data': ['Иванов И.И.', 'Петров П.П.', 'Сидоров С.С.']},
      {'title': 'Проекты', 'icon': Icons.assignment, 'data': ['Грант РФФИ 2024', 'Госзадание 1.1', 'Проект Приоритет 2030']},
      {'title': 'Типы достижений', 'icon': Icons.category, 'data': ['Статья ВАК', 'Статья Scopus', 'Патент', 'Монография']},
      {'title': 'Результаты достижений', 'icon': Icons.emoji_events, 'data': ['Опубликовано', 'Принято в печать', 'Заявка подана']},
      {'title': 'Статусы достижений', 'icon': Icons.flag, 'data': ['В работе', 'На проверке', 'Завершено']},
      {'title': 'Типы участия', 'icon': Icons.handshake, 'data': ['Руководитель', 'Исполнитель', 'Консультант']},
      {'title': 'Типы активности (Dev)', 'icon': Icons.developer_mode, 'data': []},
      {'title': 'Критерии проектов (Dev)', 'icon': Icons.checklist, 'data': []},
      {'title': 'Настройки', 'icon': Icons.settings, 'data': []},
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
                  if (dir['title'] == 'Сотрудники') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ResearcherListScreen(),
                      ),
                    );
                    return;
                  }
                  if (dir['title'] == 'Проекты') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TeamListScreen(),
                      ),
                    );
                    return;
                  }
                  if (dir['title'] == 'Типы достижений') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AchievementTypeListScreen(),
                      ),
                    );
                    return;
                  }
                  if (dir['title'] == 'Результаты достижений') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AchievementResultListScreen(),
                      ),
                    );
                    return;
                  }
                  if (dir['title'] == 'Статусы достижений') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AchievementStatusListScreen(),
                      ),
                    );
                    return;
                  }
                  if (dir['title'] == 'Типы участия') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AchievementParticipationListScreen(),
                      ),
                    );
                    return;
                  }
                  if (dir['title'] == 'Типы активности (Dev)') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DevActivityTypeListScreen(),
                      ),
                    );
                    return;
                  }
                  if (dir['title'] == 'Критерии проектов (Dev)') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DevProjectCriterionListScreen(),
                      ),
                    );
                    return;
                  }
                  if (dir['title'] == 'Настройки') {
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
                        title: dir['title'],
                        items: List<String>.from(dir['data']),
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
                        dir['title'],
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
