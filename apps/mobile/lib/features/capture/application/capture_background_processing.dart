import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../../app/local_database.dart';
import 'capture_orchestrator.dart';
import 'capture_orchestrator_provider.dart';
import 'local_capture_read_model.dart';
import 'media_preprocessing_service.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';

const captureBackgroundDrainTaskName = 'widenote.capture.backgroundDrain';
const captureBackgroundDrainUniqueName = 'widenote.capture.backgroundDrain';

final captureProcessingDrainServiceProvider =
    Provider<CaptureProcessingDrainService>((ref) {
      return CaptureProcessingDrainService(
        readModel: LocalCaptureReadModelStore(ref.watch(localDatabaseProvider)),
        orchestrator: ref.watch(captureOrchestratorProvider),
        mediaPreprocessor: ref.watch(mediaPreprocessingServiceProvider),
      );
    });

final captureBackgroundSchedulerProvider = Provider<CaptureBackgroundScheduler>(
  (ref) {
    if (_supportsWorkmanager) {
      return const WorkmanagerCaptureBackgroundScheduler();
    }
    return const NoopCaptureBackgroundScheduler();
  },
);

abstract interface class CaptureBackgroundScheduler {
  Future<void> scheduleDrain();
}

final class NoopCaptureBackgroundScheduler
    implements CaptureBackgroundScheduler {
  const NoopCaptureBackgroundScheduler();

  @override
  Future<void> scheduleDrain() async {}
}

final class WorkmanagerCaptureBackgroundScheduler
    implements CaptureBackgroundScheduler {
  const WorkmanagerCaptureBackgroundScheduler();

  @override
  Future<void> scheduleDrain() {
    return Workmanager().registerOneOffTask(
      captureBackgroundDrainUniqueName,
      captureBackgroundDrainTaskName,
      initialDelay: const Duration(seconds: 10),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }
}

final class CaptureProcessingDrainService {
  const CaptureProcessingDrainService({
    required LocalCaptureReadModelStore readModel,
    required CaptureOrchestrator orchestrator,
    required MediaPreprocessingService mediaPreprocessor,
  }) : _readModel = readModel,
       _orchestrator = orchestrator,
       _mediaPreprocessor = mediaPreprocessor;

  final LocalCaptureReadModelStore _readModel;
  final CaptureOrchestrator _orchestrator;
  final MediaPreprocessingService _mediaPreprocessor;

  Future<CaptureProcessingDrainResult> drain({
    Duration timeBudget = const Duration(seconds: 25),
  }) async {
    final stopwatch = Stopwatch()..start();
    final runtimeTasks = await _orchestrator.restoreAndDrainRuntimeQueue();
    var processed = 0;
    var failed = 0;
    var skipped = 0;
    var deferred = 0;

    for (final input in _readModel.readPendingProcessingInputs()) {
      if (stopwatch.elapsed >= timeBudget) {
        deferred += 1;
        break;
      }
      if (!_canProcessInBackground(input)) {
        skipped += 1;
        continue;
      }
      var processingInput = input;
      try {
        final materialized = await _orchestrator.materializePublishedCapture(
          processingInput.record.id,
        );
        if (materialized != null) {
          _saveResult(processingInput, materialized);
          processed += 1;
          continue;
        }
        if (await _orchestrator.hasPublishedCapture(
          processingInput.record.id,
        )) {
          deferred += 1;
          continue;
        }
        processingInput = await _preprocessInput(processingInput);
        await _processInput(processingInput);
        processed += 1;
      } catch (error) {
        if (_isCaptureAlreadyQueued(error)) {
          deferred += 1;
          continue;
        }
        _markFailed(processingInput);
        failed += 1;
      }
    }

    final remaining = _readModel.readPendingProcessingInputs().length;
    return CaptureProcessingDrainResult(
      processedCaptures: processed,
      failedCaptures: failed,
      skippedCaptures: skipped,
      deferredCaptures: deferred,
      drainedRuntimeTasks: runtimeTasks,
      remainingPendingCaptures: remaining,
    );
  }

  Future<void> _processInput(CaptureProcessingInput input) async {
    final result = await _orchestrator.processCapture(
      input.record.body,
      attachments: input.attachments,
      captureId: input.record.id,
    );
    _saveResult(input, result);
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
}

bool _hasPhotoAttachment(List<CaptureAttachment> attachments) {
  return attachments.any(
    (attachment) =>
        attachment.kind == CaptureAssetKind.photo && attachment.isReady,
  );
}

final class CaptureProcessingDrainResult {
  const CaptureProcessingDrainResult({
    required this.processedCaptures,
    required this.failedCaptures,
    required this.skippedCaptures,
    required this.deferredCaptures,
    required this.drainedRuntimeTasks,
    required this.remainingPendingCaptures,
  });

  final int processedCaptures;
  final int failedCaptures;
  final int skippedCaptures;
  final int deferredCaptures;
  final int drainedRuntimeTasks;
  final int remainingPendingCaptures;

  bool get shouldReschedule =>
      deferredCaptures > 0 || remainingPendingCaptures > skippedCaptures;
}

Future<void> initializeCaptureBackgroundProcessing() async {
  if (!_supportsWorkmanager) {
    return;
  }
  await Workmanager().initialize(captureBackgroundCallbackDispatcher);
}

@pragma('vm:entry-point')
void captureBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    DartPluginRegistrant.ensureInitialized();
    if (taskName != captureBackgroundDrainTaskName) {
      return true;
    }
    final result = await runCaptureBackgroundDrain();
    return !result.shouldReschedule;
  });
}

@pragma('vm:entry-point')
Future<CaptureProcessingDrainResult> runCaptureBackgroundDrain() async {
  final bootstrap = await WideNoteMobileBootstrap.production();
  final container = ProviderContainer(overrides: bootstrap.providerOverrides);
  try {
    final service = container.read(captureProcessingDrainServiceProvider);
    return await service.drain();
  } finally {
    container.dispose();
    bootstrap.close();
  }
}

bool _canProcessInBackground(CaptureProcessingInput input) {
  for (final attachment in input.attachments) {
    if (!attachment.isReady) {
      return false;
    }
    if (attachment.kind == CaptureAssetKind.voice &&
        _voiceTranscript(attachment).isEmpty) {
      return false;
    }
  }
  return true;
}

String _voiceTranscript(CaptureAttachment attachment) {
  final direct = attachment.rawMetadata['transcript'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }
  final adapter = attachment.rawMetadata['adapter_metadata'];
  if (adapter is Map) {
    final nested = adapter['transcript'];
    if (nested is String && nested.trim().isNotEmpty) {
      return nested.trim();
    }
  }
  return '';
}

bool _isCaptureAlreadyQueued(Object error) {
  return error is CapturePipelineException &&
      error.message == captureAlreadyQueuedMessage;
}

bool get _supportsWorkmanager {
  return Platform.isAndroid || Platform.isIOS;
}
