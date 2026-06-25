import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/capture_controller.dart';
import '../application/capture_input_controller.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';
import 'capture_console.dart';
import 'home_header.dart';
import 'home_section_widgets.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _captureTextController = TextEditingController();
  String? _feedbackMessage;
  String? _feedbackActionLabel;
  VoidCallback? _feedbackAction;

  @override
  void initState() {
    super.initState();
    _captureTextController.addListener(_clearFeedbackAfterNewInput);
  }

  @override
  void dispose() {
    _captureTextController.removeListener(_clearFeedbackAfterNewInput);
    _captureTextController.dispose();
    super.dispose();
  }

  void _clearFeedbackAfterNewInput() {
    if (_feedbackMessage == null ||
        _captureTextController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _feedbackMessage = null;
      _feedbackActionLabel = null;
      _feedbackAction = null;
    });
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
        if (_feedbackMessage != null) ...[
          HomeFeedbackLine(
            message: _feedbackMessage!,
            actionLabel: _feedbackActionLabel,
            onAction: _feedbackAction,
          ),
          const SizedBox(height: 12),
        ],
        if (captureState.errorMessage != null) ...[
          HomeErrorLine(text: captureState.errorMessage!),
          const SizedBox(height: 12),
        ],
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
    final hasText = _captureTextController.text.trim().isNotEmpty;
    if (!hasText && !inputState.hasAttachments) {
      _showFeedback(context.l10n.captureEmptyMessage);
      return;
    }
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
    if (hasText || attachments.isNotEmpty) {
      _captureTextController.clear();
      ref.read(captureInputControllerProvider.notifier).clear();
    }
    unawaited(future);
    _showFeedback(
      context.l10n.captureSavedMessage,
      actionLabel: context.l10n.captureOpenTimelineAction,
      onAction: () => context.go('/timeline'),
    );
    FocusScope.of(context).unfocus();
  }

  void _addPhoto() {
    unawaited(
      _addAttachment(
        () => ref.read(captureInputControllerProvider.notifier).addPhoto(),
        (l10n) => l10n.capturePhotoAttachedMessage,
      ),
    );
  }

  void _setCaptureMode(CaptureMode mode) {
    ref.read(captureInputControllerProvider.notifier).setMode(mode);
  }

  void _addVoice() {
    unawaited(
      _addAttachment(
        () => ref
            .read(captureInputControllerProvider.notifier)
            .addVoiceTranscript(),
        (l10n) => l10n.captureVoiceAttachedMessage,
      ),
    );
  }

  void _addShare() {
    unawaited(
      _addAttachment(
        () =>
            ref.read(captureInputControllerProvider.notifier).addShareImport(),
        (l10n) => l10n.captureShareAttachedMessage,
      ),
    );
  }

  Future<void> _addAttachment(
    Future<void> Function() action,
    String Function(AppLocalizations l10n) successMessage,
  ) async {
    final beforeCount = ref
        .read(captureInputControllerProvider)
        .attachments
        .length;
    await action();
    if (!mounted) {
      return;
    }
    final afterCount = ref
        .read(captureInputControllerProvider)
        .attachments
        .length;
    if (afterCount > beforeCount) {
      _showFeedback(successMessage(context.l10n));
    }
  }

  void _showFeedback(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    setState(() {
      _feedbackMessage = message;
      _feedbackActionLabel = actionLabel;
      _feedbackAction = onAction;
    });
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
    return HomeSurface(
      icon: Icons.dashboard_customize_outlined,
      title: l10n.cardsTitle,
      child: cards.isEmpty
          ? HomeEmptyLine(text: l10n.cardsEmpty)
          : HomeRows(
              children: [
                for (final card in cards)
                  HomeRecordRow(
                    key: Key('card-row-${card.id}'),
                    title: card.title,
                    subtitle:
                        '${card.summary} · ${card.sourceLabel} · '
                        '${card.kindLabel} · ${card.statusLabel}',
                    icon: Icons.view_agenda_outlined,
                    onTap: () => context.go('/timeline/cards/${card.id}'),
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
    return HomeSurface(
      icon: Icons.lightbulb_outline,
      title: l10n.insightsTitle,
      child: insights.isEmpty
          ? HomeEmptyLine(text: l10n.insightsEmpty)
          : HomeRows(
              children: [
                for (final insight in insights)
                  HomeRecordRow(
                    key: Key('insight-row-${insight.id}'),
                    title: insight.title,
                    subtitle:
                        '${insight.summary} · ${insight.sourceLabel} · '
                        '${insight.kindLabel} · ${insight.metricLabel}',
                    icon: Icons.insights_outlined,
                    onTap: () => context.go('/timeline/items/${insight.id}'),
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
    return HomeSurface(
      icon: Icons.article_outlined,
      title: l10n.recordsTitle,
      child: records.isEmpty
          ? HomeEmptyLine(text: l10n.recordsEmpty)
          : HomeRows(
              children: [
                for (final record in records)
                  HomeRecordRow(
                    key: Key('record-row-${record.id}'),
                    title: record.body,
                    subtitle:
                        '${record.id} · ${_localizedRecordStatus(l10n, record.status)}',
                    icon: Icons.notes_outlined,
                    onTap: () => context.go(
                      '/timeline/items/${Uri.encodeComponent(record.sourceEventId ?? record.id)}',
                    ),
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
    return HomeSurface(
      icon: Icons.rate_review_outlined,
      title: l10n.memoryReviewTitle,
      child: candidates.isEmpty
          ? HomeEmptyLine(text: l10n.memoryReviewEmpty)
          : HomeRows(
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
    return HomeSurface(
      icon: Icons.psychology_alt_outlined,
      title: l10n.memoryTitle,
      child: memories.isEmpty
          ? HomeEmptyLine(text: l10n.memoryEmpty)
          : HomeRows(
              children: [
                for (final memory in memories)
                  HomeRecordRow(
                    key: Key('memory-row-${memory.id}'),
                    title: _localizedMemoryTitle(l10n, memory.title),
                    subtitle:
                        '${memory.summary} · ${memory.sourceRecordId} · '
                        '${_localizedConfidenceLabel(l10n, memory.confidenceLabel)} · '
                        '${_localizedStatusLabel(l10n, memory.statusLabel)}',
                    icon: Icons.auto_awesome_outlined,
                    onTap: () => context.go('/timeline/items/${memory.id}'),
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
    return HomeSurface(
      icon: Icons.account_tree_outlined,
      title: l10n.traceTitle,
      child: traces.isEmpty
          ? HomeEmptyLine(text: l10n.traceEmpty)
          : HomeRows(
              children: [
                for (final trace in traces)
                  HomeRecordRow(
                    key: Key('trace-row-${trace.id}'),
                    title: trace.label,
                    subtitle:
                        '${trace.detail} · ${_traceOrigin(trace)} · ${trace.timeLabel}',
                    icon: Icons.route_outlined,
                    onTap: () => context.go('/plugins/traces'),
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
