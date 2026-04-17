import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/app/app.dart' show appNavigatorKey;
import 'package:research_activity_monitoring_system/data/services/sync_notification_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/presentation/widgets/sync_preview_dialog.dart';

/// Global floating bell shown in the bottom-right corner when background
/// sync has completed results waiting for review.
class SyncNotificationBell extends StatefulWidget {
  const SyncNotificationBell({super.key});

  @override
  State<SyncNotificationBell> createState() => _SyncNotificationBellState();
}

class _SyncNotificationBellState extends State<SyncNotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _openResults() {
    // Use the global navigator key because this widget lives in MaterialApp.builder,
    // above the Navigator in the widget tree — the local BuildContext has no Navigator.
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null) return;

    final service = SyncNotificationService.instance;
    final results = service.mergedResults;
    if (results.isEmpty) return;

    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (_) => SyncPreviewDialog(
        provider: 'background',
        preloadedResults: results,
        onResultsSaved: () {
          service.callAllOnSaved();
          service.dismissCompleted();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncNotificationService.instance,
      builder: (context, _) {
        final service = SyncNotificationService.instance;
        final isSyncing = service.isSyncing;
        final hasPending = service.hasPendingResults;
        final pendingCount = service.pendingRequests.length;

        if (!isSyncing && !hasPending) return const SizedBox.shrink();

        // Use Align so the widget fills the Stack without blocking hit-testing on empty areas.
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            // bottom: 88 keeps the bell above standard FABs (56px tall + 16px scaffold margin + buffer)
            padding: const EdgeInsets.only(bottom: 88, right: 16),
            child: _BellButton(
              isSyncing: isSyncing,
              hasPending: hasPending,
              pendingCount: pendingCount,
              pulseAnimation: _pulse,
              onTap: hasPending ? _openResults : null,
              onCancelSync: isSyncing ? () => service.cancelSync() : null,
            ),
          ),
        );
      },
    );
  }
}

class _BellButton extends StatelessWidget {
  final bool isSyncing;
  final bool hasPending;
  final int pendingCount;
  final Animation<double> pulseAnimation;
  final VoidCallback? onTap;
  final VoidCallback? onCancelSync;

  const _BellButton({
    required this.isSyncing,
    required this.hasPending,
    required this.pendingCount,
    required this.pulseAnimation,
    required this.onTap,
    required this.onCancelSync,
  });

  @override
  Widget build(BuildContext context) {
    final count = SyncNotificationService.instance.completedRequests
        .where((r) => !r.hasError && (r.results?.isNotEmpty ?? false))
        .length;

    Widget button = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(32),
      color: hasPending ? AppColors.primary : AppColors.primary.withOpacity(0.7),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncing && onCancelSync != null) ...[
                // No Tooltip / Semantics label: this subtree is under MaterialApp.builder
                // (above Navigator), so RawTooltip cannot find an Overlay on web.
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCancelSync,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.stop_circle_outlined, color: Colors.white, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (isSyncing && !hasPending)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              else
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications, color: Colors.white, size: 22),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 10),
              Text(
                isSyncing && !hasPending
                    ? (pendingCount > 1
                        ? 'Синхронизация… ($pendingCount)'
                        : 'Синхронизация…')
                    : 'Результаты синхронизации',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (hasPending) {
      button = AnimatedBuilder(
        animation: pulseAnimation,
        builder: (_, child) => Transform.scale(
          scale: 1.0 + pulseAnimation.value * 0.04,
          child: child,
        ),
        child: button,
      );
    }

    return button;
  }
}
