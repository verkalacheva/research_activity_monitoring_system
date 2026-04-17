import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/dev_employee_activity_type_service.dart';
import 'package:research_activity_monitoring_system/data/services/integration_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';

class DevActivityTypeFormScreen extends StatefulWidget {
  final DevEmployeeActivityType? type;
  final bool isEmbedded;
  final Function(DevEmployeeActivityType)? onTypeUpdated;

  const DevActivityTypeFormScreen({
    super.key,
    this.type,
    this.isEmbedded = false,
    this.onTypeUpdated,
  });

  @override
  State<DevActivityTypeFormScreen> createState() => _DevActivityTypeFormScreenState();
}

class _DevActivityTypeFormScreenState extends State<DevActivityTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DevEmployeeActivityTypeService _service = DevEmployeeActivityTypeService();
  final IntegrationService _integrationService = IntegrationService();

  late TextEditingController _titleController;
  late TextEditingController _pointsController;
  bool _isLoading = false;
  bool _isEditing = false;
  late DevEmployeeActivityType? _currentType;

  GitHubCheckKeysRegistry? _keysRegistry;
  String? _selectedCheckKey;
  bool _isLoadingKeys = false;

  @override
  void initState() {
    super.initState();
    _currentType = widget.type;
    _isEditing = widget.type == null || !widget.isEmbedded;
    _titleController = TextEditingController();
    _pointsController = TextEditingController();
    _initControllers();
    if (_isEditing) _loadKeys();
  }

  void _initControllers() {
    _titleController.text = _currentType?.title ?? '';
    _pointsController.text = _currentType?.points?.toString() ?? '';
    _selectedCheckKey = _currentType?.checkKey;
  }

  Future<void> _loadKeys() async {
    if (_keysRegistry != null) return;
    setState(() => _isLoadingKeys = true);
    try {
      final registry = await _integrationService.getGithubCheckKeys();
      setState(() {
        _keysRegistry = registry;
        _isLoadingKeys = false;
      });
    } catch (_) {
      setState(() => _isLoadingKeys = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DevActivityTypeFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      setState(() {
        _currentType = widget.type;
        _isEditing = _currentType == null || !widget.isEmbedded;
        _initControllers();
      });
      if (_isEditing) _loadKeys();
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final type = DevEmployeeActivityType(
        id: _currentType?.id,
        title: _titleController.text,
        points: double.tryParse(_pointsController.text) != null
            ? (double.parse(_pointsController.text) * 10).roundToDouble() / 10
            : null,
        checkKey: _selectedCheckKey,
      );

      try {
        DevEmployeeActivityType result;
        if (_currentType == null) {
          result = await _service.create(type);
        } else {
          result = await _service.update(_currentType!.id!, type);
        }

        if (widget.isEmbedded) {
          setState(() {
            _currentType = result;
            _isEditing = false;
            _isLoading = false;
            _initControllers();
          });
          widget.onTypeUpdated?.call(result);
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
                    child: Text(
                      _isEditing
                          ? (_currentType == null ? 'Новый тип активности' : 'Редактирование')
                          : 'Информация о типе',
                      style: AppTextStyles.h2,
                    ),
                  ),
                  if (_currentType != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_isEditing ? Icons.close : Icons.edit,
                          color: AppColors.primary),
                      onPressed: () {
                        setState(() {
                          if (_isEditing) _initControllers();
                          _isEditing = !_isEditing;
                        });
                        if (_isEditing) _loadKeys();
                      },
                    ),
                  ],
                  const SizedBox(width: 40),
                ],
              ),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (!_isEditing && _currentType != null) ...[
              _buildInfoRow('Название', _currentType!.title),
              const Divider(),
              _buildInfoRow('Баллы', _currentType!.points?.toStringAsFixed(1) ?? '0'),
              if (_currentType!.checkKey != null) ...[
                const Divider(),
                _buildInfoRow(
                  'GitHub-ключ',
                  _keysRegistry?.labelFor(_currentType!.checkKey!) ??
                      _currentType!.checkKey!,
                  subtitle: _currentType!.checkKey,
                ),
              ],
            ] else ...[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Название *', border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                controller: _pointsController,
                decoration: const InputDecoration(
                    labelText: 'Баллы', border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              _buildCheckKeySelector(),
              const SizedBox(height: AppDimensions.paddingExtraLarge),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return Scaffold(backgroundColor: Colors.transparent, body: content);
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(
              _currentType == null ? 'Новый тип активности' : 'Редактирование')),
      body: content,
    );
  }

  Widget _buildCheckKeySelector() {
    if (_isLoadingKeys) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Загрузка ключей GitHub...'),
        ]),
      );
    }

    final keys = _keysRegistry?.activityKeys ?? [];
    final categoryLabels = _keysRegistry?.categoryLabels ?? {};

    final grouped = <String, List<GitHubCheckKey>>{};
    for (final k in keys) {
      grouped.putIfAbsent(k.category, () => []).add(k);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('GitHub-ключ метрики',
                style: AppTextStyles.bodySecondary),
            const Spacer(),
            if (_selectedCheckKey != null)
              TextButton(
                onPressed: () => setState(() => _selectedCheckKey = null),
                child: const Text('Очистить'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: _selectedCheckKey,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                iconEnabledColor: AppColors.primary,
                style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                hint: Text('Выберите ключ', style: AppTextStyles.bodySecondary),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('— Не привязан —',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  ...grouped.entries.expand((entry) {
                    final catLabel =
                        categoryLabels[entry.key] ?? entry.key;
                    return [
                      DropdownMenuItem<String>(
                        enabled: false,
                        value: '__cat__${entry.key}',
                        child: Text(
                          catLabel.toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...entry.value.map((k) => DropdownMenuItem<String>(
                            value: k.key,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(k.label, style: AppTextStyles.body),
                                  Text(k.key,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                        fontFamily: 'monospace',
                                      )),
                                ],
                              ),
                            ),
                          )),
                    ];
                  }),
                ],
                onChanged: (val) {
                  if (val != null && val.startsWith('__cat__')) return;
                  setState(() => _selectedCheckKey = val);
                },
              ),
            ),
          ),
        ),
        if (_selectedCheckKey != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.link, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(_selectedCheckKey!,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.primary)),
          ]),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.body),
          if (subtitle != null)
            Text(subtitle,
                style: AppTextStyles.caption.copyWith(color: AppColors.inactive)),
        ],
      ),
    );
  }
}
