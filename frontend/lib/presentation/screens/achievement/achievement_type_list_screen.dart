import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/achievement_type_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/utils/icon_helper.dart';
import 'package:research_activity_monitoring_system/core/utils/clipboard_helper.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_type_form_screen.dart';
import 'package:research_activity_monitoring_system/presentation/screens/achievement/achievement_type_details_screen.dart';

class AchievementTypeListScreen extends StatefulWidget {
  const AchievementTypeListScreen({super.key});

  @override
  State<AchievementTypeListScreen> createState() => _AchievementTypeListScreenState();
}

class _AchievementTypeListScreenState extends State<AchievementTypeListScreen> {
  final AchievementTypeService _service = AchievementTypeService();
  final ScrollController _scrollController = ScrollController();
  final List<AchievementType> _types = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;
  AchievementType? _selectedType;

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
      _types.clear();
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
        _types.addAll(response.items);
        _currentOffset += _limit;
        _hasMore = _types.length < response.pagination.total;
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
        title: const Text('Типы достижений'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: _buildList(),
              floatingActionButton: FloatingActionButton(
                heroTag: 'add_achievement_type_fab',
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
            ),
          ),
          if (_selectedType != null) ...[
            const VerticalDivider(width: 1),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  AchievementTypeDetailsScreen(
                    type: _selectedType!,
                    isEmbedded: true,
                    onTypeUpdated: (updated) {
                      setState(() {
                        _selectedType = updated;
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
                        _selectedType = null;
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
    if (_types.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_types.isEmpty) {
      return const Center(child: Text('Типы достижений не найдены'));
    }

    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
        itemCount: _types.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _types.length) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMedium),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final type = _types[index];
          final isSelected = _selectedType?.id == type.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                IconHelper.getIcon(type.iconName),
                color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.7),
              ),
            ),
            title: Text(
              type.title,
              style: AppTextStyles.body.copyWith(
                color: isSelected ? AppColors.primary : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text('Баллы: ${type.points?.toStringAsFixed(1) ?? 0}', style: AppTextStyles.caption),
            onTap: () {
              setState(() {
                _selectedType = type;
              });
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
                  onPressed: () => ClipboardHelper.copyToClipboard(context, type.title),
                  tooltip: 'Копировать название типа',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _showDeleteDialog(type),
                ),
              ],
            ),
          );
        },
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
                if (_selectedType?.id == type.id) {
                  setState(() => _selectedType = null);
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
