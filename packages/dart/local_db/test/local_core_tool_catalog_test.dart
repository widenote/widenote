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
      final timelineRead = registry.lookup(
        LocalDbCoreToolCatalog.timelineReadTool,
      )!;
      final knowledgeRead = registry.lookup(
        LocalDbCoreToolCatalog.knowledgeReadTool,
      )!;
      final semanticSearch = registry.lookup(
        LocalDbCoreToolCatalog.semanticSearchQueryTool,
      )!;
      final memoryPropose = registry.lookup(
        LocalDbCoreToolCatalog.memoryProposeTool,
      )!;
      final todoSuggest = registry.lookup(
        LocalDbCoreToolCatalog.todoSuggestTool,
      )!;
      final fakeAsr = registry.lookup(
        LocalDbCoreToolCatalog.audioTranscribeLocalFakeTool,
      )!;
      final fakeOcr = registry.lookup(
        LocalDbCoreToolCatalog.imageOcrLocalFakeTool,
      )!;
      final fakeDescribe = registry.lookup(
        LocalDbCoreToolCatalog.imageDescribeLocalFakeTool,
      )!;
      final traceRead = registry.lookup(LocalDbCoreToolCatalog.traceReadTool)!;

      expect(context.requiredPermissions, <String>{'context_packet.build'});
      expect(memoryRead.requiredPermissions, <String>{'memory.read'});
      expect(timelineRead.requiredPermissions, <String>{'timeline.read'});
      expect(knowledgeRead.requiredPermissions, <String>{'knowledge.read'});
      expect(semanticSearch.requiredPermissions, <String>{
        'semantic_search.query',
      });
      expect(memoryPropose.requiredPermissions, <String>{'memory.propose'});
      expect(todoSuggest.requiredPermissions, <String>{'todo.suggest'});
      expect(fakeAsr.requiredPermissions, <String>{
        'audio.transcribe.local_fake',
      });
      expect(fakeOcr.requiredPermissions, <String>{'image.ocr.local_fake'});
      expect(fakeDescribe.requiredPermissions, <String>{
        'image.describe.local_fake',
      });
      expect(traceRead.requiredPermissions, <String>{'trace.read'});
      expect(
        <runtime.ToolDefinition>[
          context,
          memoryRead,
          timelineRead,
          knowledgeRead,
          semanticSearch,
          memoryPropose,
          todoSuggest,
          fakeAsr,
          fakeOcr,
          fakeDescribe,
          traceRead,
        ].every((definition) => definition.external == false),
        isTrue,
      );
      expect(memoryRead.access, runtime.ToolAccess.read);
      expect(timelineRead.access, runtime.ToolAccess.read);
      expect(knowledgeRead.access, runtime.ToolAccess.read);
      expect(semanticSearch.access, runtime.ToolAccess.read);
      expect(traceRead.access, runtime.ToolAccess.read);
      expect(memoryPropose.access, runtime.ToolAccess.write);
      expect(todoSuggest.access, runtime.ToolAccess.write);
      expect(fakeAsr.access, runtime.ToolAccess.write);
      expect(fakeOcr.access, runtime.ToolAccess.write);
      expect(fakeDescribe.access, runtime.ToolAccess.write);
      expect(memoryPropose.requiresApproval, isTrue);
      expect(todoSuggest.requiresApproval, isTrue);
      expect(fakeAsr.requiresApproval, isTrue);
      expect(fakeOcr.requiresApproval, isTrue);
      expect(fakeDescribe.requiresApproval, isTrue);
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
      'reads timeline, knowledge, and semantic query outputs with artifacts',
      () async {
        final now = DateTime.utc(2026, 6, 27, 10, 30);
        _seedCapture(database, now);
        database.attachments.insert(
          AttachmentRecord(
            id: 'attachment-whiteboard',
            captureId: 'capture-1',
            sourceEventId: 'event-1',
            assetKind: 'photo',
            mimeType: 'image/jpeg',
            storagePath: 'fs://Facts/assets/whiteboard.jpg',
            originalFileName: 'whiteboard.jpg',
            sha256: 'whiteboard-sha256',
            payload: const <String, Object?>{
              'preview_text': 'Whiteboard photo saved locally.',
            },
            createdAt: now,
            updatedAt: now,
          ),
        );
        database.derivedArtifacts.insert(
          DerivedArtifactRecord(
            id: 'artifact-whiteboard-ocr',
            sourceCaptureId: 'capture-1',
            sourceAttachmentId: 'attachment-whiteboard',
            sourceEventId: 'event-1',
            artifactKind: 'ocr_text',
            title: 'Whiteboard OCR',
            body: 'Whiteboard says ship local read tools.',
            sourceRefs: const <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
              <String, Object?>{'kind': 'file', 'id': 'attachment-whiteboard'},
            ],
            confidence: 'high',
            generatorId: 'capture.media.ocr',
            generatorVersion: '1.0.0',
            createdAt: now,
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
        );
        database.cards.insert(
          CardRecord(
            id: 'card-whiteboard',
            cardKind: 'timeline_card',
            title: 'Whiteboard plan',
            body: 'Local read tools are ready to review.',
            sourceRefs: const <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
            ],
            createdAt: now,
            updatedAt: now.add(const Duration(minutes: 2)),
          ),
        );
        LocalDbCoreToolCatalog(database).registerInto(registry);

        final timeline = await _invoke(
          registry,
          LocalDbCoreToolCatalog.timelineReadTool,
          const <String, Object?>{'limit': 1},
        );
        expect(timeline['success'], isTrue);
        final capture = ((timeline['items']! as List).single as Map);
        expect(capture['id'], 'capture-1');
        expect(capture['attachments'], hasLength(1));
        expect(capture['derived_artifacts'], hasLength(1));

        final knowledge = await _invoke(
          registry,
          LocalDbCoreToolCatalog.knowledgeReadTool,
          const <String, Object?>{'kind': 'artifact', 'limit': 5},
        );
        final knowledgeItem = ((knowledge['items']! as List).single as Map);
        expect(knowledgeItem['kind'], 'artifact');
        expect((knowledgeItem['item']! as Map)['body'], contains('read tools'));

        final semantic = await _invoke(
          registry,
          LocalDbCoreToolCatalog.semanticSearchQueryTool,
          const <String, Object?>{
            'query': 'What does the whiteboard say?',
            'limit': 6,
          },
        );
        expect(semantic['success'], isTrue);
        expect(
          semantic['selection_strategy'],
          'local_candidate_retrieval_nonsemantic',
        );
        expect(semantic['query_used_for_candidate_selection'], isFalse);
        expect(
          jsonEncode(semantic['sources']),
          contains('Whiteboard says ship local read tools.'),
        );
        expect(
          (semantic['candidates']! as List).map(
            (candidate) => (candidate as Map)['kind'],
          ),
          containsAll(<String>['capture', 'card', 'derived_artifact']),
        );
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
      'semantic query candidate collection ignores query content heuristics',
      () async {
        final now = DateTime.utc(2026, 6, 28, 9);
        _seedRetrievalFixture(database, now);
        LocalDbCoreToolCatalog(database).registerInto(registry);

        Future<List<String>> candidateIds(String query) async {
          final output = await _invoke(
            registry,
            LocalDbCoreToolCatalog.semanticSearchQueryTool,
            <String, Object?>{'query': query, 'limit': 20},
          );
          expect(output['query_used_for_candidate_selection'], isFalse);
          return _candidateIds(output);
        }

        final english = await candidateIds('alpha project launch');
        final chinese = await candidateIds('阿尔法项目发布');
        final upper = await candidateIds('ALPHA PROJECT LAUNCH');

        expect(chinese, english);
        expect(upper, english);
        expect(
          english.toSet(),
          containsAll(<String>{
            'memory/memory-alpha',
            'capture/capture-alpha',
            'card/card-alpha',
            'insight/insight-alpha',
            'todo/todo-alpha',
            'derived_artifact/artifact-alpha-ocr',
          }),
        );

        final filtered = await _invoke(
          registry,
          LocalDbCoreToolCatalog.semanticSearchQueryTool,
          const <String, Object?>{
            'query': 'alpha project launch',
            'object_kinds': <Object?>['memory'],
            'limit': 20,
          },
        );
        expect(_candidateIds(filtered), <String>['memory/memory-alpha']);
      },
    );

    test(
      'semantic query excludes tombstone deletion and high sensitivity by default',
      () async {
        final now = DateTime.utc(2026, 6, 28, 10);
        _seedRetrievalFixture(database, now);
        LocalDbCoreToolCatalog(database).registerInto(registry);

        final output = await _invoke(
          registry,
          LocalDbCoreToolCatalog.semanticSearchQueryTool,
          const <String, Object?>{'query': 'anything', 'limit': 20},
        );
        final ids = _candidateIds(output);
        expect(ids, isNot(contains('memory/memory-high')));
        expect(ids, isNot(contains('memory/memory-tombstone')));
        expect(ids, isNot(contains('capture/capture-deleted')));
        expect(ids, isNot(contains('derived_artifact/artifact-high')));

        final traceReview = await _invoke(
          registry,
          LocalDbCoreToolCatalog.semanticSearchQueryTool,
          const <String, Object?>{
            'query': 'anything',
            'permission_mode': 'trace_review',
            'limit': 20,
          },
        );
        final high = (traceReview['candidates']! as List).cast<Map>().where(
          (candidate) => candidate['id'] == 'memory-high',
        );
        expect(high, hasLength(1));
        expect(high.single['snippet'], isNull);
        expect(
          jsonEncode(traceReview),
          isNot(contains('High sensitivity body')),
        );
      },
    );

    test(
      'semantic query returns derived artifact candidates by source refs without raw paths',
      () async {
        final now = DateTime.utc(2026, 6, 28, 11);
        _seedRetrievalFixture(database, now);
        LocalDbCoreToolCatalog(database).registerInto(registry);

        final output = await _invoke(
          registry,
          LocalDbCoreToolCatalog.semanticSearchQueryTool,
          const <String, Object?>{
            'query': 'unrelated query text',
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'file', 'id': 'attachment-alpha'},
            ],
            'limit': 20,
          },
        );

        final candidates = (output['candidates']! as List).cast<Map>();
        expect(
          candidates.map((candidate) => candidate['id']),
          contains('artifact-alpha-ocr'),
        );
        final artifact = candidates.singleWhere(
          (candidate) => candidate['id'] == 'artifact-alpha-ocr',
        );
        expect(artifact['kind'], 'derived_artifact');
        expect(
          artifact['snippet'],
          contains('Alpha OCR says derived evidence'),
        );
        expect(
          (artifact['source_refs']! as List).map((ref) => (ref as Map)['kind']),
          containsAll(<String>['artifact', 'capture', 'file']),
        );
        final encoded = jsonEncode(output);
        expect(encoded, isNot(contains('/Users/guangmo/private')));
        expect(encoded, isNot(contains('/private/generated')));
        expect(encoded, isNot(contains('RAW_MEDIA_BYTES')));
      },
    );

    test(
      'redacts raw paths and media across context retrieval and trace outputs',
      () async {
        final now = DateTime.utc(2026, 6, 28, 12);
        _seedRetrievalFixture(database, now);
        _seedRuntimePrerequisites(
          database,
          now,
          packId: 'pack.paths',
          taskId: 'task-paths',
          eventId: 'event-paths',
        );
        database.traceEvents.insert(
          TraceEventRecord(
            id: 'trace-paths',
            name: 'tool.media.completed',
            level: 'info',
            sourceRunId: 'run-paths',
            packId: 'pack.paths',
            message:
                'stored at /Users/guangmo/private/raw/alpha.png with token=safe-to-redact',
            payload: const <String, Object?>{
              'storage_path': '/Users/guangmo/private/raw/alpha.png',
              'media_bytes': 'RAW_MEDIA_BYTES',
              'nested': <String, Object?>{
                'absolute_path': '/private/generated/alpha.txt',
              },
            },
            createdAt: now,
          ),
        );
        LocalDbCoreToolCatalog(database).registerInto(registry);

        final context = ContextPacketBuilder(database, clock: () => now).build(
          const ContextPacketBuildRequest(
            surface: 'chat',
            sourceRefs: <JsonMap>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-alpha'},
            ],
            disclosureLevel: 'attachment_expansion',
            includeAttachmentMetadata: true,
            allowAttachmentExpansion: false,
          ),
        );
        final retrieval = await _invoke(
          registry,
          LocalDbCoreToolCatalog.semanticSearchQueryTool,
          const <String, Object?>{
            'query': 'paths should not matter',
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-alpha'},
            ],
            'limit': 20,
          },
        );
        final trace = await _invoke(
          registry,
          LocalDbCoreToolCatalog.traceReadTool,
          const <String, Object?>{'pack_id': 'pack.paths', 'limit': 5},
        );

        final encoded = jsonEncode(<String, Object?>{
          'context': context.packet,
          'retrieval': retrieval,
          'trace': trace,
        });
        expect(encoded, isNot(contains('/Users/guangmo/private')));
        expect(encoded, isNot(contains('/private/generated')));
        expect(encoded, isNot(contains('RAW_MEDIA_BYTES')));
        expect(encoded, contains('[redacted:local_path]'));
        expect(encoded, contains('[redacted:raw_media]'));
      },
    );

    test(
      'auto-accepts safe memory proposals and rejects missing refs safely',
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
        expect(output['review_required'], isFalse);
        expect(output['accepted_memory_id'], isNotNull);
        final proposal = output['proposal']! as Map;
        expect(proposal['status'], 'auto_accepted');
        expect(proposal['source_refs'], isNotEmpty);
        expect(database.memoryCandidates.readAll(), hasLength(1));
        expect(
          database.memoryCandidates.readAll().single.status,
          'auto_accepted',
        );
        expect(database.memoryItems.readAll(), hasLength(1));
        expect(
          database.memoryItems.readAll().single.body,
          'The user wants source-linked capture summaries.',
        );

        final candidateCountBeforeMissing = database.memoryCandidates
            .readAll()
            .length;
        final itemCountBeforeMissing = database.memoryItems.readAll().length;
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
          hasLength(candidateCountBeforeMissing),
        );
        expect(
          database.memoryItems.readAll(),
          hasLength(itemCountBeforeMissing),
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
          hasLength(candidateCountBeforeMissing),
        );
        expect(
          database.memoryItems.readAll(),
          hasLength(itemCountBeforeMissing),
        );
      },
    );

    test('routes sensitive memory proposals to review', () async {
      LocalDbCoreToolCatalog(database).registerInto(registry);

      final output = await _invoke(
        registry,
        LocalDbCoreToolCatalog.memoryProposeTool,
        const <String, Object?>{
          'key': 'health.sleep',
          'body': 'The user discussed sleep and anxiety context.',
          'type': 'health',
          'confidence': 'high',
          'sensitivity': 'high',
          'source_refs': <Object?>[
            <String, Object?>{
              'kind': 'event',
              'id': 'event-sensitive',
              'excerpt': 'sleep and anxiety context',
            },
          ],
        },
      );

      expect(output['success'], isTrue);
      expect(output['review_required'], isTrue);
      expect(output['accepted_memory_id'], isNull);
      final proposal = output['proposal']! as Map;
      expect(proposal['status'], 'needs_review');
      expect(proposal['policy_reasons'], contains('review_only_type'));
      expect(proposal['policy_reasons'], contains('sensitive'));
      expect(database.memoryCandidates.readAll(), hasLength(1));
      expect(database.memoryItems.readAll(), isEmpty);
    });

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
          'due_at': '2026-07-03T18:00:00.000Z',
          'due_label': 'today evening',
          'priority': 'high',
          'sort_order': 42,
          'indent_level': 8,
          'subtasks': <Object?>[
            <String, Object?>{
              'id': 'subtask-review',
              'title': 'Review schema surface',
              'completed': true,
            },
            <String, Object?>{'title': 'Check context packet'},
          ],
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
      expect(todo.payload['todo_schema_version'], 1);
      expect(todo.payload['due_at'], '2026-07-03T18:00:00.000Z');
      expect(todo.payload['due_label'], 'today evening');
      expect(todo.payload['priority'], 'high');
      expect(todo.payload['sort_order'], 42);
      expect(todo.payload['indent_level'], 3);
      expect((todo.payload['subtasks']! as List), hasLength(2));
      expect((todo.payload['source_refs']! as List), isNotEmpty);
      final outputTodo = output['todo']! as Map;
      expect(outputTodo['priority'], 'high');
      expect(outputTodo['indent_level'], 3);
      expect(
        outputTodo['subtasks'],
        isA<List>().having((list) => list.length, 'length', 2),
      );

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

    test('knowledge read keeps completed todos visible to agents', () async {
      final now = DateTime.utc(2026, 7, 3, 12);
      database.todos.insert(
        TodoRecord(
          id: 'todo-completed-readable',
          sourceCaptureId: 'capture-completed',
          sourceEventId: 'event-completed',
          status: 'completed',
          payload: const <String, Object?>{
            'title': 'Review completed task context',
            'suggestion_kind': 'action',
            'completed_at': '2026-07-03T11:30:00.000Z',
            'completed_by': 'user',
            'priority': 'medium',
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-completed'},
              <String, Object?>{'kind': 'event', 'id': 'event-completed'},
            ],
          },
          createdAt: now.subtract(const Duration(hours: 1)),
          updatedAt: now,
        ),
      );
      database.todos.insert(
        TodoRecord(
          id: 'todo-deleted-hidden',
          status: 'deleted',
          payload: const <String, Object?>{'title': 'Hidden deleted todo'},
          createdAt: now,
          updatedAt: now,
        ),
      );
      LocalDbCoreToolCatalog(database).registerInto(registry);

      final output = await _invoke(
        registry,
        LocalDbCoreToolCatalog.knowledgeReadTool,
        const <String, Object?>{'kind': 'todo', 'limit': 10},
      );

      expect(output['success'], isTrue);
      final encoded = jsonEncode(output);
      expect(encoded, contains('Review completed task context'));
      expect(encoded, contains('2026-07-03T11:30:00.000Z'));
      expect(encoded, contains('medium'));
      expect(encoded, isNot(contains('Hidden deleted todo')));
    });

    test(
      'local fake ASR OCR and image description tools create source-linked artifacts',
      () async {
        final now = DateTime.utc(2026, 6, 28, 13);
        _seedMediaSources(database, now);
        LocalDbCoreToolCatalog(
          database,
          clock: () => now,
        ).registerInto(registry);

        final asr = await _invoke(
          registry,
          LocalDbCoreToolCatalog.audioTranscribeLocalFakeTool,
          const <String, Object?>{
            'artifact_id': 'artifact-fake-asr',
            'source_capture_id': 'capture-media',
            'source_attachment_id': 'attachment-audio',
            'source_event_id': 'event-media',
          },
          runId: 'run-media',
        );
        final ocr = await _invoke(
          registry,
          LocalDbCoreToolCatalog.imageOcrLocalFakeTool,
          const <String, Object?>{
            'artifact_id': 'artifact-fake-ocr',
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'attachment', 'id': 'attachment-image'},
            ],
          },
        );
        final describe = await _invoke(
          registry,
          LocalDbCoreToolCatalog.imageDescribeLocalFakeTool,
          const <String, Object?>{
            'artifact_id': 'artifact-fake-describe',
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-media'},
              <String, Object?>{'kind': 'file', 'id': 'attachment-image'},
            ],
          },
        );

        for (final output in <JsonMap>[asr, ocr, describe]) {
          expect(output['success'], isTrue);
          expect(output['raw_media_included'], isFalse);
          expect(jsonEncode(output), isNot(contains('/Users/guangmo/media')));
          expect(jsonEncode(output), isNot(contains('RAW_MEDIA_BYTES')));
        }
        expect(
          database.captures.readById('capture-media')!.payload['text'],
          'Media source capture',
        );
        expect(
          database.derivedArtifacts
              .readByAttachment('attachment-audio', status: 'ready')
              .single
              .artifactKind,
          'transcript',
        );
        expect(
          database.derivedArtifacts
              .readByAttachment('attachment-image', status: 'ready')
              .map((artifact) => artifact.artifactKind)
              .toSet(),
          <String>{'ocr_text', 'image_description'},
        );
        final asrArtifact = database.derivedArtifacts.readById(
          'artifact-fake-asr',
        )!;
        expect(asrArtifact.generatorId, 'audio.transcribe.local_fake');
        expect(asrArtifact.status, 'ready');
        expect(
          asrArtifact.sourceRefs.map((ref) => (ref as Map)['kind']),
          containsAll(<String>['capture', 'file', 'event']),
        );

        final beforeBlocked = database.derivedArtifacts.readAll().length;
        final blocked = await _invoke(
          registry,
          LocalDbCoreToolCatalog.imageOcrLocalFakeTool,
          const <String, Object?>{
            'artifact_id': 'artifact-blocked',
            'source_attachment_id': 'attachment-blocked',
          },
        );
        expect(blocked['success'], isFalse);
        expect((blocked['error']! as Map)['code'], 'source_not_ready');
        expect(database.derivedArtifacts.readAll(), hasLength(beforeBlocked));
      },
    );

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

List<String> _candidateIds(JsonMap output) {
  return (output['candidates']! as List)
      .cast<Map>()
      .map((candidate) {
        return '${candidate['kind']}/${candidate['id']}';
      })
      .toList(growable: false);
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

void _seedRetrievalFixture(WideNoteLocalDatabase database, DateTime now) {
  database.captures
    ..insert(
      CaptureRecord(
        id: 'capture-alpha',
        sourceType: 'manual',
        sourceId: 'event-alpha',
        payload: const <String, Object?>{'text': 'Alpha launch capture text.'},
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    )
    ..insert(
      CaptureRecord(
        id: 'capture-deleted',
        sourceType: 'manual',
        status: 'deleted',
        payload: const <String, Object?>{'text': 'Deleted capture text.'},
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 20)),
      ),
    );
  _seedMemory(
    database,
    id: 'memory-alpha',
    key: 'project.alpha',
    body: 'Alpha Memory says the local candidate collector is source-linked.',
    sourceCaptureId: 'capture-alpha',
    sourceEventId: 'event-alpha',
    updatedAt: now.add(const Duration(minutes: 10)),
  );
  _seedMemory(
    database,
    id: 'memory-high',
    key: 'private.high',
    body: 'High sensitivity body must not be exposed by default.',
    sourceCaptureId: 'capture-alpha',
    sourceEventId: 'event-alpha',
    sensitivity: 'high',
    updatedAt: now.add(const Duration(minutes: 11)),
  );
  _seedMemory(
    database,
    id: 'memory-tombstone',
    key: 'project.tombstone',
    body: 'Tombstoned Memory must not be returned by default.',
    sourceCaptureId: 'capture-alpha',
    sourceEventId: 'event-alpha',
    tombstone: true,
    updatedAt: now.add(const Duration(minutes: 12)),
  );
  _seedMemory(
    database,
    id: 'memory-deleted',
    key: 'project.deleted',
    body: 'Deleted Memory must not be returned by default.',
    sourceCaptureId: 'capture-alpha',
    sourceEventId: 'event-alpha',
    status: 'deleted',
    updatedAt: now.add(const Duration(minutes: 13)),
  );
  database.attachments.insert(
    AttachmentRecord(
      id: 'attachment-alpha',
      captureId: 'capture-alpha',
      sourceEventId: 'event-alpha',
      assetKind: 'photo',
      mimeType: 'image/png',
      storagePath: '/Users/guangmo/private/raw/alpha.png',
      originalFileName: '/Users/guangmo/private/raw/alpha.png',
      sha256: 'sha-alpha',
      payload: const <String, Object?>{
        'storage_path': '/Users/guangmo/private/raw/alpha.png',
        'media_bytes': 'RAW_MEDIA_BYTES',
      },
      createdAt: now,
      updatedAt: now.add(const Duration(minutes: 2)),
    ),
  );
  database.derivedArtifacts
    ..insert(
      DerivedArtifactRecord(
        id: 'artifact-alpha-ocr',
        sourceCaptureId: 'capture-alpha',
        sourceAttachmentId: 'attachment-alpha',
        sourceEventId: 'event-alpha',
        artifactKind: 'ocr_text',
        status: 'ready',
        title: 'Alpha OCR',
        body: 'Alpha OCR says derived evidence stays source-linked.',
        storagePath: '/private/generated/alpha-ocr.txt',
        contentHash: 'hash-alpha-ocr',
        sourceRefs: const <Object?>[
          <String, Object?>{'kind': 'capture', 'id': 'capture-alpha'},
          <String, Object?>{'kind': 'file', 'id': 'attachment-alpha'},
          <String, Object?>{'kind': 'event', 'id': 'event-alpha'},
        ],
        confidence: 'high',
        generatorId: 'image.ocr.local_fake',
        generatorVersion: 'local-fake-v1',
        payload: const <String, Object?>{
          'storage_path': '/private/generated/alpha-ocr.txt',
          'media_bytes': 'RAW_MEDIA_BYTES',
        },
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 9)),
      ),
    )
    ..insert(
      DerivedArtifactRecord(
        id: 'artifact-high',
        sourceCaptureId: 'capture-alpha',
        sourceAttachmentId: 'attachment-alpha',
        artifactKind: 'vision_summary',
        status: 'ready',
        title: 'High artifact',
        body: 'High sensitivity artifact body must be gated.',
        sourceRefs: const <Object?>[
          <String, Object?>{'kind': 'capture', 'id': 'capture-alpha'},
        ],
        sensitivity: 'high',
        generatorId: 'image.describe.local_fake',
        generatorVersion: 'local-fake-v1',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 8)),
      ),
    );
  database.cards.insert(
    CardRecord(
      id: 'card-alpha',
      cardKind: 'summary',
      title: 'Alpha card',
      body: 'Card derived from Alpha capture.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-alpha'},
      ],
      createdAt: now,
      updatedAt: now.add(const Duration(minutes: 7)),
    ),
  );
  database.insights.insert(
    InsightRecord(
      id: 'insight-alpha',
      insightKind: 'daily_summary',
      title: 'Alpha insight',
      summary: 'Insight derived from Alpha capture.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-alpha'},
      ],
      createdAt: now,
      updatedAt: now.add(const Duration(minutes: 6)),
    ),
  );
  database.todos.insert(
    TodoRecord(
      id: 'todo-alpha',
      sourceCaptureId: 'capture-alpha',
      sourceEventId: 'event-alpha',
      status: 'open',
      payload: const <String, Object?>{
        'title': 'Review Alpha candidate retrieval',
        'body': 'Keep it source-linked.',
        'source_refs': <Object?>[
          <String, Object?>{'kind': 'capture', 'id': 'capture-alpha'},
          <String, Object?>{'kind': 'event', 'id': 'event-alpha'},
        ],
      },
      createdAt: now,
      updatedAt: now.add(const Duration(minutes: 5)),
    ),
  );
}

void _seedMediaSources(WideNoteLocalDatabase database, DateTime now) {
  database.captures.insert(
    CaptureRecord(
      id: 'capture-media',
      sourceType: 'manual',
      payload: const <String, Object?>{'text': 'Media source capture'},
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.attachments
    ..insert(
      AttachmentRecord(
        id: 'attachment-audio',
        captureId: 'capture-media',
        sourceEventId: 'event-media',
        assetKind: 'audio',
        mimeType: 'audio/m4a',
        storagePath: '/Users/guangmo/media/audio.m4a',
        sha256: 'sha-audio',
        payload: const <String, Object?>{'media_bytes': 'RAW_MEDIA_BYTES'},
        createdAt: now,
        updatedAt: now,
      ),
    )
    ..insert(
      AttachmentRecord(
        id: 'attachment-image',
        captureId: 'capture-media',
        sourceEventId: 'event-media',
        assetKind: 'image',
        mimeType: 'image/jpeg',
        storagePath: '/Users/guangmo/media/image.jpg',
        sha256: 'sha-image',
        status: 'ready',
        createdAt: now,
        updatedAt: now,
      ),
    )
    ..insert(
      AttachmentRecord(
        id: 'attachment-blocked',
        captureId: 'capture-media',
        assetKind: 'image',
        mimeType: 'image/jpeg',
        storagePath: '/Users/guangmo/media/blocked.jpg',
        status: 'blocked',
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
