import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_status_service.dart';
import '../theme/app_dimensions.dart';

class AchievementStatusFormScreen extends StatefulWidget {
  final AchievementStatus? status;

  const AchievementStatusFormScreen({super.key, this.status});

  @override
  State<AchievementStatusFormScreen> createState() => _AchievementStatusFormScreenState();
}

class _AchievementStatusFormScreenState extends State<AchievementStatusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AchievementStatusService _service = AchievementStatusService();

  late TextEditingController _titleController;
  late TextEditingController _pointsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.status?.title ?? '');
    _pointsController = TextEditingController(text: widget.status?.points?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final status = AchievementStatus(
        id: widget.status?.id,
        title: _titleController.text,
        points: double.tryParse(_pointsController.text) != null ? (double.parse(_pointsController.text) * 10).roundToDouble() / 10 : null,
      );

      try {
        if (widget.status == null) {
          await _service.create(status);
        } else {
          await _service.update(widget.status!.id!, status);
        }
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.status == null ? 'Новый статус' : 'Редактирование'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Название *'),
                validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                controller: _pointsController,
                decoration: const InputDecoration(labelText: 'Баллы по умолчанию'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppDimensions.paddingExtraLarge),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

