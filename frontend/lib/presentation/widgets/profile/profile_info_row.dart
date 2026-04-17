import 'package:flutter/material.dart';

import 'package:research_activity_monitoring_system/core/l10n/l10n.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/core/utils/clipboard_helper.dart';
import 'package:research_activity_monitoring_system/core/utils/url_helper.dart';

/// Standard row for profile / detail screens: icon, label, view or edit field, copy.
class ProfileInfoRow extends StatelessWidget {
  final bool isEditing;
  final IconData icon;
  final String label;
  final String value;
  final TextEditingController? controller;
  final Widget? field;
  final Widget? trailing;

  const ProfileInfoRow({
    super.key,
    required this.isEditing,
    required this.icon,
    required this.label,
    required this.value,
    this.controller,
    this.field,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIsu = label == context.strings.tr('widgets.profile.label_isu');
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                if (isEditing && (controller != null || field != null))
                  (field ??
                      TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                      ))
                else
                  UrlHelper.buildClickableText(
                    context,
                    value,
                    enabled: !isIsu,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
              onPressed: () => ClipboardHelper.copyToClipboard(context, value),
              tooltip: context.strings.tr('common.copy'),
            ),
        ],
      ),
    );
  }
}
