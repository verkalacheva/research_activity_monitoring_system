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
    final mayOpenEmpty = service.hasCompletedEmptySuccess;
    if (results.isEmpty && !mayOpenEmpty) return;

    showDialog<bool?>(
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
    ).then((saved) {
      // Закрытие крестиком, «Отмена» или системной кнопкой «Назад» без сохранения:
      // очистить Redis и убрать колокольчик (успешное сохранение даёт saved == true).
      if (saved != true) {
        service.dismissCompleted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncNotificationService.instance.mergedListenables,
      builder: (context, _) {
        final service = SyncNotificationService.instance;
        final isSyncing = service.isSyncing;
        final hasPending = service.hasPendingResults;
        final hasEmptyDone = service.hasCompletedEmptySuccess;
        final pendingCount = service.pendingRequests.length;
        final canOpenResults = hasPending || (!isSyncing && hasEmptyDone);

        if (!isSyncing && !hasPending && !hasEmptyDone) return const SizedBox.shrink();

        // Use Align so the widget fills the Stack without blocking hit-testing on empty areas.
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            // bottom: 88 keeps the bell above standard FABs (56px tall + 16px scaffold margin + buffer)
            padding: const EdgeInsets.only(bottom: 88, right: 16),
            child: _BellButton(
              isSyncing: isSyncing,
              hasPending: hasPending,
              hasEmptyDone: hasEmptyDone,
              pendingCount: pendingCount,
              pulseAnimation: _pulse,
              onTap: canOpenResults ? _openResults : null,
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
  final bool hasEmptyDone;
  final int pendingCount;
  final Animation<double> pulseAnimation;
  final VoidCallback? onTap;
  final VoidCallback? onCancelSync;

  const _BellButton({
    required this.isSyncing,
    required this.hasPending,
    required this.hasEmptyDone,
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
      color: (hasPending || (!isSyncing && hasEmptyDone))
          ? AppColors.primary
          : AppColors.primary.withOpacity(0.7),
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
              if (isSyncing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                    if (hasPending) ...[
                      const SizedBox(width: 8),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                          if (count > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    count > 9 ? '9+' : '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
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
                isSyncing
                    ? (pendingCount > 1 ? 'Синхронизация… ($pendingCount)' : 'Синхронизация…')
                    : (hasPending
                        ? 'Результаты синхронизации'
                        : 'Синхронизация завершена'),
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

    if (hasPending || (!isSyncing && hasEmptyDone)) {
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
