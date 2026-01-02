import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_type_service.dart';
import '../theme/app_dimensions.dart';

class AchievementTypeFormScreen extends StatefulWidget {
  final AchievementType? type;

  const AchievementTypeFormScreen({super.key, this.type});

  @override
  State<AchievementTypeFormScreen> createState() => _AchievementTypeFormScreenState();
}

class _AchievementTypeFormScreenState extends State<AchievementTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AchievementTypeService _service = AchievementTypeService();

  late TextEditingController _titleController;
  late TextEditingController _pointsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.type?.title ?? '');
    _pointsController = TextEditingController(text: widget.type?.points?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final type = AchievementType(
        id: widget.type?.id,
        title: _titleController.text,
        points: double.tryParse(_pointsController.text),
      );

      try {
        if (widget.type == null) {
          await _service.create(type);
        } else {
          await _service.update(widget.type!.id!, type);
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
        title: Text(widget.type == null ? 'Новый тип достижения' : 'Редактирование'),
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

