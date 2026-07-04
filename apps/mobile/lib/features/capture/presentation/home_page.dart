import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../recap/application/daily_recap_repository.dart';
import '../../recap/domain/daily_recap_models.dart';
import '../application/capture_controller.dart';
import '../application/capture_draft_repository.dart';
import '../application/capture_input_controller.dart';
import '../application/capture_sheet_request.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';
import '../../transcription/transcription_types.dart';
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
  int? _scheduledSheetRequestId;

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
    final sheetRequest = ref.watch(captureSheetRequestProvider);
    final todayRecap = ref.watch(dailyRecapProvider);

    _handlePendingSheetRequest(sheetRequest);

    return RefreshIndicator(
      onRefresh: _refreshHome,
      child: ListView(
        key: const Key('home-page'),
        physics: const AlwaysScrollableScrollPhysics(),
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
          if (inputState.isRecordingVoice) ...[
            const SizedBox(height: 8),
            _BackgroundVoiceCard(
              onStop: _stopVoice,
              onCancel: _cancelVoice,
              inputBusy: inputState.isBusy,
              preview: inputState.voicePreview,
            ),
          ],
          if (inputState.errorMessage != null && !_isCaptureSheetOpen) ...[
            const SizedBox(height: 12),
            HomeErrorLine(
              text: localizedCaptureError(l10n, inputState.errorMessage!),
            ),
          ],
          const SizedBox(height: 12),
          _TodayRecapCard(
            recap: todayRecap,
            onOpen: () => context.push('/recap'),
          ),
          const SizedBox(height: 16),
          _RecordsSection(
            records: captureState.records,
            onRetry: _retryCapture,
          ),
          const SizedBox(height: 16),
          _InsightTeaser(insights: captureState.insights),
          const SizedBox(height: 16),
          _HomeCaptureActions(
            inputBusy: inputState.isBusy,
            isRecordingVoice: inputState.isRecordingVoice,
            onNewRecord: _openCaptureSheet,
            onStartVoice: _startVoice,
          ),
        ],
      ),
    );
  }

  void _handlePendingSheetRequest(CaptureSheetRequest sheetRequest) {
    if (!sheetRequest.hasPending ||
        _isCaptureSheetOpen ||
        _scheduledSheetRequestId == sheetRequest.requestId) {
      return;
    }
    _scheduledSheetRequestId = sheetRequest.requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final latest = ref.read(captureSheetRequestProvider);
      if (!latest.hasPending || _isCaptureSheetOpen) {
        return;
      }
      ref
          .read(captureSheetRequestProvider.notifier)
          .markHandled(latest.requestId);
      unawaited(_openCaptureSheet());
    });
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
    unawaited(
      future.whenComplete(() {
        if (mounted) {
          ref.invalidate(dailyRecapProvider);
        }
      }),
    );
    if (hasText || attachments.isNotEmpty) {
      _clearSubmittedDraft();
      ref.read(captureInputControllerProvider.notifier).clear();
    }
    _showFeedback(
      context.l10n.captureSavedMessage,
      actionLabel: context.l10n.captureOpenTimelineAction,
      onAction: () => context.push('/timeline'),
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

  void _stopVoice() {
    unawaited(() async {
      final added = await _addAttachment(
        () => ref
            .read(captureInputControllerProvider.notifier)
            .stopVoiceRecording(),
        (l10n) => l10n.captureVoiceAttachedMessage,
        showSuccess: false,
      );
      if (!mounted || !added) {
        return;
      }
      final submitted = _submitCapture();
      if (!submitted && mounted && !_isCaptureSheetOpen) {
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
    String Function(AppLocalizations l10n) successMessage, {
    bool showSuccess = true,
  }) async {
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
      if (showSuccess && !_isCaptureSheetOpen) {
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

  void _retryCapture(String id) {
    unawaited(ref.read(captureControllerProvider.notifier).retryCapture(id));
  }

  Future<void> _refreshHome() async {
    ref.invalidate(dailyRecapProvider);
    await Future.wait(<Future<void>>[
      ref.read(captureControllerProvider.notifier).refresh(),
      ref.read(dailyRecapProvider.future),
    ]);
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
    return HomeSurface(
      icon: Icons.add_circle_outline,
      title: l10n.homeContinueRecordingTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeContinueRecordingBody,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('open-new-record-button'),
                onPressed: inputBusy ? null : onNewRecord,
                icon: const Icon(Icons.edit_note_outlined),
                label: Text(l10n.homeContinueRecordingAction),
              ),
              OutlinedButton.icon(
                key: const Key('start-background-recording-button'),
                onPressed: inputBusy || isRecordingVoice ? null : onStartVoice,
                icon: const Icon(Icons.mic_none_outlined),
                label: Text(
                  isRecordingVoice
                      ? l10n.homeBackgroundVoiceActiveAction
                      : l10n.homeBackgroundVoiceTitle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayRecapCard extends StatelessWidget {
  const _TodayRecapCard({required this.recap, required this.onOpen});

  final AsyncValue<DailyRecapSnapshot> recap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('home-today-recap-card'),
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.today_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.homeTodayRecapTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      key: const Key('home-today-recap-open-button'),
                      onPressed: onOpen,
                      child: Text(l10n.homeOpenRecapAction),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                recap.when(
                  loading: () => Text(
                    l10n.homeTodayRecapLoading,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  error: (error, _) => Text(
                    l10n.homeTodayRecapUnavailable,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  data: (snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeTodayRecapSummary(
                          snapshot.captureCount,
                          snapshot.memoryCount,
                          snapshot.todoOpenCount,
                          snapshot.todoCompletedCount,
                          snapshot.cardCount,
                          snapshot.insightCount,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _HomeStatusChip(
                            icon: Icons.notes_outlined,
                            label: l10n.homeRecapMetricChip(
                              snapshot.captureCount,
                              l10n.recapCapturesMetric,
                            ),
                          ),
                          _HomeStatusChip(
                            icon: Icons.psychology_alt_outlined,
                            label: l10n.homeRecapMetricChip(
                              snapshot.memoryCount,
                              l10n.recapMemoryMetric,
                            ),
                          ),
                          _HomeStatusChip(
                            icon: Icons.radio_button_unchecked,
                            label: l10n.homeRecapMetricChip(
                              snapshot.todoOpenCount,
                              l10n.recapTodoOpenMetric,
                            ),
                          ),
                          _HomeStatusChip(
                            icon: Icons.check_circle_outline,
                            label: l10n.homeRecapMetricChip(
                              snapshot.todoCompletedCount,
                              l10n.recapTodoCompletedMetric,
                            ),
                          ),
                          _HomeStatusChip(
                            icon: Icons.dashboard_customize_outlined,
                            label: l10n.homeRecapMetricChip(
                              snapshot.cardCount,
                              l10n.recapCardsMetric,
                            ),
                          ),
                          _HomeStatusChip(
                            icon: Icons.lightbulb_outline,
                            label: l10n.homeRecapMetricChip(
                              snapshot.insightCount,
                              l10n.recapInsightsMetric,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightTeaser extends StatelessWidget {
  const _InsightTeaser({required this.insights});

  final List<SourceInsight> insights;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final insight = insights.isEmpty ? null : insights.first;
    return HomeSurface(
      icon: Icons.lightbulb_outline,
      title: l10n.homeInsightTeaserTitle,
      trailing: TextButton(
        key: const Key('home-open-insights-button'),
        onPressed: () => context.push('/insights'),
        child: Text(l10n.homeOpenInsightsAction),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight == null ? l10n.homeInsightTeaserEmpty : insight.summary,
            key: const Key('home-insight-teaser-body'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _HomeStatusChip(
                icon: Icons.question_answer_outlined,
                label: l10n.homeInsightAskHint,
              ),
              if (insight != null)
                _HomeStatusChip(
                  icon: Icons.link,
                  label: localizedSourceLabel(l10n, insight.sourceLabel),
                ),
            ],
          ),
          if (insight != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: Key('home-open-insight-${insight.id}'),
              onPressed: () =>
                  context.push('/insights/${Uri.encodeComponent(insight.id)}'),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.homeOpenInsightsAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeStatusChip extends StatelessWidget {
  const _HomeStatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
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
    required this.preview,
  });

  final VoidCallback onStop;
  final VoidCallback onCancel;
  final bool inputBusy;
  final TranscriptionPreview preview;

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
              preview.hasText
                  ? l10n.voicePreviewDraft(preview.displayText)
                  : preview.errorCode == null
                  ? l10n.backgroundVoiceActiveBody
                  : l10n.voicePreviewUnavailable,
              key: const Key('background-voice-preview'),
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

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.records, required this.onRetry});

  final List<CaptureRecord> records;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HomeSurface(
      icon: Icons.article_outlined,
      title: l10n.homeRecentRecordsTitle,
      trailing: TextButton(
        key: const Key('open-timeline-button'),
        onPressed: () => context.push('/timeline'),
        child: Text(l10n.homeOpenAllRecordsAction),
      ),
      child: records.isEmpty
          ? HomeEmptyLine(text: l10n.recordsEmpty)
          : HomeRows(
              children: [
                for (final record in records.take(3))
                  HomeRecordRow(
                    key: Key('record-row-${record.id}'),
                    title: record.body,
                    subtitle: _recordSubtitle(context, record),
                    icon: record.isProcessing
                        ? Icons.hourglass_top_outlined
                        : Icons.notes_outlined,
                    trailing: record.canRetry || record.isProcessing
                        ? _RecordTrailingAction(
                            record: record,
                            onRetry: () => onRetry(record.id),
                          )
                        : null,
                    onTap: () => context.push(
                      '/timeline/items/${Uri.encodeComponent(record.id)}',
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecordTrailingAction extends StatelessWidget {
  const _RecordTrailingAction({required this.record, required this.onRetry});

  final CaptureRecord record;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (record.canRetry) {
      return IconButton(
        key: Key('record-retry-${record.id}'),
        tooltip: context.l10n.retryButton,
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
      );
    }
    return const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

String _recordSubtitle(BuildContext context, CaptureRecord record) {
  final l10n = context.l10n;
  final parts = <String>[
    _recentRecordTimeLabel(context, record.createdAt),
    if (_shouldShowRecordStatus(record.status))
      _localizedRecordStatusShort(l10n, record.status),
  ];
  final location = record.locationContext;
  if (location != null) {
    final summary = location.displaySummary(coarseOnly: true);
    if (summary != null) {
      parts.add(l10n.locationRecordSummary(summary));
    } else if (location.hasCoordinates) {
      parts.add(l10n.locationRecordCoordinatesSaved);
    } else {
      parts.add(l10n.locationRecordUnavailable);
    }
  }
  return parts.join(' · ');
}

bool _shouldShowRecordStatus(String status) {
  return status == captureStatusSavedProcessing ||
      status == captureStatusTranscriptReady ||
      status == captureStatusAgentFailed;
}

String _localizedRecordStatusShort(AppLocalizations l10n, String status) {
  return switch (status) {
    captureStatusSavedProcessing ||
    captureStatusTranscriptReady => l10n.recordStatusProcessingShort,
    captureStatusProcessed => l10n.recordStatusProcessedShort,
    captureStatusAgentFailed => l10n.recordStatusFailedShort,
    _ => status,
  };
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _recentRecordTimeLabel(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now().toLocal();
  final time = _timeLabel(value);
  final isToday =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (isToday) {
    return time;
  }
  final date = MaterialLocalizations.of(context).formatShortDate(local);
  return '$date $time';
}
