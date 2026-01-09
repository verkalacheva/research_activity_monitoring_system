import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../services/achievement_service.dart';
import '../services/achievement_type_service.dart';
import '../services/achievement_status_service.dart';
import '../services/achievement_result_service.dart';
import '../services/achievement_participation_service.dart';
import '../theme/app_dimensions.dart';

class AchievementFormScreen extends StatefulWidget {
  final Achievement? achievement;
  final int researcherId;

  const AchievementFormScreen({super.key, this.achievement, required this.researcherId});

  @override
  State<AchievementFormScreen> createState() => _AchievementFormScreenState();
}

class _AchievementFormScreenState extends State<AchievementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _achievementService = AchievementService();
  final _typeService = AchievementTypeService();
  final _statusService = AchievementStatusService();
  final _resultService = AchievementResultService();
  final _participationService = AchievementParticipationService();

  List<AchievementType> _types = [];
  List<AchievementStatus> _statuses = [];
  List<AchievementResult> _results = [];
  List<AchievementParticipation> _participations = [];

  AchievementType? _selectedType;
  AchievementStatus? _selectedStatus;
  AchievementResult? _selectedResult;
  AchievementParticipation? _selectedParticipation;
  DateTime _submissionDate = DateTime.now();
  late TextEditingController _submissionDateController;
  
  final Map<int, TextEditingController> _fieldControllers = {};
  final Map<int, bool> _fieldBoolValues = {};
  final Map<int, String> _fieldIsoDates = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _submissionDate = widget.achievement?.submissionDate ?? DateTime.now();
    _submissionDateController = TextEditingController(
      text: DateFormat('dd.MM.yyyy HH:mm').format(_submissionDate),
    );
    _loadData();
  }

  @override
  void dispose() {
    _submissionDateController.dispose();
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _typeService.getAll(),
        _statusService.getAll(),
        _resultService.getAll(),
        _participationService.getAll(),
      ]);

      setState(() {
        _types = results[0] as List<AchievementType>;
        _statuses = results[1] as List<AchievementStatus>;
        _results = results[2] as List<AchievementResult>;
        _participations = results[3] as List<AchievementParticipation>;

        if (widget.achievement != null) {
          _selectedType = _types.firstWhere((t) => t.id == widget.achievement!.achievementTypeId);
          _selectedStatus = _statuses.firstWhere((s) => s.id == widget.achievement!.achievementStatusId);
          _selectedResult = _results.firstWhere((r) => r.id == widget.achievement!.achievementResultId);
          _selectedParticipation = _participations.firstWhere((p) => p.id == widget.achievement!.achievementParticipationId);
          
          _initFieldValues();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
      }
    }
  }

  void _initFieldValues() {
    if (_selectedType == null || widget.achievement == null) return;

    for (var field in _selectedType!.fields) {
      final answer = widget.achievement!.answers.firstWhere(
        (a) => a.achievementFieldId == field.id,
        orElse: () => AchievementFieldAnswer(achievementFieldId: field.id!, value: ''),
      );

      if (field.fieldType == 'boolean') {
        _fieldBoolValues[field.id!] = answer.value.toLowerCase() == 'true';
      } else if (field.fieldType == 'date') {
        if (answer.value.isNotEmpty) {
          try {
            final date = DateTime.parse(answer.value);
            _fieldIsoDates[field.id!] = answer.value;
            _fieldControllers[field.id!] = TextEditingController(text: DateFormat('dd.MM.yyyy').format(date));
          } catch (_) {
            _fieldControllers[field.id!] = TextEditingController(text: answer.value);
          }
        } else {
          _fieldControllers[field.id!] = TextEditingController();
        }
      } else {
        _fieldControllers[field.id!] = TextEditingController(text: answer.value);
      }
    }
  }

  void _onTypeChanged(AchievementType? type) {
    setState(() {
      _selectedType = type;
      _fieldControllers.clear();
      _fieldBoolValues.clear();
      _fieldIsoDates.clear();
      if (type != null) {
        for (var field in type.fields) {
          if (field.fieldType == 'boolean') {
            _fieldBoolValues[field.id!] = false;
          } else {
            _fieldControllers[field.id!] = TextEditingController();
          }
        }
      }
    });
  }

  double _calculatePoints() {
    double typePoints = _selectedType?.points ?? 0;
    double statusPoints = _selectedStatus?.points ?? 1;
    double resultPoints = _selectedResult?.points ?? 1;
    double participationPoints = _selectedParticipation?.points ?? 1;

    if (_selectedType == null || _selectedStatus == null || _selectedResult == null || _selectedParticipation == null) {
      return 0;
    }

    return typePoints * statusPoints * resultPoints * participationPoints;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final List<AchievementFieldAnswer> answers = [];
    if (_selectedType != null) {
      for (var field in _selectedType!.fields) {
        String value = '';
        if (field.fieldType == 'boolean') {
          value = (_fieldBoolValues[field.id!] ?? false).toString();
        } else if (field.fieldType == 'date') {
          value = _fieldIsoDates[field.id!] ?? '';
        } else {
          value = _fieldControllers[field.id!]?.text ?? '';
        }
        
        // Find existing answer ID if editing
        int? existingId;
        if (widget.achievement != null) {
          final existing = widget.achievement!.answers.firstWhere(
            (a) => a.achievementFieldId == field.id,
            orElse: () => AchievementFieldAnswer(achievementFieldId: -1, value: ''),
          );
          if (existing.id != null) existingId = existing.id;
        }

        answers.add(AchievementFieldAnswer(
          id: existingId,
          achievementFieldId: field.id!,
          value: value,
        ));
      }
    }

    final achievement = Achievement(
      id: widget.achievement?.id,
      achievementTypeId: _selectedType!.id!,
      achievementStatusId: _selectedStatus!.id!,
      achievementResultId: _selectedResult!.id!,
      achievementParticipationId: _selectedParticipation!.id!,
      submissionDate: _submissionDate,
      answers: answers,
    );

    try {
      if (widget.achievement == null) {
        await _achievementService.create(achievement, [widget.researcherId]);
      } else {
        await _achievementService.update(widget.achievement!.id!, achievement, [widget.researcherId]);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.achievement == null ? 'Добавить достижение' : 'Редактировать достижение'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<AchievementType>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Тип достижения *'),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.title))).toList(),
                onChanged: _onTypeChanged,
                validator: (v) => v == null ? 'Выберите тип' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              DropdownButtonFormField<AchievementStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Статус *'),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.title))).toList(),
                onChanged: (v) => setState(() => _selectedStatus = v),
                validator: (v) => v == null ? 'Выберите статус' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              DropdownButtonFormField<AchievementResult>(
                value: _selectedResult,
                decoration: const InputDecoration(labelText: 'Результат *'),
                items: _results.map((r) => DropdownMenuItem(value: r, child: Text(r.title))).toList(),
                onChanged: (v) => setState(() => _selectedResult = v),
                validator: (v) => v == null ? 'Выберите результат' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              DropdownButtonFormField<AchievementParticipation>(
                value: _selectedParticipation,
                decoration: const InputDecoration(labelText: 'Участие *'),
                items: _participations.map((p) => DropdownMenuItem(value: p, child: Text(p.title))).toList(),
                onChanged: (v) => setState(() => _selectedParticipation = v),
                validator: (v) => v == null ? 'Выберите тип участия' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                controller: _submissionDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Дата загрузки (Timestamp) *',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _selectSubmissionDate,
                validator: (v) => v == null || v.isEmpty ? 'Выберите дату' : null,
              ),
              if (_selectedType != null && _selectedType!.fields.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.paddingLarge),
                const Text('Дополнительные поля:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                const SizedBox(height: AppDimensions.paddingSmall),
                ..._selectedType!.fields.map((field) => _buildDynamicField(field)),
              ],
              const SizedBox(height: AppDimensions.paddingExtraLarge),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Предварительный расчет баллов:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _calculatePoints().toStringAsFixed(2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectSubmissionDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _submissionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ru', 'RU'),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_submissionDate),
      );

      if (time != null) {
        setState(() {
          _submissionDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          _submissionDateController.text = DateFormat('dd.MM.yyyy HH:mm').format(_submissionDate);
        });
      }
    }
  }

  Future<void> _selectDate(int fieldId) async {
    DateTime initialDate = DateTime.now();
    final isoDate = _fieldIsoDates[fieldId];
    if (isoDate != null && isoDate.isNotEmpty) {
      try {
        initialDate = DateTime.parse(isoDate);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ru', 'RU'),
    );

    if (picked != null) {
      setState(() {
        final isoString = picked.toIso8601String().split('T')[0];
        _fieldIsoDates[fieldId] = isoString;
        _fieldControllers[fieldId]?.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Widget _buildDynamicField(AchievementField field) {
    if (field.fieldType == 'boolean') {
      return CheckboxListTile(
        title: Text(field.title),
        value: _fieldBoolValues[field.id!] ?? false,
        onChanged: (v) => setState(() => _fieldBoolValues[field.id!] = v ?? false),
      );
    }

    if (field.fieldType == 'select') {
      return DropdownButtonFormField<String>(
        value: _fieldControllers[field.id!]?.text.isEmpty == true ? null : _fieldControllers[field.id!]?.text,
        decoration: InputDecoration(labelText: field.title + (field.isRequired ? ' *' : '')),
        items: field.options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: (v) => setState(() => _fieldControllers[field.id!]?.text = v ?? ''),
        validator: (v) => field.isRequired && (v == null || v.isEmpty) ? 'Обязательное поле' : null,
      );
    }

    if (field.fieldType == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
        child: TextFormField(
          controller: _fieldControllers[field.id!],
          readOnly: true,
          decoration: InputDecoration(
            labelText: field.title + (field.isRequired ? ' *' : ''),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () => _selectDate(field.id!),
          validator: (v) {
            if (field.isRequired && (v == null || v.isEmpty)) return 'Обязательное поле';
            return null;
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
      child: TextFormField(
        controller: _fieldControllers[field.id!],
        decoration: InputDecoration(
          labelText: field.title + (field.isRequired ? ' *' : ''),
        ),
        keyboardType: field.fieldType == 'number' ? TextInputType.number : TextInputType.text,
        validator: (v) {
          if (field.isRequired && (v == null || v.isEmpty)) return 'Обязательное поле';
          return null;
        },
      ),
    );
  }
}

