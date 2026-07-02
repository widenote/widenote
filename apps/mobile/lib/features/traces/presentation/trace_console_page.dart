import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
          title: l10n.traceConsoleTitle,
          subtitle: l10n.traceConsoleSubtitle,
        ),
        const SizedBox(height: 16),
        _Summary(snapshot: snapshot, onRefresh: controller.refresh),
        const SizedBox(height: 16),
        _ApprovalQueue(snapshot: snapshot),
        const SizedBox(height: 16),
        _EventsEntry(snapshot: snapshot),
        const SizedBox(height: 16),
        _AgentConsoleEntry(snapshot: snapshot),
      ],
    );
  }
}

class TraceRawLogsPage extends ConsumerStatefulWidget {
  const TraceRawLogsPage({super.key});

  @override
  ConsumerState<TraceRawLogsPage> createState() => _TraceRawLogsPageState();
}

class _TraceRawLogsPageState extends ConsumerState<TraceRawLogsPage> {
  static const _pageSize = 25;

  AgentConsoleFilter _filter = AgentConsoleFilter.all;
  late final TextEditingController _searchController;
  String _query = '';
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = ref.watch(traceConsoleControllerProvider);
    final rawLogs = _logsForQuery(snapshot.rawLogsForFilter(_filter), _query);
    final pageCount = rawLogs.isEmpty
        ? 1
        : ((rawLogs.length + _pageSize - 1) ~/ _pageSize);
    final maxPageIndex = pageCount - 1;
    final pageIndex = _pageIndex > maxPageIndex ? maxPageIndex : _pageIndex;
    final pageStart = rawLogs.isEmpty ? 0 : pageIndex * _pageSize;
    final pageLogs = rawLogs
        .skip(pageStart)
        .take(_pageSize)
        .toList(growable: false);
    final pageText = _rawLogPageText(pageLogs);
    return ListView(
      key: const Key('trace-raw-logs-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _BackHeader(
          title: l10n.traceConsoleEventsTitle,
          subtitle: l10n.traceConsoleEventsSubtitle,
        ),
        const SizedBox(height: 16),
        _RawWarning(),
        const SizedBox(height: 16),
        _FilterBar(
          selected: _filter,
          onSelected: (filter) => setState(() {
            _filter = filter;
            _pageIndex = 0;
          }),
        ),
        const SizedBox(height: 16),
        _RawLogSearch(
          controller: _searchController,
          query: _query,
          onChanged: (value) => setState(() {
            _query = value;
            _pageIndex = 0;
          }),
          onClear: () => setState(() {
            _searchController.clear();
            _query = '';
            _pageIndex = 0;
          }),
        ),
        const SizedBox(height: 16),
        _RawLogTextViewer(
          pageText: pageText,
          pageIndex: pageIndex,
          pageCount: pageCount,
          pageStart: pageStart,
          pageLength: pageLogs.length,
          totalCount: rawLogs.length,
          hasAnyLogs: snapshot.rawLogs.isNotEmpty,
          onCopy: pageText.isEmpty ? null : () => _copyPageText(pageText),
          onPageChanged: (page) => setState(() => _pageIndex = page),
        ),
      ],
    );
  }

  Future<void> _copyPageText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.traceRawCopiedSnackbar)),
    );
  }
}

@Deprecated('Use TraceRawLogsPage.')
class TraceEventsPage extends TraceRawLogsPage {
  const TraceEventsPage({super.key});
}

class TraceAgentsPage extends ConsumerStatefulWidget {
  const TraceAgentsPage({super.key});

  @override
  ConsumerState<TraceAgentsPage> createState() => _TraceAgentsPageState();
}

class _TraceAgentsPageState extends ConsumerState<TraceAgentsPage> {
  AgentConsoleFilter _filter = AgentConsoleFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = ref.watch(traceConsoleControllerProvider);
    final runs = snapshot.runsForFilter(_filter);
    final tasks = snapshot.tasksForFilter(_filter);
    return ListView(
      key: const Key('trace-agents-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _BackHeader(
          title: l10n.agentConsoleAgentsTitle,
          subtitle: l10n.agentConsoleAgentsSubtitle,
        ),
        const SizedBox(height: 16),
        _FilterBar(
          selected: _filter,
          onSelected: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: 16),
        _RunList(runs: runs),
        const SizedBox(height: 16),
        _TaskList(tasks: tasks),
      ],
    );
  }
}

class TraceRawPage extends ConsumerWidget {
  const TraceRawPage({required this.traceId, super.key});

  final String traceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rawTrace = ref.watch(rawTraceViewModelProvider(traceId));
    return SelectionContainer.disabled(
      child: ListView(
        key: const Key('trace-raw-page'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _BackHeader(
            title: l10n.traceRawTitle,
            subtitle: l10n.traceRawSubtitle,
          ),
          const SizedBox(height: 16),
          _RawWarning(),
          const SizedBox(height: 16),
          if (rawTrace == null)
            _Surface(
              icon: Icons.search_off_outlined,
              title: l10n.traceRawNotFoundTitle,
              child: Text(
                l10n.traceRawNotFoundBody,
                key: const Key('trace-raw-not-found'),
              ),
            )
          else
            _RawTraceDetails(trace: rawTrace),
        ],
      ),
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

class _EventsEntry extends StatelessWidget {
  const _EventsEntry({required this.snapshot});

  final TraceConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.receipt_long_outlined,
      title: l10n.traceConsoleEventsEntryTitle,
      child: Column(
        key: const Key('trace-console-raw-logs-entry'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.traceConsoleEventsEntryBody),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Tag(label: l10n.traceConsoleEventCount(snapshot.items.length)),
              _Tag(label: l10n.traceConsoleWarningCount(snapshot.warningCount)),
              OutlinedButton.icon(
                key: const Key('trace-console-raw-logs-entry-button'),
                onPressed: () => context.push(_traceChildPath(context, 'raw')),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.traceConsoleOpenEventsButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentConsoleEntry extends StatelessWidget {
  const _AgentConsoleEntry({required this.snapshot});

  final TraceConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.route_outlined,
      title: l10n.agentConsoleAgentsEntryTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.agentConsoleAgentsEntryBody),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Tag(label: l10n.traceConsoleRunCount(snapshot.runCount)),
              _Tag(label: l10n.agentConsoleTaskCount(snapshot.taskCount)),
              _Tag(
                label: l10n.agentConsoleFailedCount(snapshot.summary.failed),
              ),
              OutlinedButton.icon(
                key: const Key('trace-console-agents-entry'),
                onPressed: () =>
                    context.push(_traceChildPath(context, 'agents')),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.agentConsoleOpenAgentsButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunList extends StatelessWidget {
  const _RunList({required this.runs});

  final List<AgentConsoleRun> runs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
  const _TaskList({required this.tasks});

  final List<AgentConsoleTask> tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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

class _RawLogSearch extends StatelessWidget {
  const _RawLogSearch({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.search,
      title: l10n.traceRawSearchTitle,
      child: TextField(
        key: const Key('trace-raw-search-field'),
        controller: controller,
        decoration: InputDecoration(
          labelText: l10n.traceRawSearchLabel,
          hintText: l10n.traceRawSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  key: const Key('trace-raw-search-clear'),
                  tooltip: l10n.traceRawClearSearchTooltip,
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _RawLogTextViewer extends StatelessWidget {
  const _RawLogTextViewer({
    required this.pageText,
    required this.pageIndex,
    required this.pageCount,
    required this.pageStart,
    required this.pageLength,
    required this.totalCount,
    required this.hasAnyLogs,
    required this.onCopy,
    required this.onPageChanged,
  });

  final String pageText;
  final int pageIndex;
  final int pageCount;
  final int pageStart;
  final int pageLength;
  final int totalCount;
  final bool hasAnyLogs;
  final VoidCallback? onCopy;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasMatches = pageText.isNotEmpty;
    final start = hasMatches ? pageStart + 1 : 0;
    final end = hasMatches ? pageStart + pageLength : 0;
    final displayText = hasMatches
        ? pageText
        : hasAnyLogs
        ? l10n.traceRawNoMatches
        : l10n.traceConsoleEmpty;
    return _Surface(
      icon: Icons.subject_outlined,
      title: l10n.traceRawStreamTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasMatches
                      ? l10n.traceRawPageStatus(
                          pageIndex + 1,
                          pageCount,
                          start,
                          end,
                          totalCount,
                        )
                      : l10n.traceRawNoLogsStatus,
                  key: const Key('trace-raw-page-status'),
                  style: _mutedStyle(context),
                ),
              ),
              IconButton(
                key: const Key('trace-raw-copy-button'),
                tooltip: l10n.traceRawCopyPageTooltip,
                onPressed: onCopy,
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            key: const Key('trace-raw-text-box'),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD8DDE6)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    displayText,
                    key: const Key('trace-raw-text'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _RawLogPager(
            pageIndex: pageIndex,
            pageCount: pageCount,
            enabled: totalCount > 0,
            onPageChanged: onPageChanged,
          ),
        ],
      ),
    );
  }
}

class _RawLogPager extends StatelessWidget {
  const _RawLogPager({
    required this.pageIndex,
    required this.pageCount,
    required this.enabled,
    required this.onPageChanged,
  });

  final int pageIndex;
  final int pageCount;
  final bool enabled;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canGoBack = enabled && pageIndex > 0;
    final canGoForward = enabled && pageIndex < pageCount - 1;
    return Row(
      key: const Key('trace-raw-pager'),
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          key: const Key('trace-raw-first-page'),
          tooltip: l10n.traceRawFirstPageTooltip,
          onPressed: canGoBack ? () => onPageChanged(0) : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton(
          key: const Key('trace-raw-previous-page'),
          tooltip: l10n.traceRawPreviousPageTooltip,
          onPressed: canGoBack ? () => onPageChanged(pageIndex - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          key: const Key('trace-raw-next-page'),
          tooltip: l10n.traceRawNextPageTooltip,
          onPressed: canGoForward ? () => onPageChanged(pageIndex + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          key: const Key('trace-raw-last-page'),
          tooltip: l10n.traceRawLastPageTooltip,
          onPressed: canGoForward ? () => onPageChanged(pageCount - 1) : null,
          icon: const Icon(Icons.last_page),
        ),
      ],
    );
  }
}

List<RawTraceViewModel> _logsForQuery(
  List<RawTraceViewModel> logs,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return logs;
  }
  return logs
      .where((log) => log.rawText.toLowerCase().contains(normalized))
      .toList(growable: false);
}

String _rawLogPageText(List<RawTraceViewModel> logs) {
  return logs.map((log) => log.rawText).join('\n\n---\n\n');
}

class _RawWarning extends StatelessWidget {
  const _RawWarning();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.lock_outline,
      title: l10n.traceRawWarningTitle,
      child: Text(
        l10n.traceRawWarningBody,
        key: const Key('trace-raw-warning'),
      ),
    );
  }
}

class _RawTraceDetails extends StatelessWidget {
  const _RawTraceDetails({required this.trace});

  final RawTraceViewModel trace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Surface(
          icon: Icons.info_outline,
          title: l10n.traceRawMetadataTitle,
          child: Column(
            key: Key('trace-raw-metadata-${trace.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in trace.metadata)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.notes_outlined,
          title: l10n.traceRawMessageTitle,
          child: Text(
            trace.message.isEmpty ? l10n.traceConsoleNoMessage : trace.message,
            key: Key('trace-raw-message-${trace.id}'),
          ),
        ),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.data_object_outlined,
          title: l10n.traceRawPayloadTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  trace.payloadJson,
                  key: Key('trace-raw-payload-${trace.id}'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
              if (trace.redactedPayloadFieldCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.traceRawPolicyRedactedCount(
                    trace.redactedPayloadFieldCount,
                  ),
                  key: Key('trace-raw-redacted-count-${trace.id}'),
                  style: _mutedStyle(context),
                ),
              ],
            ],
          ),
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

class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          key: const Key('trace-console-back-button'),
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.traceConsoleBackTooltip,
        ),
        _PageHeader(title: title, subtitle: subtitle),
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

String _traceChildPath(BuildContext context, String childPath) {
  final currentPath = GoRouterState.of(context).uri.path;
  final prefix = currentPath.startsWith('/plugins/traces')
      ? '/plugins/traces'
      : '/settings/traces';
  return '$prefix/$childPath';
}
