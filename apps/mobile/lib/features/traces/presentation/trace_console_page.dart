import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/trace_console_controller.dart';

class TraceConsolePage extends ConsumerWidget {
  const TraceConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(traceConsoleControllerProvider);
    return ListView(
      key: const Key('trace-console-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.traceConsoleTitle,
          subtitle: l10n.traceConsoleSubtitle,
        ),
        const SizedBox(height: 16),
        _Summary(snapshot: snapshot),
        const SizedBox(height: 16),
        _TraceList(snapshot: snapshot),
      ],
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.snapshot});

  final TraceConsoleSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.query_stats_outlined,
      title: l10n.traceConsoleSummaryTitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Tag(label: l10n.traceConsoleEventCount(snapshot.items.length)),
          _Tag(label: l10n.traceConsoleRunCount(snapshot.runCount)),
          _Tag(label: l10n.traceConsoleWarningCount(snapshot.warningCount)),
          OutlinedButton.icon(
            key: const Key('trace-console-refresh-button'),
            onPressed: () => ref.invalidate(traceConsoleControllerProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.traceConsoleRefreshButton),
          ),
        ],
      ),
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
                for (final item in snapshot.items) ...[
                  _TraceRow(item: item),
                  const Divider(height: 20),
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
    return Row(
      key: Key('trace-console-row-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.bolt_outlined, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                item.message.isEmpty
                    ? l10n.traceConsoleNoMessage
                    : item.message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Tag(label: item.severity),
                  _Tag(label: item.status),
                  if (item.runId != null)
                    _Tag(label: l10n.traceConsoleRun(item.runId!)),
                  if (item.packId != null)
                    _Tag(label: l10n.traceConsolePack(item.packId!)),
                  if (item.agentId != null)
                    _Tag(label: l10n.traceConsoleAgent(item.agentId!)),
                  if (item.durationMs != null)
                    _Tag(label: l10n.traceConsoleDuration(item.durationMs!)),
                ],
              ),
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
  const _Tag({required this.label});

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
