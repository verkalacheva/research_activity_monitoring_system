import 'package:flutter/material.dart';

import 'package:research_activity_monitoring_system/core/l10n/l10n.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/utils/clipboard_helper.dart';
import 'package:research_activity_monitoring_system/core/utils/url_helper.dart';

/// Label/value row inside an expanded achievement card.
class AchievementDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const AchievementDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: UrlHelper.buildClickableText(context, value)),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppColors.inactive),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ClipboardHelper.copyToClipboard(context, value),
            tooltip: context.strings.tr('common.copy'),
          ),
        ],
      ),
    );
  }
}
