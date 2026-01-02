import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';

class ResearcherProfileScreen extends StatelessWidget {
  final Researcher researcher;

  const ResearcherProfileScreen({super.key, required this.researcher});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль сотрудника'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: AppDimensions.avatarSizeLarge,
                          backgroundColor: AppColors.background,
                          child: Icon(Icons.person, size: 80, color: AppColors.inactive),
                        ),
                        const SizedBox(width: AppDimensions.paddingLarge),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                researcher.fullName,
                                style: AppTextStyles.h1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${researcher.degreeLevel ?? ''} ${researcher.course != null ? '(${researcher.course} курс)' : ''}'.trim(),
                                style: AppTextStyles.bodySecondary,
                              ),
                              const SizedBox(height: 16),
                              if (researcher.subjectArea != null)
                                Chip(
                                  label: Text(researcher.subjectArea!),
                                  backgroundColor: AppColors.background,
                                  side: BorderSide.none,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingLarge),
                const Text(
                  'Информация',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: AppDimensions.paddingMedium),
                Card(
                  child: Column(
                    children: [
                      _infoRow(Icons.school, 'Степень/Статус', researcher.degreeLevel ?? 'Не указано'),
                      const Divider(height: 1, indent: 56),
                      _infoRow(Icons.book, 'Область интересов', researcher.subjectArea ?? 'Не указано'),
                      if (researcher.course != null) ...[
                        const Divider(height: 1, indent: 56),
                        _infoRow(Icons.timeline, 'Курс обучения', '${researcher.course} курс'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingExtraLarge),
                const Text(
                  'Достижения и активность',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: AppDimensions.paddingMedium),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingLarge),
                    child: Center(
                      child: Text(
                        'Список достижений пуст',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingMedium,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

