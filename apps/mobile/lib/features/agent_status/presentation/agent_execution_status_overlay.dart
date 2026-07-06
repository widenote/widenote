import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/mobile_navigation.dart';
import '../../../l10n/l10n.dart';
import '../application/agent_execution_status_controller.dart';
import '../application/agent_status_platform.dart';

class AgentExecutionStatusLayer extends ConsumerStatefulWidget {
  const AgentExecutionStatusLayer({
    required this.child,
    required this.showBottomNavigationBar,
    super.key,
  });

  final Widget child;
  final bool showBottomNavigationBar;

  @override
  ConsumerState<AgentExecutionStatusLayer> createState() =>
      _AgentExecutionStatusLayerState();
}

class _AgentExecutionStatusLayerState
    extends ConsumerState<AgentExecutionStatusLayer> {
  double? _overlayHeight;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(agentExecutionStatusControllerProvider);
    final showOverlay = snapshot.hasVisibleStatus;
    final bottomGap = widget.showBottomNavigationBar ? 12.0 : 16.0;
    final bottomPadding = showOverlay
        ? (_overlayHeight ?? _estimatedOverlayHeight(context)) +
              bottomGap +
              MediaQuery.paddingOf(context).bottom
        : 0.0;
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: widget.child,
            ),
          ),
          const AgentExecutionStatusPlatformSync(),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomGap,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.16),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                child: showOverlay
                    ? _MeasuredSize(
                        onChange: _handleOverlaySizeChanged,
                        child: _AgentExecutionStatusPill(snapshot: snapshot),
                      )
                    : const SizedBox.shrink(
                        key: Key('agent-status-overlay-hidden'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOverlaySizeChanged(Size size) {
    if (!mounted || size.height <= 0) {
      return;
    }
    final previous = _overlayHeight;
    if (previous != null && (previous - size.height).abs() < 0.5) {
      return;
    }
    setState(() {
      _overlayHeight = size.height;
    });
  }

  double _estimatedOverlayHeight(BuildContext context) {
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1);
    return 64 * textScaleFactor;
  }
}

class _MeasuredSize extends SingleChildRenderObjectWidget {
  const _MeasuredSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasuredSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _MeasuredSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasuredSizeRenderObject extends RenderProxyBox {
  _MeasuredSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size ?? Size.zero;
    if (_lastSize == newSize) {
      return;
    }
    _lastSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) {
        onChange(newSize);
      }
    });
  }
}

class AgentExecutionStatusPlatformSync extends ConsumerStatefulWidget {
  const AgentExecutionStatusPlatformSync({super.key});

  @override
  ConsumerState<AgentExecutionStatusPlatformSync> createState() =>
      _AgentExecutionStatusPlatformSyncState();
}

class _AgentExecutionStatusPlatformSyncState
    extends ConsumerState<AgentExecutionStatusPlatformSync> {
  String? _scheduledKey;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(agentExecutionStatusControllerProvider);
    final labels = _platformLabels(context.l10n, snapshot);
    final key = '${snapshot.syncIdentity}|${labels.title}|${labels.body}';
    if (_scheduledKey != key) {
      _scheduledKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(agentStatusPlatformSyncControllerProvider.notifier)
            .sync(snapshot, labels);
      });
    }
    return const SizedBox.shrink(key: Key('agent-status-platform-sync'));
  }
}

class _AgentExecutionStatusPill extends StatelessWidget {
  const _AgentExecutionStatusPill({required this.snapshot});

  final AgentExecutionStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(colorScheme, snapshot.overallStatus);
    return Material(
      key: const Key('agent-status-overlay'),
      elevation: 8,
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: const Key('agent-status-open-sheet'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showStatusSheet(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.32)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(_statusIcon(snapshot.overallStatus), color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    key: const Key('agent-status-overlay-summary'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _overlayTitle(l10n, snapshot),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _overlaySubtitle(l10n, snapshot),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_up),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const AgentExecutionStatusSheet(),
    );
  }
}

class AgentExecutionStatusSheet extends ConsumerWidget {
  const AgentExecutionStatusSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(agentExecutionStatusControllerProvider);
    return SafeArea(
      child: ListView(
        key: const Key('agent-status-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Icon(_statusIcon(snapshot.overallStatus)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.agentStatusSheetTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const Key('agent-status-refresh-button'),
                tooltip: l10n.agentStatusRefreshTooltip,
                onPressed: () => ref
                    .read(agentExecutionStatusControllerProvider.notifier)
                    .refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: l10n.agentStatusRunning(snapshot.runningCount),
              ),
              _StatusChip(label: l10n.agentStatusQueued(snapshot.queuedCount)),
              _StatusChip(
                label: l10n.agentStatusRetrying(snapshot.retryingCount),
              ),
              _StatusChip(
                label: l10n.agentStatusRecovering(snapshot.recoveringCount),
              ),
              _StatusChip(
                label: l10n.agentStatusAttention(snapshot.attentionCount),
              ),
              _StatusChip(
                label: l10n.agentStatusSucceeded(snapshot.succeededCount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (snapshot.items.isEmpty)
            Text(
              l10n.agentStatusIdleBody,
              key: const Key('agent-status-idle-body'),
            )
          else
            for (final item in snapshot.items) _StatusItemTile(item: item),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('agent-status-open-log-center'),
              onPressed: () {
                Navigator.of(context).pop();
                openMobileRouteWithParentStack(
                  context,
                  '/settings/traces/agents',
                );
              },
              icon: const Icon(Icons.account_tree_outlined),
              label: Text(l10n.agentStatusOpenLogCenter),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusItemTile extends StatelessWidget {
  const _StatusItemTile({required this.item});

  final AgentExecutionStatusItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final color = _kindColor(colorScheme, item.kind);
    return Padding(
      key: Key('agent-status-item-${item.taskId}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_kindIcon(item.kind), color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.agentId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(label: _kindLabel(l10n, item.kind)),
                    _StatusChip(label: l10n.agentStatusPack(item.packId)),
                    _StatusChip(label: l10n.agentStatusAttempt(item.attempts)),
                    if (item.missingDependencyCount > 0)
                      _StatusChip(
                        label: l10n.agentStatusMissingDependencies(
                          item.missingDependencyCount,
                        ),
                      ),
                    if (item.scheduledAt != null)
                      _StatusChip(
                        label: l10n.agentStatusNextRetry(
                          _formatTime(item.scheduledAt!),
                        ),
                      ),
                    if (item.outputCount > 0)
                      _StatusChip(
                        label: l10n.agentStatusOutputs(item.outputCount),
                      ),
                  ],
                ),
                if (item.hasError) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.agentStatusErrorRedacted,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

AgentStatusPlatformLabels _platformLabels(
  AppLocalizations l10n,
  AgentExecutionStatusSnapshot snapshot,
) {
  return AgentStatusPlatformLabels(
    title: _overlayTitle(l10n, snapshot),
    body: _overlaySubtitle(l10n, snapshot),
  );
}

String _overlayTitle(
  AppLocalizations l10n,
  AgentExecutionStatusSnapshot snapshot,
) {
  return switch (snapshot.overallStatus) {
    AgentExecutionOverallStatus.attention => l10n.agentStatusAttentionTitle,
    AgentExecutionOverallStatus.active => l10n.agentStatusActiveTitle,
    AgentExecutionOverallStatus.completed => l10n.agentStatusCompletedTitle,
    AgentExecutionOverallStatus.idle => l10n.agentStatusIdleTitle,
  };
}

String _overlaySubtitle(
  AppLocalizations l10n,
  AgentExecutionStatusSnapshot snapshot,
) {
  return l10n.agentStatusOverlaySummary(
    snapshot.runningCount,
    snapshot.queuedCount,
    snapshot.retryingCount + snapshot.recoveringCount,
    snapshot.attentionCount,
  );
}

String _kindLabel(AppLocalizations l10n, AgentExecutionStatusKind kind) {
  return switch (kind) {
    AgentExecutionStatusKind.running => l10n.agentStatusKindRunning,
    AgentExecutionStatusKind.queued => l10n.agentStatusKindQueued,
    AgentExecutionStatusKind.retrying => l10n.agentStatusKindRetrying,
    AgentExecutionStatusKind.recovering => l10n.agentStatusKindRecovering,
    AgentExecutionStatusKind.succeeded => l10n.agentStatusKindSucceeded,
    AgentExecutionStatusKind.failed => l10n.agentStatusKindFailed,
    AgentExecutionStatusKind.denied => l10n.agentStatusKindDenied,
    AgentExecutionStatusKind.canceled => l10n.agentStatusKindCanceled,
    AgentExecutionStatusKind.blocked => l10n.agentStatusKindBlocked,
  };
}

IconData _statusIcon(AgentExecutionOverallStatus status) {
  return switch (status) {
    AgentExecutionOverallStatus.attention => Icons.error_outline,
    AgentExecutionOverallStatus.active => Icons.bolt_outlined,
    AgentExecutionOverallStatus.completed => Icons.check_circle_outline,
    AgentExecutionOverallStatus.idle => Icons.bolt_outlined,
  };
}

IconData _kindIcon(AgentExecutionStatusKind kind) {
  return switch (kind) {
    AgentExecutionStatusKind.running => Icons.play_circle_outline,
    AgentExecutionStatusKind.queued => Icons.hourglass_top_outlined,
    AgentExecutionStatusKind.retrying => Icons.replay_outlined,
    AgentExecutionStatusKind.recovering => Icons.history_toggle_off_outlined,
    AgentExecutionStatusKind.succeeded => Icons.check_circle_outline,
    AgentExecutionStatusKind.failed => Icons.error_outline,
    AgentExecutionStatusKind.denied => Icons.block_outlined,
    AgentExecutionStatusKind.canceled => Icons.cancel_outlined,
    AgentExecutionStatusKind.blocked => Icons.lock_outline,
  };
}

Color _statusColor(
  ColorScheme colorScheme,
  AgentExecutionOverallStatus status,
) {
  return switch (status) {
    AgentExecutionOverallStatus.attention => colorScheme.error,
    AgentExecutionOverallStatus.active => colorScheme.primary,
    AgentExecutionOverallStatus.completed => colorScheme.tertiary,
    AgentExecutionOverallStatus.idle => colorScheme.outline,
  };
}

Color _kindColor(ColorScheme colorScheme, AgentExecutionStatusKind kind) {
  if (kind.isAttentionLike) {
    return colorScheme.error;
  }
  return switch (kind) {
    AgentExecutionStatusKind.succeeded => colorScheme.tertiary,
    AgentExecutionStatusKind.retrying ||
    AgentExecutionStatusKind.recovering => colorScheme.secondary,
    AgentExecutionStatusKind.running ||
    AgentExecutionStatusKind.queued => colorScheme.primary,
    AgentExecutionStatusKind.failed ||
    AgentExecutionStatusKind.denied ||
    AgentExecutionStatusKind.canceled ||
    AgentExecutionStatusKind.blocked => colorScheme.error,
  };
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
