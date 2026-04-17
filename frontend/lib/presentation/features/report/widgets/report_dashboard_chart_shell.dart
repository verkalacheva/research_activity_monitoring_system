import 'package:flutter/material.dart';

import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';

/// Shared card shell for dashboard charts: loading, empty state, and chart content.
class ReportDashboardChartShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget chart;
  final bool isLoading;
  final bool hasData;

  const ReportDashboardChartShell({
    super.key,
    required this.title,
    required this.icon,
    required this.chart,
    required this.isLoading,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : !hasData
                    ? Center(child: Icon(icon, size: 80, color: AppColors.divider))
                    : chart,
          ),
        ],
      ),
    );
  }
}
