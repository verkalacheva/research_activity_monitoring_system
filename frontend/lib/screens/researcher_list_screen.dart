import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/researcher_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import 'researcher_form_screen.dart';
import 'researcher_profile_screen.dart';

class ResearcherListScreen extends StatefulWidget {
  const ResearcherListScreen({super.key});

  @override
  State<ResearcherListScreen> createState() => _ResearcherListScreenState();
}

class _ResearcherListScreenState extends State<ResearcherListScreen> {
  final ResearcherService _service = ResearcherService();
  late Future<List<Researcher>> _researchersFuture;
  Researcher? _selectedResearcher;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _researchersFuture = _service.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сотрудники'),
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
                  ),
                  Positioned(
                    top: AppDimensions.paddingMedium,
                    right: AppDimensions.paddingMedium,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selectedResearcher = null),
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
    return FutureBuilder<List<Researcher>>(
      future: _researchersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Сотрудники не найдены'));
        }

        final researchers = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
          itemCount: researchers.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final researcher = researchers[index];
            final isSelected = _selectedResearcher?.id == researcher.id;

            return ListTile(
              selected: isSelected,
              selectedTileColor: AppColors.primary.withOpacity(0.05),
              onTap: () {
                setState(() {
                  _selectedResearcher = researcher;
                });
              },
              title: Text(
                researcher.fullName,
                style: AppTextStyles.body.copyWith(
                  color: isSelected ? AppColors.primary : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
              subtitle: Text(
                '${researcher.degreeLevel ?? ''} ${researcher.subjectArea ?? ''}'.trim(),
                style: AppTextStyles.caption,
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
                          builder: (context) => ResearcherFormScreen(researcher: researcher),
                        ),
                      );
                      if (result == true) {
                        _refreshList();
                        if (isSelected) {
                          _refreshSelectedResearcher(researcher.id!);
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    onPressed: () => _showDeleteDialog(researcher),
                  ),
                ],
              ),
            );
          },
        );
      },
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

