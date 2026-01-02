import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_result_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import 'achievement_result_form_screen.dart';

class AchievementResultListScreen extends StatefulWidget {
  const AchievementResultListScreen({super.key});

  @override
  State<AchievementResultListScreen> createState() => _AchievementResultListScreenState();
}

class _AchievementResultListScreenState extends State<AchievementResultListScreen> {
  final AchievementResultService _service = AchievementResultService();
  late Future<List<AchievementResult>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _resultsFuture = _service.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты достижений'),
      ),
      body: FutureBuilder<List<AchievementResult>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Результаты не найдены'));
          }

          final results = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
            itemCount: results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
              return ListTile(
                title: Text(result.title, style: AppTextStyles.body),
                subtitle: Text('Баллы: ${result.points ?? 0}', style: AppTextStyles.caption),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AchievementResultFormScreen(result: result),
                          ),
                        );
                        if (res == true) _refreshList();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _showDeleteDialog(result),
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
              builder: (context) => const AchievementResultFormScreen(),
            ),
          );
          if (res == true) _refreshList();
        },
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
    );
  }

  void _showDeleteDialog(AchievementResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить результат "${result.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _service.delete(result.id!);
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

