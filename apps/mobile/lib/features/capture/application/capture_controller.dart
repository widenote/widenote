import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'capture_orchestrator.dart';
import '../domain/capture_models.dart';

final captureOrchestratorProvider = Provider<CaptureOrchestrator>((ref) {
  return CaptureOrchestrator.local();
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

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final result = await ref
          .read(captureOrchestratorProvider)
          .processCapture(body);

      state = state.copyWith(
        records: [result.record, ...state.records],
        memories: [result.memoryItem, ...state.memories],
        todos: [result.todo, ...state.todos],
        traces: [...result.traces, ...state.traces],
        isProcessing: false,
      );
    } catch (error) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Capture failed: $error',
      );
    }
  }
}
