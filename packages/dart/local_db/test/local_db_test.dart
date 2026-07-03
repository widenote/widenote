import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_memory/memory.dart' as memory;

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

    test('stores attachment metadata linked to captures', () {
      final createdAt = DateTime.utc(2026, 6, 24, 8, 10);
      database.captures.insert(
        CaptureRecord(
          id: 'capture-asset-1',
          sourceType: 'manual_with_attachments',
          payload: const <String, Object?>{'text': 'Photo note'},
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      database.attachments.insert(
        AttachmentRecord(
          id: 'attachment-1',
          captureId: 'capture-asset-1',
          sourceEventId: 'event-asset-1',
          assetKind: 'photo',
          mimeType: 'image/jpeg',
          storagePath: 'media/originals/2026/06/attachment-1.jpg',
          originalFileName: 'field-note.jpg',
          sha256: 'hash-attachment-1',
          byteLength: 1024,
          payload: const <String, Object?>{
            'preview_text': 'whiteboard snapshot',
          },
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      final attachment = database.attachments.readById('attachment-1')!;

      expect(attachment.captureId, 'capture-asset-1');
      expect(attachment.assetKind, 'photo');
      expect(attachment.mimeType, 'image/jpeg');
      expect(attachment.sha256, 'hash-attachment-1');
      expect(attachment.byteLength, 1024);
      expect(
        database.attachments
            .readByCapture('capture-asset-1')
            .map((record) => record.id),
        ['attachment-1'],
      );
      expect(database.attachments.readAll(status: 'available'), hasLength(1));
      expect(
        () => database.attachments.insert(
          AttachmentRecord(
            id: 'attachment-bad-size',
            captureId: 'capture-asset-1',
            assetKind: 'photo',
            storagePath: 'media/originals/bad.jpg',
            byteLength: -1,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('stores derived artifacts linked to captures and attachments', () {
      final createdAt = DateTime.utc(2026, 6, 24, 8, 15);
      database.captures.insert(
        CaptureRecord(
          id: 'capture-artifact-1',
          sourceType: 'manual_with_attachments',
          payload: const <String, Object?>{'text': 'Photo note'},
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      database.attachments.insert(
        AttachmentRecord(
          id: 'attachment-artifact-1',
          captureId: 'capture-artifact-1',
          assetKind: 'photo',
          mimeType: 'image/jpeg',
          storagePath: 'media/originals/attachment-artifact-1.jpg',
          sha256: 'hash-artifact-attachment-1',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      database.derivedArtifacts.insert(
        DerivedArtifactRecord(
          id: 'artifact-ocr-1',
          sourceCaptureId: 'capture-artifact-1',
          sourceAttachmentId: 'attachment-artifact-1',
          sourceEventId: 'event-artifact-1',
          artifactKind: 'ocr_text',
          title: 'OCR text',
          body: 'Whiteboard says: ship source-linked media cards.',
          contentHash: 'hash-artifact-ocr-1',
          sourceRefs: const <Object?>[
            <String, Object?>{'kind': 'capture', 'id': 'capture-artifact-1'},
            <String, Object?>{'kind': 'file', 'id': 'attachment-artifact-1'},
          ],
          sensitivity: 'low',
          confidence: 'high',
          generatorId: 'ocr.fake',
          generatorVersion: '1',
          payload: const <String, Object?>{
            'language': 'en',
            'blocks': <Object?>[
              <String, Object?>{'text': 'ship source-linked media cards'},
            ],
          },
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      final artifact = database.derivedArtifacts.readById('artifact-ocr-1')!;

      expect(artifact.artifactKind, 'ocr_text');
      expect(artifact.sourceCaptureId, 'capture-artifact-1');
      expect(artifact.sourceAttachmentId, 'attachment-artifact-1');
      expect(artifact.body, contains('source-linked media cards'));
      expect(artifact.sourceRefs, hasLength(2));
      expect(
        database.derivedArtifacts
            .readByCapture('capture-artifact-1')
            .map((record) => record.id),
        ['artifact-ocr-1'],
      );
      expect(
        database.derivedArtifacts
            .readByAttachment('attachment-artifact-1')
            .map((record) => record.id),
        ['artifact-ocr-1'],
      );
      expect(
        database.derivedArtifacts.readAll(artifactKind: 'ocr_text'),
        hasLength(1),
      );
      expect(
        () => database.derivedArtifacts.insert(
          DerivedArtifactRecord(
            id: 'artifact-missing-refs',
            sourceCaptureId: 'capture-artifact-1',
            artifactKind: 'ocr_text',
            title: 'Missing refs',
            body: 'This should fail.',
            sourceRefs: const <Object?>[],
            generatorId: 'ocr.fake',
            generatorVersion: '1',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ),
        throwsArgumentError,
      );
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

    test('stores source-linked cards and insights', () {
      final createdAt = DateTime.utc(2026, 6, 24, 8);
      const sourceRefs = <Object?>[
        <String, Object?>{
          'kind': 'capture',
          'id': 'capture-card-1',
          'excerpt': 'source-linked card',
        },
      ];

      database.cards.insert(
        CardRecord(
          id: 'card-1',
          cardKind: 'capture_summary',
          title: 'Capture: source-linked card',
          body: 'A card derived from the original capture.',
          sourceRefs: sourceRefs,
          payload: const <String, Object?>{'source_count': 1},
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      database.insights.insert(
        InsightRecord(
          id: 'insight-1',
          insightKind: 'count',
          title: 'Knowledge layer coverage',
          summary: '1 captures and 0 Memory items generated 1 card.',
          sourceRefs: sourceRefs,
          metricLabel: 'source-linked cards',
          metricValue: 1,
          payload: const <String, Object?>{'capture_count': 1},
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      final card = database.cards.readById('card-1');
      final insight = database.insights.readById('insight-1');

      expect(card, isNotNull);
      expect(card!.cardKind, 'capture_summary');
      expect(card.title, 'Capture: source-linked card');
      expect((card.sourceRefs.single as Map)['id'], 'capture-card-1');
      expect(card.payload['source_count'], 1);
      expect(database.cards.readAll(status: 'active'), hasLength(1));

      expect(insight, isNotNull);
      expect(insight!.insightKind, 'count');
      expect(insight.metricLabel, 'source-linked cards');
      expect(insight.metricValue, 1);
      expect((insight.sourceRefs.single as Map)['kind'], 'capture');
      expect(database.insights.readAll(status: 'active'), hasLength(1));
    });

    test('rejects card and insight rows without source links', () {
      final createdAt = DateTime.utc(2026, 6, 24, 8, 30);

      expect(
        () => database.cards.insert(
          CardRecord(
            id: 'card-empty-source',
            cardKind: 'capture_summary',
            title: 'No source',
            body: 'This should not be stored.',
            sourceRefs: const <Object?>[],
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => database.insights.insert(
          InsightRecord(
            id: 'insight-empty-source',
            insightKind: 'count',
            title: 'No source',
            summary: 'This should not be stored.',
            sourceRefs: const <Object?>[],
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('stores chat sessions, messages, and provider configs', () {
      final createdAt = DateTime.utc(2026, 6, 23, 10, 15);
      final updatedAt = DateTime.utc(2026, 6, 23, 10, 20);

      database.chatSessions.save(
        ChatSessionRecord(
          id: 'session-1',
          title: 'Launch review',
          payload: const <String, Object?>{'source': 'test'},
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
      database.chatMessages
        ..save(
          ChatMessageRecord(
            id: 'message-user',
            sessionId: 'session-1',
            role: 'user',
            body: 'What did Lin say?',
            createdAt: createdAt,
          ),
        )
        ..save(
          ChatMessageRecord(
            id: 'message-assistant',
            sessionId: 'session-1',
            role: 'assistant',
            body: 'Lin asked for source-linked cards.',
            sourceRefs: const <Object?>[
              <String, Object?>{'kind': 'memory', 'id': 'memory-1'},
            ],
            createdAt: updatedAt,
          ),
        );
      database.modelProviderConfigs.save(
        ModelProviderConfigRecord(
          id: 'mimo-main',
          providerKind: 'mimo',
          displayName: 'Xiaomi MIMO',
          endpoint:
              'https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages',
          model: 'mimo-v2.5-pro',
          isDefault: true,
          hasApiKey: true,
          apiKey: _testCredential(),
          capabilities: const <Object?>['chat', 'completion'],
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );

      expect(database.chatSessions.readAll().single.title, 'Launch review');
      expect(
        database.chatMessages
            .readBySession('session-1')
            .map((message) => message.role),
        ['user', 'assistant'],
      );
      expect(
        (database.chatMessages.readById('message-assistant')!.sourceRefs.single
            as Map)['id'],
        'memory-1',
      );
      final provider = database.modelProviderConfigs.readDefault()!;
      expect(provider.id, 'mimo-main');
      expect(provider.hasApiKey, isTrue);
      expect(provider.apiKey, _testCredential());
      expect(provider.capabilities, contains('chat'));

      database.chatSessions.deleteById('session-1');
      expect(database.chatSessions.readById('session-1'), isNull);
      expect(database.chatMessages.readBySession('session-1'), isEmpty);
    });

    test('transitions memory review candidates in SQLite', () {
      final createdAt = DateTime.utc(2026, 6, 23, 10, 30);
      final reviewedAt = DateTime.utc(2026, 6, 23, 10, 45);
      database.memoryCandidates
        ..insert(
          MemoryCandidateRecord(
            id: 'candidate-accept',
            key: 'preference.editor',
            sourceEventId: 'event-accept',
            status: 'needs_review',
            body: 'The user prefers compact editor layouts.',
            sourceRefs: const <Object?>[
              <String, Object?>{
                'kind': 'event',
                'id': 'event-accept',
                'evidence_text': 'compact editor layouts',
              },
            ],
            memoryType: 'preference',
            confidence: 'medium',
            sensitivity: 'low',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        )
        ..insert(
          MemoryCandidateRecord(
            id: 'candidate-reject',
            key: 'credential.api_key',
            sourceEventId: 'event-reject',
            status: 'needs_review',
            body: 'The user pasted a secret token.',
            memoryType: 'credential',
            confidence: 'high',
            sensitivity: 'high',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );

      final accepted = database.memoryCandidates.acceptCandidate(
        'candidate-accept',
        itemId: 'memory-accepted',
        body: 'The user prefers dense editor layouts.',
        acceptedAt: reviewedAt,
      );
      final rejected = database.memoryCandidates.rejectCandidate(
        'candidate-reject',
        reason: 'credential_redacted',
        rejectedAt: reviewedAt,
      );

      expect(accepted.id, 'memory-accepted');
      expect(accepted.body, 'The user prefers dense editor layouts.');
      expect(accepted.sourceEventId, 'event-accept');
      expect((accepted.sourceRefs.single as Map)['kind'], 'event');
      expect(
        accepted.payload['accepted_from_candidate_id'],
        'candidate-accept',
      );
      expect(
        database.memoryCandidates.readById('candidate-accept')!.status,
        'accepted',
      );
      expect(rejected.status, 'rejected');
      expect(
        rejected.payload['review_rejection_reason'],
        'credential_redacted',
      );
      expect(database.memoryCandidates.readReviewQueue(), isEmpty);
    });

    test(
      'memory service persists review actions through local DB adapter',
      () async {
        final repository = LocalDbMemoryRepository(
          database,
          clock: _sequenceClock([
            DateTime.utc(2026, 6, 23, 10, 50),
            DateTime.utc(2026, 6, 23, 10, 55),
            DateTime.utc(2026, 6, 23, 11),
          ]),
        );
        final service = memory.MemoryService(
          repository: repository,
          clock: _sequenceClock([
            DateTime.utc(2026, 6, 23, 11, 5),
            DateTime.utc(2026, 6, 23, 11, 10),
          ]),
          idFactory: () => 'memory-local-review',
        );

        await service.submitProposal(
          memory.MemoryProposal(
            id: 'proposal-local-review',
            key: 'preference.layout',
            body: 'The user likes narrow sidebars.',
            evidence: const <memory.MemorySourceRef>[
              memory.MemorySourceRef(
                sourceType: 'event',
                sourceId: 'event-local-review',
                excerpt: 'narrow sidebars',
              ),
            ],
            memoryType: memory.MemoryType.preference,
            confidence: memory.MemoryConfidence.low,
            sensitivity: memory.MemorySensitivity.low,
          ),
        );

        expect(database.memoryCandidates.readReviewQueue(), hasLength(1));
        final accepted = await service.acceptProposal(
          'proposal-local-review',
          editedBody: 'The user prefers narrow sidebars for writing.',
        );

        expect(accepted.accepted, isTrue);
        expect(
          database.memoryCandidates.readById('proposal-local-review')!.status,
          'accepted',
        );
        final persisted = database.memoryItems.readById('memory-local-review')!;
        expect(persisted.body, 'The user prefers narrow sidebars for writing.');
        expect(persisted.sourceEventId, 'event-local-review');
        expect(
          (persisted.sourceRefs.single as Map)['evidence_text'],
          isNotEmpty,
        );
        expect(
          (await repository.listItems(
            status: memory.MemoryItemStatus.active,
          )).single.body,
          'The user prefers narrow sidebars for writing.',
        );
      },
    );

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

    test(
      'stores durable runtime tasks, runs, packs, permissions, and cache',
      () {
        final createdAt = DateTime.utc(2026, 6, 26, 8);
        final updatedAt = DateTime.utc(2026, 6, 26, 8, 5);
        database.eventLog.append(
          EventLogEntry(
            id: 'event-runtime-1',
            type: 'wn.capture.created',
            actor: 'user',
            createdAt: createdAt,
          ),
        );
        database.packInstallations.insert(
          PackInstallationRecord(
            packId: 'pack.default',
            name: 'Default Capture Loop',
            version: '0.1.0',
            publisher: 'widenote',
            edition: 'official',
            status: 'enabled',
            runtimeStatus: 'idle',
            requestedPermissions: const <Object?>[
              'model.complete',
              'memory.propose',
            ],
            enabledSubscriptionIds: const <Object?>['sub.capture_created'],
            manifest: const <String, Object?>{
              'id': 'pack.default',
              'version': '0.1.0',
            },
            installedAt: createdAt,
            updatedAt: createdAt,
          ),
        );
        database.permissionGrants.insert(
          PermissionGrantRecord(
            id: 'grant-model',
            packId: 'pack.default',
            permissionId: 'model.complete',
            grantedAt: createdAt,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
        final identity = runtimeTaskIdentityKey(
          triggerEventId: 'event-runtime-1',
          subscriptionId: 'sub.capture_created',
          packId: 'pack.default',
          packVersion: '0.1.0',
          handlerId: 'agent.capture_loop',
        );
        database.runtimeTasks.insert(
          RuntimeTaskRecord(
            id: 'task-runtime-1',
            packId: 'pack.default',
            packVersion: '0.1.0',
            agentId: 'agent.capture_loop',
            handlerId: 'agent.capture_loop',
            subscriptionId: 'sub.capture_created',
            triggerEventId: 'event-runtime-1',
            maxAttempts: 2,
            payload: const <String, Object?>{
              'required_permissions': <String>['model.complete'],
            },
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
        database.runtimeRuns.insert(
          RuntimeRunRecord(
            id: 'run-runtime-1',
            taskId: 'task-runtime-1',
            packId: 'pack.default',
            packVersion: '0.1.0',
            agentId: 'agent.capture_loop',
            handlerId: 'agent.capture_loop',
            status: 'succeeded',
            attempt: 1,
            outputEventIds: const <Object?>['event-output-1'],
            startedAt: createdAt,
            completedAt: updatedAt,
          ),
        );
        database.runtimeApprovals.insert(
          RuntimeApprovalRecord(
            id: 'approval-runtime-1',
            packId: 'pack.default',
            agentId: 'agent.capture_loop',
            taskId: 'task-runtime-1',
            runId: 'run-runtime-1',
            toolName: 'memory.propose',
            runMode: 'confirm',
            toolAccess: 'write',
            toolRisk: 'low',
            isExternal: false,
            requiredPermissions: const <Object?>['memory.propose'],
            inputKeys: const <Object?>['source_refs', 'body'],
            sourceRefs: const <Object?>[
              <String, Object?>{'kind': 'event', 'id': 'event-runtime-1'},
            ],
            actionSummary: 'Approve one memory.propose tool invocation.',
            requestedAt: createdAt,
            expiresAt: createdAt.add(const Duration(minutes: 15)),
          ),
        );
        database.contextPacketCaches.insert(
          ContextPacketCacheRecord(
            id: 'cache-runtime-1',
            surface: 'pack_run',
            requestRef: const <String, Object?>{
              'kind': 'event',
              'id': 'event-runtime-1',
            },
            subjectRef: const <String, Object?>{
              'kind': 'capture',
              'id': 'capture-runtime-1',
            },
            sourceRefs: const <Object?>[
              <String, Object?>{'kind': 'event', 'id': 'event-runtime-1'},
            ],
            sourceVersions: const <Object?>[
              <String, Object?>{
                'kind': 'event',
                'id': 'event-runtime-1',
                'hash': 'hash-v1',
              },
            ],
            permissionScope: 'pack.default:model.complete,memory.propose',
            disclosureLevel: 'memory_and_derived',
            generatorId: 'context.packet.builder',
            generatorVersion: '1',
            promptVersion: 'prompt-v1',
            packId: 'pack.default',
            packVersion: '0.1.0',
            agentId: 'agent.capture_loop',
            localDate: '2026-06-26',
            privacyProfile: 'owner_export_safe',
            invalidationKeys: const <Object?>[
              'source:event-runtime-1:hash-v1',
              'memory:memory-1:revision:2',
              'memory:memory-1:tombstone:false',
              'memory:memory-1:sensitivity:low',
              'permission:pack.default:model.complete',
              'generator:context.packet.builder:1',
              'pack:pack.default:0.1.0',
              'prompt:prompt-v1',
              'local_date:2026-06-26',
              'privacy:owner_export_safe',
            ],
            cacheKey: 'pack.default/event-runtime-1',
            packet: const <String, Object?>{'synthetic_context': 'cache body'},
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );

        final task = database.runtimeTasks.readById('task-runtime-1')!;
        expect(task.effectiveIdentityKey, identity);
        expect(task.status, 'queued');
        expect(database.runtimeTasks.readByIdentityKey(identity)!.id, task.id);
        expect(
          database.runtimeRuns
              .readByTask('task-runtime-1')
              .single
              .outputEventIds,
          ['event-output-1'],
        );
        expect(
          database.runtimeApprovals.readPending(now: updatedAt),
          hasLength(1),
        );
        expect(
          database.packInstallations.readById('pack.default')!.status,
          'enabled',
        );
        expect(
          database.permissionGrants.isGranted('pack.default', 'model.complete'),
          isTrue,
        );
        expect(
          database.contextPacketCaches
              .readReusableByCacheKey(
                'pack.default/event-runtime-1',
                now: updatedAt,
              )!
              .packet['synthetic_context'],
          'cache body',
        );

        final revoked = database.permissionGrants.revoke(
          'pack.default',
          'model.complete',
          reason: 'user_revoked',
          revokedAt: updatedAt,
        );
        final deniedCount = database.runtimeTasks.denyActiveForPack(
          'pack.default',
          reason: 'permission_revoked:model.complete',
          updatedAt: updatedAt,
        );
        final invalidatedCount = database.contextPacketCaches.invalidateByKeys(
          const <String>['permission:pack.default:model.complete'],
          invalidatedAt: updatedAt,
          reason: 'permission_revoked',
        );

        expect(revoked.status, 'revoked');
        expect(
          database.permissionGrants.isGranted('pack.default', 'model.complete'),
          isFalse,
        );
        expect(deniedCount, 1);
        expect(
          database.runtimeTasks.readById('task-runtime-1')!.status,
          'denied',
        );
        expect(
          database.runtimeTasks.readById('task-runtime-1')!.error,
          'permission_revoked:model.complete',
        );
        expect(invalidatedCount, 1);
        expect(
          database.contextPacketCaches.readReusableByCacheKey(
            'pack.default/event-runtime-1',
            now: updatedAt,
          ),
          isNull,
        );
      },
    );

    test('does not reuse expired or invalidated context packet caches', () {
      final createdAt = DateTime.utc(2026, 6, 26, 8, 30);
      database.packInstallations.insert(
        PackInstallationRecord(
          packId: 'pack.cache',
          name: 'Cache Pack',
          version: '0.1.0',
          publisher: 'widenote',
          edition: 'official',
          installedAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      for (final id in <String>['expired', 'invalidated']) {
        database.contextPacketCaches.insert(
          ContextPacketCacheRecord(
            id: 'cache-$id',
            surface: 'chat',
            sourceRefs: const <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-cache'},
            ],
            sourceVersions: const <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-cache'},
            ],
            permissionScope: 'pack.cache:model.complete',
            disclosureLevel: 'memory',
            generatorId: 'context.packet.builder',
            generatorVersion: '1',
            promptVersion: 'prompt-v1',
            packId: 'pack.cache',
            packVersion: '0.1.0',
            invalidationKeys: <Object?>['source:capture-cache:$id'],
            cacheKey: 'cache-key-$id',
            packet: <String, Object?>{'text': id},
            expiresAt: id == 'expired'
                ? createdAt.subtract(const Duration(minutes: 1))
                : null,
            invalidatedAt: id == 'invalidated' ? createdAt : null,
            status: id == 'invalidated' ? 'invalidated' : 'active',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
      }

      expect(
        database.contextPacketCaches.readReusableByCacheKey(
          'cache-key-expired',
          now: createdAt,
        ),
        isNull,
      );
      expect(
        database.contextPacketCaches.readReusableByCacheKey(
          'cache-key-invalidated',
          now: createdAt,
        ),
        isNull,
      );
    });

    test('writes capture, event, and initial tasks in one transaction', () {
      final createdAt = DateTime.utc(2026, 6, 26, 9);
      database.insertCaptureEventAndTasks(
        capture: CaptureRecord(
          id: 'capture-transaction',
          sourceType: 'manual',
          payload: const <String, Object?>{'text': 'transactional enqueue'},
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        event: EventLogEntry(
          id: 'event-transaction',
          type: 'wn.capture.created',
          actor: 'user',
          sourceCaptureId: 'capture-transaction',
          createdAt: createdAt,
        ),
        tasks: <RuntimeTaskRecord>[
          RuntimeTaskRecord(
            id: 'task-transaction',
            packId: 'pack.default',
            packVersion: '0.1.0',
            agentId: 'agent.capture_loop',
            handlerId: 'agent.capture_loop',
            subscriptionId: 'sub.capture_created',
            triggerEventId: 'event-transaction',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ],
      );

      expect(database.captures.readById('capture-transaction'), isNotNull);
      expect(database.eventLog.readById('event-transaction'), isNotNull);
      expect(database.runtimeTasks.readById('task-transaction'), isNotNull);

      expect(
        () => database.insertCaptureEventAndTasks(
          capture: CaptureRecord(
            id: 'capture-rollback',
            sourceType: 'manual',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
          event: EventLogEntry(
            id: 'event-rollback',
            type: 'wn.capture.created',
            actor: 'user',
            createdAt: createdAt,
          ),
          tasks: <RuntimeTaskRecord>[
            RuntimeTaskRecord(
              id: 'task-rollback',
              packId: 'pack.default',
              packVersion: '0.1.0',
              agentId: 'agent.capture_loop',
              handlerId: 'agent.capture_loop',
              subscriptionId: 'sub.capture_created',
              triggerEventId: 'event-rollback',
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
            RuntimeTaskRecord(
              id: 'task-rollback',
              packId: 'pack.todo',
              packVersion: '0.1.0',
              agentId: 'agent.todo_loop',
              handlerId: 'agent.todo_loop',
              subscriptionId: 'sub.todo_capture_created',
              triggerEventId: 'event-rollback',
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          ],
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(database.captures.readById('capture-rollback'), isNull);
      expect(database.eventLog.readById('event-rollback'), isNull);
      expect(database.runtimeTasks.readById('task-rollback'), isNull);
    });

    test('enforces runtime foreign key actions', () {
      final createdAt = DateTime.utc(2026, 6, 26, 9, 30);
      database.eventLog.append(
        EventLogEntry(
          id: 'event-fk',
          type: 'wn.capture.created',
          actor: 'user',
          createdAt: createdAt,
        ),
      );
      database.packInstallations.insert(
        PackInstallationRecord(
          packId: 'pack.fk',
          name: 'Foreign Key Pack',
          version: '0.1.0',
          publisher: 'widenote',
          edition: 'official',
          installedAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      database.permissionGrants.insert(
        PermissionGrantRecord(
          id: 'grant-fk',
          packId: 'pack.fk',
          permissionId: 'model.complete',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      database.runtimeTasks.insert(
        RuntimeTaskRecord(
          id: 'task-fk',
          packId: 'pack.fk',
          packVersion: '0.1.0',
          agentId: 'agent.fk',
          handlerId: 'agent.fk',
          subscriptionId: 'sub.fk',
          triggerEventId: 'event-fk',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      database.runtimeRuns.insert(
        RuntimeRunRecord(
          id: 'run-fk',
          taskId: 'task-fk',
          packId: 'pack.fk',
          packVersion: '0.1.0',
          agentId: 'agent.fk',
          handlerId: 'agent.fk',
          status: 'running',
          attempt: 1,
          startedAt: createdAt,
        ),
      );
      database.contextPacketCaches.insert(
        ContextPacketCacheRecord(
          id: 'cache-fk',
          surface: 'pack_run',
          sourceRefs: const <Object?>[
            <String, Object?>{'kind': 'event', 'id': 'event-fk'},
          ],
          sourceVersions: const <Object?>[
            <String, Object?>{'kind': 'event', 'id': 'event-fk'},
          ],
          permissionScope: 'pack.fk:model.complete',
          disclosureLevel: 'memory',
          generatorId: 'context.packet.builder',
          generatorVersion: '1',
          promptVersion: 'prompt-v1',
          packId: 'pack.fk',
          packVersion: '0.1.0',
          invalidationKeys: const <Object?>['source:event-fk'],
          cacheKey: 'cache-fk',
          packet: const <String, Object?>{'text': 'fk'},
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      database.rawDatabase.execute(
        "DELETE FROM event_log WHERE id = 'event-fk';",
      );
      expect(database.runtimeTasks.readById('task-fk'), isNull);
      expect(database.runtimeRuns.readById('run-fk'), isNull);

      database.rawDatabase.execute(
        "DELETE FROM pack_installations WHERE pack_id = 'pack.fk';",
      );
      expect(database.permissionGrants.readById('grant-fk'), isNull);
      expect(database.contextPacketCaches.readById('cache-fk')!.packId, isNull);
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
        database.attachments.insert(
          AttachmentRecord(
            id: 'attachment-$index',
            captureId: 'capture-$index',
            assetKind: 'photo',
            storagePath: 'media/originals/attachment-$index.jpg',
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
        database.cards.insert(
          CardRecord(
            id: 'card-$index',
            cardKind: 'capture_summary',
            title: 'Card $index',
            body: 'Card $index',
            sourceRefs: <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-$index'},
            ],
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.insights.insert(
          InsightRecord(
            id: 'insight-$index',
            insightKind: 'count',
            title: 'Insight $index',
            summary: 'Insight $index',
            sourceRefs: <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-$index'},
            ],
            metricValue: index,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.chatSessions.insert(
          ChatSessionRecord(
            id: 'session-$index',
            title: 'Session $index',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.chatMessages.insert(
          ChatMessageRecord(
            id: 'message-$index',
            sessionId: 'session-$index',
            role: 'user',
            body: 'Message $index',
            createdAt: timestamp,
          ),
        );
        database.modelProviderConfigs.insert(
          ModelProviderConfigRecord(
            id: 'provider-$index',
            providerKind: 'openAiCompatible',
            displayName: 'Provider $index',
            endpoint: 'https://example.com/v1/chat/completions',
            model: 'model-$index',
            capabilities: const <Object?>['chat'],
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
        database.packInstallations.insert(
          PackInstallationRecord(
            packId: 'pack.$index',
            name: 'Pack $index',
            version: '0.1.$index',
            publisher: 'widenote',
            edition: 'official',
            installedAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.permissionGrants.insert(
          PermissionGrantRecord(
            id: 'grant-$index',
            packId: 'pack.$index',
            permissionId: 'model.complete',
            grantedAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.runtimeTasks.insert(
          RuntimeTaskRecord(
            id: 'task-$index',
            packId: 'pack.$index',
            packVersion: '0.1.$index',
            agentId: 'agent.$index',
            handlerId: 'agent.$index',
            subscriptionId: 'sub.$index',
            triggerEventId: 'event-$index',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        database.runtimeRuns.insert(
          RuntimeRunRecord(
            id: 'run-$index',
            taskId: 'task-$index',
            packId: 'pack.$index',
            packVersion: '0.1.$index',
            agentId: 'agent.$index',
            handlerId: 'agent.$index',
            status: 'succeeded',
            attempt: 1,
            startedAt: timestamp,
            completedAt: timestamp,
          ),
        );
        database.runtimeApprovals.insert(
          RuntimeApprovalRecord(
            id: 'approval-$index',
            packId: 'pack.$index',
            agentId: 'agent.$index',
            taskId: 'task-$index',
            runId: 'run-$index',
            toolName: 'todo.suggest',
            runMode: 'confirm',
            toolAccess: 'write',
            toolRisk: 'low',
            isExternal: false,
            requestedAt: timestamp,
          ),
        );
        database.contextPacketCaches.insert(
          ContextPacketCacheRecord(
            id: 'cache-$index',
            surface: 'chat',
            sourceRefs: <Object?>[
              <String, Object?>{'kind': 'event', 'id': 'event-$index'},
            ],
            sourceVersions: <Object?>[
              <String, Object?>{'kind': 'event', 'id': 'event-$index'},
            ],
            permissionScope: 'pack.$index:model.complete',
            disclosureLevel: 'memory',
            generatorId: 'context.packet.builder',
            generatorVersion: '1',
            promptVersion: 'prompt-v1',
            packId: 'pack.$index',
            packVersion: '0.1.$index',
            invalidationKeys: <Object?>['source:event-$index'],
            cacheKey: 'chat/event-$index',
            packet: <String, Object?>{'text': 'cache $index'},
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
        database.attachments.readAll(limit: 1, offset: 1).single.id,
        'attachment-1',
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
      expect(database.cards.readAll(limit: 1, offset: 1).single.id, 'card-1');
      expect(
        database.insights.readAll(limit: 1, offset: 1).single.id,
        'insight-1',
      );
      expect(
        database.chatSessions.readAll(limit: 1, offset: 1).single.id,
        'session-1',
      );
      expect(
        database.chatMessages.readAll(limit: 1, offset: 1).single.id,
        'message-1',
      );
      expect(
        database.modelProviderConfigs.readAll(limit: 1, offset: 1).single.id,
        'provider-1',
      );
      expect(database.todos.readAll(limit: 1, offset: 1).single.id, 'todo-1');
      expect(
        database.packInstallations.readAll(limit: 1, offset: 1).single.packId,
        'pack.1',
      );
      expect(
        database.permissionGrants.readAll(limit: 1, offset: 1).single.id,
        'grant-1',
      );
      expect(
        database.runtimeTasks.readAll(limit: 1, offset: 1).single.id,
        'task-1',
      );
      expect(
        database.runtimeRuns.readAll(limit: 1, offset: 1).single.id,
        'run-1',
      );
      expect(
        database.runtimeApprovals.readAll(limit: 1, offset: 1).single.id,
        'approval-1',
      );
      expect(
        database.contextPacketCaches.readAll(limit: 1, offset: 1).single.id,
        'cache-1',
      );
      expect(
        database.traceEvents.readAll(limit: 1, offset: 1).single.id,
        'trace-1',
      );
      expect(
        () => database.eventLog.readAll(limit: -1),
        throwsA(isA<RangeError>()),
      );
    });

    test('migrates v1 contract columns to current schema version', () {
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

      expect(migrated.schemaVersion, LocalDbSchema.currentVersion);
      final event = migrated.eventLog.readById('event-old')!;
      expect(event.privacy, 'local_only');
      expect(event.subjectRefKind, 'capture');
      expect(event.subjectRefId, 'capture-old');

      final trace = migrated.traceEvents.readById('trace-old')!;
      expect(trace.traceType, 'run_started');
      expect(trace.runId, 'run-old');
      expect(trace.severity, 'warn');
      expect(migrated.cards.readAll(), isEmpty);
      expect(migrated.insights.readAll(), isEmpty);
      expect(migrated.attachments.readAll(), isEmpty);
      expect(migrated.chatSessions.readAll(), isEmpty);
      expect(migrated.modelProviderConfigs.readAll(), isEmpty);
      expect(migrated.runtimeTasks.readAll(), isEmpty);
      expect(migrated.runtimeRuns.readAll(), isEmpty);
      expect(migrated.runtimeApprovals.readAll(), isEmpty);
      expect(migrated.packInstallations.readAll(), isEmpty);
      expect(migrated.permissionGrants.readAll(), isEmpty);
      expect(migrated.contextPacketCaches.readAll(), isEmpty);
      expect(migrated.embeddingProviderConfigs.readAll(), isEmpty);
      expect(migrated.searchIndex.listDocuments(), isEmpty);
      expect(
        rawDatabase
            .select('PRAGMA table_info(model_provider_configs);')
            .map((row) => row['name']),
        contains('api_key'),
      );
      expect(
        rawDatabase
            .select("SELECT name FROM sqlite_master WHERE type = 'table';")
            .map((row) => row['name']),
        containsAll(<String>[
          'embedding_provider_configs',
          'search_documents',
          'search_chunks',
          'search_chunk_embeddings',
          'search_chunks_fts',
        ]),
      );
      expect(
        rawDatabase
            .select("SELECT name FROM sqlite_master WHERE type = 'index';")
            .map((row) => row['name']),
        containsAll(<String>[
          'runtime_tasks_identity_key_idx',
          'runtime_tasks_pack_status_idx',
          'runtime_runs_task_idx',
          'runtime_approvals_pack_status_idx',
          'runtime_approvals_run_status_idx',
          'pack_installations_status_idx',
          'permission_grants_pack_status_idx',
          'context_packet_cache_key_idx',
          'memory_items_created_at_idx',
          'memory_candidates_created_at_idx',
          'context_packet_cache_created_at_idx',
          'embedding_provider_configs_default_idx',
          'search_documents_kind_status_idx',
          'search_chunks_doc_idx',
          'search_chunks_kind_status_idx',
          'search_chunk_embeddings_model_idx',
        ]),
      );
      expect(
        rawDatabase
            .select('PRAGMA foreign_key_list(runtime_tasks);')
            .map((row) => row['table']),
        contains('event_log'),
      );
      expect(
        rawDatabase
            .select('PRAGMA foreign_key_list(runtime_runs);')
            .map((row) => row['table']),
        contains('runtime_tasks'),
      );
      expect(
        rawDatabase
            .select('PRAGMA foreign_key_list(permission_grants);')
            .map((row) => row['table']),
        contains('pack_installations'),
      );
      expect(
        rawDatabase
            .select('PRAGMA foreign_key_list(runtime_approval_requests);')
            .map((row) => row['table']),
        containsAll(<String>[
          'pack_installations',
          'runtime_tasks',
          'runtime_runs',
        ]),
      );
      expect(
        rawDatabase
            .select('PRAGMA foreign_key_list(search_chunks);')
            .map((row) => row['table']),
        contains('search_documents'),
      );
      expect(
        rawDatabase
            .select('PRAGMA foreign_key_list(search_chunk_embeddings);')
            .map((row) => row['table']),
        contains('search_chunks'),
      );
      LocalDbMigrator.bootstrap(rawDatabase);
      expect(migrated.schemaVersion, LocalDbSchema.currentVersion);
    });

    test('rolls back a failed v8 migration without bumping user_version', () {
      final rawDatabase = sqlite3.openInMemory();
      addTearDown(rawDatabase.dispose);
      LocalDbMigrator.bootstrap(rawDatabase, targetVersion: 7);
      rawDatabase.execute('''
CREATE TABLE runtime_tasks (
  id TEXT PRIMARY KEY
);
''');

      expect(
        () => LocalDbMigrator.bootstrap(rawDatabase),
        throwsA(isA<SqliteException>()),
      );

      expect(LocalDbMigrator.readSchemaVersion(rawDatabase), 7);
      expect(
        rawDatabase
            .select("SELECT name FROM sqlite_master WHERE type = 'table';")
            .map((row) => row['name']),
        isNot(contains('runtime_runs')),
      );
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
              agentDefinitions: <String, runtime.AgentDefinition>{
                'agent.capture_loop': runtime.AgentDefinition(
                  id: 'agent.capture_loop',
                  requiredPermissions: <String>{
                    runtime.ModelPermissions.complete,
                    'memory.propose',
                  },
                  outputEvents: <String>{runtime.WnEventTypes.memoryProposed},
                ),
              },
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
          type: 'wn.capture.ignored',
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

    test(
      'runtime event store rejects duplicate capture-created subjects',
      () async {
        final eventStore = LocalDbEventStore(database);
        final first = runtime.WnEvent(
          id: 'event-capture-first',
          type: runtime.WnEventTypes.captureCreated,
          schemaVersion: 1,
          actor: runtime.WnActor.user,
          subjectRef: const runtime.SubjectRef(
            kind: 'capture',
            id: 'capture-dedupe',
          ),
          payload: const <String, Object?>{'text': 'first'},
          privacy: runtime.WnPrivacy.localOnly,
          deviceId: 'device-db',
          createdAt: DateTime.utc(2026, 7, 2, 1),
        );
        final duplicate = runtime.WnEvent(
          id: 'event-capture-second',
          type: runtime.WnEventTypes.captureCreated,
          schemaVersion: 1,
          actor: runtime.WnActor.user,
          subjectRef: const runtime.SubjectRef(
            kind: 'capture',
            id: 'capture-dedupe',
          ),
          payload: const <String, Object?>{'text': 'second'},
          privacy: runtime.WnPrivacy.localOnly,
          deviceId: 'device-db',
          createdAt: DateTime.utc(2026, 7, 2, 1, 1),
        );

        await eventStore.append(first);

        expect(() => eventStore.append(duplicate), throwsA(isA<StateError>()));
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

String _testCredential() {
  return String.fromCharCodes(<int>[
    116,
    101,
    115,
    116,
    45,
    109,
    105,
    109,
    111,
    45,
    107,
    101,
    121,
  ]);
}

DateTime Function() _sequenceClock(List<DateTime> values) {
  var index = 0;
  return () {
    final value = values[index];
    if (index < values.length - 1) {
      index += 1;
    }
    return value;
  };
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
