import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/researcher_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';

class ResearcherFormScreen extends StatefulWidget {
  final Researcher? researcher;
  final bool isEmbedded;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  const ResearcherFormScreen({
    super.key,
    this.researcher,
    this.isEmbedded = false,
    this.onSave,
    this.onCancel,
  });

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
  late TextEditingController _emailController;
  late TextEditingController _telegramController;
  late TextEditingController _isuNumberController;
  late TextEditingController _facultyController;
  late TextEditingController _employmentStatusController;
  late TextEditingController _orcidIdController;
  late TextEditingController _openalexIdController;

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
    _emailController = TextEditingController(text: widget.researcher?.email ?? '');
    _telegramController = TextEditingController(text: widget.researcher?.telegram ?? '');
    _isuNumberController = TextEditingController(text: widget.researcher?.isuNumber ?? '');
    _facultyController = TextEditingController(text: widget.researcher?.faculty ?? '');
    _employmentStatusController = TextEditingController(text: widget.researcher?.employmentStatus ?? '');
    _orcidIdController = TextEditingController(text: widget.researcher?.orcidId ?? '');
    _openalexIdController = TextEditingController(text: widget.researcher?.openalexId ?? '');

    _selectedDegreeLevel = widget.researcher?.degreeLevel;
    _selectedCourse = widget.researcher?.course;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _secondNameController.dispose();
    _subjectAreaController.dispose();
    _emailController.dispose();
    _telegramController.dispose();
    _isuNumberController.dispose();
    _facultyController.dispose();
    _employmentStatusController.dispose();
    _orcidIdController.dispose();
    _openalexIdController.dispose();
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
        email: _emailController.text.isEmpty ? null : _emailController.text,
        telegram: _telegramController.text.isEmpty ? null : _telegramController.text,
        isuNumber: _isuNumberController.text.isEmpty ? null : _isuNumberController.text,
        faculty: _facultyController.text.isEmpty ? null : _facultyController.text,
        employmentStatus: _employmentStatusController.text.isEmpty ? null : _employmentStatusController.text,
        orcidId: _orcidIdController.text.isEmpty ? null : _orcidIdController.text,
        openalexId: _openalexIdController.text.isEmpty ? null : _openalexIdController.text,
      );

      try {
        if (widget.researcher == null) {
          await _service.create(researcher);
        } else {
          await _service.update(widget.researcher!.id!, researcher);
        }
        if (mounted) {
          if (widget.onSave != null) {
            widget.onSave!();
          } else {
            Navigator.pop(context, true);
          }
        }
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
    final content = SingleChildScrollView(
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
              decoration: const InputDecoration(labelText: 'Направление'),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Почта'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: _telegramController,
              decoration: const InputDecoration(labelText: 'Телеграм (ссылка)'),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: _isuNumberController,
              decoration: const InputDecoration(labelText: 'ИСУ'),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: _facultyController,
              decoration: const InputDecoration(labelText: 'Факультет'),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: _employmentStatusController,
              decoration: const InputDecoration(
                labelText: 'Трудоустройство',
                helperText: 'Укажите дату поступления или период (напр. март 2025, 01.09.2024)',
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: _orcidIdController,
              decoration: const InputDecoration(labelText: 'ORCID ID (напр. 0000-0001-2345-6789)'),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: _openalexIdController,
              decoration: const InputDecoration(labelText: 'OpenAlex ID (напр. A5023888336)'),
            ),
            const SizedBox(height: AppDimensions.paddingExtraLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isEmbedded) ...[
                  OutlinedButton(
                    onPressed: widget.onCancel ?? () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: AppDimensions.paddingMedium),
                ],
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Сохранить'),
                ),
              ],
            ),
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
        title: Text(widget.researcher == null ? 'Новый сотрудник' : 'Редактирование'),
      ),
      body: content,
    );
  }
}

