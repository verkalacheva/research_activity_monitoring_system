import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_result_service.dart';
import '../theme/app_dimensions.dart';

class AchievementResultFormScreen extends StatefulWidget {
  final AchievementResult? result;

  const AchievementResultFormScreen({super.key, this.result});

  @override
  State<AchievementResultFormScreen> createState() => _AchievementResultFormScreenState();
}

class _AchievementResultFormScreenState extends State<AchievementResultFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AchievementResultService _service = AchievementResultService();

  late TextEditingController _titleController;
  late TextEditingController _pointsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.result?.title ?? '');
    _pointsController = TextEditingController(text: widget.result?.points?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final result = AchievementResult(
        id: widget.result?.id,
        title: _titleController.text,
        points: double.tryParse(_pointsController.text) != null ? (double.parse(_pointsController.text) * 10).roundToDouble() / 10 : null,
      );

      try {
        if (widget.result == null) {
          await _service.create(result);
        } else {
          await _service.update(widget.result!.id!, result);
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
        title: Text(widget.result == null ? 'Новый результат' : 'Редактирование'),
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

