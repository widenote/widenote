import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../capture/application/capture_replay_service.dart';
import '../application/debugging_controller.dart';

class DebuggingPage extends ConsumerWidget {
  const DebuggingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(debuggingControllerProvider);
    return state.when(
      data: (debugging) => _DebuggingBody(debugging: debugging),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DebuggingError(message: '$error'),
    );
  }
}

class _DebuggingBody extends ConsumerWidget {
  const _DebuggingBody({required this.debugging});

  final DebuggingState debugging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canRetry =
        !debugging.isRunning && debugging.snapshot.retryableAgentTasks > 0;
    final canReplay =
        !debugging.isRunning &&
        debugging.range.isValid &&
        debugging.snapshot.matchingCaptures > 0;
    return ListView(
      key: const Key('debugging-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        _PageHeader(
          title: l10n.debuggingTitle,
          subtitle: l10n.debuggingSubtitle,
        ),
        const SizedBox(height: 16),
        if (debugging.isRunning) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
        ],
        _Surface(
          icon: Icons.replay_outlined,
          title: l10n.debuggingAgentRetryTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.debuggingAgentRetryBody),
              const SizedBox(height: 12),
              _MetricLine(
                icon: Icons.account_tree_outlined,
                label: l10n.debuggingAgentRetryStatus(
                  debugging.snapshot.retryableAgentTasks,
                  debugging.snapshot.agentBatchLimit,
                ),
              ),
              if (debugging.snapshot.retryableAgentTasks == 0) ...[
                const SizedBox(height: 8),
                Text(l10n.debuggingNoRetryableAgents),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('debugging-retry-agents-button'),
                onPressed: canRetry
                    ? () => _confirmRetryAgents(context, ref, debugging)
                    : null,
                icon: const Icon(Icons.replay),
                label: Text(
                  debugging.isRunning
                      ? l10n.debuggingRunningLabel
                      : l10n.debuggingRetryFailedAgentsButton,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.calendar_month_outlined,
          title: l10n.debuggingDateReplayTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.debuggingDateReplayBody),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('debugging-start-date-button'),
                    onPressed: debugging.isRunning
                        ? null
                        : () => _pickStartDate(context, ref, debugging),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      l10n.debuggingStartDateValue(
                        _formatDate(context, debugging.range.startDate),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('debugging-end-date-button'),
                    onPressed: debugging.isRunning
                        ? null
                        : () => _pickEndDate(context, ref, debugging),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      l10n.debuggingEndDateValue(
                        _formatDate(context, debugging.range.endDate),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MetricLine(
                icon: Icons.history_outlined,
                label: l10n.debuggingDateReplayStatus(
                  debugging.snapshot.matchingCaptures,
                  debugging.snapshot.captureBatchLimit,
                ),
              ),
              if (!debugging.range.isValid) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.debuggingDateRangeInvalid,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ] else if (debugging.snapshot.matchingCaptures == 0) ...[
                const SizedBox(height: 8),
                Text(l10n.debuggingNoMatchingCaptures),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('debugging-process-date-range-button'),
                onPressed: canReplay
                    ? () => _confirmReplayDateRange(context, ref, debugging)
                    : null,
                icon: const Icon(Icons.playlist_play),
                label: Text(
                  debugging.isRunning
                      ? l10n.debuggingRunningLabel
                      : l10n.debuggingReplayDateRangeButton,
                ),
              ),
            ],
          ),
        ),
        if (debugging.lastOperation != null ||
            debugging.errorMessage != null) ...[
          const SizedBox(height: 16),
          _ResultSurface(debugging: debugging),
        ],
      ],
    );
  }

  Future<void> _pickStartDate(
    BuildContext context,
    WidgetRef ref,
    DebuggingState debugging,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: debugging.range.startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      await ref.read(debuggingControllerProvider.notifier).setStartDate(picked);
    }
  }

  Future<void> _pickEndDate(
    BuildContext context,
    WidgetRef ref,
    DebuggingState debugging,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: debugging.range.endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      await ref.read(debuggingControllerProvider.notifier).setEndDate(picked);
    }
  }

  Future<void> _confirmRetryAgents(
    BuildContext context,
    WidgetRef ref,
    DebuggingState debugging,
  ) async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: l10n.debuggingRetryConfirmTitle,
      body: l10n.debuggingRetryConfirmBody(
        debugging.snapshot.retryableAgentTasks,
        debugging.snapshot.agentBatchLimit,
      ),
      action: l10n.debuggingRetryConfirmAction,
    );
    if (confirmed) {
      await ref.read(debuggingControllerProvider.notifier).retryFailedAgents();
    }
  }

  Future<void> _confirmReplayDateRange(
    BuildContext context,
    WidgetRef ref,
    DebuggingState debugging,
  ) async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: l10n.debuggingReplayConfirmTitle,
      body: l10n.debuggingReplayConfirmBody(
        debugging.snapshot.matchingCaptures,
        debugging.snapshot.captureBatchLimit,
      ),
      action: l10n.debuggingReplayConfirmAction,
    );
    if (confirmed) {
      await ref.read(debuggingControllerProvider.notifier).replayDateRange();
    }
  }
}

class _ResultSurface extends StatelessWidget {
  const _ResultSurface({required this.debugging});

  final DebuggingState debugging;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = debugging.errorMessage;
    final operation = debugging.lastOperation;
    return _Surface(
      icon: error == null ? Icons.done_all_outlined : Icons.error_outline,
      title: l10n.debuggingResultTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null)
            Text(l10n.debuggingOperationFailed(error))
          else if (operation?.agentRetryResult != null)
            _AgentRetrySummary(result: operation!.agentRetryResult!)
          else if (operation?.dateReplayResult != null)
            _DateReplaySummary(result: operation!.dateReplayResult!),
        ],
      ),
    );
  }
}

class _AgentRetrySummary extends StatelessWidget {
  const _AgentRetrySummary({required this.result});

  final AgentRetryBatchResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.debuggingAgentRetrySummary(
            result.retriedAgentTasks,
            result.selectedAgentTasks,
            result.drainedRuntimeTasks,
            result.refreshedCaptures,
            result.failedRefreshes,
            result.skippedRefreshes,
          ),
        ),
        if (result.limited) ...[
          const SizedBox(height: 8),
          Text(l10n.debuggingAgentRetryLimited(result.selectedAgentTasks)),
        ],
      ],
    );
  }
}

class _DateReplaySummary extends StatelessWidget {
  const _DateReplaySummary({required this.result});

  final CaptureDateReplayResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.debuggingDateReplaySummary(
            result.processedCaptures,
            result.retriedCaptures,
            result.refreshedCaptures,
            result.failedCaptures,
            result.skippedCaptures,
            result.deferredCaptures,
            result.selectedCaptures,
          ),
        ),
        if (result.limited) ...[
          const SizedBox(height: 8),
          Text(l10n.debuggingDateReplayLimited(result.selectedCaptures)),
        ],
      ],
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _DebuggingError extends StatelessWidget {
  const _DebuggingError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(child: Text(l10n.debuggingOperationFailed(message)));
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.outlined(
          key: const Key('debugging-close-button'),
          tooltip: l10n.debuggingBackTooltip,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.debuggingConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

String _formatDate(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatCompactDate(value);
}
