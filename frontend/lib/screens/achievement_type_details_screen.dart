import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../utils/icon_helper.dart';
import '../utils/clipboard_helper.dart';

class AchievementTypeDetailsScreen extends StatelessWidget {
  final AchievementType type;

  const AchievementTypeDetailsScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Информация о типе достижения'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(IconHelper.getIcon(type.iconName), size: 32, color: Theme.of(context).primaryColor),
                    ),
                    const SizedBox(width: AppDimensions.paddingLarge),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(type.title, style: AppTextStyles.h1)),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                                onPressed: () => ClipboardHelper.copyToClipboard(context, type.title),
                                tooltip: 'Копировать название',
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.paddingMedium),
                          Text('Баллы по умолчанию: ${type.points?.toStringAsFixed(1) ?? 0}', style: AppTextStyles.bodySecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingLarge),
            const Text('Дополнительные поля:', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.paddingSmall),
            if (type.fields.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingMedium),
                child: Text('Дополнительных полей нет', style: AppTextStyles.bodySecondary),
              )
            else
              ...type.fields.map((field) => Card(
                margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
                child: ListTile(
                  title: Text(field.title),
                  subtitle: Text(
                    'Тип: ${_fieldTypeName(field.fieldType)} | Обязательно: ${field.isRequired ? "Да" : "Нет"}${field.options.isNotEmpty ? "\nВарианты: ${field.options.join(", ")}" : ""}'
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                    onPressed: () => ClipboardHelper.copyToClipboard(context, field.title),
                    tooltip: 'Копировать название поля',
                  ),
                ),
              )).toList(),
          ],
        ),
      ),
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

