import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/achievement_result_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/utils/clipboard_helper.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_result_form_screen.dart';

class AchievementResultListScreen extends StatefulWidget {
  const AchievementResultListScreen({super.key});

  @override
  State<AchievementResultListScreen> createState() => _AchievementResultListScreenState();
}

class _AchievementResultListScreenState extends State<AchievementResultListScreen> {
  final AchievementResultService _service = AchievementResultService();
  final ScrollController _scrollController = ScrollController();
  final List<AchievementResult> _results = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;
  AchievementResult? _selectedResult;

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
      _results.clear();
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
        _results.addAll(response.items);
        _currentOffset += _limit;
        _hasMore = _results.length < response.pagination.total;
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
        title: const Text('Результаты достижений'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: _buildList(),
              floatingActionButton: FloatingActionButton(
                heroTag: 'add_achievement_result_fab',
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
            ),
          ),
          if (_selectedResult != null) ...[
            const VerticalDivider(width: 1),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  AchievementResultFormScreen(
                    result: _selectedResult,
                    isEmbedded: true,
                    onResultUpdated: (updated) {
                      setState(() {
                        _selectedResult = updated;
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
                        _selectedResult = null;
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
    if (_results.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_results.isEmpty) {
      return const Center(child: Text('Результаты не найдены'));
    }

    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
        itemCount: _results.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _results.length) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMedium),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final result = _results[index];
          final isSelected = _selectedResult?.id == result.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            onTap: () {
              setState(() {
                _selectedResult = result;
              });
            },
            title: Text(
              result.title,
              style: AppTextStyles.body.copyWith(
                color: isSelected ? AppColors.primary : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text('Баллы: ${result.points ?? 0}', style: AppTextStyles.caption),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
                  onPressed: () => ClipboardHelper.copyToClipboard(context, result.title),
                  tooltip: 'Копировать название результата',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _showDeleteDialog(result),
                ),
              ],
            ),
          );
        },
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
                if (_selectedResult?.id == result.id) {
                  setState(() => _selectedResult = null);
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
