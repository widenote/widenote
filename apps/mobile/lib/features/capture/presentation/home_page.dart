import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/capture_controller.dart';
import '../application/capture_draft_repository.dart';
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
  Timer? _draftSaveTimer;
  late final CaptureDraftRepository _draftRepository;
  bool _suppressDraftSaves = false;
  bool _isCaptureSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _draftRepository = ref.read(captureDraftRepositoryProvider);
    _captureTextController.addListener(_handleCaptureTextChanged);
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _captureTextController.removeListener(_handleCaptureTextChanged);
    _draftSaveTimer?.cancel();
    if (!_suppressDraftSaves) {
      unawaited(_draftRepository.saveTextDraft(_captureTextController.text));
    }
    _captureTextController.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final draft = await _draftRepository.loadActiveDraft();
    if (!mounted ||
        draft == null ||
        _captureTextController.text.trim().isNotEmpty) {
      return;
    }
    _suppressDraftSaves = true;
    _captureTextController.text = draft.text;
    _suppressDraftSaves = false;
  }

  void _handleCaptureTextChanged() {
    _clearFeedbackAfterNewInput();
    if (_captureTextController.text.trim().isNotEmpty) {
      ref.read(captureInputControllerProvider.notifier).clearError();
    }
    if (_suppressDraftSaves) {
      return;
    }
    _scheduleDraftSave();
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

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      unawaited(_draftRepository.saveTextDraft(_captureTextController.text));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final captureState = ref.watch(captureControllerProvider);
    final inputState = ref.watch(captureInputControllerProvider);

    return ListView(
      key: const Key('home-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        const HomeHeader(),
        const SizedBox(height: 16),
        if (_feedbackMessage != null && !_isCaptureSheetOpen) ...[
          HomeFeedbackLine(
            message: _feedbackMessage!,
            actionLabel: _feedbackActionLabel,
            onAction: _feedbackAction,
          ),
          const SizedBox(height: 12),
        ],
        if (captureState.errorMessage != null) ...[
          HomeErrorLine(
            text: localizedCaptureError(l10n, captureState.errorMessage!),
          ),
          const SizedBox(height: 12),
        ],
        _HomeCaptureActions(
          inputBusy: inputState.isBusy || captureState.isProcessing,
          isRecordingVoice: inputState.isRecordingVoice,
          onNewRecord: _openCaptureSheet,
          onStartVoice: _startVoice,
        ),
        if (inputState.isRecordingVoice) ...[
          const SizedBox(height: 16),
          _BackgroundVoiceCard(
            onStop: () => _stopVoice(openComposerAfterStop: true),
            onCancel: _cancelVoice,
            inputBusy: inputState.isBusy,
          ),
        ],
        if (inputState.errorMessage != null && !_isCaptureSheetOpen) ...[
          const SizedBox(height: 12),
          HomeErrorLine(
            text: localizedCaptureError(l10n, inputState.errorMessage!),
          ),
        ],
        const SizedBox(height: 16),
        _HomeSummaryStrip(state: captureState),
        const SizedBox(height: 16),
        _RecordsSection(records: captureState.records),
        const SizedBox(height: 16),
        _MemorySection(memories: captureState.memories),
      ],
    );
  }

  Future<void> _openCaptureSheet() async {
    setState(() {
      _isCaptureSheetOpen = true;
    });
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Consumer(
            builder: (context, ref, _) {
              final captureState = ref.watch(captureControllerProvider);
              final inputState = ref.watch(captureInputControllerProvider);
              return Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                  ),
                  child: SingleChildScrollView(
                    child: CaptureConsole(
                      controller: _captureTextController,
                      onSubmit: () => _submitCapture(closeComposer: true),
                      onAddCamera: _addCamera,
                      onAddGallery: _addGallery,
                      onRemoveAttachment: _removeAttachment,
                      onAcceptAttachmentReview: _acceptAttachmentReview,
                      isProcessing: captureState.isProcessing,
                      inputState: inputState,
                      onClose: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCaptureSheetOpen = false;
        });
      }
    }
  }

  bool _submitCapture({bool closeComposer = false}) {
    final inputState = ref.read(captureInputControllerProvider);
    final hasText = _captureTextController.text.trim().isNotEmpty;
    if (!hasText && !inputState.hasAttachments) {
      ref
          .read(captureInputControllerProvider.notifier)
          .markEmptySubmitBlocked(context.l10n.captureEmptyMessage);
      return false;
    }
    if (!inputState.canSubmit) {
      ref.read(captureInputControllerProvider.notifier).markSubmitBlocked();
      return false;
    }
    final attachments = List<CaptureAttachment>.unmodifiable(
      inputState.attachments,
    );
    final future = ref
        .read(captureControllerProvider.notifier)
        .submitCapture(_captureTextController.text, attachments: attachments);
    if (hasText || attachments.isNotEmpty) {
      _clearSubmittedDraft();
      ref.read(captureInputControllerProvider.notifier).clear();
    }
    unawaited(future);
    _showFeedback(
      context.l10n.captureSavedMessage,
      actionLabel: context.l10n.captureOpenTimelineAction,
      onAction: () => context.go('/timeline'),
    );
    FocusScope.of(context).unfocus();
    if (closeComposer) {
      Navigator.of(context).pop();
    }
    return true;
  }

  void _clearSubmittedDraft() {
    _draftSaveTimer?.cancel();
    _suppressDraftSaves = true;
    _captureTextController.clear();
    _suppressDraftSaves = false;
    unawaited(_draftRepository.clearActiveDraft());
  }

  void _addCamera() {
    unawaited(
      _addAttachment(
        () =>
            ref.read(captureInputControllerProvider.notifier).addCameraPhoto(),
        (l10n) => l10n.capturePhotoAttachedMessage,
      ),
    );
  }

  void _addGallery() {
    unawaited(
      _addAttachment(
        () =>
            ref.read(captureInputControllerProvider.notifier).addGalleryPhoto(),
        (l10n) => l10n.capturePhotoAttachedMessage,
      ),
    );
  }

  void _startVoice() {
    unawaited(
      ref.read(captureInputControllerProvider.notifier).startVoiceRecording(),
    );
  }

  void _stopVoice({bool openComposerAfterStop = false}) {
    unawaited(() async {
      final added = await _addAttachment(
        () => ref
            .read(captureInputControllerProvider.notifier)
            .stopVoiceRecording(),
        (l10n) => l10n.captureVoiceAttachedMessage,
      );
      if (mounted && added && openComposerAfterStop) {
        await _openCaptureSheet();
      }
    }());
  }

  void _cancelVoice() {
    unawaited(
      ref.read(captureInputControllerProvider.notifier).cancelVoiceRecording(),
    );
  }

  Future<bool> _addAttachment(
    Future<void> Function() action,
    String Function(AppLocalizations l10n) successMessage,
  ) async {
    final beforeCount = ref
        .read(captureInputControllerProvider)
        .attachments
        .length;
    await action();
    if (!mounted) {
      return false;
    }
    final afterCount = ref
        .read(captureInputControllerProvider)
        .attachments
        .length;
    if (afterCount > beforeCount) {
      if (!_isCaptureSheetOpen) {
        _showFeedback(successMessage(context.l10n));
      }
      return true;
    }
    return false;
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
}

class _HomeCaptureActions extends StatelessWidget {
  const _HomeCaptureActions({
    required this.inputBusy,
    required this.isRecordingVoice,
    required this.onNewRecord,
    required this.onStartVoice,
  });

  final bool inputBusy;
  final bool isRecordingVoice;
  final VoidCallback onNewRecord;
  final VoidCallback onStartVoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _HomeActionTile(
          key: const Key('open-new-record-button'),
          icon: Icons.edit_note_outlined,
          title: l10n.homeNewRecordTitle,
          body: l10n.homeNewRecordBody,
          primary: true,
          onTap: inputBusy ? null : onNewRecord,
        ),
        const SizedBox(height: 10),
        _HomeActionTile(
          key: const Key('start-background-recording-button'),
          icon: Icons.mic_none_outlined,
          title: l10n.homeBackgroundVoiceTitle,
          body: isRecordingVoice
              ? l10n.homeBackgroundVoiceActiveBody
              : l10n.homeBackgroundVoiceBody,
          onTap: inputBusy || isRecordingVoice ? null : onStartVoice,
        ),
      ],
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.primary = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = primary ? colorScheme.primary : colorScheme.secondary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: primary ? colorScheme.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: primary
                  ? colorScheme.primary.withValues(alpha: 0.28)
                  : const Color(0xFFD8DDE6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: primary ? 0.74 : 1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundVoiceCard extends StatelessWidget {
  const _BackgroundVoiceCard({
    required this.onStop,
    required this.onCancel,
    required this.inputBusy,
  });

  final VoidCallback onStop;
  final VoidCallback onCancel;
  final bool inputBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('background-voice-card'),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0C4B9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq_outlined, color: colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.backgroundVoiceActiveTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  l10n.backgroundVoiceTimerPlaceholder,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.backgroundVoiceActiveBody,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('background-voice-stop-button'),
                  onPressed: inputBusy ? null : onStop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(l10n.captureVoiceStopButton),
                ),
                OutlinedButton.icon(
                  key: const Key('background-voice-cancel-button'),
                  onPressed: inputBusy ? null : onCancel,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.captureVoiceCancelButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSummaryStrip extends StatelessWidget {
  const _HomeSummaryStrip({required this.state});

  final CaptureState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = [
      _SummaryMetric(
        title: l10n.homeSummaryRecords,
        detail: state.isProcessing
            ? l10n.stageProcessingRunning
            : state.records.isEmpty
            ? l10n.stageProcessingIdle
            : l10n.stageProcessingProcessed(state.records.length),
        icon: Icons.notes_outlined,
        color: const Color(0xFF2367C9),
      ),
      _SummaryMetric(
        title: l10n.homeSummaryMemory,
        detail: state.memories.isEmpty
            ? l10n.stageMemoryReady
            : l10n.stageMemoryAccepted(state.memories.length),
        icon: Icons.psychology_alt_outlined,
        color: const Color(0xFF178D66),
      ),
      _SummaryMetric(
        title: l10n.homeSummaryInsights,
        detail: state.insights.isEmpty
            ? l10n.stageInsightWaiting
            : l10n.stageInsightSourceLinked(state.insights.length),
        icon: Icons.lightbulb_outline,
        color: const Color(0xFFB7791F),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 3 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.3 : 4.4,
          children: [
            for (final metric in metrics) _SummaryCard(metric: metric),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.metric});

  final _SummaryMetric metric;

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
        child: Row(
          children: [
            Icon(metric.icon, color: metric.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric {
  const _SummaryMetric({
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
                      '/timeline/items/${Uri.encodeComponent(record.id)}',
                    ),
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
                        '${memory.summary} · '
                        '${localizedSourceLabel(l10n, memory.sourceRecordId)} · '
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
