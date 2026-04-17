import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/achievement_participation_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';

class AchievementParticipationFormScreen extends StatefulWidget {
  final AchievementParticipation? participation;
  final bool isEmbedded;
  final Function(AchievementParticipation)? onParticipationUpdated;

  const AchievementParticipationFormScreen({
    super.key,
    this.participation,
    this.isEmbedded = false,
    this.onParticipationUpdated,
  });

  @override
  State<AchievementParticipationFormScreen> createState() => _AchievementParticipationFormScreenState();
}

class _AchievementParticipationFormScreenState extends State<AchievementParticipationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AchievementParticipationService _service = AchievementParticipationService();

  late TextEditingController _titleController;
  late TextEditingController _pointsController;
  bool _isLoading = false;
  bool _isEditing = false;
  late AchievementParticipation? _currentParticipation;

  @override
  void initState() {
    super.initState();
    _currentParticipation = widget.participation;
    _isEditing = widget.participation == null || !widget.isEmbedded;
    _titleController = TextEditingController();
    _pointsController = TextEditingController();
    _initControllers();
  }

  void _initControllers() {
    _titleController.text = _currentParticipation?.title ?? '';
    _pointsController.text = _currentParticipation?.points?.toString() ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AchievementParticipationFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participation != widget.participation) {
      setState(() {
        _currentParticipation = widget.participation;
        _isEditing = _currentParticipation == null || !widget.isEmbedded;
        _initControllers();
      });
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final participation = AchievementParticipation(
        id: _currentParticipation?.id,
        title: _titleController.text,
        points: double.tryParse(_pointsController.text) != null ? (double.parse(_pointsController.text) * 10).roundToDouble() / 10 : null,
      );

      try {
        AchievementParticipation result;
        if (_currentParticipation == null) {
          result = await _service.create(participation);
        } else {
          result = await _service.update(_currentParticipation!.id!, participation);
        }

        if (widget.isEmbedded) {
          setState(() {
            _currentParticipation = result;
            _isEditing = false;
            _isLoading = false;
            _initControllers();
          });
          widget.onParticipationUpdated?.call(result);
        } else {
          if (mounted) Navigator.pop(context, true);
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
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isEmbedded)
              Row(
                children: [
                  Flexible(
                    child: Text(_isEditing ? (_currentParticipation == null ? 'Новое участие' : 'Редактирование') : 'Информация об участии', style: AppTextStyles.h2),
                  ),
                  if (_currentParticipation != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_isEditing ? Icons.close : Icons.edit, color: AppColors.primary),
                      onPressed: () {
                        setState(() {
                          if (_isEditing) _initControllers();
                          _isEditing = !_isEditing;
                        });
                      },
                    ),
                  ],
                  const SizedBox(width: 40),
                ],
              ),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (!_isEditing && _currentParticipation != null) ...[
              _buildInfoRow('Название', _currentParticipation!.title),
              const Divider(),
              _buildInfoRow('Баллы по умолчанию', _currentParticipation!.points?.toStringAsFixed(1) ?? '0'),
            ] else ...[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Название *', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                controller: _pointsController,
                decoration: const InputDecoration(labelText: 'Баллы по умолчанию', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppDimensions.paddingExtraLarge),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Сохранить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentParticipation == null ? 'Новое участие' : 'Редактирование'),
      ),
      body: content,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
