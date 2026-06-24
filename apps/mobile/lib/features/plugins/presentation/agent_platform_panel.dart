import 'package:flutter/material.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

import '../application/agent_platform_controller.dart';

class AgentPlatformPanel extends StatefulWidget {
  const AgentPlatformPanel({super.key});

  @override
  State<AgentPlatformPanel> createState() => _AgentPlatformPanelState();
}

class _AgentPlatformPanelState extends State<AgentPlatformPanel> {
  late final AgentPlatformController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AgentPlatformController.preview();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _controller.snapshot;
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
            _SectionHeader(
              icon: Icons.account_tree_outlined,
              title: 'Agent Platform',
              trailing: _StatusChip(label: '${snapshot.runs.length} runs'),
            ),
            const SizedBox(height: 12),
            ...snapshot.packs.map(_buildPackRow),
            const Divider(height: 24),
            Text(
              'Runs',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...snapshot.runs.map(_buildRunRow),
          ],
        ),
      ),
    );
  }

  Widget _buildPackRow(AgentPackStatusView pack) {
    return Padding(
      key: Key('agent-pack-status-${_keyId(pack.packId)}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.extension_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _packSummary(pack),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(label: _packStatusLabel(pack.status)),
        ],
      ),
    );
  }

  Widget _buildRunRow(AgentRunView run) {
    return Padding(
      key: Key('agent-run-${run.taskId}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_runIcon(run.status), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${run.packId} · ${run.agentId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${run.detail} · attempt ${run.attempts}/${run.maxAttempts}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusChip(label: _taskStatusLabel(run.status)),
              const SizedBox(height: 4),
              _RunActions(
                run: run,
                onCancel: () {
                  setState(() => _controller.cancel(run.taskId));
                },
                onRetry: () {
                  setState(() => _controller.retry(run.taskId));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunActions extends StatelessWidget {
  const _RunActions({
    required this.run,
    required this.onCancel,
    required this.onRetry,
  });

  final AgentRunView run;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (run.canCancel)
          IconButton(
            key: Key('agent-run-cancel-${run.taskId}'),
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.cancel_outlined, size: 18),
            onPressed: onCancel,
          ),
        if (run.canRetry)
          IconButton(
            key: Key('agent-run-retry-${run.taskId}'),
            tooltip: 'Retry',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_outlined, size: 18),
            onPressed: onRetry,
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
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

String _packSummary(AgentPackStatusView pack) {
  final parts = <String>[];
  _addCount(parts, pack.queuedCount, 'queued');
  _addCount(parts, pack.runningCount, 'running');
  _addCount(parts, pack.succeededCount, 'succeeded');
  _addCount(parts, pack.failedCount, 'failed');
  _addCount(parts, pack.deniedCount, 'denied');
  _addCount(parts, pack.canceledCount, 'canceled');
  return parts.isEmpty ? 'idle' : parts.join(' · ');
}

void _addCount(List<String> parts, int count, String label) {
  if (count > 0) {
    parts.add('$count $label');
  }
}

String _packStatusLabel(runtime.RuntimePackStatusKind status) {
  return switch (status) {
    runtime.RuntimePackStatusKind.idle => 'idle',
    runtime.RuntimePackStatusKind.queued => 'queued',
    runtime.RuntimePackStatusKind.running => 'running',
    runtime.RuntimePackStatusKind.succeeded => 'succeeded',
    runtime.RuntimePackStatusKind.failed => 'failed',
    runtime.RuntimePackStatusKind.denied => 'permission denied',
    runtime.RuntimePackStatusKind.canceled => 'canceled',
    runtime.RuntimePackStatusKind.blocked => 'blocked',
  };
}

String _taskStatusLabel(runtime.RuntimeTaskStatus status) {
  return switch (status) {
    runtime.RuntimeTaskStatus.queued => 'queued',
    runtime.RuntimeTaskStatus.waiting => 'waiting',
    runtime.RuntimeTaskStatus.running => 'running',
    runtime.RuntimeTaskStatus.succeeded => 'succeeded',
    runtime.RuntimeTaskStatus.failed => 'failed',
    runtime.RuntimeTaskStatus.denied => 'permission denied',
    runtime.RuntimeTaskStatus.canceled => 'canceled',
    runtime.RuntimeTaskStatus.blocked => 'blocked',
  };
}

IconData _runIcon(runtime.RuntimeTaskStatus status) {
  return switch (status) {
    runtime.RuntimeTaskStatus.queued ||
    runtime.RuntimeTaskStatus.waiting => Icons.schedule_outlined,
    runtime.RuntimeTaskStatus.running => Icons.play_circle_outline,
    runtime.RuntimeTaskStatus.succeeded => Icons.check_circle_outline,
    runtime.RuntimeTaskStatus.failed => Icons.error_outline,
    runtime.RuntimeTaskStatus.denied => Icons.verified_user_outlined,
    runtime.RuntimeTaskStatus.canceled => Icons.cancel_outlined,
    runtime.RuntimeTaskStatus.blocked => Icons.block_outlined,
  };
}

String _keyId(String value) {
  return value.replaceAll('.', '-');
}
