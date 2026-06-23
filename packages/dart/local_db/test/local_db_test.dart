import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

void main() {
  group('WideNoteLocalDatabase', () {
    late WideNoteLocalDatabase database;

    setUp(() {
      database = WideNoteLocalDatabase.inMemory();
    });

    tearDown(() {
      database.close();
    });

    test('bootstraps an in-memory database with schema version', () {
      expect(database.schemaVersion, LocalDbSchema.currentVersion);
    });

    test('opens a persistent database path and reuses stored rows', () {
      final directory = Directory.systemTemp.createTempSync(
        'widenote_db_test_',
      );
      addTearDown(() {
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      });
      final databasePath =
          '${directory.path}${Platform.pathSeparator}test.sqlite';
      final createdAt = DateTime.utc(2026, 6, 23, 7);

      final first = WideNoteLocalDatabase.openPath(databasePath);
      first.captures.insert(
        CaptureRecord(
          id: 'capture-path-1',
          sourceType: 'manual',
          payload: const <String, Object?>{'text': 'Persistent capture'},
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      first.close();

      final second = WideNoteLocalDatabase.openPath(databasePath);
      addTearDown(second.close);

      expect(second.schemaVersion, LocalDbSchema.currentVersion);
      expect(
        second.captures.readById('capture-path-1')!.payload['text'],
        'Persistent capture',
      );
    });

    test('inserts and reads captures', () {
      final createdAt = DateTime.utc(2026, 6, 23, 8);
      database.captures.insert(
        CaptureRecord(
          id: 'capture-1',
          sourceType: 'manual',
          sourceId: 'composer',
          payload: const <String, Object?>{
            'text': 'Ship the local DB MVP.',
            'tags': <String>['local', 'sqlite'],
          },
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      final capture = database.captures.readById('capture-1');

      expect(capture, isNotNull);
      expect(capture!.schemaVersion, 1);
      expect(capture.sourceType, 'manual');
      expect(capture.sourceId, 'composer');
      expect(capture.status, 'created');
      expect(capture.payload['text'], 'Ship the local DB MVP.');
      expect(database.captures.readAll(status: 'created'), hasLength(1));
    });

    test('appends and reads event log entries', () {
      final firstCreatedAt = DateTime.utc(2026, 6, 23, 9);
      final secondCreatedAt = DateTime.utc(2026, 6, 23, 9, 1);
      database.eventLog
        ..append(
          EventLogEntry(
            id: 'event-1',
            type: 'wn.capture.created',
            actor: 'user',
            sourceCaptureId: 'capture-1',
            privacy: 'encrypted_sync',
            subjectRef: const <String, Object?>{
              'kind': 'capture',
              'id': 'capture-1',
              'uri': 'wn://capture/capture-1',
            },
            deviceId: 'device-local',
            payload: const <String, Object?>{'text': 'first'},
            createdAt: firstCreatedAt,
          ),
        )
        ..append(
          EventLogEntry(
            id: 'event-2',
            type: 'wn.memory.proposed',
            actor: 'agent',
            sourceEventId: 'event-1',
            packId: 'pack.default',
            agentId: 'agent.capture',
            causationId: 'event-1',
            correlationId: 'event-1',
            privacy: 'local_only',
            subjectKind: 'memory_candidate',
            subjectId: 'candidate-1',
            payload: const <String, Object?>{'state': 'proposed'},
            createdAt: secondCreatedAt,
          ),
        );

      final events = database.eventLog.readAll();
      final memoryEvents = database.eventLog.readByType('wn.memory.proposed');

      expect(events.map((event) => event.id), ['event-1', 'event-2']);
      expect(events.first.privacy, 'encrypted_sync');
      expect(events.first.subjectKind, 'capture');
      expect(events.first.subjectId, 'capture-1');
      expect(events.first.subjectRefKind, 'capture');
      expect(events.first.subjectRefId, 'capture-1');
      expect(events.first.subjectRef['uri'], 'wn://capture/capture-1');
      expect(memoryEvents.single.sourceEventId, 'event-1');
      expect(memoryEvents.single.privacy, 'local_only');
      expect(memoryEvents.single.subjectRef['kind'], 'memory_candidate');
      expect(memoryEvents.single.payload['state'], 'proposed');
      expect(database.eventLog.readById('event-1')!.deviceId, 'device-local');
    });

    test('stores memory items and candidates', () {
      final createdAt = DateTime.utc(2026, 6, 23, 10);
      database.memoryCandidates.insert(
        MemoryCandidateRecord(
          id: 'candidate-1',
          key: 'preference.editor',
          sourceCaptureId: 'capture-1',
          sourceEventId: 'event-1',
          status: 'needs_review',
          body: 'The user prefers compact editor layouts.',
          sourceRefs: const <Object?>[
            <String, Object?>{
              'kind': 'event',
              'id': 'event-1',
              'evidence_text': 'compact editor layouts',
            },
          ],
          memoryType: 'preference',
          confidence: 'medium',
          sensitivity: 'low',
          payload: const <String, Object?>{
            'policy_reasons': <String>['requires_review'],
          },
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      database.memoryItems.insert(
        MemoryItemRecord(
          id: 'memory-1',
          key: 'preference.editor',
          sourceCaptureId: 'capture-1',
          sourceEventId: 'event-2',
          body: 'The user prefers compact editor layouts.',
          sourceRefs: const <Object?>[
            <String, Object?>{
              'kind': 'event',
              'id': 'event-2',
              'event_id': 'event-2',
            },
          ],
          memoryType: 'preference',
          confidence: 'high',
          sensitivity: 'low',
          revision: 2,
          payload: const <String, Object?>{
            'metadata': <String, Object?>{'accepted_by': 'policy'},
          },
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      final candidate = database.memoryCandidates.readById('candidate-1');
      final item = database.memoryItems.readById('memory-1');

      expect(candidate, isNotNull);
      expect(candidate!.status, 'needs_review');
      expect(candidate.sourceEventId, 'event-1');
      expect(candidate.body, 'The user prefers compact editor layouts.');
      expect(candidate.memoryType, 'preference');
      expect(candidate.confidence, 'medium');
      expect(candidate.sensitivity, 'low');
      expect((candidate.sourceRefs.single as Map)['kind'], 'event');
      expect(item, isNotNull);
      expect(item!.status, 'active');
      expect(item.key, 'preference.editor');
      expect(item.body, 'The user prefers compact editor layouts.');
      expect(item.memoryType, 'preference');
      expect(item.confidence, 'high');
      expect(item.sensitivity, 'low');
      expect(item.revision, 2);
      expect(item.tombstone, isFalse);
      expect((item.sourceRefs.single as Map)['event_id'], 'event-2');
      expect(database.memoryItems.readAll(status: 'active'), hasLength(1));
    });

    test('updates todo status', () {
      final createdAt = DateTime.utc(2026, 6, 23, 11);
      final completedAt = DateTime.utc(2026, 6, 23, 12);
      database.todos.insert(
        TodoRecord(
          id: 'todo-1',
          sourceCaptureId: 'capture-1',
          sourceEventId: 'event-1',
          payload: const <String, Object?>{'title': 'Write DAO tests'},
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      final updated = database.todos.updateStatus(
        'todo-1',
        'completed',
        updatedAt: completedAt,
      );

      expect(updated.status, 'completed');
      expect(updated.updatedAt, completedAt);
      expect(database.todos.readById('todo-1')!.status, 'completed');
      expect(database.todos.readAll(status: 'completed'), hasLength(1));
    });

    test('records and reads trace events', () {
      final firstCreatedAt = DateTime.utc(2026, 6, 23, 13);
      final secondCreatedAt = DateTime.utc(2026, 6, 23, 13, 1);
      database.traceEvents
        ..insert(
          TraceEventRecord(
            id: 'trace-1',
            name: 'run_started',
            level: 'info',
            sourceEventId: 'event-1',
            sourceRunId: 'run-1',
            sourceTaskId: 'task-1',
            payload: const <String, Object?>{'pack_id': 'pack.default'},
            createdAt: firstCreatedAt,
          ),
        )
        ..insert(
          TraceEventRecord(
            id: 'trace-2',
            name: 'run_completed',
            level: 'info',
            sourceEventId: 'event-2',
            sourceRunId: 'run-1',
            sourceTaskId: 'task-1',
            payload: const <String, Object?>{'output_count': 4},
            createdAt: secondCreatedAt,
          ),
        );

      final traces = database.traceEvents.readByRun('run-1');

      expect(traces.map((trace) => trace.name), [
        'run_started',
        'run_completed',
      ]);
      expect(traces.first.traceType, 'run_started');
      expect(traces.first.runId, 'run-1');
      expect(traces.first.severity, 'info');
      expect(traces.first.eventId, 'event-1');
      expect(traces.first.taskId, 'task-1');
      expect(traces.first.payload['pack_id'], 'pack.default');
      expect(database.traceEvents.readAll(), hasLength(2));
    });

    test('paginates readAll results', () {
      final createdAt = DateTime.utc(2026, 6, 23, 14);
      for (var index = 0; index < 3; index += 1) {
        final timestamp = createdAt.add(Duration(minutes: index));
        database.captures.insert(
          CaptureRecord(
            id: 'capture-$index',
            sourceType: 'manual',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.eventLog.append(
          EventLogEntry(
            id: 'event-$index',
            type: 'wn.capture.created',
            actor: 'user',
            subjectKind: 'capture',
            subjectId: 'capture-$index',
            deviceId: 'device-local',
            createdAt: timestamp,
          ),
        );
        database.memoryCandidates.insert(
          MemoryCandidateRecord(
            id: 'candidate-$index',
            key: 'memory.candidate.$index',
            body: 'Candidate $index',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.memoryItems.insert(
          MemoryItemRecord(
            id: 'memory-$index',
            key: 'memory.item.$index',
            body: 'Memory $index',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.todos.insert(
          TodoRecord(
            id: 'todo-$index',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.traceEvents.insert(
          TraceEventRecord(
            id: 'trace-$index',
            name: 'event_received',
            level: 'debug',
            sourceRunId: 'run-$index',
            createdAt: timestamp,
          ),
        );
      }

      expect(
        database.captures.readAll(limit: 1, offset: 1).single.id,
        'capture-1',
      );
      expect(
        database.eventLog.readAll(limit: 1, offset: 1).single.id,
        'event-1',
      );
      expect(
        database.memoryCandidates.readAll(limit: 1, offset: 1).single.id,
        'candidate-1',
      );
      expect(
        database.memoryItems.readAll(limit: 1, offset: 1).single.id,
        'memory-1',
      );
      expect(database.todos.readAll(limit: 1, offset: 1).single.id, 'todo-1');
      expect(
        database.traceEvents.readAll(limit: 1, offset: 1).single.id,
        'trace-1',
      );
      expect(
        () => database.eventLog.readAll(limit: -1),
        throwsA(isA<RangeError>()),
      );
    });

    test('migrates v1 contract columns to schema version 3', () {
      final rawDatabase = sqlite3.openInMemory();
      LocalDbMigrator.bootstrap(rawDatabase, targetVersion: 1);
      rawDatabase
        ..execute('''
INSERT INTO event_log (
  id,
  type,
  schema_version,
  actor,
  status,
  subject_kind,
  subject_id,
  payload_json,
  created_at
) VALUES (
  'event-old',
  'wn.capture.created',
  1,
  'user',
  'recorded',
  'capture',
  'capture-old',
  '{}',
  '2026-06-23T15:00:00.000Z'
);
''')
        ..execute('''
INSERT INTO trace_events (
  id,
  name,
  level,
  schema_version,
  source_run_id,
  status,
  payload_json,
  created_at
) VALUES (
  'trace-old',
  'run_started',
  'warn',
  1,
  'run-old',
  'recorded',
  '{}',
  '2026-06-23T15:01:00.000Z'
);
''');

      LocalDbMigrator.bootstrap(rawDatabase);
      final migrated = WideNoteLocalDatabase.open(
        rawDatabase,
        bootstrap: false,
      );
      addTearDown(migrated.close);

      expect(migrated.schemaVersion, 3);
      final event = migrated.eventLog.readById('event-old')!;
      expect(event.privacy, 'local_only');
      expect(event.subjectRefKind, 'capture');
      expect(event.subjectRefId, 'capture-old');

      final trace = migrated.traceEvents.readById('trace-old')!;
      expect(trace.traceType, 'run_started');
      expect(trace.runId, 'run-old');
      expect(trace.severity, 'warn');
    });

    test('backs runtime event store and trace sink', () async {
      final eventStore = LocalDbEventStore(database);
      final traceSink = LocalDbTraceSink(database);
      final model = runtime.FakeModel(responses: <String>['stored summary']);
      final permissions = runtime.InMemoryPermissionBroker()
        ..grantAll('pack.default', <String>{
          runtime.ModelPermissions.complete,
          'memory.propose',
        });
      final kernel =
          runtime.RuntimeKernel(
            eventStore: eventStore,
            traceSink: traceSink,
            permissionBroker: permissions,
            toolRegistry: runtime.InMemoryToolRegistry(),
            idGenerator: SequenceWnIdGenerator(seed: 'db'),
            clock: TickingWnClock(DateTime.utc(2026, 6, 23, 16)),
            model: model,
            deviceId: 'device-db',
          )..registerPack(
            const runtime.AgentPack(
              id: 'pack.default',
              name: 'Persistent default pack',
              version: '0.1.0',
              requiredPermissions: <String>{
                runtime.ModelPermissions.complete,
                'memory.propose',
              },
              subscriptions: <runtime.Subscription>[
                runtime.Subscription(
                  id: 'sub.capture_created',
                  agentId: 'agent.capture_loop',
                  eventTypes: <String>{runtime.WnEventTypes.captureCreated},
                ),
              ],
              agents: <String, runtime.AgentHandler>{
                'agent.capture_loop': _PersistentMemoryHandler(),
              },
            ),
          );

      await kernel.publish(
        const runtime.WnEventDraft(
          type: runtime.WnEventTypes.captureCreated,
          actor: runtime.WnActor.user,
          subjectRef: runtime.SubjectRef(kind: 'capture', id: 'capture-db'),
          payload: <String, Object?>{'text': 'Persist this runtime chain.'},
        ),
      );

      final persistedEvents = await eventStore.readAll();
      final persistedMemory = await eventStore.readByType(
        runtime.WnEventTypes.memoryProposed,
      );
      final runId = kernel.runs.single.id;
      final persistedRunTraces = await traceSink.readByRun(runId);

      expect(persistedEvents.map((event) => event.type), [
        runtime.WnEventTypes.captureCreated,
        runtime.WnEventTypes.memoryProposed,
      ]);
      expect(persistedEvents.first.deviceId, 'device-db');
      expect(persistedEvents.first.subjectRef!.id, 'capture-db');
      expect(persistedMemory.single.packId, 'pack.default');
      expect(persistedMemory.single.agentId, 'agent.capture_loop');
      expect(persistedMemory.single.payload['text'], 'stored summary');
      expect(
        persistedRunTraces.map((trace) => trace.name),
        containsAll(<String>[
          'runtime.run.started',
          'runtime.handler.output',
          'runtime.run.completed',
        ]),
      );
      expect(
        persistedRunTraces.map((trace) => trace.packId),
        everyElement('pack.default'),
      );
      expect(
        persistedRunTraces.map((trace) => trace.agentId),
        everyElement('agent.capture_loop'),
      );
      expect(
        database.traceEvents
            .readByRun(runId)
            .singleWhere((trace) => trace.name == 'runtime.run.completed')
            .traceType,
        'run_completed',
      );
    });

    test(
      'runtime event store rejects duplicate events without overwrite',
      () async {
        final eventStore = LocalDbEventStore(database);
        final event = runtime.WnEvent(
          id: 'event-duplicate',
          type: runtime.WnEventTypes.captureCreated,
          schemaVersion: 1,
          actor: runtime.WnActor.user,
          subjectRef: const runtime.SubjectRef(
            kind: 'capture',
            id: 'capture-1',
          ),
          payload: const <String, Object?>{'text': 'first'},
          privacy: runtime.WnPrivacy.localOnly,
          deviceId: 'device-db',
          createdAt: DateTime.utc(2026, 6, 23, 17),
        );

        await eventStore.append(event);

        expect(() => eventStore.append(event), throwsA(isA<SqliteException>()));
        expect((await eventStore.readAll()).single.payload['text'], 'first');
      },
    );

    test('runtime event store appendAll rolls back partial batches', () async {
      final eventStore = LocalDbEventStore(database);
      final createdAt = DateTime.utc(2026, 6, 23, 18);
      await eventStore.append(
        runtime.WnEvent(
          id: 'event-existing',
          type: runtime.WnEventTypes.captureCreated,
          schemaVersion: 1,
          actor: runtime.WnActor.user,
          payload: const <String, Object?>{'text': 'existing'},
          privacy: runtime.WnPrivacy.localOnly,
          deviceId: 'device-db',
          createdAt: createdAt,
        ),
      );

      final newEvent = runtime.WnEvent(
        id: 'event-new',
        type: runtime.WnEventTypes.cardCreated,
        schemaVersion: 1,
        actor: runtime.WnActor.agent,
        packId: 'pack.default',
        agentId: 'agent.capture_loop',
        payload: const <String, Object?>{'title': 'new'},
        privacy: runtime.WnPrivacy.localOnly,
        deviceId: 'device-db',
        createdAt: createdAt.add(const Duration(minutes: 1)),
      );
      final duplicate = runtime.WnEvent(
        id: 'event-existing',
        type: runtime.WnEventTypes.insightCreated,
        schemaVersion: 1,
        actor: runtime.WnActor.agent,
        payload: const <String, Object?>{'text': 'duplicate'},
        privacy: runtime.WnPrivacy.localOnly,
        deviceId: 'device-db',
        createdAt: createdAt.add(const Duration(minutes: 2)),
      );

      expect(
        () => eventStore.appendAll(<runtime.WnEvent>[newEvent, duplicate]),
        throwsA(isA<SqliteException>()),
      );
      expect(await eventStore.readById('event-new'), isNull);
      expect((await eventStore.readAll()).single.id, 'event-existing');
    });
  });
}

final class _PersistentMemoryHandler implements runtime.AgentHandler {
  const _PersistentMemoryHandler();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    final response = await context.model.complete(
      const runtime.ModelRequest(prompt: 'Summarize persistent capture.'),
    );
    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.memoryProposed,
          subjectRef: event.subjectRef,
          payload: <String, Object?>{
            'text': response.text,
            'source_event_id': event.id,
          },
        ),
      ],
    );
  }
}
