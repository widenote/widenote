import 'dart:convert';

import 'package:test/test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';

void main() {
  group('LocalDbCoreToolCatalog', () {
    late WideNoteLocalDatabase database;
    late runtime.InMemoryToolRegistry registry;

    setUp(() {
      database = WideNoteLocalDatabase.inMemory();
      registry = runtime.InMemoryToolRegistry();
    });

    tearDown(() {
      database.close();
    });

    test('registers local-only tools with runtime permission metadata', () {
      LocalDbCoreToolCatalog(database).registerInto(registry);

      final context = registry.lookup(
        LocalDbCoreToolCatalog.contextPacketBuildTool,
      )!;
      final memoryRead = registry.lookup(
        LocalDbCoreToolCatalog.memoryReadTool,
      )!;
      final memoryPropose = registry.lookup(
        LocalDbCoreToolCatalog.memoryProposeTool,
      )!;
      final todoSuggest = registry.lookup(
        LocalDbCoreToolCatalog.todoSuggestTool,
      )!;
      final traceRead = registry.lookup(LocalDbCoreToolCatalog.traceReadTool)!;

      expect(context.requiredPermissions, <String>{'context_packet.build'});
      expect(memoryRead.requiredPermissions, <String>{'memory.read'});
      expect(memoryPropose.requiredPermissions, <String>{'memory.propose'});
      expect(todoSuggest.requiredPermissions, <String>{'todo.suggest'});
      expect(traceRead.requiredPermissions, <String>{'trace.read'});
      expect(
        <runtime.ToolDefinition>[
          context,
          memoryRead,
          memoryPropose,
          todoSuggest,
          traceRead,
        ].every((definition) => definition.external == false),
        isTrue,
      );
      expect(memoryRead.access, runtime.ToolAccess.read);
      expect(traceRead.access, runtime.ToolAccess.read);
      expect(memoryPropose.access, runtime.ToolAccess.write);
      expect(todoSuggest.access, runtime.ToolAccess.write);
      expect(memoryPropose.requiresApproval, isTrue);
      expect(todoSuggest.requiresApproval, isTrue);
    });

    test(
      'builds context packet summaries and rejects unsafe input keys',
      () async {
        final now = DateTime.utc(2026, 6, 27, 9);
        _seedCapture(database, now);
        _seedMemory(
          database,
          id: 'memory-context',
          key: 'preference.editor',
          body: 'The user prefers compact local-first notes.',
          sourceCaptureId: 'capture-1',
          sourceEventId: 'event-1',
          updatedAt: now,
        );
        LocalDbCoreToolCatalog(database).registerInto(registry);

        final output = await _invoke(
          registry,
          LocalDbCoreToolCatalog.contextPacketBuildTool,
          <String, Object?>{
            'surface': 'chat',
            'subject_ref': <String, Object?>{
              'kind': 'capture',
              'id': 'capture-1',
            },
            'source_refs': const <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
            ],
            'cache_key': 'tool/context',
            'max_items': 3,
            'permissions': const <Object?>['memory.read'],
            'privacy_profile': 'default',
          },
        );

        expect(output['success'], isTrue);
        expect(output.containsKey('packet'), isFalse);
        expect(
          output['cache_key'],
          isA<String>().having((value) => value, 'cache key', isNotEmpty),
        );
        final summary = output['packet_summary']! as Map;
        expect(summary['surface'], 'chat');
        expect(summary['source_backed_section_count'], greaterThan(0));
        expect(summary['section_count'], greaterThan(0));
        final sourceRefs = output['source_refs']! as List;
        expect(
          sourceRefs.map((ref) => (ref as Map)['kind']),
          containsAll(<String>['capture', 'memory']),
        );

        final cacheCount = database.contextPacketCaches.readAll().length;
        final rejected = await _invoke(
          registry,
          LocalDbCoreToolCatalog.contextPacketBuildTool,
          const <String, Object?>{
            'surface': 'chat',
            'sql': 'select * from memory_items',
          },
        );
        expect(rejected['success'], isFalse);
        expect((rejected['error']! as Map)['code'], 'unsupported_input');
        expect(database.contextPacketCaches.readAll(), hasLength(cacheCount));
      },
    );

    test(
      'reads accepted active memory with refs, filters, and limits',
      () async {
        final now = DateTime.utc(2026, 6, 27, 10);
        _seedMemory(
          database,
          id: 'memory-older',
          key: 'preference.layout',
          body: 'The user likes dense layouts.',
          sourceCaptureId: 'capture-older',
          sourceEventId: 'event-older',
          memoryType: 'preference',
          sensitivity: 'low',
          updatedAt: now,
        );
        _seedMemory(
          database,
          id: 'memory-newer',
          key: 'project.local',
          body: 'WideNote local DB work is active.',
          sourceCaptureId: 'capture-newer',
          sourceEventId: 'event-newer',
          memoryType: 'project',
          sensitivity: 'medium',
          updatedAt: now.add(const Duration(minutes: 1)),
        );
        _seedMemory(
          database,
          id: 'memory-tombstone',
          key: 'deleted.memory',
          body: 'This should not be returned.',
          sourceCaptureId: 'capture-old',
          sourceEventId: 'event-old',
          tombstone: true,
          updatedAt: now.add(const Duration(minutes: 2)),
        );
        _seedMemory(
          database,
          id: 'memory-deleted',
          key: 'deleted.status',
          body: 'This should not be returned either.',
          sourceCaptureId: 'capture-old',
          sourceEventId: 'event-old',
          status: 'deleted',
          updatedAt: now.add(const Duration(minutes: 3)),
        );
        LocalDbCoreToolCatalog(database).registerInto(registry);

        final limited = await _invoke(
          registry,
          LocalDbCoreToolCatalog.memoryReadTool,
          const <String, Object?>{'limit': 1},
        );
        expect(limited['success'], isTrue);
        expect(limited['count'], 1);
        expect(
          ((limited['items']! as List).single as Map)['id'],
          'memory-newer',
        );

        final filtered = await _invoke(
          registry,
          LocalDbCoreToolCatalog.memoryReadTool,
          const <String, Object?>{
            'source_event_id': 'event-older',
            'type': 'preference',
            'sensitivity': 'low',
            'limit': 10,
          },
        );
        final items = filtered['items']! as List;
        expect(items, hasLength(1));
        final item = items.single as Map;
        expect(item['id'], 'memory-older');
        expect(item['source_refs'], isNotEmpty);
        expect(
          (item['source_refs']! as List).map((ref) => (ref as Map)['kind']),
          containsAll(<String>['capture', 'event']),
        );
      },
    );

    test(
      'creates review-oriented memory proposals and rejects missing refs safely',
      () async {
        var idCounter = 0;
        LocalDbCoreToolCatalog(
          database,
          idFactory: (prefix) {
            idCounter += 1;
            return '$prefix-$idCounter';
          },
        ).registerInto(registry);

        final output = await _invoke(
          registry,
          LocalDbCoreToolCatalog.memoryProposeTool,
          const <String, Object?>{
            'key': 'preference.capture',
            'body': 'The user wants source-linked capture summaries.',
            'type': 'preference',
            'confidence': 'high',
            'sensitivity': 'low',
            'source_refs': <Object?>[
              <String, Object?>{
                'kind': 'event',
                'id': 'event-proposal',
                'excerpt': 'source-linked capture summaries',
              },
            ],
          },
        );

        expect(output['success'], isTrue);
        expect(output['review_required'], isTrue);
        final proposal = output['proposal']! as Map;
        expect(proposal['status'], 'needs_review');
        expect(proposal['source_refs'], isNotEmpty);
        expect(database.memoryCandidates.readAll(), hasLength(1));
        expect(
          database.memoryCandidates.readAll().single.status,
          'needs_review',
        );
        expect(database.memoryItems.readAll(), isEmpty);

        final countBeforeMissing = database.memoryCandidates.readAll().length;
        final missingRefs = await _invoke(
          registry,
          LocalDbCoreToolCatalog.memoryProposeTool,
          const <String, Object?>{
            'key': 'preference.no_source',
            'body': 'This must not be persisted.',
          },
        );
        expect(missingRefs['success'], isFalse);
        expect((missingRefs['error']! as Map)['code'], 'missing_source_refs');
        expect(
          database.memoryCandidates.readAll(),
          hasLength(countBeforeMissing),
        );

        final illegal = await _invoke(
          registry,
          LocalDbCoreToolCatalog.memoryProposeTool,
          const <String, Object?>{
            'key': 'preference.sql',
            'body': 'This must not be persisted either.',
            'source_event_id': 'event-illegal',
            'sql': 'update memory_items set body = body',
          },
        );
        expect(illegal['success'], isFalse);
        expect((illegal['error']! as Map)['code'], 'unsupported_input');
        expect(
          database.memoryCandidates.readAll(),
          hasLength(countBeforeMissing),
        );
        expect(database.memoryItems.readAll(), isEmpty);
      },
    );

    test('creates source-linked todo suggestions only with refs', () async {
      final now = DateTime.utc(2026, 6, 27, 11);
      LocalDbCoreToolCatalog(
        database,
        clock: () => now,
        idFactory: (_) => 'todo-suggested',
      ).registerInto(registry);

      final output = await _invoke(
        registry,
        LocalDbCoreToolCatalog.todoSuggestTool,
        const <String, Object?>{
          'title': 'Review local core tool catalog',
          'body': 'Check source refs and runtime permissions.',
          'source_capture_id': 'capture-todo',
          'source_event_id': 'event-todo',
        },
        runId: 'run-todo',
      );

      expect(output['success'], isTrue);
      expect(output['review_required'], isTrue);
      final todo = database.todos.readById('todo-suggested')!;
      expect(todo.status, 'suggested');
      expect(todo.sourceCaptureId, 'capture-todo');
      expect(todo.sourceEventId, 'event-todo');
      expect(todo.payload['review_state'], 'needs_review');
      expect(todo.payload['source_run_id'], 'run-todo');
      expect((todo.payload['source_refs']! as List), isNotEmpty);

      final countBeforeMissing = database.todos.readAll().length;
      final missingRefs = await _invoke(
        registry,
        LocalDbCoreToolCatalog.todoSuggestTool,
        const <String, Object?>{'title': 'This must not be persisted'},
      );
      expect(missingRefs['success'], isFalse);
      expect((missingRefs['error']! as Map)['code'], 'missing_source_refs');
      expect(database.todos.readAll(), hasLength(countBeforeMissing));
    });

    test('reads run traces with pack filters, limits, and redaction', () async {
      final now = DateTime.utc(2026, 6, 27, 12);
      _seedRuntimePrerequisites(
        database,
        now,
        packId: 'pack.redacted',
        taskId: 'task-redacted',
        eventId: 'event-redacted',
      );
      _seedRuntimePrerequisites(
        database,
        now,
        packId: 'pack.other',
        taskId: 'task-other',
        eventId: 'event-other',
      );
      database.runtimeRuns
        ..insert(
          RuntimeRunRecord(
            id: 'run-redacted',
            taskId: 'task-redacted',
            packId: 'pack.redacted',
            packVersion: '0.1.0',
            agentId: 'agent.trace',
            handlerId: 'agent.trace',
            status: 'failed',
            attempt: 1,
            error: 'token=do-not-emit-run-token',
            startedAt: now,
            completedAt: now.add(const Duration(minutes: 1)),
          ),
        )
        ..insert(
          RuntimeRunRecord(
            id: 'run-other',
            taskId: 'task-other',
            packId: 'pack.other',
            packVersion: '0.1.0',
            agentId: 'agent.other',
            handlerId: 'agent.other',
            status: 'succeeded',
            attempt: 1,
            startedAt: now,
          ),
        );
      database.traceEvents
        ..insert(
          TraceEventRecord(
            id: 'trace-old',
            name: 'tool.started',
            level: 'info',
            sourceRunId: 'run-redacted',
            packId: 'pack.redacted',
            message: 'Authorization: Bearer do-not-emit-old-token',
            payload: const <String, Object?>{
              'safe': 'visible',
              'api_key': 'do-not-emit-api-key',
            },
            createdAt: now,
          ),
        )
        ..insert(
          TraceEventRecord(
            id: 'trace-new',
            name: 'tool.completed',
            level: 'info',
            sourceRunId: 'run-redacted',
            packId: 'pack.redacted',
            message: 'token=do-not-emit-new-token',
            payload: const <String, Object?>{
              'safe': 'visible',
              'nested': <String, Object?>{
                'refresh_token': 'do-not-emit-refresh-token',
              },
            },
            createdAt: now.add(const Duration(minutes: 1)),
          ),
        )
        ..insert(
          TraceEventRecord(
            id: 'trace-other',
            name: 'other.completed',
            level: 'info',
            sourceRunId: 'run-other',
            packId: 'pack.other',
            payload: const <String, Object?>{'safe': 'other'},
            createdAt: now.add(const Duration(minutes: 2)),
          ),
        );
      LocalDbCoreToolCatalog(database).registerInto(registry);

      final output = await _invoke(
        registry,
        LocalDbCoreToolCatalog.traceReadTool,
        const <String, Object?>{'pack_id': 'pack.redacted', 'limit': 1},
      );

      expect(output['success'], isTrue);
      expect(output['count'], 1);
      expect(((output['traces']! as List).single as Map)['id'], 'trace-new');
      expect((output['runs']! as List), hasLength(1));
      final encoded = jsonEncode(output);
      expect(encoded, contains('visible'));
      expect(encoded, contains('[redacted]'));
      expect(encoded, isNot(contains('do-not-emit')));
      expect(encoded, isNot(contains('trace-other')));
    });
  });
}

Future<JsonMap> _invoke(
  runtime.ToolRegistry registry,
  String toolName,
  JsonMap input, {
  String packId = 'pack.test',
  String? runId,
}) async {
  final result = await registry.invoke(
    runtime.ToolInvocation(
      packId: packId,
      runId: runId,
      toolName: toolName,
      input: input,
    ),
  );
  expect(result.isOk, isTrue);
  return result.value;
}

void _seedCapture(WideNoteLocalDatabase database, DateTime now) {
  database.captures.insert(
    CaptureRecord(
      id: 'capture-1',
      sourceType: 'manual',
      payload: const <String, Object?>{'text': 'Context packet source text.'},
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _seedMemory(
  WideNoteLocalDatabase database, {
  required String id,
  required String key,
  required String body,
  required String sourceCaptureId,
  required String sourceEventId,
  required DateTime updatedAt,
  String memoryType = 'project',
  String sensitivity = 'low',
  String status = 'active',
  bool tombstone = false,
}) {
  database.memoryItems.insert(
    MemoryItemRecord(
      id: id,
      key: key,
      sourceCaptureId: sourceCaptureId,
      sourceEventId: sourceEventId,
      status: status,
      body: body,
      sourceRefs: <Object?>[
        <String, Object?>{'kind': 'capture', 'id': sourceCaptureId},
        <String, Object?>{'kind': 'event', 'id': sourceEventId},
      ],
      memoryType: memoryType,
      confidence: 'high',
      sensitivity: sensitivity,
      tombstone: tombstone,
      createdAt: updatedAt.subtract(const Duration(minutes: 5)),
      updatedAt: updatedAt,
    ),
  );
}

void _seedRuntimePrerequisites(
  WideNoteLocalDatabase database,
  DateTime now, {
  required String packId,
  required String taskId,
  required String eventId,
}) {
  database.eventLog.append(
    EventLogEntry(
      id: eventId,
      type: 'wn.capture.created',
      actor: 'user',
      createdAt: now,
    ),
  );
  database.packInstallations.insert(
    PackInstallationRecord(
      packId: packId,
      name: 'Test Pack $packId',
      version: '0.1.0',
      publisher: 'widenote',
      edition: 'official',
      status: 'enabled',
      runtimeStatus: 'idle',
      installedAt: now,
      updatedAt: now,
    ),
  );
  database.runtimeTasks.insert(
    RuntimeTaskRecord(
      id: taskId,
      packId: packId,
      packVersion: '0.1.0',
      agentId: 'agent.trace',
      handlerId: 'agent.trace',
      subscriptionId: 'sub.trace.$packId',
      triggerEventId: eventId,
      createdAt: now,
      updatedAt: now,
    ),
  );
}
