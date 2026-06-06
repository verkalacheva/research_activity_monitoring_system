import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/data/services/researcher_service.dart';
import 'package:research_activity_monitoring_system/data/services/achievement_service.dart';
import 'package:research_activity_monitoring_system/data/services/researcher_dev_activity_service.dart';
import 'package:research_activity_monitoring_system/data/services/integration_service.dart';
import 'package:research_activity_monitoring_system/data/services/sync_notification_service.dart';
import 'package:research_activity_monitoring_system/core/utils/icon_helper.dart';
import 'package:research_activity_monitoring_system/core/utils/clipboard_helper.dart';
import 'package:research_activity_monitoring_system/core/utils/url_helper.dart';
import 'package:research_activity_monitoring_system/core/l10n/l10n.dart';
import 'package:research_activity_monitoring_system/presentation/widgets/profile/achievement_detail_row.dart';
import 'package:research_activity_monitoring_system/presentation/widgets/profile/profile_info_row.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_form_screen.dart';
class ResearcherProfileScreen extends StatefulWidget {
  final Researcher researcher;
  final bool isEmbedded;
  final bool readOnly;
  final Function(Researcher)? onResearcherUpdated;

  const ResearcherProfileScreen({
    super.key,
    required this.researcher,
    this.isEmbedded = false,
    this.readOnly = false,
    this.onResearcherUpdated,
  });

  @override
  State<ResearcherProfileScreen> createState() => _ResearcherProfileScreenState();
}

class _ResearcherProfileScreenState extends State<ResearcherProfileScreen> {
  final _researcherService = ResearcherService();
  final _achievementService = AchievementService();
  final _devActivityService = ResearcherDevActivityService();
  final _integrationService = IntegrationService();

  GitHubCheckKeysRegistry? _keysRegistry;
  final _formKey = GlobalKey<FormState>();
  
  late Researcher _researcher;
  bool _isLoading = true;
  bool _isEditing = false;
  int _selectedTab = 0; // 0: Achievements, 1: Dev Activity
  int? _selectedYear;

  bool _isSelectionMode = false;
  final Set<int> _selectedActivityIds = {};

  // Контроллеры для редактирования
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _secondNameController;
  late TextEditingController _subjectAreaController;
  late TextEditingController _emailController;
  late TextEditingController _telegramController;
  late TextEditingController _isuNumberController;
  late TextEditingController _facultyController;
  late TextEditingController _employmentStatusController;
  late TextEditingController _orcidIdController;
  late TextEditingController _openalexIdController;
  late TextEditingController _githubController;
  String? _selectedDegreeLevel;
  int? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _researcher = widget.researcher;
    _initControllers();
    if (widget.readOnly) {
      _isEditing = false;
      _isSelectionMode = false;
    }
    _refreshProfile();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: _researcher.name);
    _surnameController = TextEditingController(text: _researcher.surname);
    _secondNameController = TextEditingController(text: _researcher.secondName ?? '');
    _subjectAreaController = TextEditingController(text: _researcher.subjectArea ?? '');
    _emailController = TextEditingController(text: _researcher.email ?? '');
    _telegramController = TextEditingController(text: _researcher.telegram ?? '');
    _isuNumberController = TextEditingController(text: _researcher.isuNumber ?? '');
    _facultyController = TextEditingController(text: _researcher.faculty ?? '');
    _employmentStatusController = TextEditingController(text: _researcher.employmentStatus ?? '');
    _orcidIdController = TextEditingController(text: _researcher.orcidId ?? '');
    _openalexIdController = TextEditingController(text: _researcher.openalexId ?? '');
    _githubController = TextEditingController(text: _researcher.github ?? '');
    _selectedDegreeLevel = _researcher.degreeLevel;
    _selectedCourse = _researcher.course;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _secondNameController.dispose();
    _subjectAreaController.dispose();
    _emailController.dispose();
    _telegramController.dispose();
    _isuNumberController.dispose();
    _facultyController.dispose();
    _employmentStatusController.dispose();
    _orcidIdController.dispose();
    _openalexIdController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ResearcherProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.researcher != widget.researcher) {
      setState(() {
        _researcher = widget.researcher;
        _initControllers();
      });
      if (oldWidget.researcher.id != widget.researcher.id) {
        _isLoading = true;
        _isEditing = false;
        _refreshProfile();
      }
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final results = await Future.wait([
        _researcherService.getById(_researcher.id!),
        if (!widget.readOnly && _keysRegistry == null) _integrationService.getGithubCheckKeys(),
      ]);
      setState(() {
        _researcher = results[0] as Researcher;
        if (_keysRegistry == null && results.length > 1) {
          _keysRegistry = results[1] as GitHubCheckKeysRegistry;
        }
        _isLoading = false;
        if (!_isEditing) {
          _emailController.text = _researcher.email ?? '';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка обновления профиля: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updatedResearcher = Researcher(
          id: _researcher.id,
          name: _nameController.text,
          surname: _surnameController.text,
          secondName: _secondNameController.text.isEmpty ? null : _secondNameController.text,
          degreeLevel: _selectedDegreeLevel,
          course: _selectedCourse,
          subjectArea: _subjectAreaController.text.isEmpty ? null : _subjectAreaController.text,
          email: _emailController.text.isEmpty ? null : _emailController.text,
          telegram: _telegramController.text.isEmpty ? null : _telegramController.text,
          isuNumber: _isuNumberController.text.isEmpty ? null : _isuNumberController.text,
          faculty: _facultyController.text.isEmpty ? null : _facultyController.text,
          employmentStatus: _employmentStatusController.text.isEmpty ? null : _employmentStatusController.text,
          orcidId: _orcidIdController.text.isEmpty ? null : _orcidIdController.text,
          openalexId: _openalexIdController.text.isEmpty ? null : _openalexIdController.text,
          github: _githubController.text.isEmpty ? null : _githubController.text,
        );

        final updated = await _researcherService.update(_researcher.id!, updatedResearcher);
        setState(() {
          _researcher = updated.copyWith(
            achievements: updated.achievements.isEmpty ? _researcher.achievements : updated.achievements,
          );
          _isEditing = false;
          _initControllers(); // Обновляем контроллеры новыми данными
        });
        widget.onResearcherUpdated?.call(_researcher);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
        }
      }
    }
  }

  Future<void> _deleteAchievement(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Вы уверены, что хотите удалить это достижение?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _achievementService.delete(id);
        _refreshProfile();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
        }
      }
    }
  }

  Future<void> _editDevActivity(ResearcherDevActivity activity) async {
    final countController = TextEditingController(text: activity.count.toString());
    String? editedDate = activity.date;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(activity.type?.title ?? 'Активность'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: countController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                  labelText: 'Количество',
                  helperText: 'Отрицательное значение уменьшает баллы',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editedDate != null
                          ? 'Дата: $editedDate'
                          : 'Дата не указана',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Изменить'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: editedDate != null
                            ? (DateTime.tryParse(editedDate!) ?? DateTime.now())
                            : DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          editedDate = picked.toIso8601String().split('T').first;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && activity.id != null) {
      final newCount = int.tryParse(countController.text.trim());
      if (newCount == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Введите корректное число')),
          );
        }
        return;
      }
      try {
        // Optimistic local update so computed points change immediately
        setState(() {
          _researcher = _researcher.copyWith(
            devActivities: _researcher.devActivities.map((a) {
              if (a.id == activity.id) {
                return ResearcherDevActivity(
                  id: a.id,
                  researcherId: a.researcherId,
                  teamId: a.teamId,
                  devEmployeeActivityTypeId: a.devEmployeeActivityTypeId,
                  count: newCount,
                  date: editedDate,
                  createdAt: a.createdAt,
                  type: a.type,
                );
              }
              return a;
            }).toList(),
          );
        });
        await _devActivityService.update(
          _researcher.id!,
          activity.id!,
          count: newCount,
          date: editedDate,
        );
        _refreshProfile();
      } catch (e) {
        _refreshProfile(); // revert on error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка сохранения: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteDevActivity(ResearcherDevActivity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление активности'),
        content: Text(
          'Удалить "${activity.type?.title ?? 'активность'}" (${activity.count} ед.)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && activity.id != null) {
      // Optimistic local update
      setState(() {
        _researcher = _researcher.copyWith(
          devActivities: _researcher.devActivities.where((a) => a.id != activity.id).toList(),
        );
      });
      try {
        await _devActivityService.delete(_researcher.id!, activity.id!);
        _refreshProfile();
      } catch (e) {
        _refreshProfile(); // revert on error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e')),
          );
        }
      }
    }
  }

  void _toggleActivitySelection(int id) {
    setState(() {
      if (_selectedActivityIds.contains(id)) {
        _selectedActivityIds.remove(id);
        if (_selectedActivityIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedActivityIds.add(id);
      }
    });
  }

  void _enterSelectionMode(int id) {
    setState(() {
      _isSelectionMode = true;
      _selectedActivityIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedActivityIds.clear();
    });
  }

  void _selectAllActivities() {
    final allIds = _researcher.devActivities
        .where((a) => a.id != null)
        .map((a) => a.id!)
        .toSet();
    setState(() {
      if (_selectedActivityIds.length == allIds.length) {
        _selectedActivityIds.clear();
        if (_selectedActivityIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedActivityIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final count = _selectedActivityIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление активностей'),
        content: Text('Удалить $count запис${_recordsEnding(count)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = List<int>.from(_selectedActivityIds);
    _exitSelectionMode();
    // Optimistic local update
    setState(() {
      _researcher = _researcher.copyWith(
        devActivities: _researcher.devActivities.where((a) => a.id == null || !ids.contains(a.id)).toList(),
      );
    });
    int errors = 0;
    for (final id in ids) {
      try {
        await _devActivityService.delete(_researcher.id!, id);
      } catch (_) {
        errors++;
      }
    }
    _refreshProfile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors == 0
              ? 'Удалено записей: ${ids.length}'
              : 'Удалено: ${ids.length - errors}, ошибок: $errors'),
        ),
      );
    }
  }

  Future<void> _bulkChangeDate() async {
    String? pickedDate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Изменить дату у ${_selectedActivityIds.length} запис${_recordsEnding(_selectedActivityIds.length)}'),
          content: Row(
            children: [
              Expanded(
                child: Text(
                  pickedDate != null ? 'Новая дата: $pickedDate' : 'Дата не выбрана',
                  style: AppTextStyles.bodySecondary,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Выбрать'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      pickedDate = picked.toIso8601String().split('T').first;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: pickedDate == null ? null : () => Navigator.pop(context, true),
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || pickedDate == null) return;

    final ids = List<int>.from(_selectedActivityIds);
    final activities = _researcher.devActivities
        .where((a) => a.id != null && ids.contains(a.id))
        .toList();
    _exitSelectionMode();
    // Optimistic local date update
    setState(() {
      _researcher = _researcher.copyWith(
        devActivities: _researcher.devActivities.map((a) {
          if (a.id != null && ids.contains(a.id)) {
            return ResearcherDevActivity(
              id: a.id,
              researcherId: a.researcherId,
              teamId: a.teamId,
              devEmployeeActivityTypeId: a.devEmployeeActivityTypeId,
              count: a.count,
              date: pickedDate,
              createdAt: a.createdAt,
              type: a.type,
            );
          }
          return a;
        }).toList(),
      );
    });
    int errors = 0;
    for (final a in activities) {
      try {
        await _devActivityService.update(
          _researcher.id!,
          a.id!,
          count: a.count,
          date: pickedDate,
        );
      } catch (_) {
        errors++;
      }
    }
    _refreshProfile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors == 0
              ? 'Дата обновлена у ${ids.length} запис${_recordsEnding(ids.length)}'
              : 'Обновлено: ${ids.length - errors}, ошибок: $errors'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: AppDimensions.paddingLarge),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Информация', style: AppTextStyles.h2),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      _buildInfoCard(),
                      if (_isEditing) ...[
                        const SizedBox(height: AppDimensions.paddingLarge),
                        Center(
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            child: const Text('Сохранить изменения'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.paddingExtraLarge),
                      _buildTabHeader(),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      _selectedTab == 0 ? _buildAchievementsList() : _buildDevActivityList(),
                    ],
                  ),
                ),
              ),
            ),
          );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _buildFab(),
        body: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль сотрудника'),
      ),
      floatingActionButton: _buildFab(),
      body: content,
    );
  }

  Widget? _buildFab() {
    if (widget.readOnly) return null;
    return FloatingActionButton(
      heroTag: 'add_achievement_fab',
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AchievementFormScreen(researcherId: _researcher.id!),
          ),
        );
        if (result == true) _refreshProfile();
      },
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.add, color: AppColors.textOnPrimary),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: AppDimensions.avatarSizeLarge,
              backgroundColor: AppColors.background,
              child: Icon(Icons.person, size: 80, color: AppColors.inactive),
            ),
            const SizedBox(width: AppDimensions.paddingLarge),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditing) ...[
                          TextFormField(
                            controller: _surnameController,
                            decoration: const InputDecoration(labelText: 'Фамилия *', isDense: true),
                            validator: (v) => v?.isEmpty ?? true ? 'Обязательно' : null,
                          ),
                          const SizedBox(height: AppDimensions.paddingMedium),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Имя *', isDense: true),
                            validator: (v) => v?.isEmpty ?? true ? 'Обязательно' : null,
                          ),
                          const SizedBox(height: AppDimensions.paddingMedium),
                          TextFormField(
                            controller: _secondNameController,
                            decoration: const InputDecoration(labelText: 'Отчество', isDense: true),
                          ),
                        ] else
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _researcher.fullName,
                                  style: AppTextStyles.h1,
                                ),
                              ),
                              if (_researcher.isLeader) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.star,
                                  size: 28,
                                  color: AppColors.warning,
                                ),
                              ],
                              if (widget.isEmbedded && !widget.readOnly) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(_isEditing ? Icons.close : Icons.edit, color: AppColors.primary),
                                  onPressed: () {
                                    setState(() {
                                      _initControllers();
                                      _isEditing = !_isEditing;
                                    });
                                  },
                                  tooltip: _isEditing ? 'Отмена' : 'Редактировать',
                                ),
                              ],
                            ],
                          ),
                        const SizedBox(height: AppDimensions.paddingMedium),
                        if (_isEditing)
                          DropdownButtonFormField<int>(
                            value: _selectedCourse,
                            decoration: const InputDecoration(labelText: 'Курс', isDense: true),
                            items: [1, 2, 3, 4, 5, 6].map((c) => DropdownMenuItem(value: c, child: Text('$c курс'))).toList(),
                            onChanged: (v) => setState(() => _selectedCourse = v),
                          )
                        else
                          Text(
                            '${_researcher.degreeLevel ?? ''} ${_researcher.course != null ? '(${_researcher.course} курс)' : ''}'.trim(),
                            style: AppTextStyles.bodySecondary,
                          ),
                        const SizedBox(height: 16),
                        if (_isEditing)
                          TextFormField(
                            controller: _subjectAreaController,
                            decoration: const InputDecoration(labelText: 'Направление', isDense: true),
                          )
                        else if (_researcher.subjectArea != null)
                          Chip(
                            label: Text(_researcher.subjectArea!),
                            backgroundColor: AppColors.background,
                            side: BorderSide.none,
                          ),
                      ],
                    ),
                  ),
                  if (widget.isEmbedded && _isEditing) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.primary),
                      onPressed: () {
                        setState(() {
                          _initControllers();
                          _isEditing = false;
                        });
                      },
                      tooltip: 'Отмена',
                    ),
                    const SizedBox(width: 40),
                  ] else if (widget.isEmbedded) ...[
                    const SizedBox(width: 40),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Column(
        children: [
          _infoRow(context, Icons.school, 'Степень/Статус', _researcher.degreeLevel ?? 'Не указано', field: _buildDegreeDropdown()),
          const Divider(height: 1, indent: 56),
          _infoRow(context, Icons.business, 'Факультет', _researcher.faculty ?? 'Не указано', controller: _facultyController),
          const Divider(height: 1, indent: 56),
          _infoRow(context, Icons.book, 'Направление', _researcher.subjectArea ?? 'Не указано', controller: _subjectAreaController),
          const Divider(height: 1, indent: 56),
          _infoRow(context, Icons.email, 'Почта', _researcher.email ?? 'Не указано', controller: _emailController),
          const Divider(height: 1, indent: 56),
          _infoRow(context, Icons.send, 'Телеграм', _researcher.telegram ?? 'Не указано', controller: _telegramController),
          const Divider(height: 1, indent: 56),
          _infoRow(context, Icons.fingerprint, context.strings.tr('widgets.profile.label_isu'), _researcher.isuNumber ?? 'Не указано', controller: _isuNumberController),
          const Divider(height: 1, indent: 56),
          _infoRow(context, Icons.work, 'Трудоустройство (дата/период)', _researcher.employmentStatus ?? 'Не указано', controller: _employmentStatusController),
          const Divider(height: 1, indent: 56),
          _infoRow(
            context,
            Icons.link,
            'ORCID ID',
            _researcher.orcidId ?? 'Не указано',
            controller: _orcidIdController,
            trailing: _researcher.orcidId != null &&
                    _researcher.orcidId!.trim().isNotEmpty &&
                    !_isEditing &&
                    !widget.readOnly
                ? IconButton(
                    icon: const Icon(Icons.sync, color: AppColors.primary),
                    onPressed: () {
                      SyncNotificationService.instance.enqueue(SyncRequest(
                        provider: 'orcid',
                        researcherId: _researcher.id,
                        label: 'ORCID — ${_researcher.fullName}',
                        onSaved: _refreshProfile,
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Синхронизация ORCID запущена в фоне')),
                      );
                    },
                    tooltip: 'Синхронизировать ORCID',
                  )
                : null,
          ),
          const Divider(height: 1, indent: 56),
          _infoRow(
            context,
            Icons.school_outlined,
            'OpenAlex ID',
            _researcher.openalexId ?? 'Не указано',
            controller: _openalexIdController,
            trailing: _researcher.openalexId != null &&
                    _researcher.openalexId!.trim().isNotEmpty &&
                    !_isEditing &&
                    !widget.readOnly
                ? IconButton(
                    icon: const Icon(Icons.sync, color: AppColors.primary),
                    onPressed: () {
                      SyncNotificationService.instance.enqueue(SyncRequest(
                        provider: 'openalex',
                        researcherId: _researcher.id,
                        label: 'OpenAlex — ${_researcher.fullName}',
                        onSaved: _refreshProfile,
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Синхронизация OpenAlex запущена в фоне')),
                      );
                    },
                    tooltip: 'Синхронизировать OpenAlex',
                  )
                : null,
          ),
          const Divider(height: 1, indent: 56),
          _infoRow(
            context,
            Icons.code,
            'Github',
            _researcher.github ?? 'Не указано',
            controller: _githubController,
            trailing: _researcher.github != null &&
                    _researcher.github!.trim().isNotEmpty &&
                    !_isEditing &&
                    !widget.readOnly
                ? IconButton(
                    icon: const Icon(Icons.sync, color: AppColors.primary),
                    onPressed: () {
                      SyncNotificationService.instance.enqueue(SyncRequest(
                        provider: 'github',
                        researcherId: _researcher.id,
                        label: 'GitHub — ${_researcher.fullName}',
                        onSaved: _refreshProfile,
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Синхронизация GitHub запущена в фоне')),
                      );
                    },
                    tooltip: 'Синхронизировать GitHub',
                  )
                : null,
          ),
          if (!_isEditing && !widget.readOnly) ...[
            const Divider(height: 1, indent: 56),
            _infoRow(
              context,
              Icons.travel_explore,
              'Поиск в интернете',
              'Краулер по ФИО и открытым данным',
              trailing: IconButton(
                icon: const Icon(Icons.sync, color: AppColors.primary),
                onPressed: () {
                  SyncNotificationService.instance.enqueue(SyncRequest(
                    provider: 'crawl_search',
                    researcherId: _researcher.id,
                    label: 'Интернет (краулер) — ${_researcher.fullName}',
                    onSaved: _refreshProfile,
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Поиск в интернете запущен в фоне')),
                  );
                },
                tooltip: 'Запустить краулер по интернету',
              ),
            ),
          ],
          if (!_isEditing && _researcher.course != null) ...[
            const Divider(height: 1, indent: 56),
            _infoRow(context, Icons.timeline, 'Курс обучения', '${_researcher.course} курс'),
          ],
          const Divider(height: 1, indent: 56),
          _infoRow(
            context,
            Icons.assignment_turned_in,
            'Руководитель команды',
            _researcher.isLeader ? 'Да' : 'Нет',
          ),
          Builder(builder: (context) {
            final points = _researcher.computedDevPoints;
            if (points == null) return const SizedBox.shrink();
            return Column(
              children: [
                const Divider(height: 1, indent: 56),
                _infoRow(
                  context,
                  Icons.trending_up,
                  'Баллы за разработку',
                  points.toStringAsFixed(1),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDegreeDropdown() {
    final options = ['к.т.н.', 'д.т.н.', 'к.ф.-м.н.', 'д.ф.-м.н.', 'аспирант', 'бакалавр', 'магистрант'];
    return DropdownButtonFormField<String>(
      value: _selectedDegreeLevel,
      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
      items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _selectedDegreeLevel = v),
    );
  }

  Widget _buildTabHeader() {
    final availableYears = _getAvailableYears();
    final isDevTab = _selectedTab == 1;
    final allIds = _researcher.devActivities.where((a) => a.id != null).map((a) => a.id!).toSet();
    final allSelected = allIds.isNotEmpty && _selectedActivityIds.length == allIds.length;

    return Column(
      children: [
        Row(
          children: [
            _tabButton('Достижения', 0, count: _researcher.achievements.length),
            const SizedBox(width: 16),
            _tabButton('Активность', 1, count: _researcher.devActivities.length),
            const Spacer(),
            // Year filter (visible when not in selection mode)
            if (!_isSelectionMode && availableYears.isNotEmpty)
              DropdownButton<int?>(
                value: _selectedYear,
                hint: const Text('Все годы'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Все годы')),
                  ...availableYears.map((y) => DropdownMenuItem(value: y, child: Text('$y год'))),
                ],
                onChanged: (y) => setState(() => _selectedYear = y),
                underline: const SizedBox(),
                style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            // Selection mode controls
            if (isDevTab && _isSelectionMode) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _selectAllActivities,
                icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 18),
                label: Text(allSelected ? 'Снять все' : 'Выбрать все'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton(
                onPressed: _exitSelectionMode,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Отмена'),
              ),
            ] else if (isDevTab && allIds.isNotEmpty && !widget.readOnly) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() => _isSelectionMode = true),
                icon: const Icon(Icons.checklist, size: 18),
                label: const Text('Выбрать'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ],
        ),
        // Bulk actions bar
        if (isDevTab && _isSelectionMode && _selectedActivityIds.isNotEmpty && !widget.readOnly)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Выбрано ${_selectedActivityIds.length} из ${allIds.length}',
                  style: AppTextStyles.bodySecondary.copyWith(color: AppColors.primary),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _bulkChangeDate,
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text('Изменить дату'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Удалить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        const Divider(height: 1),
      ],
    );
  }

  Widget _tabButton(String label, int index, {int count = 0}) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppTextStyles.h2.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 18,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<int> _getAvailableYears() {
    final years = <int>{};
    for (var a in _researcher.achievements) {
      if (a.submissionDate != null) years.add(a.submissionDate!.year);
    }
    for (var a in _researcher.devActivities) {
      if (a.date != null) {
        try {
          years.add(DateTime.parse(a.date!).year);
        } catch (_) {}
      } else if (a.createdAt != null) {
        years.add(a.createdAt!.year);
      }
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  Widget _buildDevActivityList() {
    var activities = _researcher.devActivities;
    if (_selectedYear != null) {
      activities = activities.where((a) {
        if (a.date != null) {
          try {
            return DateTime.parse(a.date!).year == _selectedYear;
          } catch (_) {}
        }
        return a.createdAt?.year == _selectedYear;
      }).toList();
    }

    if (activities.isEmpty) {
      return _buildEmptyState('Активность в разработке не найдена');
    }

    // Group by activity type
    final Map<int, List<ResearcherDevActivity>> byType = {};
    for (final a in activities) {
      final key = a.devEmployeeActivityTypeId;
      byType.putIfAbsent(key, () => []).add(a);
    }

    // Sort each group by date descending
    for (final list in byType.values) {
      list.sort((a, b) {
        final da = a.date != null ? (DateTime.tryParse(a.date!) ?? DateTime(0)) : (a.createdAt ?? DateTime(0));
        final db = b.date != null ? (DateTime.tryParse(b.date!) ?? DateTime(0)) : (b.createdAt ?? DateTime(0));
        return db.compareTo(da);
      });
    }

    // Sort groups by total absolute points descending
    final sortedGroups = byType.values.toList()
      ..sort((a, b) {
        final pa = a.fold<double>(0, (s, x) => s + (x.count * (x.type?.points ?? 0)).abs());
        final pb = b.fold<double>(0, (s, x) => s + (x.count * (x.type?.points ?? 0)).abs());
        return pb.compareTo(pa);
      });

    final devPoints = _researcher.computedDevPoints;
    final rawActivitySum = activities.fold<double>(
      0, (s, a) => s + a.count * (a.type?.points ?? 0));
    final multiplierIsZero = _researcher.devTeamMultipliers.isNotEmpty &&
        _researcher.devTeamMultipliers.values.every((v) => v == 0);

    return Column(
      children: [
        ...sortedGroups.map((group) => _buildActivityTypeCard(group)),
        if (multiplierIsZero && rawActivitySum != 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Баллы за разработку = 0, так как у команды не настроены критерии проекта '
                    'и не выполнена командная синхронизация. '
                    'Сумма активностей сотрудника: ${rawActivitySum >= 0 ? '+' : ''}${rawActivitySum.toStringAsFixed(1)} ед.',
                    style: const TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (devPoints != null && devPoints != 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Итого баллы за разработку',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${devPoints >= 0 ? '+' : ''}${devPoints.toStringAsFixed(1)} б.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: devPoints < 0 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityTypeCard(List<ResearcherDevActivity> records) {
    final type = records.first.type;
    final checkKey = type?.checkKey ?? '';

    final typeActivityDetails = (_researcher.activityDetails
        .where((d) {
          if (d.activityType != checkKey) return false;
          if (_selectedYear != null && d.date != null) {
            try {
              return DateTime.parse(d.date!).year == _selectedYear;
            } catch (_) {}
          }
          return true;
        })
        .toList()
      ..sort((a, b) {
        final da = a.date != null ? (DateTime.tryParse(a.date!) ?? DateTime(0)) : DateTime(0);
        final db = b.date != null ? (DateTime.tryParse(b.date!) ?? DateTime(0)) : DateTime(0);
        return db.compareTo(da);
      }));

    // Resolve category label from registry
    final keyDef = _keysRegistry?.activityKeys.firstWhere(
      (k) => k.key == checkKey,
      orElse: () => GitHubCheckKey(key: checkKey, label: type?.title ?? '', category: ''),
    );
    final categoryLabel = keyDef != null && keyDef.category.isNotEmpty
        ? (_keysRegistry?.categoryLabels[keyDef.category] ?? keyDef.category)
        : null;

    final totalCount = records.fold<int>(0, (s, a) => s + a.count);
    final pointsPerUnit = type?.points ?? 0;
    final totalPoints = (totalCount * pointsPerUnit).toDouble();
    final hasNegative = records.any((a) => a.count < 0);
    final isNegativeOverall = totalCount < 0;
    final headerColor = isNegativeOverall ? AppColors.error : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: headerColor.withOpacity(0.1),
          child: Icon(
            isNegativeOverall ? Icons.trending_down : _activityIcon(checkKey),
            color: headerColor,
            size: 20,
          ),
        ),
        title: Text(type?.title ?? 'Активность', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: categoryLabel != null
            ? Text(categoryLabel, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCount(totalCount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isNegativeOverall ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatPoints(totalPoints),
                    style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            if (hasNegative)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Tooltip(
                  message: 'Есть записи об уменьшении активности',
                  child: Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                ),
              ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta info row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _metaChip(Icons.star_border, '${pointsPerUnit.toStringAsFixed(1)} балл/ед.'),
                const SizedBox(width: 12),
                _metaChip(Icons.receipt_long, '${records.length} запис${_recordsEnding(records.length)}'),
                if (checkKey.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _metaChip(Icons.key, checkKey, monospace: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Individual date records
          ...records.map((a) => _buildActivityRecord(a)),
          if (typeActivityDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(_activityIcon(checkKey), size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Подробнее (${typeActivityDetails.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...typeActivityDetails.map((d) => _buildActivityDetailRow(d)),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityRecord(ResearcherDevActivity activity) {
    String dateStr = '';
    if (activity.date != null) {
      try {
        dateStr = DateFormat('dd.MM.yyyy').format(DateTime.parse(activity.date!));
      } catch (_) {}
    } else if (activity.createdAt != null) {
      dateStr = DateFormat('dd.MM.yyyy').format(activity.createdAt!);
    }

    final points = (activity.count * (activity.type?.points ?? 0)).toDouble();
    final isNeg = activity.count < 0;
    final rowColor = isNeg ? AppColors.error : AppColors.primary;
    final isSelected = activity.id != null && _selectedActivityIds.contains(activity.id);

    return GestureDetector(
      onLongPress: activity.id != null && !_isSelectionMode && !widget.readOnly
          ? () => _enterSelectionMode(activity.id!)
          : null,
      onTap: _isSelectionMode && activity.id != null
          ? () => _toggleActivitySelection(activity.id!)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: isSelected ? 4 : 0),
        child: Row(
          children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: activity.id != null
                        ? (_) => _toggleActivitySelection(activity.id!)
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: AppColors.primary,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.inactive,
                      width: 1.5,
                    ),
                  ),
                ),
              )
            else
              Icon(
                isNeg ? Icons.remove_circle_outline : Icons.add_circle_outline,
                size: 16,
                color: rowColor,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateStr.isNotEmpty ? dateStr : 'Дата не указана',
                style: AppTextStyles.bodySecondary,
              ),
            ),
            Text(
              _formatCount(activity.count),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isNeg ? AppColors.error : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Text(
                _formatPoints(points),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: rowColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!_isSelectionMode && !widget.readOnly) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit, size: 16, color: AppColors.inactive),
                tooltip: 'Редактировать',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _editDevActivity(activity),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                tooltip: 'Удалить',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _deleteDevActivity(activity),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityDetailRow(ResearcherActivityDetail detail) {
    String dateStr = '';
    if (detail.date != null) {
      try {
        dateStr = DateFormat('dd.MM.yyyy').format(DateTime.parse(detail.date!));
      } catch (_) {}
    }

    final isCommit = detail.activityType == 'commits';
    final shortId = detail.externalId.length >= 7 && isCommit
        ? detail.externalId.substring(0, 7)
        : detail.externalId;
    final repoName = detail.repository?.split('/').last ?? detail.repository ?? '';
    final stateColor = detail.state == 'merged'
        ? Colors.purple
        : detail.state == 'closed'
            ? AppColors.error
            : detail.state == 'open'
                ? Colors.green
                : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.subdirectory_arrow_right, size: 14, color: AppColors.inactive),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortId,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title ?? '',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (repoName.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_outlined, size: 11, color: AppColors.textTertiary),
                            const SizedBox(width: 2),
                            Text(repoName,
                                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                          ],
                        ),
                      if (dateStr.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textTertiary),
                            const SizedBox(width: 2),
                            Text(dateStr,
                                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                          ],
                        ),
                      if (detail.state != null && detail.state!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: (stateColor ?? AppColors.textTertiary).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            detail.state!,
                            style: TextStyle(
                              fontSize: 10,
                              color: stateColor ?? AppColors.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (detail.url != null && detail.url!.isNotEmpty)
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(detail.url!);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.open_in_new, size: 13, color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, {bool monospace = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontFamily: monospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  IconData _activityIcon(String checkKey) {
    if (['commits', 'contributions'].contains(checkKey)) return Icons.commit;
    if (['pull_requests', 'merged_prs'].contains(checkKey)) return Icons.merge;
    if (['issues', 'open_issues', 'closed_issues'].contains(checkKey)) return Icons.bug_report;
    if (checkKey == 'code_reviews') return Icons.rate_review;
    if (['stars'].contains(checkKey)) return Icons.star;
    if (['forks'].contains(checkKey)) return Icons.fork_right;
    if (['followers'].contains(checkKey)) return Icons.people;
    if (['releases'].contains(checkKey)) return Icons.new_releases;
    return Icons.code;
  }

  String _formatCount(int count) {
    if (count > 0) return '+$count';
    return '$count';
  }

  String _formatPoints(double points) {
    final abs = points.abs();
    if (points > 0) return '+${abs.toStringAsFixed(1)} б.';
    if (points < 0) return '−${abs.toStringAsFixed(1)} б.';
    return '0 б.';
  }

  String _recordsEnding(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return 'ей';
    switch (n % 10) {
      case 1: return 'ь';
      case 2: case 3: case 4: return 'и';
      default: return 'ей';
    }
  }

  Widget _buildYearHeader(int year) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Text(year == 0 ? 'Дата не указана' : '$year год', style: AppTextStyles.h3),
          const SizedBox(width: 16),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.info_outline, size: 48, color: AppColors.inactive),
              const SizedBox(height: 16),
              Text(message, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsList() {
    var achievements = _researcher.achievements;
    if (_selectedYear != null) {
      achievements = achievements.where((a) => a.submissionDate?.year == _selectedYear).toList();
    }
    
    // Сортировка по дате (новые сверху)
    achievements.sort((a, b) => (b.submissionDate ?? DateTime(0)).compareTo(a.submissionDate ?? DateTime(0)));

    if (achievements.isEmpty) {
      return _buildEmptyState('Список достижений пуст');
    }

    // Группировка по годам
    final Map<int, List<Achievement>> grouped = {};
    for (var a in achievements) {
      final year = a.submissionDate?.year ?? 0;
      grouped.putIfAbsent(year, () => []).add(a);
    }

    final sortedYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedYears.expand((year) => [
        if (_selectedYear == null) _buildYearHeader(year),
        ...grouped[year]!.map((achievement) {
          return Card(
            margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
            child: ExpansionTile(
              leading: Icon(IconHelper.getIcon(achievement.type?.iconName), color: AppColors.primary),
              title: Text(achievement.type?.title ?? 'Достижение'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${achievement.status?.title ?? ""}, ${achievement.result?.title ?? ""}, Баллы: ${achievement.points?.toStringAsFixed(1) ?? 0}'),
                  if (achievement.submissionDate != null)
                    Text(
                      'Загружено: ${DateFormat('dd.MM.yyyy HH:mm').format(achievement.submissionDate!)}',
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
              trailing: widget.readOnly
                  ? null
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AchievementFormScreen(
                            achievement: achievement,
                            researcherId: _researcher.id!,
                          ),
                        ),
                      );
                      if (result == true) _refreshProfile();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                    onPressed: () => _deleteAchievement(achievement.id!),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      if (achievement.type?.fields != null && achievement.type!.fields.isNotEmpty) ...[
                        const Divider(),
                        const Text('Дополнительные данные:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...achievement.type!.fields.map((field) {
                          final answer = achievement.answers.firstWhere(
                            (a) => a.achievementFieldId == field.id,
                            orElse: () => AchievementFieldAnswer(achievementFieldId: -1, value: '—'),
                          );
                          String displayValue = answer.value;
                          if (displayValue.isEmpty) displayValue = '—';
                          
                          if (field.fieldType == 'boolean') {
                            displayValue = displayValue == 'true' ? 'Да' : (displayValue == 'false' ? 'Нет' : '—');
                          } else if (field.fieldType == 'date' && displayValue != '—') {
                            try {
                              final date = DateTime.parse(displayValue);
                              displayValue = DateFormat('dd.MM.yyyy').format(date);
                            } catch (_) {}
                          }
                          return AchievementDetailRow(label: field.title, value: displayValue);
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ]).toList(),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value, {TextEditingController? controller, Widget? field, Widget? trailing}) {
    return ProfileInfoRow(
      isEditing: _isEditing,
      icon: icon,
      label: label,
      value: value,
      controller: controller,
      field: field,
      trailing: trailing,
    );
  }
}

