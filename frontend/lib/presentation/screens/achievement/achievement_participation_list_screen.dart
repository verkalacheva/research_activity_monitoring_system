import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/achievement_participation_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/utils/clipboard_helper.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_participation_form_screen.dart';

class AchievementParticipationListScreen extends StatefulWidget {
  const AchievementParticipationListScreen({super.key});

  @override
  State<AchievementParticipationListScreen> createState() => _AchievementParticipationListScreenState();
}

class _AchievementParticipationListScreenState extends State<AchievementParticipationListScreen> {
  final AchievementParticipationService _service = AchievementParticipationService();
  final ScrollController _scrollController = ScrollController();
  final List<AchievementParticipation> _participations = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;
  AchievementParticipation? _selectedParticipation;

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
      _participations.clear();
      _currentOffset = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _service.list(limit: _limit, offset: _currentOffset);
      setState(() {
        _participations.addAll(response.items);
        _currentOffset += _limit;
        _hasMore = _participations.length < response.pagination.total;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Типы участия'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: _buildList(),
              floatingActionButton: FloatingActionButton(
                heroTag: 'add_participation_fab',
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
            ),
          ),
          if (_selectedParticipation != null) ...[
            const VerticalDivider(width: 1),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  AchievementParticipationFormScreen(
                    participation: _selectedParticipation,
                    isEmbedded: true,
                    onParticipationUpdated: (updated) {
                      setState(() {
                        _selectedParticipation = updated;
                      });
                      _refreshList();
                    },
                  ),
                  Positioned(
                    top: AppDimensions.paddingMedium,
                    right: AppDimensions.paddingMedium,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _selectedParticipation = null;
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
    if (_participations.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_participations.isEmpty) {
      return const Center(child: Text('Типы участия не найдены'));
    }

    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
        itemCount: _participations.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _participations.length) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMedium),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final participation = _participations[index];
          final isSelected = _selectedParticipation?.id == participation.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            onTap: () {
              setState(() {
                _selectedParticipation = participation;
              });
            },
            title: Text(
              participation.title,
              style: AppTextStyles.body.copyWith(
                color: isSelected ? AppColors.primary : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text('Баллы: ${participation.points ?? 0}', style: AppTextStyles.caption),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
                  onPressed: () => ClipboardHelper.copyToClipboard(context, participation.title),
                  tooltip: 'Копировать название участия',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _showDeleteDialog(participation),
                ),
              ],
            ),
          );
        },
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
                if (_selectedParticipation?.id == participation.id) {
                  setState(() => _selectedParticipation = null);
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
