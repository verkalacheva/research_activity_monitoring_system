import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/researcher_service.dart';
import '../theme/app_dimensions.dart';

class ResearcherFormScreen extends StatefulWidget {
  final Researcher? researcher;

  const ResearcherFormScreen({super.key, this.researcher});

  @override
  State<ResearcherFormScreen> createState() => _ResearcherFormScreenState();
}

class _ResearcherFormScreenState extends State<ResearcherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ResearcherService _service = ResearcherService();

  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _secondNameController;
  late TextEditingController _subjectAreaController;

  String? _selectedDegreeLevel;
  int? _selectedCourse;

  final List<String> _degreeLevelOptions = [
    'к.т.н.',
    'д.т.н.',
    'к.ф.-м.н.',
    'д.ф.-м.н.',
    'аспирант',
    'бакалавр',
    'магистрант',
  ];

  final List<int> _courseOptions = [1, 2, 3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.researcher?.name ?? '');
    _surnameController = TextEditingController(text: widget.researcher?.surname ?? '');
    _secondNameController = TextEditingController(text: widget.researcher?.secondName ?? '');
    _subjectAreaController = TextEditingController(text: widget.researcher?.subjectArea ?? '');

    _selectedDegreeLevel = widget.researcher?.degreeLevel;
    _selectedCourse = widget.researcher?.course;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _secondNameController.dispose();
    _subjectAreaController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final researcher = Researcher(
        id: widget.researcher?.id,
        name: _nameController.text,
        surname: _surnameController.text,
        secondName: _secondNameController.text.isEmpty ? null : _secondNameController.text,
        degreeLevel: _selectedDegreeLevel,
        course: _selectedCourse,
        subjectArea: _subjectAreaController.text.isEmpty ? null : _subjectAreaController.text,
      );

      try {
        if (widget.researcher == null) {
          await _service.create(researcher);
        } else {
          await _service.update(widget.researcher!.id!, researcher);
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
        title: Text(widget.researcher == null ? 'Новый сотрудник' : 'Редактирование'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(labelText: 'Фамилия *'),
                validator: (value) => value == null || value.isEmpty ? 'Введите фамилию' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Имя *'),
                validator: (value) => value == null || value.isEmpty ? 'Введите имя' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                controller: _secondNameController,
                decoration: const InputDecoration(labelText: 'Отчество'),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              DropdownButtonFormField<String>(
                value: _selectedDegreeLevel,
                decoration: const InputDecoration(labelText: 'Ученая степень'),
                items: _degreeLevelOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() => _selectedDegreeLevel = newValue);
                },
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              DropdownButtonFormField<int>(
                value: _selectedCourse,
                decoration: const InputDecoration(labelText: 'Курс (для студентов/аспирантов)'),
                items: _courseOptions.map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() => _selectedCourse = newValue);
                },
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                controller: _subjectAreaController,
                decoration: const InputDecoration(labelText: 'Область исследований'),
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

