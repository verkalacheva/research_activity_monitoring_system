import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/achievement_type_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../utils/icon_helper.dart';
import '../utils/clipboard_helper.dart';

class AchievementTypeDetailsScreen extends StatefulWidget {
  final AchievementType type;
  final bool isEmbedded;
  final Function(AchievementType)? onTypeUpdated;

  const AchievementTypeDetailsScreen({
    super.key,
    required this.type,
    this.isEmbedded = false,
    this.onTypeUpdated,
  });

  @override
  State<AchievementTypeDetailsScreen> createState() => _AchievementTypeDetailsScreenState();
}

class _AchievementTypeDetailsScreenState extends State<AchievementTypeDetailsScreen> {
  final _service = AchievementTypeService();
  final _formKey = GlobalKey<FormState>();

  late AchievementType _type;
  bool _isLoading = false;
  bool _isEditing = false;

  late TextEditingController _titleController;
  late TextEditingController _pointsController;
  String? _selectedIconName;
  List<AchievementField> _fields = [];

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _titleController = TextEditingController();
    _pointsController = TextEditingController();
    _initControllers();
  }

  void _initControllers() {
    _titleController.text = _type.title;
    _pointsController.text = _type.points?.toString() ?? '';
    _selectedIconName = _type.iconName;
    _fields = _type.fields.map((f) => AchievementField(
      id: f.id,
      title: f.title,
      fieldType: f.fieldType,
      isRequired: f.isRequired,
      options: List.from(f.options),
    )).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AchievementTypeDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      setState(() {
        _type = widget.type;
        _isEditing = false;
        _initControllers();
      });
    }
  }

  Future<void> _saveType() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);
      try {
        final typeToUpdate = AchievementType(
          id: _type.id,
          title: _titleController.text,
          points: double.tryParse(_pointsController.text) != null 
              ? (double.parse(_pointsController.text) * 10).roundToDouble() / 10 
              : null,
          iconName: _selectedIconName,
          fields: _fields,
        );

        final updated = await _service.update(_type.id!, typeToUpdate);
        setState(() {
          _type = updated;
          _isEditing = false;
          _isLoading = false;
          _initControllers();
        });
        widget.onTypeUpdated?.call(_type);
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

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                child: Row(
                  children: [
                    _buildIconSelector(),
                    const SizedBox(width: AppDimensions.paddingLarge),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: _isEditing
                                    ? TextFormField(
                                        controller: _titleController,
                                        style: AppTextStyles.h1,
                                        decoration: const InputDecoration(labelText: 'Название *'),
                                        validator: (v) => v?.isEmpty ?? true ? 'Обязательно' : null,
                                      )
                                    : Text(_type.title, style: AppTextStyles.h1),
                              ),
                              if (widget.isEmbedded) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(_isEditing ? Icons.close : Icons.edit, color: AppColors.primary),
                                  onPressed: () {
                                    setState(() {
                                      if (_isEditing) _initControllers();
                                      _isEditing = !_isEditing;
                                    });
                                  },
                                  tooltip: _isEditing ? 'Отмена' : 'Редактировать',
                                ),
                              ],
                              if (widget.isEmbedded) const SizedBox(width: 40),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.paddingMedium),
                          _isEditing
                              ? TextFormField(
                                  controller: _pointsController,
                                  decoration: const InputDecoration(labelText: 'Баллы по умолчанию'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                )
                              : Text('Баллы по умолчанию: ${_type.points?.toStringAsFixed(1) ?? 0}', style: AppTextStyles.bodySecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Дополнительные поля:', style: AppTextStyles.h2),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addField,
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            _buildFieldsList(),
            if (_isEditing) ...[
              const SizedBox(height: AppDimensions.paddingExtraLarge),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveType,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить изменения'),
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
        title: const Text('Информация о типе достижения'),
      ),
      body: content,
    );
  }

  Widget _buildIconSelector() {
    if (!_isEditing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(IconHelper.getIcon(_type.iconName), size: 32, color: AppColors.primary),
      );
    }

    return Column(
      children: [
        const Text('Иконка', style: AppTextStyles.caption),
        const SizedBox(height: 4),
        DropdownButton<String>(
          value: _selectedIconName,
          items: IconHelper.icons.entries.map((e) {
            return DropdownMenuItem(
              value: e.key,
              child: Icon(e.value, color: AppColors.primary),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedIconName = v),
        ),
      ],
    );
  }

  Widget _buildFieldsList() {
    final activeFields = _fields.where((f) => f.destroy != true).toList();
    if (!_isEditing) {
      if (activeFields.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
          child: Text('Дополнительных полей нет', style: AppTextStyles.bodySecondary),
        );
      }
      return Column(
        children: activeFields.map((field) => Card(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
          child: ListTile(
            title: Text(field.title),
            subtitle: Text(
              'Тип: ${_fieldTypeName(field.fieldType)} | Обязательно: ${field.isRequired ? "Да" : "Нет"}${field.options.isNotEmpty ? "\nВарианты: ${field.options.join(", ")}" : ""}'
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 20, color: AppColors.textTertiary),
              onPressed: () => ClipboardHelper.copyToClipboard(context, field.title),
              tooltip: 'Копировать название поля',
            ),
          ),
        )).toList(),
      );
    }

    return Column(
      children: List.generate(_fields.length, (index) {
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
                      child: TextFormField(
                        initialValue: _fields[index].title,
                        decoration: const InputDecoration(labelText: 'Название поля'),
                        validator: (v) => v == null || v.isEmpty ? 'Обязательно' : null,
                        onSaved: (v) => _fields[index] = _fields[index].copyWith(title: v!),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
                        onChanged: (v) => setState(() => _fields[index] = _fields[index].copyWith(fieldType: v!)),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Обязательно'),
                        value: _fields[index].isRequired,
                        onChanged: (v) => setState(() => _fields[index] = _fields[index].copyWith(isRequired: v ?? false)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _fieldTypeName(String type) {
    switch (type) {
      case 'string': return 'Текст';
      case 'number': return 'Число';
      case 'date': return 'Дата';
      case 'boolean': return 'Логический';
      case 'select': return 'Выпадающий список';
      default: return type;
    }
  }
}
