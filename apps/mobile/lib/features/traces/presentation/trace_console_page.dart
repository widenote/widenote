import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/trace_console_controller.dart';

class TraceConsolePage extends ConsumerWidget {
  const TraceConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(traceConsoleControllerProvider);
    final controller = ref.read(traceConsoleControllerProvider.notifier);
    return ListView(
      key: const Key('trace-console-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.agentConsoleTitle,
          subtitle: l10n.agentConsoleSubtitle,
        ),
        const SizedBox(height: 16),
        _Summary(snapshot: snapshot, onRefresh: controller.refresh),
        const SizedBox(height: 16),
        _FilterBar(selected: snapshot.filter, onSelected: controller.setFilter),
        const SizedBox(height: 16),
        _ApprovalQueue(snapshot: snapshot),
        const SizedBox(height: 16),
        _RunList(snapshot: snapshot),
        const SizedBox(height: 16),
        _TaskList(snapshot: snapshot),
        const SizedBox(height: 16),
        _TraceList(snapshot: snapshot),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot, required this.onRefresh});

  final TraceConsoleSnapshot snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = snapshot.summary;
    return _Surface(
      icon: Icons.query_stats_outlined,
      title: l10n.agentConsoleSummaryTitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Tag(
            key: const Key('agent-console-total-count'),
            label: l10n.agentConsoleTotalCount(summary.total),
          ),
          _Tag(
            key: const Key('agent-console-active-count'),
            label: l10n.agentConsoleActiveCount(summary.active),
          ),
          _Tag(
            key: const Key('agent-console-failed-count'),
            label: l10n.agentConsoleFailedCount(summary.failed),
          ),
          _Tag(
            key: const Key('agent-console-denied-count'),
            label: l10n.agentConsoleDeniedCount(summary.denied),
          ),
          _Tag(
            key: const Key('agent-console-blocked-count'),
            label: l10n.agentConsoleBlockedCount(summary.blocked),
          ),
          _Tag(label: l10n.traceConsoleRunCount(snapshot.runCount)),
          _Tag(label: l10n.agentConsoleTaskCount(snapshot.taskCount)),
          _Tag(label: l10n.traceConsoleEventCount(snapshot.items.length)),
          _Tag(
            label: l10n.agentConsolePendingApprovalCount(
              snapshot.pendingApprovalCount,
            ),
          ),
          OutlinedButton.icon(
            key: const Key('trace-console-refresh-button'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.traceConsoleRefreshButton),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final AgentConsoleFilter selected;
  final ValueChanged<AgentConsoleFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.filter_list,
      title: l10n.agentConsoleFilterTitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in AgentConsoleFilter.values)
            ChoiceChip(
              key: Key('agent-console-filter-${filter.name}'),
              selected: selected == filter,
              label: Text(_filterLabel(l10n, filter)),
              onSelected: (_) => onSelected(filter),
            ),
        ],
      ),
    );
  }
}

class _ApprovalQueue extends StatelessWidget {
  const _ApprovalQueue({required this.snapshot});

  final TraceConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.rule_folder_outlined,
      title: l10n.approvalQueueTitle,
      child: snapshot.pendingApprovals.isEmpty
          ? Column(
              key: const Key('approval-queue-empty'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.approvalQueueEmpty,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.approvalQueueScaffoldBody,
                  style: _mutedStyle(context),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _RunList extends StatelessWidget {
  const _RunList({required this.snapshot});

  final TraceConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final runs = snapshot.filteredRuns;
    return _Surface(
      icon: Icons.playlist_play_outlined,
      title: l10n.agentConsoleRunsTitle,
      child: runs.isEmpty
          ? Text(
              l10n.agentConsoleRunsEmpty,
              key: const Key('agent-console-runs-empty'),
            )
          : Column(
              children: [
                for (var index = 0; index < runs.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  _RunTile(run: runs[index]),
                ],
              ],
            ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});

  final AgentConsoleRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpansionTile(
      key: Key('agent-console-run-${run.id}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      title: Text(
        run.id,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${run.packId} - ${run.agentId} - ${_runModeLabel(l10n, run.runMode)}',
      ),
      leading: Icon(
        _statusIcon(run.status),
        color: _statusColor(context, run.status),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: l10n.agentConsoleStatus(run.status)),
              _Tag(label: l10n.traceConsolePack(run.packId)),
              _Tag(label: l10n.traceConsoleAgent(run.agentId)),
              _Tag(label: l10n.agentConsoleTask(run.taskId)),
              _Tag(label: l10n.agentConsoleAttempt(run.attempt)),
              _Tag(label: _runModeLabel(l10n, run.runMode)),
              _Tag(label: l10n.agentConsoleOutputCount(run.outputCount)),
              _Tag(
                label: l10n.agentConsoleStarted(_formatDateTime(run.startedAt)),
              ),
              _Tag(
                label: l10n.agentConsoleCompleted(
                  run.completedAt == null
                      ? l10n.agentConsoleNotCompleted
                      : _formatDateTime(run.completedAt!),
                ),
              ),
            ],
          ),
        ),
        if (run.error != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.agentConsoleError(_displayText(l10n, run.error!)),
              key: Key('agent-console-run-error-${run.id}'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _RunControls(run: run),
        const SizedBox(height: 8),
        _RunTraceList(run: run),
      ],
    );
  }
}

class _RunControls extends StatelessWidget {
  const _RunControls({required this.run});

  final AgentConsoleRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('agent-console-retry-run-${run.id}'),
                onPressed: null,
                icon: const Icon(Icons.replay_outlined),
                label: Text(l10n.agentConsoleRetryAction),
              ),
              OutlinedButton.icon(
                key: Key('agent-console-cancel-run-${run.id}'),
                onPressed: null,
                icon: const Icon(Icons.cancel_outlined),
                label: Text(l10n.agentConsoleCancelAction),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.agentConsoleControlsUnavailable,
            style: _mutedStyle(context),
          ),
        ],
      ),
    );
  }
}

class _RunTraceList extends StatelessWidget {
  const _RunTraceList({required this.run});

  final AgentConsoleRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (run.traces.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(l10n.agentConsoleRunNoTraces, style: _mutedStyle(context)),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.agentConsoleRunTracesTitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final trace in run.traces)
            Padding(
              key: Key('agent-console-run-${run.id}-trace-${trace.id}'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${trace.title} - ${trace.status}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.snapshot});

  final TraceConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tasks = snapshot.filteredTasks;
    return _Surface(
      icon: Icons.task_alt_outlined,
      title: l10n.agentConsoleTasksTitle,
      child: tasks.isEmpty
          ? Text(
              l10n.agentConsoleTasksEmpty,
              key: const Key('agent-console-tasks-empty'),
            )
          : Column(
              children: [
                for (var index = 0; index < tasks.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  _TaskRow(task: tasks[index]),
                ],
              ],
            ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final AgentConsoleTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      key: Key('agent-console-task-${task.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _statusIcon(task.status),
          color: _statusColor(context, task.status),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.id,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(label: l10n.agentConsoleStatus(task.status)),
                  _Tag(label: l10n.traceConsolePack(task.packId)),
                  _Tag(label: l10n.traceConsoleAgent(task.agentId)),
                  _Tag(label: l10n.agentConsoleEvent(task.triggerEventId)),
                  _Tag(
                    label: l10n.agentConsoleTaskAttempts(
                      task.attempts,
                      task.maxAttempts,
                    ),
                  ),
                  if (task.missingDependencyIds.isNotEmpty)
                    _Tag(
                      label: l10n.agentConsoleMissingDependencies(
                        task.missingDependencyIds.length,
                      ),
                    ),
                ],
              ),
              if (task.error != null) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.agentConsoleError(_displayText(l10n, task.error!)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TraceList extends StatelessWidget {
  const _TraceList({required this.snapshot});

  final TraceConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.account_tree_outlined,
      title: l10n.traceConsoleEventsTitle,
      child: snapshot.items.isEmpty
          ? Text(l10n.traceConsoleEmpty, key: const Key('trace-console-empty'))
          : Column(
              children: [
                for (var index = 0; index < snapshot.items.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  _TraceRow(item: snapshot.items[index]),
                ],
              ],
            ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({required this.item});

  final TraceConsoleItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = item.isWarningLike
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return ExpansionTile(
      key: Key('trace-console-row-${item.id}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(30, 0, 0, 8),
      leading: Icon(Icons.bolt_outlined, size: 20, color: color),
      title: Text(
        item.title,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        _displayText(
          l10n,
          item.message,
          emptyLabel: l10n.traceConsoleNoMessage,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      children: [_TraceDetails(item: item)],
    );
  }
}

class _TraceDetails extends StatelessWidget {
  const _TraceDetails({required this.item});

  final TraceConsoleItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: l10n.agentConsoleSeverity(item.severity)),
              _Tag(label: l10n.agentConsoleStatus(item.status)),
              _Tag(
                label: l10n.agentConsoleCreated(
                  _formatDateTime(item.createdAt),
                ),
              ),
              if (item.runId != null)
                _Tag(label: l10n.traceConsoleRun(item.runId!)),
              if (item.taskId != null)
                _Tag(label: l10n.agentConsoleTask(item.taskId!)),
              if (item.eventId != null)
                _Tag(label: l10n.agentConsoleEvent(item.eventId!)),
              if (item.packId != null)
                _Tag(label: l10n.traceConsolePack(item.packId!)),
              if (item.agentId != null)
                _Tag(label: l10n.traceConsoleAgent(item.agentId!)),
              if (item.parentTraceId != null)
                _Tag(label: l10n.agentConsoleParentTrace(item.parentTraceId!)),
              if (item.durationMs != null)
                _Tag(label: l10n.traceConsoleDuration(item.durationMs!)),
            ],
          ),
          const SizedBox(height: 8),
          if (item.delegation != null) ...[
            _DelegationDetails(traceId: item.id, link: item.delegation!),
            const SizedBox(height: 8),
          ],
          _SourceAction(item: item),
          const SizedBox(height: 8),
          _PayloadView(item: item),
        ],
      ),
    );
  }
}

class _DelegationDetails extends StatelessWidget {
  const _DelegationDetails({required this.traceId, required this.link});

  final String traceId;
  final AgentDelegationLink link;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (link.delegationId.isNotEmpty)
          _Tag(
            key: Key('agent-console-child-delegation-$traceId'),
            label: l10n.agentConsoleChildDelegation(link.delegationId),
          ),
        if (link.childRunId != null && link.childRunId!.isNotEmpty)
          _Tag(
            key: Key('agent-console-child-run-$traceId'),
            label: l10n.agentConsoleChildRun(link.childRunId!),
          ),
        if (link.status.isNotEmpty)
          _Tag(
            key: Key('agent-console-child-status-$traceId'),
            label: l10n.agentConsoleChildStatus(link.status),
          ),
        if (link.violationCodes.isNotEmpty)
          _Tag(
            key: Key('agent-console-delegation-violations-$traceId'),
            label: l10n.agentConsoleDelegationViolations(
              link.violationCodes.join(', '),
            ),
          ),
      ],
    );
  }
}

class _SourceAction extends StatelessWidget {
  const _SourceAction({required this.item});

  final TraceConsoleItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final eventId = item.eventId;
    if (eventId == null || eventId.isEmpty) {
      return Text(l10n.traceConsoleNoSource, style: _mutedStyle(context));
    }
    return OutlinedButton.icon(
      key: Key('trace-console-open-source-${item.id}'),
      onPressed: () {
        context.push('/timeline/items/${Uri.encodeComponent(eventId)}');
      },
      icon: const Icon(Icons.open_in_new),
      label: Text(l10n.traceConsoleOpenSourceButton),
    );
  }
}

class _PayloadView extends StatelessWidget {
  const _PayloadView({required this.item});

  final TraceConsoleItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (item.payloadEntries.isEmpty && item.redactedPayloadFieldCount == 0) {
      return Text(l10n.traceConsolePayloadEmpty, style: _mutedStyle(context));
    }
    return Column(
      key: Key('trace-console-payload-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.traceConsolePayloadTitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        for (final entry in item.payloadEntries)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${entry.key}: ${entry.isValueRedacted ? l10n.traceConsoleRedactedValue : entry.value}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (item.redactedPayloadFieldCount > 0)
          Text(
            l10n.traceConsolePayloadRedactedCount(
              item.redactedPayloadFieldCount,
            ),
            style: _mutedStyle(context),
          ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6)),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

String _filterLabel(AppLocalizations l10n, AgentConsoleFilter filter) {
  return switch (filter) {
    AgentConsoleFilter.all => l10n.agentConsoleFilterAll,
    AgentConsoleFilter.active => l10n.agentConsoleFilterActive,
    AgentConsoleFilter.failed => l10n.agentConsoleFilterFailed,
    AgentConsoleFilter.denied => l10n.agentConsoleFilterDenied,
    AgentConsoleFilter.blocked => l10n.agentConsoleFilterBlocked,
  };
}

String _runModeLabel(AppLocalizations l10n, AgentRunMode mode) {
  return switch (mode) {
    AgentRunMode.readOnly => l10n.agentConsoleRunModeReadOnly,
    AgentRunMode.confirm => l10n.agentConsoleRunModeConfirm,
    AgentRunMode.auto => l10n.agentConsoleRunModeAuto,
    AgentRunMode.unknown => l10n.agentConsoleRunModeUnknown,
  };
}

String _displayText(
  AppLocalizations l10n,
  RedactedText text, {
  String? emptyLabel,
}) {
  if (text.isRedacted) {
    return l10n.traceConsoleRedactedValue;
  }
  if (text.value.isEmpty) {
    return emptyLabel ?? '';
  }
  return text.value;
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return local.toIso8601String().split('.').first;
}

IconData _statusIcon(String status) {
  return switch (status) {
    'running' || 'queued' || 'waiting' => Icons.pending_actions_outlined,
    'failed' => Icons.error_outline,
    'denied' => Icons.block_outlined,
    'blocked' => Icons.lock_outline,
    'succeeded' => Icons.check_circle_outline,
    'canceled' => Icons.cancel_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

Color _statusColor(BuildContext context, String status) {
  return switch (status) {
    'failed' || 'denied' || 'blocked' => Theme.of(context).colorScheme.error,
    'succeeded' => Theme.of(context).colorScheme.primary,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

TextStyle? _mutedStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
