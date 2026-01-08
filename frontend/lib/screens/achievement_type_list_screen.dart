import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_type_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../utils/icon_helper.dart';
import 'achievement_type_form_screen.dart';
import 'achievement_type_details_screen.dart';

class AchievementTypeListScreen extends StatefulWidget {
  const AchievementTypeListScreen({super.key});

  @override
  State<AchievementTypeListScreen> createState() => _AchievementTypeListScreenState();
}

class _AchievementTypeListScreenState extends State<AchievementTypeListScreen> {
  final AchievementTypeService _service = AchievementTypeService();
  late Future<List<AchievementType>> _typesFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _typesFuture = _service.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Типы достижений'),
      ),
      body: FutureBuilder<List<AchievementType>>(
        future: _typesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Типы достижений не найдены'));
          }

          final types = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
            itemCount: types.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final type = types[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(IconHelper.getIcon(type.iconName), color: AppColors.primary),
                ),
                title: Text(type.title, style: AppTextStyles.body),
                subtitle: Text('Баллы: ${type.points ?? 0}', style: AppTextStyles.caption),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AchievementTypeDetailsScreen(type: type),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AchievementTypeFormScreen(type: type),
                          ),
                        );
                        if (result == true) _refreshList();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _showDeleteDialog(type),
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
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AchievementTypeFormScreen(),
            ),
          );
          if (result == true) _refreshList();
        },
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
    );
  }

  void _showDeleteDialog(AchievementType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить тип достижения "${type.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _service.delete(type.id!);
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

