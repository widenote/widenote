import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_database.dart';
import 'capture_orchestrator.dart';
import '../domain/capture_models.dart';

final captureOrchestratorProvider = Provider<CaptureOrchestrator>((ref) {
  return CaptureOrchestrator.local(
    eventStore: ref.watch(localEventStoreProvider),
    traceSink: ref.watch(localTraceSinkProvider),
    memoryRepository: ref.watch(localMemoryRepositoryProvider),
  );
});

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);

class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => CaptureState.initial();

  Future<void> submitCapture(String value) async {
    final body = value.trim();
    if (body.isEmpty) {
      return;
    }
    if (state.isProcessing) {
      return;
    }

    final pendingRecord = CaptureRecord(
      id: 'local-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      body: body,
      createdAt: DateTime.now().toUtc(),
      status: 'Saved locally, processing',
    );

    state = state.copyWith(
      records: [pendingRecord, ...state.records],
      isProcessing: true,
      clearError: true,
    );

    try {
      final result = await ref
          .read(captureOrchestratorProvider)
          .processCapture(body);

      state = state.copyWith(
        records: _replaceRecord(state.records, pendingRecord.id, result.record),
        memories: result.memoryItem.needsReview
            ? state.memories
            : [result.memoryItem, ...state.memories],
        reviewCandidates: result.reviewCandidate == null
            ? state.reviewCandidates
            : [result.reviewCandidate!, ...state.reviewCandidates],
        todos: [result.todo, ...state.todos],
        traces: [...result.traces, ...state.traces],
        isProcessing: false,
      );
    } catch (error) {
      state = state.copyWith(
        records: _replaceRecord(
          state.records,
          pendingRecord.id,
          pendingRecord.copyWith(status: 'Saved locally, agent failed'),
        ),
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
      state = state.copyWith(
        memories: [memory, ...state.memories],
        reviewCandidates: _removeReviewCandidate(state.reviewCandidates, id),
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
      state = state.copyWith(
        memories: [memory, ...state.memories],
        reviewCandidates: _removeReviewCandidate(state.reviewCandidates, id),
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
}
