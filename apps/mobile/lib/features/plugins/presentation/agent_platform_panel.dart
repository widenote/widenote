import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../traces/application/trace_console_controller.dart';

class AgentPlatformPanel extends ConsumerWidget {
  const AgentPlatformPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(traceConsoleControllerProvider);
    return DecoratedBox(
      key: const Key('agent-platform-panel'),
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
            _Header(
              title: l10n.agentConsoleTitle,
              trailing: _StatusChip(
                label: l10n.traceConsoleEventCount(snapshot.items.length),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.agentConsoleSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: l10n.traceConsoleRunCount(snapshot.runCount),
                ),
                _StatusChip(
                  label: l10n.agentConsoleTaskCount(snapshot.taskCount),
                ),
                _StatusChip(
                  label: l10n.agentConsoleFailedCount(snapshot.summary.failed),
                ),
                OutlinedButton.icon(
                  key: const Key('agent-platform-open-traces-button'),
                  onPressed: () => context.go('/plugins/traces'),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(l10n.traceConsoleOpenButton),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.items.isEmpty)
              Text(
                l10n.traceConsoleEmpty,
                key: const Key('agent-platform-empty-traces'),
              )
            else
              Column(
                children: [
                  for (final item in snapshot.items.take(3))
                    _TracePreview(item: item),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TracePreview extends StatelessWidget {
  const _TracePreview({required this.item});

  final TraceConsoleItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('agent-platform-trace-${item.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isWarningLike ? Icons.error_outline : Icons.bolt_outlined,
            size: 20,
            color: item.isWarningLike
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  item.message.isRedacted
                      ? context.l10n.traceConsoleRedactedValue
                      : item.message.value.isEmpty
                      ? context.l10n.traceConsoleNoMessage
                      : item.message.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(label: item.severity),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.account_tree_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        trailing,
      ],
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
