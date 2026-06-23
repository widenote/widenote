import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_database.dart';
import 'capture_orchestrator.dart';
import '../domain/capture_models.dart';

final captureOrchestratorProvider = Provider<CaptureOrchestrator>((ref) {
  return CaptureOrchestrator.local(
    eventStore: ref.watch(localEventStoreProvider),
    traceSink: ref.watch(localTraceSinkProvider),
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
        memories: [result.memoryItem, ...state.memories],
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
}
