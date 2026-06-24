import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';
import 'capture_orchestrator.dart';
import 'local_capture_read_model.dart';
import 'local_knowledge_sink.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';

final captureOrchestratorProvider = Provider<CaptureOrchestrator>((ref) {
  return CaptureOrchestrator.local(
    eventStore: ref.watch(localEventStoreProvider),
    traceSink: ref.watch(localTraceSinkProvider),
    memoryRepository: ref.watch(localMemoryRepositoryProvider),
    knowledgeSink: LocalDbCaptureKnowledgeSink(
      ref.watch(localDatabaseProvider),
    ),
    model: ref.watch(modelClientProvider),
  );
});

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);

class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() {
    return _readModelStore().hydrate();
  }

  Future<void> submitCapture(
    String value, {
    List<CaptureAttachment> attachments = const <CaptureAttachment>[],
  }) async {
    final body = value.trim();
    if (body.isEmpty && attachments.isEmpty) {
      return;
    }
    if (state.isProcessing) {
      return;
    }
    if (attachments.any((attachment) => !attachment.isReady)) {
      state = state.copyWith(
        errorMessage: 'Review or remove pending attachments before recording.',
      );
      return;
    }

    final recordBody = body.isEmpty ? _attachmentRecordBody(attachments) : body;

    final pendingRecord = CaptureRecord(
      id: 'local-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      body: recordBody,
      createdAt: DateTime.now().toUtc(),
      status: 'Saved locally, processing',
    );
    _readModelStore().saveCapture(pendingRecord, attachments: attachments);

    state = state.copyWith(
      records: [pendingRecord, ...state.records],
      isProcessing: true,
      clearError: true,
    );

    try {
      final result = await ref
          .read(captureOrchestratorProvider)
          .processCapture(
            body,
            attachments: attachments,
            captureId: pendingRecord.id,
          );
      _readModelStore()
        ..saveCapture(result.record, attachments: attachments)
        ..saveTodo(result.todo);

      state = state.copyWith(
        records: _replaceRecord(state.records, pendingRecord.id, result.record),
        memories: result.memoryItem.needsReview
            ? state.memories
            : [result.memoryItem, ...state.memories],
        reviewCandidates: result.reviewCandidate == null
            ? state.reviewCandidates
            : [result.reviewCandidate!, ...state.reviewCandidates],
        cards: result.cards,
        insights: result.insights,
        todos: [result.todo, ...state.todos],
        traces: [...result.traces, ...state.traces],
        isProcessing: false,
        clearError: true,
      );
    } catch (error) {
      final failedRecord = pendingRecord.copyWith(
        status: 'Saved locally, agent failed',
      );
      _readModelStore().saveCapture(failedRecord, attachments: attachments);
      state = state.copyWith(
        records: _replaceRecord(state.records, pendingRecord.id, failedRecord),
        isProcessing: false,
        errorMessage: 'Capture failed: $error',
      );
    }
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
}
