import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/capture_controller.dart';
import '../domain/capture_models.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _captureTextController = TextEditingController();

  @override
  void dispose() {
    _captureTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(captureControllerProvider);

    return ListView(
      key: const Key('home-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _HomeHeader(),
        const SizedBox(height: 16),
        _QuickCaptureCard(
          controller: _captureTextController,
          onSubmit: _submitCapture,
          isProcessing: captureState.isProcessing,
        ),
        if (captureState.errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorLine(text: captureState.errorMessage!),
        ],
        const SizedBox(height: 16),
        _StageGrid(state: captureState),
        const SizedBox(height: 16),
        _RecordsSection(records: captureState.records),
        const SizedBox(height: 16),
        _MemorySection(memories: captureState.memories),
        const SizedBox(height: 16),
        _TraceSection(traces: captureState.traces),
      ],
    );
  }

  void _submitCapture() {
    unawaited(
      ref
          .read(captureControllerProvider.notifier)
          .submitCapture(_captureTextController.text),
    );
    _captureTextController.clear();
    FocusScope.of(context).unfocus();
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WideNote / 广记',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'quick capture -> timeline -> memory -> insight',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _QuickCaptureCard extends StatelessWidget {
  const _QuickCaptureCard({
    required this.controller,
    required this.onSubmit,
    required this.isProcessing,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: Icons.flash_on_outlined,
      title: 'Quick Capture',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('quick-capture-field'),
            controller: controller,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText:
                  'Drop a thought, meeting note, promise, or raw memory...',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('record-capture-button'),
              onPressed: isProcessing ? null : onSubmit,
              icon: const Icon(Icons.fiber_manual_record),
              label: Text(isProcessing ? '处理中' : '记录'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageGrid extends StatelessWidget {
  const _StageGrid({required this.state});

  final CaptureState state;

  @override
  Widget build(BuildContext context) {
    final stages = [
      _StageData(
        title: 'Processing',
        detail: state.isProcessing
            ? 'running'
            : state.records.isEmpty
            ? 'idle'
            : '${state.records.length} processed',
        icon: Icons.sync_outlined,
        color: const Color(0xFF2367C9),
      ),
      _StageData(
        title: 'Memory',
        detail: state.memories.isEmpty
            ? 'ready'
            : '${state.memories.length} auto-accepted',
        icon: Icons.psychology_alt_outlined,
        color: const Color(0xFF178D66),
      ),
      const _StageData(
        title: 'Insight',
        detail: 'draft lane',
        icon: Icons.lightbulb_outline,
        color: Color(0xFFB7791F),
      ),
      _StageData(
        title: 'Todo',
        detail: '${state.todos.length} linked',
        icon: Icons.task_alt_outlined,
        color: const Color(0xFFC94A3A),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.25 : 1.55,
          children: [for (final stage in stages) _StageCard(stage: stage)],
        );
      },
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage});

  final _StageData stage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(stage.icon, color: stage.color),
            const Spacer(),
            Text(
              stage.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              stage.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.records});

  final List<CaptureRecord> records;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: Icons.article_outlined,
      title: 'Records',
      child: records.isEmpty
          ? const _EmptyLine(text: 'No local records yet.')
          : _Rows(
              children: [
                for (final record in records)
                  _RecordRow(
                    title: record.body,
                    subtitle: '${record.id} · ${record.status}',
                    icon: Icons.notes_outlined,
                  ),
              ],
            ),
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({required this.memories});

  final List<CaptureMemoryItem> memories;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: Icons.psychology_alt_outlined,
      title: 'Memory',
      child: memories.isEmpty
          ? const _EmptyLine(text: 'Memory queue is waiting for first capture.')
          : _Rows(
              children: [
                for (final memory in memories)
                  _RecordRow(
                    title: memory.title,
                    subtitle:
                        '${memory.summary} · ${memory.sourceRecordId} · ${memory.confidenceLabel} · ${memory.statusLabel}',
                    icon: Icons.auto_awesome_outlined,
                  ),
              ],
            ),
    );
  }
}

class _TraceSection extends StatelessWidget {
  const _TraceSection({required this.traces});

  final List<TraceEvent> traces;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: Icons.account_tree_outlined,
      title: 'Trace',
      child: traces.isEmpty
          ? const _EmptyLine(
              text: 'Trace 占位: local runtime events appear here.',
            )
          : _Rows(
              children: [
                for (final trace in traces)
                  _RecordRow(
                    title: trace.label,
                    subtitle: '${trace.detail} · ${trace.timeLabel}',
                    icon: Icons.route_outlined,
                  ),
              ],
            ),
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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

class _Rows extends StatelessWidget {
  const _Rows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const Divider(height: 20),
          children[index],
        ],
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _StageData {
  const _StageData({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;
}
