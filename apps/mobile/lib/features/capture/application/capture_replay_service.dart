import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';
import 'capture_orchestrator.dart';
import 'capture_orchestrator_provider.dart';
import 'local_capture_read_model.dart';
import 'media_preprocessing_service.dart';

const defaultCaptureReplayBatchLimit = 50;
const defaultAgentRetryBatchLimit = 100;

final captureReplayServiceProvider = Provider<CaptureReplayService>((ref) {
  final database = ref.watch(localDatabaseProvider);
  return LocalCaptureReplayService(
    database: database,
    readModel: LocalCaptureReadModelStore(database),
    orchestrator: ref.watch(captureOrchestratorProvider),
    mediaPreprocessor: ref.watch(mediaPreprocessingServiceProvider),
  );
});

abstract interface class CaptureReplayService {
  CaptureReplaySnapshot snapshot(CaptureReplayDateRange range);

  Future<AgentRetryBatchResult> retryFailedAgents();

  Future<CaptureDateReplayResult> replayDateRange(CaptureReplayDateRange range);
}

final class CaptureReplayDateRange {
  const CaptureReplayDateRange({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;

  bool get isValid => !_dateOnly(endDate).isBefore(_dateOnly(startDate));
}

final class CaptureReplaySnapshot {
  const CaptureReplaySnapshot({
    required this.retryableAgentTasks,
    required this.matchingCaptures,
    required this.agentBatchLimit,
    required this.captureBatchLimit,
  });

  final int retryableAgentTasks;
  final int matchingCaptures;
  final int agentBatchLimit;
  final int captureBatchLimit;

  bool get agentRetryLimited => retryableAgentTasks > agentBatchLimit;
  bool get captureReplayLimited => matchingCaptures > captureBatchLimit;
}

final class AgentRetryBatchResult {
  const AgentRetryBatchResult({
    required this.retryableAgentTasks,
    required this.selectedAgentTasks,
    required this.retriedAgentTasks,
    required this.drainedRuntimeTasks,
    required this.refreshedCaptures,
    required this.failedRefreshes,
    required this.skippedRefreshes,
    required this.limited,
  });

  final int retryableAgentTasks;
  final int selectedAgentTasks;
  final int retriedAgentTasks;
  final int drainedRuntimeTasks;
  final int refreshedCaptures;
  final int failedRefreshes;
  final int skippedRefreshes;
  final bool limited;
}

final class CaptureDateReplayResult {
  const CaptureDateReplayResult({
    required this.matchingCaptures,
    required this.selectedCaptures,
    required this.processedCaptures,
    required this.retriedCaptures,
    required this.refreshedCaptures,
    required this.failedCaptures,
    required this.skippedCaptures,
    required this.deferredCaptures,
    required this.limited,
  });

  final int matchingCaptures;
  final int selectedCaptures;
  final int processedCaptures;
  final int retriedCaptures;
  final int refreshedCaptures;
  final int failedCaptures;
  final int skippedCaptures;
  final int deferredCaptures;
  final bool limited;
}

final class LocalCaptureReplayService implements CaptureReplayService {
  const LocalCaptureReplayService({
    required localdb.WideNoteLocalDatabase database,
    required LocalCaptureReadModelStore readModel,
    required CaptureOrchestrator orchestrator,
    required MediaPreprocessingService mediaPreprocessor,
    int captureBatchLimit = defaultCaptureReplayBatchLimit,
    int agentBatchLimit = defaultAgentRetryBatchLimit,
  }) : _database = database,
       _readModel = readModel,
       _orchestrator = orchestrator,
       _mediaPreprocessor = mediaPreprocessor,
       _captureBatchLimit = captureBatchLimit,
       _agentBatchLimit = agentBatchLimit;

  final localdb.WideNoteLocalDatabase _database;
  final LocalCaptureReadModelStore _readModel;
  final CaptureOrchestrator _orchestrator;
  final MediaPreprocessingService _mediaPreprocessor;
  final int _captureBatchLimit;
  final int _agentBatchLimit;

  @override
  CaptureReplaySnapshot snapshot(CaptureReplayDateRange range) {
    return CaptureReplaySnapshot(
      retryableAgentTasks: _retryableTaskRecords().length,
      matchingCaptures: range.isValid
          ? _readModel.countProcessingInputsInDateRange(
              startDate: range.startDate,
              endDate: range.endDate,
            )
          : 0,
      agentBatchLimit: _agentBatchLimit,
      captureBatchLimit: _captureBatchLimit,
    );
  }

  @override
  Future<AgentRetryBatchResult> retryFailedAgents() async {
    final retryableAgentTasks = _retryableTaskRecords().length;
    final retry = await _orchestrator.retryFailedAgentTasks(
      limit: _agentBatchLimit,
    );
    final refresh = await _refreshCaptureReadModels(retry.affectedCaptureIds);
    return AgentRetryBatchResult(
      retryableAgentTasks: retryableAgentTasks,
      selectedAgentTasks: retry.retryableTaskCount,
      retriedAgentTasks: retry.retriedTaskCount,
      drainedRuntimeTasks: retry.drainedTaskCount,
      refreshedCaptures: refresh.refreshed,
      failedRefreshes: refresh.failed,
      skippedRefreshes: refresh.skipped,
      limited: retryableAgentTasks > _agentBatchLimit,
    );
  }

  @override
  Future<CaptureDateReplayResult> replayDateRange(
    CaptureReplayDateRange range,
  ) async {
    if (!range.isValid) {
      return const CaptureDateReplayResult(
        matchingCaptures: 0,
        selectedCaptures: 0,
        processedCaptures: 0,
        retriedCaptures: 0,
        refreshedCaptures: 0,
        failedCaptures: 0,
        skippedCaptures: 0,
        deferredCaptures: 0,
        limited: false,
      );
    }

    final matchingCaptures = _readModel.countProcessingInputsInDateRange(
      startDate: range.startDate,
      endDate: range.endDate,
    );
    final inputs = _readModel.readProcessingInputsInDateRange(
      startDate: range.startDate,
      endDate: range.endDate,
      limit: _captureBatchLimit,
    );
    await _orchestrator.restoreAndDrainRuntimeQueue();

    var processed = 0;
    var retried = 0;
    var refreshed = 0;
    var failed = 0;
    var skipped = 0;
    var deferred = 0;

    for (final input in inputs) {
      try {
        if (await _orchestrator.hasPublishedCapture(input.record.id)) {
          final retry = await _orchestrator.retryCaptureAgentTasks(
            input.record.id,
            limit: _agentBatchLimit,
          );
          final materialized = await _orchestrator.materializePublishedCapture(
            input.record.id,
          );
          if (materialized == null) {
            deferred += 1;
            continue;
          }
          _saveResult(input, materialized);
          if (retry.retriedTaskCount > 0) {
            retried += 1;
          } else {
            refreshed += 1;
          }
          continue;
        }

        if (!_canProcess(input)) {
          skipped += 1;
          continue;
        }
        final processingInput = await _preprocessInput(input);
        final result = await _orchestrator.processCapture(
          processingInput.record.body,
          attachments: processingInput.attachments,
          captureId: processingInput.record.id,
        );
        _saveResult(processingInput, result);
        processed += 1;
      } catch (error) {
        if (_isCaptureAlreadyQueued(error)) {
          deferred += 1;
          continue;
        }
        _markFailed(input);
        failed += 1;
      }
    }

    return CaptureDateReplayResult(
      matchingCaptures: matchingCaptures,
      selectedCaptures: inputs.length,
      processedCaptures: processed,
      retriedCaptures: retried,
      refreshedCaptures: refreshed,
      failedCaptures: failed,
      skippedCaptures: skipped,
      deferredCaptures: deferred,
      limited: matchingCaptures > _captureBatchLimit,
    );
  }

  Future<_RefreshResult> _refreshCaptureReadModels(
    Iterable<String> captureIds,
  ) async {
    var refreshed = 0;
    var failed = 0;
    var skipped = 0;
    for (final captureId in captureIds) {
      final input = _readModel.readProcessingInput(captureId);
      if (input == null) {
        skipped += 1;
        continue;
      }
      try {
        final result = await _orchestrator.materializePublishedCapture(
          captureId,
        );
        if (result == null) {
          skipped += 1;
          continue;
        }
        _saveResult(input, result);
        refreshed += 1;
      } catch (_) {
        failed += 1;
      }
    }
    return _RefreshResult(
      refreshed: refreshed,
      failed: failed,
      skipped: skipped,
    );
  }

  Future<CaptureProcessingInput> _preprocessInput(
    CaptureProcessingInput input,
  ) async {
    if (!_hasPhotoAttachment(input.attachments)) {
      return input;
    }
    final attachments = await _mediaPreprocessor.preprocessPhotoAttachments(
      input.record,
      input.attachments,
    );
    _readModel.saveCapture(
      input.record,
      attachments: attachments,
      rawText: input.typedText,
    );
    return CaptureProcessingInput(
      record: input.record,
      typedText: input.typedText,
      attachments: attachments,
    );
  }

  void _saveResult(CaptureProcessingInput input, CapturePipelineResult result) {
    final resultRecord = result.record.copyWith(
      locationContext: input.record.locationContext,
      memoryGenerated: result.memoryGenerated,
    );
    _readModel.saveCapture(
      resultRecord,
      attachments: input.attachments,
      rawText: input.typedText,
    );
    if (result.todo.isSuggested) {
      _readModel.saveTodo(result.todo);
    }
  }

  void _markFailed(CaptureProcessingInput input) {
    _readModel.saveCapture(
      input.record.copyWith(status: captureStatusAgentFailed),
      attachments: input.attachments,
      rawText: input.typedText,
    );
  }

  bool _canProcess(CaptureProcessingInput input) {
    return input.attachments.every((attachment) => attachment.isReady);
  }

  bool _hasPhotoAttachment(List<CaptureAttachment> attachments) {
    return attachments.any(
      (attachment) =>
          attachment.kind == CaptureAssetKind.photo && attachment.isReady,
    );
  }

  bool _isCaptureAlreadyQueued(Object error) {
    return error is CapturePipelineException &&
        error.message == captureAlreadyQueuedMessage;
  }

  List<localdb.RuntimeTaskRecord> _retryableTaskRecords() {
    final tasks = _database.runtimeTasks.readAll();
    final tasksById = <String, localdb.RuntimeTaskRecord>{
      for (final task in tasks) task.id: task,
    };
    final selectedIds = <String>{};
    final selected = <localdb.RuntimeTaskRecord>[];
    var changed = true;
    while (changed) {
      changed = false;
      for (final task in tasks) {
        if (selectedIds.contains(task.id) ||
            (!_failedTaskCanRetry(task, selectedIds, tasksById) &&
                !_blockedTaskCanRetry(task, selectedIds, tasksById))) {
          continue;
        }
        selectedIds.add(task.id);
        selected.add(task);
        changed = true;
      }
    }
    return selected;
  }

  bool _failedTaskCanRetry(
    localdb.RuntimeTaskRecord task,
    Set<String> selectedIds,
    Map<String, localdb.RuntimeTaskRecord> tasksById,
  ) {
    if (task.status != 'failed' || task.missingDependencyIds.isNotEmpty) {
      return false;
    }
    return _dependenciesCanRetry(
      task.dependencyTaskIds,
      selectedIds,
      tasksById,
    );
  }

  bool _blockedTaskCanRetry(
    localdb.RuntimeTaskRecord task,
    Set<String> selectedIds,
    Map<String, localdb.RuntimeTaskRecord> tasksById,
  ) {
    if (task.status != 'blocked' ||
        task.missingDependencyIds.isNotEmpty ||
        task.dependencyTaskIds.isEmpty) {
      return false;
    }
    return _dependenciesCanRetry(
      task.dependencyTaskIds,
      selectedIds,
      tasksById,
    );
  }

  bool _dependenciesCanRetry(
    List<Object?> rawDependencyIds,
    Set<String> selectedIds,
    Map<String, localdb.RuntimeTaskRecord> tasksById,
  ) {
    final dependencyIds = rawDependencyIds.whereType<String>().toList(
      growable: false,
    );
    if (dependencyIds.length != rawDependencyIds.length) {
      return false;
    }
    return dependencyIds.every((dependencyId) {
      final dependency = tasksById[dependencyId];
      if (dependency == null) {
        return false;
      }
      return dependency.status == 'succeeded' ||
          selectedIds.contains(dependency.id);
    });
  }
}

final class _RefreshResult {
  const _RefreshResult({
    required this.refreshed,
    required this.failed,
    required this.skipped,
  });

  final int refreshed;
  final int failed;
  final int skipped;
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
