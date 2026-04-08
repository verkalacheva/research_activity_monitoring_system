import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/researcher_service.dart';
import '../services/sync_notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../utils/clipboard_helper.dart';
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
  bool _bulkSelectMode = false;
  final Set<int> _bulkSelectedIds = {};

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

  void _showSyncMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height + 8,
        buttonPosition.dx + button.size.width,
        buttonPosition.dy + button.size.height + 108,
      ),
      items: [
        PopupMenuItem(
          value: 'all',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Icon(Icons.all_inclusive, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 16),
              const Text('Все', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'orcid',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Icon(Icons.link, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 16),
              const Text('ORCID', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'openalex',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Icon(Icons.school_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 16),
              const Text('OpenAlex', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'github', 
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Icon(Icons.code, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 16),
              const Text('GitHub', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'crawl',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Icon(Icons.search, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 16),
              const Text('Поиск по ссылке (AI)', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'crawl_search',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Icon(Icons.travel_explore, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 16),
              const Text('Поиск в интернете (AI)', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    ).then((provider) async {
      if (provider == null) return;

      final bulkIds = _bulkSelectMode ? _bulkSelectedIds.toList() : const <int>[];
      final useBulk = _bulkSelectMode && bulkIds.isNotEmpty;

      if (_bulkSelectMode && bulkIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Отметьте сотрудников для синхронизации')),
          );
        }
        return;
      }

      if (useBulk && provider == 'crawl') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Поиск по ссылке (AI) — только без массового выбора: один URL на задачу.',
              ),
            ),
          );
        }
        return;
      }

      void onSavedForResearcher(int? rid) {
        _refreshList();
        if (rid != null && _selectedResearcher?.id == rid) {
          _refreshSelectedResearcher(rid);
        }
      }

      // For 'crawl' provider ask for URL first, then start background sync.
      if (provider == 'crawl') {
        final url = await _askCrawlUrl(context);
        if (url == null) return;
        SyncNotificationService.instance.enqueue(SyncRequest(
          provider: 'crawl',
          url: url,
          researcherId: _selectedResearcher?.id,
          label: 'Поиск по ссылке (AI)',
          onSaved: () => onSavedForResearcher(_selectedResearcher?.id),
        ));
      } else {
        if (useBulk) {
          for (final id in bulkIds) {
            Researcher? ref;
            for (final r in _researchers) {
              if (r.id == id) {
                ref = r;
                break;
              }
            }
            final name = ref?.fullName ?? '#$id';
            final shortLabel = switch (provider) {
              'all' => 'Все источники',
              'crawl_search' => 'Поиск в интернете (AI)',
              _ => provider.toUpperCase(),
            };
            SyncNotificationService.instance.enqueue(SyncRequest(
              provider: provider,
              researcherId: id,
              label: '$shortLabel — $name',
              onSaved: () => onSavedForResearcher(id),
            ));
          }
        } else {
          final singleLabel = provider == 'crawl_search'
              ? 'Поиск в интернете (AI)'
              : 'Синхронизация: ${provider.toUpperCase()}';
          SyncNotificationService.instance.enqueue(SyncRequest(
            provider: provider,
            researcherId: _selectedResearcher?.id,
            label: singleLabel,
            onSaved: () => onSavedForResearcher(_selectedResearcher?.id),
          ));
        }
      }
      if (mounted) {
        final msg = useBulk
            ? 'Запущено задач синхронизации: ${bulkIds.length}'
            : 'Синхронизация запущена в фоне';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    });
  }

  void _toggleBulkSelectMode() {
    setState(() {
      _bulkSelectMode = !_bulkSelectMode;
      if (!_bulkSelectMode) {
        _bulkSelectedIds.clear();
      }
    });
  }

  void _selectAllLoadedResearchers() {
    setState(() {
      for (final r in _researchers) {
        if (r.id != null) _bulkSelectedIds.add(r.id!);
      }
    });
  }

  void _toggleBulkId(int id) {
    setState(() {
      if (_bulkSelectedIds.contains(id)) {
        _bulkSelectedIds.remove(id);
      } else {
        _bulkSelectedIds.add(id);
      }
    });
  }

  Future<String?> _askCrawlUrl(BuildContext ctx) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Поиск по ссылке (AI)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'URL страницы',
            hintText: 'https://example.com/publications',
            prefixIcon: Icon(Icons.link),
          ),
          onSubmitted: (_) => Navigator.pop(dCtx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('НАЧАТЬ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((v) => (v != null && v.isNotEmpty) ? v : null);
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
        title: Text(_bulkSelectMode ? 'Выбрано: ${_bulkSelectedIds.length}' : 'Сотрудники'),
        actions: [
          if (_bulkSelectMode) ...[
            TextButton(
              onPressed: _researchers.isEmpty ? null : _selectAllLoadedResearchers,
              child: const Text('ВСЕ НА ЭКРАНЕ'),
            ),
            IconButton(
              tooltip: 'Выйти из режима выбора',
              icon: const Icon(Icons.close),
              onPressed: _toggleBulkSelectMode,
            ),
          ] else
            IconButton(
              tooltip: 'Массовый выбор для синхронизации',
              icon: const Icon(Icons.checklist),
              onPressed: _toggleBulkSelectMode,
            ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Builder(
              builder: (context) => OutlinedButton.icon(
                onPressed: () => _showSyncMenu(context),
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('СИНХРОНИЗАЦИЯ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
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
          final rid = researcher.id;
          final isSelected = _selectedResearcher?.id == researcher.id;
          final inBulk = rid != null && _bulkSelectedIds.contains(rid);

          return ListTile(
            leading: _bulkSelectMode && rid != null
                ? Checkbox(
                    value: inBulk,
                    onChanged: (_) => _toggleBulkId(rid),
                  )
                : null,
            selected: !_bulkSelectMode && isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            onTap: () {
              if (_bulkSelectMode && rid != null) {
                _toggleBulkId(rid);
              } else {
                setState(() {
                  _selectedResearcher = researcher;
                });
              }
            },
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    researcher.fullName,
                    style: AppTextStyles.body.copyWith(
                      color: (isSelected || inBulk) ? AppColors.primary : null,
                      fontWeight: (isSelected || inBulk) ? FontWeight.bold : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (researcher.isLeader) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.star,
                    size: 16,
                    color: AppColors.warning,
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

