import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../services/researcher_service.dart';
import '../services/achievement_service.dart';
import '../utils/icon_helper.dart';
import '../utils/clipboard_helper.dart';
import '../utils/url_helper.dart';
import 'achievement_form_screen.dart';

class ResearcherProfileScreen extends StatefulWidget {
  final Researcher researcher;
  final bool isEmbedded;
  final Function(Researcher)? onResearcherUpdated;

  const ResearcherProfileScreen({
    super.key,
    required this.researcher,
    this.isEmbedded = false,
    this.onResearcherUpdated,
  });

  @override
  State<ResearcherProfileScreen> createState() => _ResearcherProfileScreenState();
}

class _ResearcherProfileScreenState extends State<ResearcherProfileScreen> {
  final _researcherService = ResearcherService();
  final _achievementService = AchievementService();
  final _formKey = GlobalKey<FormState>();
  
  late Researcher _researcher;
  bool _isLoading = true;
  bool _isEditing = false;

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
  String? _selectedDegreeLevel;
  int? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _researcher = widget.researcher;
    _initControllers();
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
      final updated = await _researcherService.getById(_researcher.id!);
      setState(() {
        _researcher = updated;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
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
                      const Text('Достижения и активность', style: AppTextStyles.h2),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      _buildAchievementsList(),
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
      child: const Icon(Icons.add, color: Colors.white),
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
                                  color: Colors.amber,
                                ),
                              ],
                              if (widget.isEmbedded) ...[
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
          _infoRow(context, Icons.fingerprint, 'ИСУ', _researcher.isuNumber ?? 'Не указано', controller: _isuNumberController),
          const Divider(height: 1, indent: 56),
          _infoRow(context, Icons.work, 'Трудоустройство', _researcher.employmentStatus ?? 'Не указано', controller: _employmentStatusController),
          const Divider(height: 1, indent: 56),
          _infoRow(context, Icons.link, 'ORCID ID', _researcher.orcidId ?? 'Не указано', controller: _orcidIdController),
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

  Widget _buildAchievementsList() {
    if (_researcher.achievements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLarge),
          child: Center(
            child: Text('Список достижений пуст', style: AppTextStyles.bodySecondary),
          ),
        ),
      );
    }

    return Column(
      children: _researcher.achievements.map((achievement) {
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
            trailing: Row(
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
                        return _achievementDetailRow(context, field.title, displayValue);
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _achievementDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: UrlHelper.buildClickableText(context, value)),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppColors.inactive),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ClipboardHelper.copyToClipboard(context, value),
            tooltip: 'Копировать',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value, {TextEditingController? controller, Widget? field}) {
    final bool isIsu = label == 'ИСУ';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingMedium,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                if (_isEditing && (controller != null || field != null))
                  field ?? TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                  )
                else
                  UrlHelper.buildClickableText(
                    context, 
                    value, 
                    enabled: !isIsu,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)
                  ),
              ],
            ),
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
              onPressed: () => ClipboardHelper.copyToClipboard(context, value),
              tooltip: 'Копировать',
            ),
        ],
      ),
    );
  }
}

