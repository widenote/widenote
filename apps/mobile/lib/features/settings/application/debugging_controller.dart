import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/application/capture_controller.dart';
import '../../capture/application/capture_replay_service.dart';

final debuggingControllerProvider =
    AsyncNotifierProvider<DebuggingController, DebuggingState>(
      DebuggingController.new,
    );

final class DebuggingController extends AsyncNotifier<DebuggingState> {
  @override
  Future<DebuggingState> build() async {
    final today = _dateOnly(DateTime.now());
    final range = CaptureReplayDateRange(
      startDate: today.subtract(const Duration(days: 7)),
      endDate: today,
    );
    return _load(range);
  }

  Future<void> setStartDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(
      _load(
        CaptureReplayDateRange(startDate: date, endDate: current.range.endDate),
      ),
    );
  }

  Future<void> setEndDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(
      _load(
        CaptureReplayDateRange(
          startDate: current.range.startDate,
          endDate: date,
        ),
      ),
    );
  }

  Future<void> retryFailedAgents() async {
    final current = state.valueOrNull;
    if (current == null || current.isRunning) {
      return;
    }
    state = AsyncData(
      current.copyWith(isRunning: true, clearErrorMessage: true),
    );
    try {
      final result = await ref
          .read(captureReplayServiceProvider)
          .retryFailedAgents();
      ref.invalidate(captureControllerProvider);
      final next = _load(
        current.range,
      ).copyWith(lastOperation: DebuggingLastOperation.agentRetry(result));
      state = AsyncData(next);
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isRunning: false,
          errorMessage: '$error',
          clearLastOperation: true,
        ),
      );
    }
  }

  Future<void> replayDateRange() async {
    final current = state.valueOrNull;
    if (current == null || current.isRunning || !current.range.isValid) {
      return;
    }
    state = AsyncData(
      current.copyWith(isRunning: true, clearErrorMessage: true),
    );
    try {
      final result = await ref
          .read(captureReplayServiceProvider)
          .replayDateRange(current.range);
      ref.invalidate(captureControllerProvider);
      final next = _load(
        current.range,
      ).copyWith(lastOperation: DebuggingLastOperation.dateReplay(result));
      state = AsyncData(next);
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isRunning: false,
          errorMessage: '$error',
          clearLastOperation: true,
        ),
      );
    }
  }

  DebuggingState _load(CaptureReplayDateRange range) {
    final snapshot = ref.read(captureReplayServiceProvider).snapshot(range);
    return DebuggingState(range: range, snapshot: snapshot);
  }
}

final class DebuggingState {
  const DebuggingState({
    required this.range,
    required this.snapshot,
    this.isRunning = false,
    this.lastOperation,
    this.errorMessage,
  });

  final CaptureReplayDateRange range;
  final CaptureReplaySnapshot snapshot;
  final bool isRunning;
  final DebuggingLastOperation? lastOperation;
  final String? errorMessage;

  DebuggingState copyWith({
    CaptureReplayDateRange? range,
    CaptureReplaySnapshot? snapshot,
    bool? isRunning,
    DebuggingLastOperation? lastOperation,
    String? errorMessage,
    bool clearLastOperation = false,
    bool clearErrorMessage = false,
  }) {
    return DebuggingState(
      range: range ?? this.range,
      snapshot: snapshot ?? this.snapshot,
      isRunning: isRunning ?? this.isRunning,
      lastOperation: clearLastOperation
          ? null
          : lastOperation ?? this.lastOperation,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

enum DebuggingLastOperationType { agentRetry, dateReplay }

final class DebuggingLastOperation {
  const DebuggingLastOperation.agentRetry(AgentRetryBatchResult result)
    : type = DebuggingLastOperationType.agentRetry,
      agentRetryResult = result,
      dateReplayResult = null;

  const DebuggingLastOperation.dateReplay(CaptureDateReplayResult result)
    : type = DebuggingLastOperationType.dateReplay,
      agentRetryResult = null,
      dateReplayResult = result;

  final DebuggingLastOperationType type;
  final AgentRetryBatchResult? agentRetryResult;
  final CaptureDateReplayResult? dateReplayResult;
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
