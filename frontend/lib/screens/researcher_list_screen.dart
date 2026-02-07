import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/researcher_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../utils/clipboard_helper.dart';
import '../widgets/sync_preview_dialog.dart';
import 'researcher_form_screen.dart';
import 'researcher_profile_screen.dart';

class ResearcherListScreen extends StatefulWidget {
  const ResearcherListScreen({super.key});

  @override
  State<ResearcherListScreen> createState() => _ResearcherListScreenState();
}

class _ResearcherListScreenState extends State<ResearcherListScreen> {
  final ResearcherService _service = ResearcherService();
  final ScrollController _scrollController = ScrollController();
  final List<Researcher> _researchers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;
  Researcher? _selectedResearcher;

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
      _researchers.clear();
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
        _researchers.addAll(response.items);
        _currentOffset += _limit;
        _hasMore = _researchers.length < response.pagination.total;
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
        title: const Text('Сотрудники'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Синхронизировать с ORCID',
            onPressed: () async {
              final result = await showDialog(
                context: context,
                builder: (context) => const SyncPreviewDialog(),
              );
              if (result == true) {
                _refreshList();
                if (_selectedResearcher != null) {
                  _refreshSelectedResearcher(_selectedResearcher!.id!);
                }
              }
            },
          ),
          const SizedBox(width: 8),
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
                heroTag: 'add_researcher_fab',
                backgroundColor: AppColors.primary,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ResearcherFormScreen(),
                    ),
                  );
                  if (result == true) _refreshList();
                },
                child: const Icon(Icons.add, color: AppColors.surface),
              ),
            ),
          ),
          if (_selectedResearcher != null) ...[
            const VerticalDivider(width: 1),
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ResearcherProfileScreen(
                    researcher: _selectedResearcher!,
                    isEmbedded: true,
                    onResearcherUpdated: (updated) {
                      setState(() {
                        _selectedResearcher = updated;
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
                        _selectedResearcher = null;
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
    if (_researchers.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_researchers.isEmpty) {
      return const Center(child: Text('Сотрудники не найдены'));
    }

    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
        itemCount: _researchers.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _researchers.length) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMedium),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final researcher = _researchers[index];
          final isSelected = _selectedResearcher?.id == researcher.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            onTap: () {
              setState(() {
                _selectedResearcher = researcher;
              });
            },
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    researcher.fullName,
                    style: AppTextStyles.body.copyWith(
                      color: isSelected ? AppColors.primary : null,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (researcher.isLeader) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.amber,
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '${researcher.degreeLevel ?? ''} ${researcher.subjectArea ?? ''}'.trim(),
              style: AppTextStyles.caption,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
                  onPressed: () => ClipboardHelper.copyToClipboard(context, researcher.fullName),
                  tooltip: 'Копировать ФИО',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _showDeleteDialog(researcher),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshSelectedResearcher(int id) async {
    try {
      final updated = await _service.getById(id);
      setState(() {
        _selectedResearcher = updated;
      });
    } catch (_) {}
  }

  void _showDeleteDialog(Researcher researcher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить сотрудника ${researcher.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _service.delete(researcher.id!);
              if (mounted) {
                Navigator.pop(context);
                if (_selectedResearcher?.id == researcher.id) {
                  setState(() => _selectedResearcher = null);
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

