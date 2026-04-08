import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/team_service.dart';
import '../services/sync_notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../utils/clipboard_helper.dart';
import 'team_details_screen.dart';
import 'team_form_screen.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  final TeamService _service = TeamService();
  final ScrollController _scrollController = ScrollController();
  final List<Team> _teams = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;
  Team? _selectedTeam;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _refreshList() async {
    setState(() {
      _teams.clear();
      _currentOffset = 0;
      _hasMore = true;
    });
    await _loadMore();
    _syncSelectedTeam();
  }

  void _syncSelectedTeam() {
    if (_selectedTeam == null) return;
    final fresh = _teams.where((t) => t.id == _selectedTeam!.id).firstOrNull;
    if (fresh != null && fresh != _selectedTeam) {
      setState(() => _selectedTeam = fresh);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _service.list(limit: _limit, offset: _currentOffset);
      setState(() {
        _teams.addAll(response.items);
        _currentOffset += _limit;
        _hasMore = _teams.length < response.pagination.total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  void _syncAllTeams() {
    SyncNotificationService.instance.enqueue(SyncRequest(
      provider: 'github',
      scope: 'teams',
      label: 'GitHub — все проекты',
      onSaved: _refreshList,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Синхронизация GitHub запущена в фоне')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проекты'),
        actions: [
          Tooltip(
            message: 'Синхронизировать все проекты через GitHub',
            child: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncAllTeams,
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: _buildList(),
              floatingActionButton: FloatingActionButton(
                heroTag: 'add_team_fab',
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
            ),
          ),
          if (_selectedTeam != null) ...[
            const VerticalDivider(width: 1),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  TeamDetailsScreen(
                    team: _selectedTeam!,
                    isEmbedded: true,
                    onTeamUpdated: (updated) {
                      setState(() => _selectedTeam = updated);
                      _refreshList();
                    },
                  ),
                  Positioned(
                    top: AppDimensions.paddingMedium,
                    right: AppDimensions.paddingMedium,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _selectedTeam = null;
                      }),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_teams.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_teams.isEmpty) {
      return const Center(child: Text('Проекты не найдены'));
    }

    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
        itemCount: _teams.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _teams.length) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMedium),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final team = _teams[index];
          final isSelected = _selectedTeam?.id == team.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            onTap: () {
              setState(() {
                _selectedTeam = team;
              });
            },
            title: Text(
              team.title,
              style: AppTextStyles.body.copyWith(
                color: isSelected ? AppColors.primary : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
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
                  icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
                  onPressed: () => ClipboardHelper.copyToClipboard(context, team.title),
                  tooltip: 'Копировать название проекта',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _showDeleteDialog(team),
                ),
              ],
            ),
          );
        },
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
                if (_selectedTeam?.id == team.id) {
                  setState(() => _selectedTeam = null);
                }
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

