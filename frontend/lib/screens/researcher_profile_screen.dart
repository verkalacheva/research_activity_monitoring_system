import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../services/researcher_service.dart';
import '../services/achievement_service.dart';
import '../utils/icon_helper.dart';
import 'achievement_form_screen.dart';

class ResearcherProfileScreen extends StatefulWidget {
  final Researcher researcher;
  final bool isEmbedded;

  const ResearcherProfileScreen({
    super.key,
    required this.researcher,
    this.isEmbedded = false,
  });

  @override
  State<ResearcherProfileScreen> createState() => _ResearcherProfileScreenState();
}

class _ResearcherProfileScreenState extends State<ResearcherProfileScreen> {
  final _researcherService = ResearcherService();
  final _achievementService = AchievementService();
  late Researcher _researcher;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _researcher = widget.researcher;
    _refreshProfile();
  }

  @override
  void didUpdateWidget(ResearcherProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.researcher.id != widget.researcher.id) {
      _researcher = widget.researcher;
      _isLoading = true;
      _refreshProfile();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AppDimensions.paddingLarge),
                    const Text('Информация', style: AppTextStyles.h2),
                    const SizedBox(height: AppDimensions.paddingMedium),
                    _buildInfoCard(),
                    const SizedBox(height: AppDimensions.paddingExtraLarge),
                    const Text('Достижения и активность', style: AppTextStyles.h2),
                    const SizedBox(height: AppDimensions.paddingMedium),
                    _buildAchievementsList(),
                  ],
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
          children: [
            const CircleAvatar(
              radius: AppDimensions.avatarSizeLarge,
              backgroundColor: AppColors.background,
              child: Icon(Icons.person, size: 80, color: AppColors.inactive),
            ),
            const SizedBox(width: AppDimensions.paddingLarge),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_researcher.fullName, style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    '${_researcher.degreeLevel ?? ''} ${_researcher.course != null ? '(${_researcher.course} курс)' : ''}'.trim(),
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 16),
                  if (_researcher.subjectArea != null)
                    Chip(
                      label: Text(_researcher.subjectArea!),
                      backgroundColor: AppColors.background,
                      side: BorderSide.none,
                    ),
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
          _infoRow(Icons.school, 'Степень/Статус', _researcher.degreeLevel ?? 'Не указано'),
          const Divider(height: 1, indent: 56),
          _infoRow(Icons.business, 'Факультет', _researcher.faculty ?? 'Не указано'),
          const Divider(height: 1, indent: 56),
          _infoRow(Icons.book, 'Направление', _researcher.subjectArea ?? 'Не указано'),
          const Divider(height: 1, indent: 56),
          _infoRow(Icons.email, 'Почта', _researcher.email ?? 'Не указано'),
          const Divider(height: 1, indent: 56),
          _infoRow(Icons.send, 'Телеграм', _researcher.telegram ?? 'Не указано'),
          const Divider(height: 1, indent: 56),
          _infoRow(Icons.fingerprint, 'ИСУ', _researcher.isuNumber ?? 'Не указано'),
          const Divider(height: 1, indent: 56),
          _infoRow(Icons.work, 'Трудоустройство', _researcher.employmentStatus ?? 'Не указано'),
          if (_researcher.course != null) ...[
            const Divider(height: 1, indent: 56),
            _infoRow(Icons.timeline, 'Курс обучения', '${_researcher.course} курс'),
          ],
          const Divider(height: 1, indent: 56),
          _infoRow(
            Icons.assignment_turned_in,
            'Руководитель команды',
            _researcher.isLeader ? 'Да' : 'Нет',
          ),
        ],
      ),
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
                Text('${achievement.status?.title ?? ""}, ${achievement.result?.title ?? ""}, Баллы: ${achievement.points ?? 0}'),
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
                        return _achievementDetailRow(field.title, displayValue);
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

  Widget _achievementDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

