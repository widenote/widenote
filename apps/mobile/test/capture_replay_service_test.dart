import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';
import 'package:widenote_mobile/features/capture/application/capture_replay_service.dart';
import 'package:widenote_mobile/features/capture/application/local_capture_read_model.dart';
import 'package:widenote_mobile/features/capture/application/local_knowledge_sink.dart';
import 'package:widenote_mobile/features/capture/application/media_preprocessing_service.dart';
import 'package:widenote_mobile/features/capture/domain/capture_models.dart';

const _todoQuietJson =
    '{"kind":"quiet","title":"","confidence":"high","reason":"ordinary_record","scheduled_at_label":null}';
const _pkmJson =
    '{"title":"Replay source truth","summary":"Replay keeps the original capture id.","topics":["debugging"],"people":[],"projects":["WideNote"],"source_excerpt":"Replay this historical input.","confidence":"high","sensitivity":"low"}';
const _memoryJson =
    '{"text":"Replay keeps the original capture id.","memory_type":"task_context","confidence":"high","sensitivity":"low","durability":"durable"}';

void main() {
  test(
    'snapshot counts retryable failed and dependency-blocked Agent tasks',
    () {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      final now = DateTime.utc(2026, 7, 3, 10);
      _seedTask(database, id: 'task-failed', status: 'failed', now: now);
      _seedTask(database, id: 'task-succeeded', status: 'succeeded', now: now);
      _seedTask(
        database,
        id: 'task-blocked-failed-dep',
        status: 'blocked',
        dependencyTaskIds: const <Object?>['task-failed'],
        now: now,
      );
      _seedTask(
        database,
        id: 'task-blocked-succeeded-dep',
        status: 'blocked',
        dependencyTaskIds: const <Object?>['task-succeeded'],
        now: now,
      );
      _seedTask(database, id: 'task-denied', status: 'denied', now: now);
      _seedTask(database, id: 'task-canceled', status: 'canceled', now: now);
      _seedTask(
        database,
        id: 'task-failed-missing-dep',
        status: 'failed',
        missingDependencyIds: const <Object?>['pack.default::missing'],
        now: now,
      );
      _seedTask(
        database,
        id: 'task-missing-dep',
        status: 'blocked',
        missingDependencyIds: const <Object?>['pack.default::missing'],
        now: now,
      );

      final service = _service(database);

      final snapshot = service.snapshot(
        CaptureReplayDateRange(startDate: now, endDate: now),
      );

      expect(snapshot.retryableAgentTasks, 3);
    },
  );

  test('Agent retry skips failed tasks with missing dependencies', () async {
    final database = localdb.WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 3, 10);
    _seedTask(
      database,
      id: 'task-failed-missing-dep',
      status: 'failed',
      missingDependencyIds: const <Object?>['pack.default::missing'],
      now: now,
    );
    final service = _service(database);

    final result = await service.retryFailedAgents();

    expect(result.retryableAgentTasks, 0);
    expect(result.selectedAgentTasks, 0);
    expect(result.retriedAgentTasks, 0);
  });

  test(
    'date replay processes unpublished captures without duplicating source',
    () async {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      final now = DateTime.utc(2026, 7, 3, 10);
      _seedCapture(database, id: 'capture-replay', now: now);
      final service = _service(
        database,
        model: _SequenceMetadataModel(
          responses: <String>[_memoryJson, _todoQuietJson, _pkmJson],
        ),
      );

      final result = await service.replayDateRange(
        CaptureReplayDateRange(startDate: now, endDate: now),
      );

      expect(result.processedCaptures, 1);
      expect(result.failedCaptures, 0);
      expect(database.captures.readAll(), hasLength(1));
      expect(
        database.captures.readById('capture-replay')!.status,
        'Processed locally',
      );
      expect(
        database.eventLog.readCaptureCreatedBySubject('capture-replay'),
        isNotNull,
      );
    },
  );

  test(
    'date replay retries published captures with failed Agent tasks',
    () async {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      final now = DateTime.utc(2026, 7, 3, 10);
      _seedCapture(database, id: 'capture-failed-replay', now: now);

      final failing = _service(
        database,
        model: const _FailingModel(),
        seed: 'replay-fail',
      );
      final failedResult = await failing.replayDateRange(
        CaptureReplayDateRange(startDate: now, endDate: now),
      );
      expect(failedResult.failedCaptures, 1);
      expect(
        database.captures.readById('capture-failed-replay')!.status,
        captureStatusAgentFailed,
      );
      expect(
        database.eventLog.readCaptureCreatedBySubject('capture-failed-replay'),
        isNotNull,
      );
      for (final task in database.runtimeTasks.readAll()) {
        database.runtimeTasks.save(
          task.copyWith(
            status: 'failed',
            attempts: task.maxAttempts,
            clearScheduledAt: true,
            updatedAt: now,
          ),
        );
      }
      expect(database.runtimeTasks.readAll(status: 'failed'), isNotEmpty);

      final repaired = _service(
        database,
        model: _SequenceMetadataModel(
          responses: <String>[_memoryJson, _todoQuietJson, _pkmJson],
        ),
        seed: 'replay-repair',
      );
      final repairedResult = await repaired.replayDateRange(
        CaptureReplayDateRange(startDate: now, endDate: now),
      );

      expect(repairedResult.retriedCaptures, 1);
      expect(repairedResult.failedCaptures, 0);
      expect(
        database.captures.readById('capture-failed-replay')!.status,
        captureStatusProcessed,
      );
    },
  );
}

CaptureReplayService _service(
  localdb.WideNoteLocalDatabase database, {
  runtime.ModelClient? model,
  String seed = 'replay',
}) {
  final orchestrator = CaptureOrchestrator.local(
    clock: TickingWnClock(DateTime.utc(2026, 7, 3, 10)),
    idGenerator: SequenceWnIdGenerator(seed: seed),
    model: model ?? runtime.FakeModel(),
    eventStore: localdb.LocalDbEventStore(database),
    traceSink: localdb.LocalDbTraceSink(database),
    runtimeStore: localdb.LocalDbRuntimeStore(database),
    memoryRepository: localdb.LocalDbMemoryRepository(database),
    knowledgeSink: LocalDbCaptureKnowledgeSink(database),
  );
  return LocalCaptureReplayService(
    database: database,
    readModel: LocalCaptureReadModelStore(database),
    orchestrator: orchestrator,
    mediaPreprocessor: MediaPreprocessingService(
      database: database,
      modelClient: runtime.FakeModel(),
    ),
  );
}

void _seedCapture(
  localdb.WideNoteLocalDatabase database, {
  required String id,
  required DateTime now,
}) {
  database.captures.insert(
    localdb.CaptureRecord(
      id: id,
      sourceType: 'manual',
      status: captureStatusSavedProcessing,
      payload: const <String, Object?>{
        'text': 'Replay this historical input.',
        'raw_text': 'Replay this historical input.',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _seedTask(
  localdb.WideNoteLocalDatabase database, {
  required String id,
  required String status,
  required DateTime now,
  List<Object?> dependencyTaskIds = const <Object?>[],
  List<Object?> missingDependencyIds = const <Object?>[],
}) {
  database.eventLog.append(
    localdb.EventLogEntry(
      id: 'event-$id',
      type: 'wn.capture.created',
      actor: 'user',
      subjectKind: 'capture',
      subjectId: 'capture-$id',
      createdAt: now,
    ),
  );
  database.runtimeTasks.insert(
    localdb.RuntimeTaskRecord(
      id: id,
      packId: 'pack.default',
      packVersion: '1.0.0',
      agentId: 'agent.capture_loop',
      handlerId: 'agent.capture_loop',
      subscriptionId: 'sub.capture_created',
      triggerEventId: 'event-$id',
      status: status,
      dependencyTaskIds: dependencyTaskIds,
      missingDependencyIds: missingDependencyIds,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

final class _SequenceMetadataModel implements runtime.ModelClient {
  _SequenceMetadataModel({required List<String> responses})
    : _responses = responses;

  final List<String> _responses;
  var _index = 0;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    if (_index >= _responses.length) {
      throw StateError('No fake model response configured.');
    }
    final response = _responses[_index];
    _index += 1;
    return runtime.ModelResponse(
      text: response,
      raw: const <String, Object?>{
        'memory_type': 'task_context',
        'confidence': 'high',
        'sensitivity': 'low',
        'durability': 'durable',
      },
    );
  }
}

final class _FailingModel implements runtime.ModelClient {
  const _FailingModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) {
    throw StateError('model unavailable');
  }
}
