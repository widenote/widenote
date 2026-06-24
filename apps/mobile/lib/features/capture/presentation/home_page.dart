import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/capture_controller.dart';
import '../application/capture_input_controller.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';
import 'capture_console.dart';
import 'home_header.dart';

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
    final inputState = ref.watch(captureInputControllerProvider);

    return ListView(
      key: const Key('home-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        const HomeHeader(),
        const SizedBox(height: 16),
        CaptureConsole(
          controller: _captureTextController,
          onSubmit: _submitCapture,
          onModeChanged: _setCaptureMode,
          onAddPhoto: _addPhoto,
          onAddVoice: _addVoice,
          onAddShare: _addShare,
          onRemoveAttachment: _removeAttachment,
          onAcceptAttachmentReview: _acceptAttachmentReview,
          isProcessing: captureState.isProcessing,
          inputState: inputState,
        ),
        if (captureState.errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorLine(text: captureState.errorMessage!),
        ],
        if (captureState.reviewCandidates.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MemoryReviewSection(
            candidates: captureState.reviewCandidates,
            onAccept: _acceptReviewCandidate,
            onReject: _rejectReviewCandidate,
            onEdit: _editReviewCandidate,
          ),
        ],
        const SizedBox(height: 16),
        _StageGrid(state: captureState),
        const SizedBox(height: 16),
        _CardsSection(cards: captureState.cards),
        const SizedBox(height: 16),
        _InsightsSection(insights: captureState.insights),
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
    final inputState = ref.read(captureInputControllerProvider);
    if (!inputState.canSubmit) {
      ref.read(captureInputControllerProvider.notifier).markSubmitBlocked();
      return;
    }
    final attachments = List<CaptureAttachment>.unmodifiable(
      inputState.attachments,
    );
    final future = ref
        .read(captureControllerProvider.notifier)
        .submitCapture(_captureTextController.text, attachments: attachments);
    if (_captureTextController.text.trim().isNotEmpty ||
        attachments.isNotEmpty) {
      _captureTextController.clear();
      ref.read(captureInputControllerProvider.notifier).clear();
    }
    unawaited(future);
    FocusScope.of(context).unfocus();
  }

  void _addPhoto() {
    unawaited(ref.read(captureInputControllerProvider.notifier).addPhoto());
  }

  void _setCaptureMode(CaptureMode mode) {
    ref.read(captureInputControllerProvider.notifier).setMode(mode);
  }

  void _addVoice() {
    unawaited(
      ref.read(captureInputControllerProvider.notifier).addVoiceTranscript(),
    );
  }

  void _addShare() {
    unawaited(
      ref.read(captureInputControllerProvider.notifier).addShareImport(),
    );
  }

  void _removeAttachment(String id) {
    ref.read(captureInputControllerProvider.notifier).removeAttachment(id);
  }

  void _acceptAttachmentReview(String id) {
    ref
        .read(captureInputControllerProvider.notifier)
        .acceptAttachmentReview(id);
  }

  void _acceptReviewCandidate(String id) {
    unawaited(
      ref.read(captureControllerProvider.notifier).acceptReviewCandidate(id),
    );
  }

  void _rejectReviewCandidate(String id) {
    unawaited(
      ref.read(captureControllerProvider.notifier).rejectReviewCandidate(id),
    );
  }

  Future<void> _editReviewCandidate(MemoryReviewCandidate candidate) async {
    final editedBody = await showDialog<String>(
      context: context,
      builder: (context) => _MemoryEditDialog(initialBody: candidate.summary),
    );
    if (!mounted || editedBody == null) {
      return;
    }
    unawaited(
      ref
          .read(captureControllerProvider.notifier)
          .editAndAcceptReviewCandidate(candidate.id, editedBody),
    );
  }
}

class _MemoryEditDialog extends StatefulWidget {
  const _MemoryEditDialog({required this.initialBody});

  final String initialBody;

  @override
  State<_MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<_MemoryEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.memoryEditTitle),
      content: TextField(
        key: const Key('memory-review-edit-field'),
        controller: _controller,
        minLines: 3,
        maxLines: 5,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('memory-review-edit-save'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.saveButton),
        ),
      ],
    );
  }
}

class _StageGrid extends StatelessWidget {
  const _StageGrid({required this.state});

  final CaptureState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stages = [
      _StageData(
        title: l10n.stageProcessingTitle,
        detail: state.isProcessing
            ? l10n.stageProcessingRunning
            : state.records.isEmpty
            ? l10n.stageProcessingIdle
            : l10n.stageProcessingProcessed(state.records.length),
        icon: Icons.sync_outlined,
        color: const Color(0xFF2367C9),
      ),
      _StageData(
        title: l10n.stageMemoryTitle,
        detail: state.memories.isEmpty && state.reviewCandidates.isEmpty
            ? l10n.stageMemoryReady
            : state.reviewCandidates.isEmpty
            ? l10n.stageMemoryAccepted(state.memories.length)
            : l10n.stageMemoryAcceptedReview(
                state.memories.length,
                state.reviewCandidates.length,
              ),
        icon: Icons.psychology_alt_outlined,
        color: const Color(0xFF178D66),
      ),
      _StageData(
        title: l10n.stageCardsTitle,
        detail: state.cards.isEmpty
            ? l10n.stageCardsWaiting
            : l10n.stageCardsLinked(state.cards.length),
        icon: Icons.dashboard_customize_outlined,
        color: const Color(0xFF7A5AF8),
      ),
      _StageData(
        title: l10n.stageInsightTitle,
        detail: state.insights.isEmpty
            ? l10n.stageInsightWaiting
            : l10n.stageInsightSourceLinked(state.insights.length),
        icon: Icons.lightbulb_outline,
        color: const Color(0xFFB7791F),
      ),
      _StageData(
        title: l10n.stageTodoTitle,
        detail: l10n.stageTodoLinked(state.todos.length),
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

class _CardsSection extends StatelessWidget {
  const _CardsSection({required this.cards});

  final List<SourceCard> cards;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.dashboard_customize_outlined,
      title: l10n.cardsTitle,
      child: cards.isEmpty
          ? _EmptyLine(text: l10n.cardsEmpty)
          : _Rows(
              children: [
                for (final card in cards)
                  _RecordRow(
                    key: Key('card-row-${card.id}'),
                    title: card.title,
                    subtitle:
                        '${card.summary} · ${card.sourceLabel} · '
                        '${card.kindLabel} · ${card.statusLabel}',
                    icon: Icons.view_agenda_outlined,
                  ),
              ],
            ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({required this.insights});

  final List<SourceInsight> insights;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.lightbulb_outline,
      title: l10n.insightsTitle,
      child: insights.isEmpty
          ? _EmptyLine(text: l10n.insightsEmpty)
          : _Rows(
              children: [
                for (final insight in insights)
                  _RecordRow(
                    key: Key('insight-row-${insight.id}'),
                    title: insight.title,
                    subtitle:
                        '${insight.summary} · ${insight.sourceLabel} · '
                        '${insight.kindLabel} · ${insight.metricLabel}',
                    icon: Icons.insights_outlined,
                  ),
              ],
            ),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.records});

  final List<CaptureRecord> records;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.article_outlined,
      title: l10n.recordsTitle,
      child: records.isEmpty
          ? _EmptyLine(text: l10n.recordsEmpty)
          : _Rows(
              children: [
                for (final record in records)
                  _RecordRow(
                    key: Key('record-row-${record.id}'),
                    title: record.body,
                    subtitle:
                        '${record.id} · ${_localizedRecordStatus(l10n, record.status)}',
                    icon: Icons.notes_outlined,
                  ),
              ],
            ),
    );
  }
}

class _MemoryReviewSection extends StatelessWidget {
  const _MemoryReviewSection({
    required this.candidates,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
  });

  final List<MemoryReviewCandidate> candidates;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;
  final ValueChanged<MemoryReviewCandidate> onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.rate_review_outlined,
      title: l10n.memoryReviewTitle,
      child: candidates.isEmpty
          ? _EmptyLine(text: l10n.memoryReviewEmpty)
          : _Rows(
              children: [
                for (final candidate in candidates)
                  _ReviewCandidateRow(
                    candidate: candidate,
                    onAccept: onAccept,
                    onReject: onReject,
                    onEdit: onEdit,
                  ),
              ],
            ),
    );
  }
}

class _ReviewCandidateRow extends StatelessWidget {
  const _ReviewCandidateRow({
    required this.candidate,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
  });

  final MemoryReviewCandidate candidate;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;
  final ValueChanged<MemoryReviewCandidate> onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.fact_check_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${candidate.sourceLabel} · ${candidate.reasonLabel} · ${candidate.typeLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    key: Key('memory-review-accept-${candidate.id}'),
                    onPressed: () => onAccept(candidate.id),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.memoryReviewAccept),
                  ),
                  OutlinedButton.icon(
                    key: Key('memory-review-edit-${candidate.id}'),
                    onPressed: () => onEdit(candidate),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.memoryReviewEdit),
                  ),
                  TextButton.icon(
                    key: Key('memory-review-reject-${candidate.id}'),
                    onPressed: () => onReject(candidate.id),
                    icon: const Icon(Icons.close),
                    label: Text(l10n.memoryReviewReject),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({required this.memories});

  final List<CaptureMemoryItem> memories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.psychology_alt_outlined,
      title: l10n.memoryTitle,
      child: memories.isEmpty
          ? _EmptyLine(text: l10n.memoryEmpty)
          : _Rows(
              children: [
                for (final memory in memories)
                  _RecordRow(
                    key: Key('memory-row-${memory.id}'),
                    title: _localizedMemoryTitle(l10n, memory.title),
                    subtitle:
                        '${memory.summary} · ${memory.sourceRecordId} · '
                        '${_localizedConfidenceLabel(l10n, memory.confidenceLabel)} · '
                        '${_localizedStatusLabel(l10n, memory.statusLabel)}',
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
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.account_tree_outlined,
      title: l10n.traceTitle,
      child: traces.isEmpty
          ? _EmptyLine(text: l10n.traceEmpty)
          : _Rows(
              children: [
                for (final trace in traces)
                  _RecordRow(
                    key: Key('trace-row-${trace.id}'),
                    title: trace.label,
                    subtitle:
                        '${trace.detail} · ${_traceOrigin(trace)} · ${trace.timeLabel}',
                    icon: Icons.route_outlined,
                  ),
              ],
            ),
    );
  }
}

String _traceOrigin(TraceEvent trace) {
  final pack = trace.packId ?? 'runtime';
  final agent = trace.agentId ?? 'system';
  final run = trace.runId ?? 'no-run';
  return '$pack · $agent · $run';
}

String _localizedRecordStatus(AppLocalizations l10n, String status) {
  return switch (status) {
    'Saved locally, processing' => l10n.recordStatusSavedProcessing,
    'Processed locally' => l10n.recordStatusProcessed,
    'Saved locally, agent failed' => l10n.recordStatusAgentFailed,
    _ => status,
  };
}

String _localizedMemoryTitle(AppLocalizations l10n, String title) {
  return switch (title) {
    'memory.auto_saved' => l10n.memoryAutoSavedTitle,
    'memory.needs_review' => l10n.memoryNeedsReviewTitle,
    'memory.accepted' => l10n.memorySavedTitle,
    _ => title,
  };
}

String _localizedStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'auto-accepted' => l10n.statusAutoAccepted,
    'needs review' => l10n.statusNeedsReview,
    'accepted' => l10n.statusAccepted,
    _ => status,
  };
}

String _localizedConfidenceLabel(AppLocalizations l10n, String label) {
  final confidence = switch (label) {
    'high confidence' => l10n.confidenceHigh,
    'medium confidence' => l10n.confidenceMedium,
    'low confidence' => l10n.confidenceLow,
    _ => null,
  };
  return confidence == null ? label : l10n.confidenceLabel(confidence);
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
    super.key,
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
