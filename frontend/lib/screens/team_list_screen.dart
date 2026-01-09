import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import 'team_details_screen.dart';
import 'team_form_screen.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  final TeamService _service = TeamService();
  late Future<List<Team>> _teamsFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _teamsFuture = _service.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проекты'),
      ),
      body: FutureBuilder<List<Team>>(
        future: _teamsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Проекты не найдены'));
          }

          final teams = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
            itemCount: teams.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final team = teams[index];
              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeamDetailsScreen(team: team),
                    ),
                  );
                },
                title: Text(team.title, style: AppTextStyles.body),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (team.leader != null)
                      Text(
                        'Руководитель: ${team.leader!.fullName}',
                        style: AppTextStyles.caption,
                      ),
                    Text(
                      'Участников: ${team.researchers?.length ?? 0}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeamFormScreen(team: team),
                          ),
                        );
                        if (result == true) _refreshList();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () => _showDeleteDialog(team),
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
              builder: (context) => const TeamFormScreen(),
            ),
          );
          if (result == true) _refreshList();
        },
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
    );
  }

  void _showDeleteDialog(Team team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить проект "${team.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _service.delete(team.id!);
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

