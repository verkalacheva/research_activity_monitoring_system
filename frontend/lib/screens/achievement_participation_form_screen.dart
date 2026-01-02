import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_participation_service.dart';
import '../theme/app_dimensions.dart';

class AchievementParticipationFormScreen extends StatefulWidget {
  final AchievementParticipation? participation;

  const AchievementParticipationFormScreen({super.key, this.participation});

  @override
  State<AchievementParticipationFormScreen> createState() => _AchievementParticipationFormScreenState();
}

class _AchievementParticipationFormScreenState extends State<AchievementParticipationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AchievementParticipationService _service = AchievementParticipationService();

  late TextEditingController _titleController;
  late TextEditingController _pointsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.participation?.title ?? '');
    _pointsController = TextEditingController(text: widget.participation?.points?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final participation = AchievementParticipation(
        id: widget.participation?.id,
        title: _titleController.text,
        points: double.tryParse(_pointsController.text),
      );

      try {
        if (widget.participation == null) {
          await _service.create(participation);
        } else {
          await _service.update(widget.participation!.id!, participation);
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
        title: Text(widget.participation == null ? 'Новый тип участия' : 'Редактирование'),
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

