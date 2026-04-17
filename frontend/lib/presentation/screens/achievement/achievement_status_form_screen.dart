import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/achievement_status_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';

class AchievementStatusFormScreen extends StatefulWidget {
  final AchievementStatus? status;
  final bool isEmbedded;
  final Function(AchievementStatus)? onStatusUpdated;

  const AchievementStatusFormScreen({
    super.key,
    this.status,
    this.isEmbedded = false,
    this.onStatusUpdated,
  });

  @override
  State<AchievementStatusFormScreen> createState() => _AchievementStatusFormScreenState();
}

class _AchievementStatusFormScreenState extends State<AchievementStatusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AchievementStatusService _service = AchievementStatusService();

  late TextEditingController _titleController;
  late TextEditingController _pointsController;
  bool _isLoading = false;
  bool _isEditing = false;
  late AchievementStatus? _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _isEditing = widget.status == null || !widget.isEmbedded;
    _titleController = TextEditingController();
    _pointsController = TextEditingController();
    _initControllers();
  }

  void _initControllers() {
    _titleController.text = _currentStatus?.title ?? '';
    _pointsController.text = _currentStatus?.points?.toString() ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AchievementStatusFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      setState(() {
        _currentStatus = widget.status;
        _isEditing = _currentStatus == null || !widget.isEmbedded;
        _initControllers();
      });
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final status = AchievementStatus(
        id: _currentStatus?.id,
        title: _titleController.text,
        points: double.tryParse(_pointsController.text) != null ? (double.parse(_pointsController.text) * 10).roundToDouble() / 10 : null,
      );

      try {
        AchievementStatus result;
        if (_currentStatus == null) {
          result = await _service.create(status);
        } else {
          result = await _service.update(_currentStatus!.id!, status);
        }
        
        if (widget.isEmbedded) {
          setState(() {
            _currentStatus = result;
            _isEditing = false;
            _isLoading = false;
            _initControllers();
          });
          widget.onStatusUpdated?.call(result);
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
                    child: Text(_isEditing ? (_currentStatus == null ? 'Новый статус' : 'Редактирование') : 'Информация о статусе', style: AppTextStyles.h2),
                  ),
                  if (_currentStatus != null) ...[
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
            if (!_isEditing && _currentStatus != null) ...[
              _buildInfoRow('Название', _currentStatus!.title),
              const Divider(),
              _buildInfoRow('Баллы по умолчанию', _currentStatus!.points?.toStringAsFixed(1) ?? '0'),
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
        title: Text(_currentStatus == null ? 'Новый статус' : 'Редактирование'),
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
