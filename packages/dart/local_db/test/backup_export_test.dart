import 'dart:convert';

import 'package:test/test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

void main() {
  group('LocalBackupService', () {
    test('exports a manifest and imports local data round-trip', () {
      final source = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      _seedBackupSource(source);

      final exportedAt = DateTime.utc(2026, 6, 24, 9);
      final json = LocalBackupService(
        source,
        clock: () => exportedAt,
      ).exportJson();
      final backup = LocalBackupCodec.decode(json);

      expect(backup.manifest.format, LocalBackupCodec.formatId);
      expect(backup.manifest.formatVersion, 2);
      expect(
        backup.manifest.localDbSchemaVersion,
        LocalDbSchema.currentVersion,
      );
      expect(backup.manifest.createdAt, exportedAt);
      expect(backup.manifest.recordCounts, containsPair('event_log', 1));
      expect(backup.manifest.recordCounts, containsPair('captures', 1));
      expect(backup.manifest.recordCounts, containsPair('attachments', 1));
      expect(backup.manifest.recordCounts, containsPair('memory_items', 1));
      expect(
        backup.manifest.recordCounts,
        containsPair('memory_candidates', 1),
      );
      expect(backup.manifest.recordCounts, containsPair('cards', 1));
      expect(backup.manifest.recordCounts, containsPair('insights', 1));
      expect(backup.manifest.recordCounts, containsPair('chat_sessions', 1));
      expect(backup.manifest.recordCounts, containsPair('chat_messages', 2));
      expect(
        backup.manifest.recordCounts,
        containsPair('model_provider_configs', 1),
      );
      expect(backup.modelProviderConfigs.single.apiKey, _backupCredential());
      expect(backup.manifest.recordCounts, containsPair('todos', 1));
      expect(backup.manifest.recordCounts, containsPair('trace_events', 1));

      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(target.close);
      LocalBackupService(target).importBackup(backup);

      final capture = target.captures.readById('capture-backup')!;
      expect(capture.sourceType, 'manual');
      expect(capture.sourceId, 'composer');
      expect(capture.payload['text'], 'Remember the backup demo.');

      final attachment = target.attachments.readById('attachment-backup')!;
      expect(attachment.captureId, 'capture-backup');
      expect(attachment.assetKind, 'photo');
      expect(attachment.storagePath, 'media/originals/attachment-backup.jpg');

      final event = target.eventLog.readById('event-backup')!;
      expect(event.type, 'wn.capture.created');
      expect(event.subjectRefKind, 'capture');
      expect(event.subjectRefId, 'capture-backup');
      expect(event.privacy, 'local_only');

      final memory = target.memoryItems.readById('memory-backup')!;
      expect(memory.key, 'project.backup');
      expect(memory.body, 'WideNote has a local backup demo.');
      expect(memory.revision, 3);
      expect(memory.tombstone, isFalse);
      expect((memory.sourceRefs.single as Map)['id'], 'event-backup');

      final candidate = target.memoryCandidates.readById('candidate-backup')!;
      expect(candidate.status, 'needs_review');
      expect(candidate.memoryType, 'project');
      expect(candidate.payload['policy_reason'], 'review');

      final card = target.cards.readById('card-backup')!;
      expect(card.cardKind, 'summary');
      expect(card.title, 'Backup demo');
      expect((card.sourceRefs.single as Map)['id'], 'capture-backup');

      final insight = target.insights.readById('insight-backup')!;
      expect(insight.insightKind, 'weekly_summary');
      expect(insight.metricLabel, 'portable records');
      expect(insight.metricValue, 1);

      final session = target.chatSessions.readById('session-backup')!;
      expect(session.title, 'Backup conversation');
      final messages = target.chatMessages.readBySession('session-backup');
      expect(messages.map((message) => message.role), ['user', 'assistant']);
      expect((messages.last.sourceRefs.single as Map)['id'], 'memory-backup');

      final provider = target.modelProviderConfigs.readDefault()!;
      expect(provider.id, 'provider-backup');
      expect(provider.hasApiKey, isTrue);
      expect(provider.apiKey, _backupCredential());
      expect(provider.payload.toString(), isNot(contains('sk-')));

      final todo = target.todos.readById('todo-backup')!;
      expect(todo.status, 'open');
      expect(todo.payload['title'], 'Test backup import');

      final trace = target.traceEvents.readById('trace-backup')!;
      expect(trace.traceType, 'runtime.handler.output');
      expect(trace.runId, 'run-backup');
      expect(trace.severity, 'debug');
      expect(trace.message, 'Generated fake output');
      expect(trace.durationMs, 12.5);
    });

    test('rejects a newer local DB schema during import', () {
      final source = WideNoteLocalDatabase.inMemory();
      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      addTearDown(target.close);

      final json = LocalBackupService(source).exportJson();
      final edited = _editBackupJson(json, (root) {
        final manifest = root['manifest']! as Map<String, Object?>;
        manifest['local_db_schema_version'] = LocalDbSchema.currentVersion + 1;
      });
      final backup = LocalBackupCodec.decode(edited);

      expect(
        () => LocalBackupService(target).importBackup(backup),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects importing over existing rows before partial writes', () {
      final source = WideNoteLocalDatabase.inMemory();
      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      addTearDown(target.close);
      _seedBackupSource(source);
      target.captures.insert(
        CaptureRecord(
          id: 'capture-backup',
          sourceType: 'manual',
          payload: const <String, Object?>{'text': 'existing row'},
          createdAt: DateTime.utc(2026, 6, 24),
          updatedAt: DateTime.utc(2026, 6, 24),
        ),
      );

      final backup = LocalBackupCodec.decode(
        LocalBackupService(source).exportJson(),
      );

      expect(
        () => LocalBackupService(target).importBackup(backup),
        throwsA(isA<StateError>()),
      );
      expect(target.captures.readAll(), hasLength(1));
      expect(target.eventLog.readAll(), isEmpty);
      expect(target.modelProviderConfigs.readAll(), isEmpty);
    });

    test('migrates v1 backups that predate attachment rows', () {
      final source = WideNoteLocalDatabase.inMemory();
      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      addTearDown(target.close);
      _seedBackupSource(source);

      final v1Json = _editBackupJson(
        LocalBackupService(source).exportJson(),
        (root) {
          final manifest = root['manifest']! as Map<String, Object?>;
          manifest['format_version'] = 1;
          final counts = manifest['record_counts']! as Map<String, Object?>;
          counts.remove('attachments');
          root.remove('attachments');
        },
      );
      final backup = LocalBackupCodec.decode(v1Json);

      expect(backup.manifest.formatVersion, 1);
      expect(backup.attachments, isEmpty);
      expect(backup.manifest.recordCounts, containsPair('attachments', 0));

      LocalBackupService(target).importBackup(backup);

      expect(target.captures.readById('capture-backup'), isNotNull);
      expect(target.todos.readById('todo-backup'), isNotNull);
      expect(target.attachments.readAll(), isEmpty);
    });
  });

  group('LocalBackupCodec', () {
    test('rejects corrupt JSON', () {
      expect(
        () => LocalBackupCodec.decode('{not-json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported format versions', () {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);

      final json = LocalBackupService(database).exportJson();
      final edited = _editBackupJson(json, (root) {
        final manifest = root['manifest']! as Map<String, Object?>;
        manifest['format_version'] = LocalBackupCodec.currentFormatVersion + 1;
      });

      expect(
        () => LocalBackupCodec.decode(edited),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects missing backup sections', () {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);

      final json = LocalBackupService(database).exportJson();
      final edited = _editBackupJson(json, (root) {
        root.remove('trace_events');
      });

      expect(
        () => LocalBackupCodec.decode(edited),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects current backups missing the attachments section', () {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);

      final json = LocalBackupService(database).exportJson();
      final edited = _editBackupJson(json, (root) {
        root.remove('attachments');
      });

      expect(
        () => LocalBackupCodec.decode(edited),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate ids inside a backup section', () {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _seedBackupSource(database);

      final json = LocalBackupService(database).exportJson();
      final edited = _editBackupJson(json, (root) {
        final manifest = root['manifest']! as Map<String, Object?>;
        final counts = manifest['record_counts']! as Map<String, Object?>;
        counts['captures'] = 2;
        final captures = root['captures']! as List<Object?>;
        captures.add(captures.single);
      });
      final backup = LocalBackupCodec.decode(edited);
      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(target.close);

      expect(
        () => LocalBackupService(target).importBackup(backup),
        throwsA(isA<FormatException>()),
      );
      expect(target.captures.readAll(), isEmpty);
    });

    test('rejects manifest count mismatches', () {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);

      final json = LocalBackupService(database).exportJson();
      final edited = _editBackupJson(json, (root) {
        final manifest = root['manifest']! as Map<String, Object?>;
        final counts = manifest['record_counts']! as Map<String, Object?>;
        counts['captures'] = 99;
      });

      expect(
        () => LocalBackupCodec.decode(edited),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

void _seedBackupSource(WideNoteLocalDatabase database) {
  final createdAt = DateTime.utc(2026, 6, 24, 8);
  final updatedAt = DateTime.utc(2026, 6, 24, 8, 30);

  database.captures.insert(
    CaptureRecord(
      id: 'capture-backup',
      sourceType: 'manual',
      sourceId: 'composer',
      payload: const <String, Object?>{
        'text': 'Remember the backup demo.',
        'labels': <String>['backup', 'round-trip'],
      },
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.attachments.insert(
    AttachmentRecord(
      id: 'attachment-backup',
      captureId: 'capture-backup',
      sourceEventId: 'event-backup',
      assetKind: 'photo',
      mimeType: 'image/jpeg',
      storagePath: 'media/originals/attachment-backup.jpg',
      originalFileName: 'backup-demo.jpg',
      sha256: 'hash-backup-attachment',
      byteLength: 2048,
      payload: const <String, Object?>{
        'preview_text': 'backup attachment preview',
      },
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.eventLog.append(
    EventLogEntry(
      id: 'event-backup',
      type: 'wn.capture.created',
      actor: 'user',
      sourceCaptureId: 'capture-backup',
      subjectRef: const <String, Object?>{
        'kind': 'capture',
        'id': 'capture-backup',
        'uri': 'wn://capture/capture-backup',
      },
      payload: const <String, Object?>{'text_length': 25},
      createdAt: createdAt,
    ),
  );
  database.memoryItems.insert(
    MemoryItemRecord(
      id: 'memory-backup',
      key: 'project.backup',
      sourceCaptureId: 'capture-backup',
      sourceEventId: 'event-backup',
      body: 'WideNote has a local backup demo.',
      sourceRefs: const <Object?>[
        <String, Object?>{
          'kind': 'event',
          'id': 'event-backup',
          'evidence_text': 'backup demo',
        },
      ],
      memoryType: 'project',
      confidence: 'high',
      sensitivity: 'low',
      revision: 3,
      payload: const <String, Object?>{
        'metadata': <String, Object?>{'accepted_by': 'fake_policy'},
      },
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.memoryCandidates.insert(
    MemoryCandidateRecord(
      id: 'candidate-backup',
      key: 'project.backup.followup',
      sourceCaptureId: 'capture-backup',
      sourceEventId: 'event-backup',
      status: 'needs_review',
      body: 'Backups should keep local records portable.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-backup'},
      ],
      memoryType: 'project',
      confidence: 'medium',
      sensitivity: 'low',
      payload: const <String, Object?>{'policy_reason': 'review'},
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.cards.insert(
    CardRecord(
      id: 'card-backup',
      cardKind: 'summary',
      title: 'Backup demo',
      body: 'The backup demo keeps WideNote records portable.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-backup'},
      ],
      payload: const <String, Object?>{'tone': 'fake_fixture'},
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.insights.insert(
    InsightRecord(
      id: 'insight-backup',
      insightKind: 'weekly_summary',
      title: 'Portable records',
      summary: 'One fake capture is covered by backup export.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'card', 'id': 'card-backup'},
      ],
      metricLabel: 'portable records',
      metricValue: 1,
      payload: const <String, Object?>{'confidence': 'fake'},
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.chatSessions.insert(
    ChatSessionRecord(
      id: 'session-backup',
      title: 'Backup conversation',
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.chatMessages
    ..insert(
      ChatMessageRecord(
        id: 'message-backup-user',
        sessionId: 'session-backup',
        role: 'user',
        body: 'What should the backup include?',
        createdAt: createdAt,
      ),
    )
    ..insert(
      ChatMessageRecord(
        id: 'message-backup-assistant',
        sessionId: 'session-backup',
        role: 'assistant',
        body: 'It should include source-linked records and Memory.',
        sourceRefs: const <Object?>[
          <String, Object?>{'kind': 'memory', 'id': 'memory-backup'},
        ],
        createdAt: updatedAt,
      ),
    );
  database.modelProviderConfigs.insert(
    ModelProviderConfigRecord(
      id: 'provider-backup',
      providerKind: 'mimo',
      displayName: 'Xiaomi MIMO',
      endpoint: 'https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages',
      model: 'mimo-v2.5-pro',
      isDefault: true,
      hasApiKey: true,
      apiKey: _backupCredential(),
      capabilities: const <Object?>['chat', 'completion'],
      payload: const <String, Object?>{'secret_storage': 'local_db_backup'},
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.todos.insert(
    TodoRecord(
      id: 'todo-backup',
      sourceCaptureId: 'capture-backup',
      sourceEventId: 'event-backup',
      payload: const <String, Object?>{'title': 'Test backup import'},
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.traceEvents.insert(
    TraceEventRecord(
      id: 'trace-backup',
      name: 'runtime.handler.output',
      level: 'debug',
      traceTypeOverride: 'runtime.handler.output',
      runIdOverride: 'run-backup',
      severityOverride: 'debug',
      message: 'Generated fake output',
      sourceEventId: 'event-backup',
      sourceRunId: 'run-backup',
      sourceTaskId: 'task-backup',
      packId: 'pack.default',
      agentId: 'agent.capture',
      parentTraceId: 'trace-parent',
      durationMs: 12.5,
      payload: const <String, Object?>{'output_count': 1},
      createdAt: updatedAt,
    ),
  );
}

String _backupCredential() {
  return String.fromCharCodes(<int>[
    98,
    97,
    99,
    107,
    117,
    112,
    45,
    97,
    112,
    105,
    45,
    107,
    101,
    121,
  ]);
}

String _editBackupJson(
  String json,
  void Function(Map<String, Object?> root) edit,
) {
  final root = jsonDecode(json) as Map<String, Object?>;
  edit(root);
  return jsonEncode(root);
}
