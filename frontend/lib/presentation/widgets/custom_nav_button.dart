import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';

class CustomNavButton extends StatelessWidget {
  final int index;
  final int currentIndex;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const CustomNavButton({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = index == currentIndex;
    final Color color = isSelected ? AppColors.primary : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(
                  color: color,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

