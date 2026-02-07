import 'package:flutter/material.dart';
import '../services/integration_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';

class SyncPreviewDialog extends StatefulWidget {
  const SyncPreviewDialog({super.key});

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
      final results = await _service.syncPreview();
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
    return AlertDialog(
      title: const Text('Новые достижения из ORCID'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _results.isEmpty
                ? const Center(child: Text('Новых достижений не найдено'))
                : _buildList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _selectedAchievements.isEmpty ? null : _saveSelected,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Сохранить выбранные', style: TextStyle(color: Colors.white)),
        ),
      ],
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                researcherName,
                style: AppTextStyles.h3.copyWith(color: AppColors.primary),
              ),
            ),
            ...achievements.map((achievement) {
              final isSelected = _selectedAchievements.contains(achievement);

              return CheckboxListTile(
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
                title: Text(achievement['title'] ?? 'Без названия'),
                subtitle: Text('${achievement['type']} | ${achievement['date']}'),
                controlAffinity: ListTileControlAffinity.leading,
              );
            }).toList(),
            const Divider(),
          ],
        );
      },
    );
  }
}

