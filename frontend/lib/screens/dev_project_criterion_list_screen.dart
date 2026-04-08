import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/dev_project_criterion_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../utils/clipboard_helper.dart';
import 'dev_project_criterion_form_screen.dart';

class DevProjectCriterionListScreen extends StatefulWidget {
  const DevProjectCriterionListScreen({super.key});

  @override
  State<DevProjectCriterionListScreen> createState() => _DevProjectCriterionListScreenState();
}

class _DevProjectCriterionListScreenState extends State<DevProjectCriterionListScreen> {
  final DevProjectCriterionService _service = DevProjectCriterionService();
  final ScrollController _scrollController = ScrollController();
  final List<DevProjectCriterion> _criteria = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;
  DevProjectCriterion? _selectedCriterion;

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
      _criteria.clear();
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
        _criteria.addAll(response.items);
        _currentOffset += _limit;
        _hasMore = _criteria.length < response.pagination.total;
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
        title: const Text('Критерии проектов (Dev)'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: _buildList(),
              floatingActionButton: FloatingActionButton(
                heroTag: 'add_dev_project_criterion_fab',
                backgroundColor: AppColors.primary,
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DevProjectCriterionFormScreen(),
                    ),
                  );
                  if (res == true) _refreshList();
                },
                child: const Icon(Icons.add, color: AppColors.surface),
              ),
            ),
          ),
          if (_selectedCriterion != null) ...[
            const VerticalDivider(width: 1),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  DevProjectCriterionFormScreen(
                    criterion: _selectedCriterion,
                    isEmbedded: true,
                    onCriterionUpdated: (updated) {
                      setState(() {
                        _selectedCriterion = updated;
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
                        _selectedCriterion = null;
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
    if (_criteria.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_criteria.isEmpty) {
      return const Center(child: Text('Критерии не найдены'));
    }

    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
        itemCount: _criteria.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _criteria.length) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMedium),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final criterion = _criteria[index];
          final isSelected = _selectedCriterion?.id == criterion.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            onTap: () {
              setState(() {
                _selectedCriterion = criterion;
              });
            },
            title: Text(
              criterion.title,
              style: AppTextStyles.body.copyWith(
                color: isSelected ? AppColors.primary : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text('Баллы: ${criterion.points ?? 0}', style: AppTextStyles.caption),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
                  onPressed: () => ClipboardHelper.copyToClipboard(context, criterion.title),
                  tooltip: 'Копировать название',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _showDeleteDialog(criterion),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(DevProjectCriterion criterion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить критерий "${criterion.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _service.delete(criterion.id!);
              if (mounted) {
                Navigator.pop(context);
                if (_selectedCriterion?.id == criterion.id) {
                  setState(() => _selectedCriterion = null);
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
