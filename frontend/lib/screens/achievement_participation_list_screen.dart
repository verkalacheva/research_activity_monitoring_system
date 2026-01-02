import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_participation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import 'achievement_participation_form_screen.dart';

class AchievementParticipationListScreen extends StatefulWidget {
  const AchievementParticipationListScreen({super.key});

  @override
  State<AchievementParticipationListScreen> createState() => _AchievementParticipationListScreenState();
}

class _AchievementParticipationListScreenState extends State<AchievementParticipationListScreen> {
  final AchievementParticipationService _service = AchievementParticipationService();
  late Future<List<AchievementParticipation>> _participationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _participationsFuture = _service.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Типы участия'),
      ),
      body: FutureBuilder<List<AchievementParticipation>>(
        future: _participationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Типы участия не найдены'));
          }

          final participations = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
            itemCount: participations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final participation = participations[index];
              return ListTile(
                title: Text(participation.title, style: AppTextStyles.body),
                subtitle: Text('Баллы: ${participation.points ?? 0}', style: AppTextStyles.caption),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AchievementParticipationFormScreen(participation: participation),
                          ),
                        );
                        if (res == true) _refreshList();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _showDeleteDialog(participation),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AchievementParticipationFormScreen(),
            ),
          );
          if (res == true) _refreshList();
        },
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
    );
  }

  void _showDeleteDialog(AchievementParticipation participation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить тип участия "${participation.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _service.delete(participation.id!);
              if (mounted) {
                Navigator.pop(context);
                _refreshList();
              }
            },
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

