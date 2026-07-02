import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_database.dart';
import '../../location/application/location_settings_controller.dart';
import '../../location/domain/location_context.dart';
import '../../transcription/transcription_service.dart';
import '../../transcription/transcription_types.dart';
import 'capture_background_processing.dart';
import 'capture_orchestrator.dart';
import 'capture_orchestrator_provider.dart';
import 'local_capture_read_model.dart';
import 'media_preprocessing_service.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);

class CaptureController extends Notifier<CaptureState> {
  final Queue<_QueuedCaptureJob> _processingQueue = Queue<_QueuedCaptureJob>();
  final Set<String> _processingRecordIds = <String>{};
  bool _isDrainingQueue = false;
  int _activeProcessingJobs = 0;

  @override
  CaptureState build() {
    final hydrated = _readModelStore().hydrate();
    scheduleMicrotask(() {
      _restorePendingProcessingQueue();
      if (_readModelStore().readPendingProcessingInputs().isNotEmpty) {
        unawaited(ref.read(captureBackgroundSchedulerProvider).scheduleDrain());
      }
    });
    return hydrated;
  }

  Future<void> refresh() async {
    _reloadStateFromReadModel(clearError: true);
  }

  Future<void> submitCapture(
    String value, {
    List<CaptureAttachment> attachments = const <CaptureAttachment>[],
  }) async {
    final body = value.trim();
    if (body.isEmpty && attachments.isEmpty) {
      return;
    }
    if (attachments.any((attachment) => !attachment.isReady)) {
      state = state.copyWith(
        errorMessage: 'Review or remove pending attachments before saving.',
      );
      return;
    }

    final recordBody = body.isEmpty ? _attachmentRecordBody(attachments) : body;
    state = state.copyWith(clearError: true);
    final locationContext = await _captureLocationContext();
    final now = DateTime.now().toUtc();

    final pendingRecord = CaptureRecord(
      id: 'local-${now.microsecondsSinceEpoch}',
      body: recordBody,
      createdAt: now,
      status: captureStatusSavedProcessing,
      locationContext: locationContext,
    );
    _readModelStore().saveCapture(
      pendingRecord,
      attachments: attachments,
      rawText: body,
    );

    state = state.copyWith(
      records: _upsertRecord(state.records, pendingRecord),
      clearError: true,
    );

    final job = _enqueueProcessing(
      CaptureProcessingInput(
        record: pendingRecord,
        typedText: body,
        attachments: attachments,
      ),
    );
    unawaited(ref.read(captureBackgroundSchedulerProvider).scheduleDrain());
    return job.completer.future;
  }

  Future<void> retryCapture(String id) async {
    final queuedJob = _queuedJobFor(id);
    if (queuedJob != null) {
      return queuedJob.completer.future;
    }
    if (_processingRecordIds.contains(id)) {
      return;
    }
    final input = _readModelStore().readProcessingInput(id);
    if (input == null || !input.record.canRetry) {
      return;
    }
    final taskRetryResult = await _retryRuntimeTaskForCapture(input);
    if (taskRetryResult) {
      return;
    }
    if (await ref
        .read(captureOrchestratorProvider)
        .hasPublishedCapture(input.record.id)) {
      _reloadStateFromReadModel(clearError: true);
      return;
    }
    final retryRecord = input.record.copyWith(
      status: captureStatusSavedProcessing,
    );
    _readModelStore().saveCapture(
      retryRecord,
      attachments: input.attachments,
      rawText: input.typedText,
    );
    state = state.copyWith(
      records: _replaceRecord(state.records, id, retryRecord),
      clearError: true,
    );
    final job = _enqueueProcessing(
      CaptureProcessingInput(
        record: retryRecord,
        typedText: input.typedText,
        attachments: input.attachments,
      ),
    );
    return job.completer.future;
  }

  Future<void> acceptReviewCandidate(String id) async {
    try {
      final memory = await ref
          .read(captureOrchestratorProvider)
          .acceptMemoryProposal(id);
      final knowledgeLayer = await ref
          .read(captureOrchestratorProvider)
          .buildKnowledgeLayer();
      state = state.copyWith(
        memories: [memory, ...state.memories],
        reviewCandidates: _removeReviewCandidate(state.reviewCandidates, id),
        cards: knowledgeLayer.cards,
        insights: knowledgeLayer.insights,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'Memory review failed: $error');
    }
  }

  Future<void> editAndAcceptReviewCandidate(String id, String body) async {
    try {
      final memory = await ref
          .read(captureOrchestratorProvider)
          .acceptMemoryProposal(id, editedBody: body);
      final knowledgeLayer = await ref
          .read(captureOrchestratorProvider)
          .buildKnowledgeLayer();
      state = state.copyWith(
        memories: [memory, ...state.memories],
        reviewCandidates: _removeReviewCandidate(state.reviewCandidates, id),
        cards: knowledgeLayer.cards,
        insights: knowledgeLayer.insights,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'Memory review failed: $error');
    }
  }

  Future<void> rejectReviewCandidate(String id) async {
    try {
      await ref.read(captureOrchestratorProvider).rejectMemoryProposal(id);
      state = state.copyWith(
        reviewCandidates: _removeReviewCandidate(state.reviewCandidates, id),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'Memory review failed: $error');
    }
  }

  List<CaptureRecord> _replaceRecord(
    List<CaptureRecord> records,
    String id,
    CaptureRecord replacement,
  ) {
    return [
      for (final record in records)
        if (record.id == id) replacement else record,
    ];
  }

  List<CaptureRecord> _upsertRecord(
    List<CaptureRecord> records,
    CaptureRecord next,
  ) {
    if (records.any((record) => record.id == next.id)) {
      return _replaceRecord(records, next.id, next);
    }
    return [next, ...records];
  }

  void _restorePendingProcessingQueue() {
    final pendingInputs = _readModelStore().readPendingProcessingInputs();
    for (final input in pendingInputs) {
      if (_queuedJobFor(input.record.id) != null ||
          _processingRecordIds.contains(input.record.id)) {
        continue;
      }
      _enqueueProcessing(input);
    }
  }

  _QueuedCaptureJob _enqueueProcessing(CaptureProcessingInput input) {
    final queued = _queuedJobFor(input.record.id);
    if (queued != null) {
      return queued;
    }
    final job = _QueuedCaptureJob(input);
    _processingQueue.add(job);
    _syncProcessingState();
    unawaited(_drainProcessingQueue());
    return job;
  }

  _QueuedCaptureJob? _queuedJobFor(String id) {
    for (final job in _processingQueue) {
      if (job.input.record.id == id) {
        return job;
      }
    }
    return null;
  }

  Future<void> _drainProcessingQueue() async {
    if (_isDrainingQueue) {
      return;
    }
    _isDrainingQueue = true;
    _syncProcessingState();
    try {
      while (_processingQueue.isNotEmpty &&
          _activeProcessingJobs < _maxConcurrentCaptureJobs) {
        final job = _processingQueue.removeFirst();
        _startProcessingJob(job);
      }
    } finally {
      _isDrainingQueue = false;
      _syncProcessingState();
    }
  }

  void _startProcessingJob(_QueuedCaptureJob job) {
    _activeProcessingJobs += 1;
    _processingRecordIds.add(job.input.record.id);
    _syncProcessingState();
    unawaited(
      _processQueuedCapture(job.input).whenComplete(() {
        _activeProcessingJobs -= 1;
        _processingRecordIds.remove(job.input.record.id);
        if (!job.completer.isCompleted) {
          job.completer.complete();
        }
        _syncProcessingState();
        unawaited(_drainProcessingQueue());
      }),
    );
  }

  Future<void> _processQueuedCapture(CaptureProcessingInput input) async {
    var processingAttachments = input.attachments;
    var currentRecord = input.record;
    var recordBody = currentRecord.body;

    try {
      processingAttachments = await _transcribeVoiceAttachments(
        currentRecord,
        processingAttachments,
      );
      if (_hasActiveVoiceTranscript(processingAttachments)) {
        final transcriptReadyRecord = currentRecord.copyWith(
          status: captureStatusTranscriptReady,
        );
        _readModelStore().saveCapture(
          transcriptReadyRecord,
          attachments: processingAttachments,
          rawText: input.typedText,
        );
        state = state.copyWith(
          records: _replaceRecord(
            state.records,
            currentRecord.id,
            transcriptReadyRecord,
          ),
        );
        currentRecord = transcriptReadyRecord;
      }

      processingAttachments = await ref
          .read(mediaPreprocessingServiceProvider)
          .preprocessPhotoAttachments(currentRecord, processingAttachments);
      if (_hasPhotoAttachment(processingAttachments)) {
        _readModelStore().saveCapture(
          currentRecord,
          attachments: processingAttachments,
          rawText: input.typedText,
        );
      }

      final orchestrator = ref.read(captureOrchestratorProvider);
      final materialized = await orchestrator.materializePublishedCapture(
        currentRecord.id,
      );
      if (materialized != null) {
        _savePipelineResult(
          materialized,
          currentRecord,
          processingAttachments,
          input.typedText,
        );
        _reloadStateFromReadModel(clearError: true);
        return;
      }
      if (await orchestrator.hasPublishedCapture(currentRecord.id)) {
        _reloadStateFromReadModel(clearError: true);
        return;
      }

      final result = await orchestrator.processCapture(
        recordBody,
        attachments: processingAttachments,
        captureId: currentRecord.id,
      );
      _savePipelineResult(
        result,
        currentRecord,
        processingAttachments,
        input.typedText,
      );
      _reloadStateFromReadModel(clearError: true);
    } catch (error) {
      if (_isCaptureAlreadyQueued(error)) {
        _reloadStateFromReadModel(clearError: true);
        return;
      }
      final failedRecord = currentRecord.copyWith(
        status: captureStatusAgentFailed,
      );
      _readModelStore().saveCapture(
        failedRecord,
        attachments: processingAttachments,
        rawText: input.typedText,
      );
      _reloadStateFromReadModel(errorMessage: _captureFailureMessage(error));
    }
  }

  void _reloadStateFromReadModel({
    String? errorMessage,
    bool clearError = false,
  }) {
    final processing = state.isProcessing;
    state = _readModelStore().hydrate().copyWith(
      isProcessing: processing,
      errorMessage: errorMessage,
      clearError: clearError,
    );
  }

  void _savePipelineResult(
    CapturePipelineResult result,
    CaptureRecord currentRecord,
    List<CaptureAttachment> processingAttachments,
    String typedText,
  ) {
    final resultRecord = result.record.copyWith(
      locationContext: currentRecord.locationContext,
      memoryGenerated: result.memoryGenerated,
    );
    final readModel = _readModelStore()
      ..saveCapture(
        resultRecord,
        attachments: processingAttachments,
        rawText: typedText,
      );
    if (result.todo.isSuggested) {
      readModel.saveTodo(result.todo);
    }
  }

  void _syncProcessingState() {
    final next =
        _isDrainingQueue ||
        _activeProcessingJobs > 0 ||
        _processingQueue.isNotEmpty ||
        _processingRecordIds.isNotEmpty;
    if (state.isProcessing == next) {
      return;
    }
    state = state.copyWith(isProcessing: next);
  }

  List<MemoryReviewCandidate> _removeReviewCandidate(
    List<MemoryReviewCandidate> candidates,
    String id,
  ) {
    return [
      for (final candidate in candidates)
        if (candidate.id != id) candidate,
    ];
  }

  String _attachmentRecordBody(List<CaptureAttachment> attachments) {
    return attachments
        .map((attachment) {
          final preview = attachment.previewText.trim();
          if (preview.isNotEmpty) {
            return preview;
          }
          return '${attachment.kind.wireName}: ${attachment.displayName}';
        })
        .where((preview) => preview.isNotEmpty)
        .join('\n');
  }

  LocalCaptureReadModelStore _readModelStore() {
    return LocalCaptureReadModelStore(ref.read(localDatabaseProvider));
  }

  Future<CapturedLocationContext?> _captureLocationContext() async {
    try {
      return await ref.read(locationCaptureServiceProvider).captureForRecord();
    } catch (_) {
      return null;
    }
  }

  Future<List<CaptureAttachment>> _transcribeVoiceAttachments(
    CaptureRecord record,
    List<CaptureAttachment> attachments,
  ) async {
    final updated = <CaptureAttachment>[];
    for (final attachment in attachments) {
      if (attachment.kind != CaptureAssetKind.voice || !attachment.isReady) {
        updated.add(attachment);
        continue;
      }
      final result = await ref
          .read(transcriptionServiceProvider)
          .transcribeAttachment(attachment.id);
      updated.add(_attachmentWithTranscript(attachment, result));
    }
    return List<CaptureAttachment>.unmodifiable(updated);
  }

  Future<bool> _retryRuntimeTaskForCapture(CaptureProcessingInput input) async {
    try {
      final result = await ref
          .read(captureOrchestratorProvider)
          .retryCaptureTasks(input.record.id);
      if (result == null) {
        return false;
      }
      _savePipelineResult(
        result,
        input.record,
        input.attachments,
        input.typedText,
      );
      _reloadStateFromReadModel(clearError: true);
      return true;
    } catch (error) {
      _reloadStateFromReadModel(errorMessage: _captureFailureMessage(error));
      return true;
    }
  }

  CaptureAttachment _attachmentWithTranscript(
    CaptureAttachment attachment,
    TranscriptionResult result,
  ) {
    if (result.status != TranscriptStatus.active ||
        result.text.trim().isEmpty) {
      return attachment.copyWith(
        rawMetadata: <String, Object?>{
          ...attachment.rawMetadata,
          'transcript_status': result.status.wireName,
          if (result.errorCode != null)
            'last_error_code': result.errorCode!.wireName,
        },
      );
    }
    return attachment.copyWith(
      previewText: result.text,
      rawMetadata: <String, Object?>{
        ...attachment.rawMetadata,
        'transcript': result.text,
        'transcript_status': result.status.wireName,
        'transcription_provider_id': result.providerId,
        'transcription_provider_kind': result.providerKind.wireName,
      },
    );
  }

  bool _hasActiveVoiceTranscript(List<CaptureAttachment> attachments) {
    for (final attachment in attachments) {
      if (attachment.kind != CaptureAssetKind.voice) {
        continue;
      }
      if (attachment.rawMetadata['transcript_status'] ==
          TranscriptStatus.active.wireName) {
        return true;
      }
    }
    return false;
  }

  bool _hasPhotoAttachment(List<CaptureAttachment> attachments) {
    return attachments.any(
      (attachment) =>
          attachment.kind == CaptureAssetKind.photo && attachment.isReady,
    );
  }
}

const _maxConcurrentCaptureJobs = 4;

final class _QueuedCaptureJob {
  _QueuedCaptureJob(this.input);

  final CaptureProcessingInput input;
  final Completer<void> completer = Completer<void>();
}

String _captureFailureMessage(Object error) {
  if (error is CapturePipelineException) {
    return 'Record saved locally. Configure a model provider or retry after agent recovery to generate Memory, cards, insights, and todos.';
  }
  return 'Record saved locally, but agent processing failed. Retry after model or permission recovery.';
}

bool _isCaptureAlreadyQueued(Object error) {
  return error is CapturePipelineException &&
      error.message == captureAlreadyQueuedMessage;
}
