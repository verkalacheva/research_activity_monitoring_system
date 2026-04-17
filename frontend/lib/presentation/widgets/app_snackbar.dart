import 'package:flutter/material.dart';

import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';

void showAppSnackBar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
      duration: duration ?? const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
    ),
  );
}
