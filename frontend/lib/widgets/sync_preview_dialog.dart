import 'package:flutter/material.dart';
import '../services/integration_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';

class SyncPreviewDialog extends StatefulWidget {
  final String provider;
  const SyncPreviewDialog({super.key, this.provider = 'orcid'});

  @override
  State<SyncPreviewDialog> createState() => _SyncPreviewDialogState();
}

class _SyncPreviewDialogState extends State<SyncPreviewDialog> {
  final IntegrationService _service = IntegrationService();
  bool _isLoading = true;
  List<dynamic> _results = [];
  final Set<Map<String, dynamic>> _selectedAchievements = {};

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final results = await _service.syncPreview(provider: widget.provider);
      final enrichedResults = (results as List).map((res) {
        final researcherId = res['researcher_id'];
        final achievements = (res['achievements'] as List).map((a) {
          final achievement = Map<String, dynamic>.from(a);
          achievement['researcher_id'] = researcherId;
          return achievement;
        }).toList();
        
        return {
          ...res,
          'achievements': achievements,
        };
      }).toList();

      setState(() {
        _results = enrichedResults;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка синхронизации: $e')),
        );
      }
    }
  }

  Future<void> _saveSelected() async {
    if (_selectedAchievements.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await _service.saveAchievements(_selectedAchievements.toList());
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'])),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName = widget.provider == 'all' ? 'всех источников' : widget.provider.toUpperCase();
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Icon(
                        widget.provider == 'orcid' 
                          ? Icons.link 
                          : (widget.provider == 'openalex' ? Icons.school_outlined : Icons.all_inclusive),
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Синхронизация: $providerName', style: AppTextStyles.h2),
                        const Text('Выберите достижения для импорта в систему', style: AppTextStyles.bodySecondary),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: AppColors.inactive),
                              SizedBox(height: 16),
                              Text('Новых достижений не найдено', style: AppTextStyles.h3),
                            ],
                          ),
                        )
                      : _buildList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_selectedAchievements.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      'Выбрано: ${_selectedAchievements.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('ОТМЕНА'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _selectedAchievements.isEmpty ? null : _saveSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('СОХРАНИТЬ ВЫБРАННЫЕ', style: const TextStyle(color: AppColors.textOnPrimary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final res = _results[index];
        final researcherName = res['researcher_name'] ?? 'Неизвестный сотрудник';
        final achievements = res['achievements'] as List;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              margin: const EdgeInsets.only(top: 16, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Text(
                    researcherName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    'Найдено: ${achievements.length}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            ...achievements.map((achievement) {
              final isSelected = _selectedAchievements.contains(achievement);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.02) : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedAchievements.add(achievement);
                      } else {
                        _selectedAchievements.remove(achievement);
                      }
                    });
                  },
                  title: Text(
                    achievement['title'] ?? 'Без названия',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            achievement['type']?.toString().toUpperCase() ?? 'WORK',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          achievement['date'] ?? '—',
                          style: AppTextStyles.caption,
                        ),
                        if (achievement['journal_title'] != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.menu_book_outlined, size: 16, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              achievement['journal_title'],
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

