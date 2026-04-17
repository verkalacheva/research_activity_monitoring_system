import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/achievement_type_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/utils/icon_helper.dart';

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
  String? _selectedIconName;
  List<AchievementField> _fields = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.type?.title ?? '');
    _pointsController = TextEditingController(text: widget.type?.points?.toString() ?? '');
    _selectedIconName = widget.type?.iconName;
    _fields = widget.type?.fields.map((f) => AchievementField(
      id: f.id,
      title: f.title,
      fieldType: f.fieldType,
      isRequired: f.isRequired,
      options: List.from(f.options),
    )).toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  void _addField() {
    setState(() {
      _fields.add(AchievementField(
        title: '',
        fieldType: 'string',
        isRequired: false,
        options: [],
      ));
    });
  }

  void _removeField(int index) {
    setState(() {
      if (_fields[index].id != null) {
        // Mark for destruction
        _fields[index] = AchievementField(
          id: _fields[index].id,
          title: _fields[index].title,
          fieldType: _fields[index].fieldType,
          isRequired: _fields[index].isRequired,
          options: _fields[index].options,
          destroy: true,
        );
      } else {
        _fields.removeAt(index);
      }
    });
  }

  void _addOption(int fieldIndex) {
    setState(() {
      _fields[fieldIndex].options.add('');
    });
  }

  void _removeOption(int fieldIndex, int optionIndex) {
    setState(() {
      _fields[fieldIndex].options.removeAt(optionIndex);
    });
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final type = AchievementType(
        id: widget.type?.id,
        title: _titleController.text,
        points: double.tryParse(_pointsController.text) != null ? (double.parse(_pointsController.text) * 10).roundToDouble() / 10 : null,
        iconName: _selectedIconName,
        fields: _fields,
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
    final activeFields = _fields.where((f) => f.destroy != true).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == null ? 'Новый тип достижения' : 'Редактирование'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: AppDimensions.paddingMedium),
              const Text('Иконка', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppDimensions.paddingSmall),
              Wrap(
                spacing: 8,
                children: IconHelper.icons.entries.map((entry) {
                  final isSelected = _selectedIconName == entry.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIconName = entry.key),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        entry.value,
                        color: isSelected ? Colors.white : Colors.black54,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.paddingExtraLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Дополнительные поля', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addField,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppDimensions.paddingSmall),
              ...List.generate(_fields.length, (index) {
                if (_fields[index].destroy == true) return const SizedBox.shrink();
                
                return Card(
                  margin: const EdgeInsets.only(bottom: AppDimensions.paddingMedium),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: _fields[index].title,
                                decoration: const InputDecoration(labelText: 'Название поля'),
                                validator: (v) => v == null || v.isEmpty ? 'Обязательно' : null,
                                onSaved: (v) => _fields[index] = AchievementField(
                                  id: _fields[index].id,
                                  title: v!,
                                  fieldType: _fields[index].fieldType,
                                  isRequired: _fields[index].isRequired,
                                  options: _fields[index].options,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.paddingMedium),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeField(index),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _fields[index].fieldType,
                                decoration: const InputDecoration(labelText: 'Тип'),
                                items: const [
                                  DropdownMenuItem(value: 'string', child: Text('Текст')),
                                  DropdownMenuItem(value: 'number', child: Text('Число')),
                                  DropdownMenuItem(value: 'date', child: Text('Дата')),
                                  DropdownMenuItem(value: 'boolean', child: Text('Логический')),
                                  DropdownMenuItem(value: 'select', child: Text('Выпадающий список')),
                                ],
                                onChanged: (v) => setState(() {
                                  _fields[index] = AchievementField(
                                    id: _fields[index].id,
                                    title: _fields[index].title,
                                    fieldType: v!,
                                    isRequired: _fields[index].isRequired,
                                    options: _fields[index].options,
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.paddingMedium),
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Обязательно'),
                                value: _fields[index].isRequired,
                                onChanged: (v) => setState(() {
                                  _fields[index] = AchievementField(
                                    id: _fields[index].id,
                                    title: _fields[index].title,
                                    fieldType: _fields[index].fieldType,
                                    isRequired: v ?? false,
                                    options: _fields[index].options,
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                        if (_fields[index].fieldType == 'select') ...[
                          const SizedBox(height: AppDimensions.paddingSmall),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Варианты ответа:'),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Добавить'),
                                onPressed: () => _addOption(index),
                              ),
                            ],
                          ),
                          ...List.generate(_fields[index].options.length, (optIndex) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _fields[index].options[optIndex],
                                      decoration: InputDecoration(
                                        hintText: 'Вариант ${optIndex + 1}',
                                        isDense: true,
                                      ),
                                      onChanged: (v) => _fields[index].options[optIndex] = v,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                    onPressed: () => _removeOption(index, optIndex),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: AppDimensions.paddingExtraLarge),
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
}

