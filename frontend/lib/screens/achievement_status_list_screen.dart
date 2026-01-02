import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_status_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import 'achievement_status_form_screen.dart';

class AchievementStatusListScreen extends StatefulWidget {
  const AchievementStatusListScreen({super.key});

  @override
  State<AchievementStatusListScreen> createState() => _AchievementStatusListScreenState();
}

class _AchievementStatusListScreenState extends State<AchievementStatusListScreen> {
  final AchievementStatusService _service = AchievementStatusService();
  late Future<List<AchievementStatus>> _statusesFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _statusesFuture = _service.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статусы достижений'),
      ),
      body: FutureBuilder<List<AchievementStatus>>(
        future: _statusesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Статусы не найдены'));
          }

          final statuses = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
            itemCount: statuses.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final status = statuses[index];
              return ListTile(
                title: Text(status.title, style: AppTextStyles.body),
                subtitle: Text('Баллы: ${status.points ?? 0}', style: AppTextStyles.caption),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AchievementStatusFormScreen(status: status),
                          ),
                        );
                        if (res == true) _refreshList();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _showDeleteDialog(status),
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
              builder: (context) => const AchievementStatusFormScreen(),
            ),
          );
          if (res == true) _refreshList();
        },
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
    );
  }

  void _showDeleteDialog(AchievementStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить статус "${status.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _service.delete(status.id!);
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

