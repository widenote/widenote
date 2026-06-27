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

      expect(backup.manifest.kind, 'backup_manifest');
      expect(backup.manifest.schemaVersion, 1);
      expect(backup.manifest.format, LocalBackupCodec.formatId);
      expect(backup.manifest.formatVersion, 4);
      expect(backup.manifest.backupMode, LocalBackupMode.safe);
      expect(backup.manifest.includesSecrets, isFalse);
      expect(backup.manifest.encryption, isNull);
      expect(
        backup.manifest.localDbSchemaVersion,
        LocalDbSchema.currentVersion,
      );
      expect(backup.manifest.createdAt, exportedAt);
      expect(backup.manifest.recordCounts, containsPair('event_log', 1));
      expect(backup.manifest.recordCounts, containsPair('captures', 1));
      expect(backup.manifest.recordCounts, containsPair('attachments', 1));
      expect(
        backup.manifest.recordCounts,
        containsPair('derived_artifacts', 1),
      );
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
      expect(backup.manifest.recordCounts, containsPair('todos', 1));
      expect(backup.manifest.recordCounts, containsPair('runtime_tasks', 1));
      expect(backup.manifest.recordCounts, containsPair('runtime_runs', 1));
      expect(
        backup.manifest.recordCounts,
        containsPair('pack_installations', 1),
      );
      expect(
        backup.manifest.recordCounts,
        containsPair('permission_grants', 1),
      );
      expect(
        backup.manifest.recordCounts,
        containsPair('context_packet_cache', 1),
      );
      expect(backup.manifest.recordCounts, containsPair('trace_events', 1));
      expect(backup.modelProviderConfigs.single.hasApiKey, isTrue);
      expect(backup.modelProviderConfigs.single.apiKey, isEmpty);

      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(target.close);
      final report = LocalBackupService(target).importBackup(backup);

      expect(report.backupMode, LocalBackupMode.safe);
      expect(report.includesSecrets, isFalse);
      expect(report.providerConfigsRestored, 1);
      expect(report.providerConfigsNeedingCredentialReentry, 1);
      expect(report.requiresCredentialReentry, isTrue);
      expect(report.packInstallationsRestored, 1);
      expect(report.permissionGrantsRestored, 1);
      expect(report.runtimeTasksRestored, 1);
      expect(report.runtimeRunsRestored, 1);
      expect(report.contextPacketCachesRestored, 1);

      final capture = target.captures.readById('capture-backup')!;
      expect(capture.sourceType, 'manual');
      expect(capture.sourceId, 'composer');
      expect(capture.payload['text'], 'Remember the backup demo.');

      final attachment = target.attachments.readById('attachment-backup')!;
      expect(attachment.captureId, 'capture-backup');
      expect(attachment.assetKind, 'photo');
      expect(attachment.storagePath, 'media/originals/attachment-backup.jpg');

      final artifact = target.derivedArtifacts.readById('artifact-backup-ocr')!;
      expect(artifact.sourceCaptureId, 'capture-backup');
      expect(artifact.sourceAttachmentId, 'attachment-backup');
      expect(artifact.artifactKind, 'ocr_text');
      expect(artifact.body, contains('restore derived evidence'));

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
      expect(provider.apiKey, isEmpty);
      expect(provider.payload['secret_storage'], 'local_db_backup');
      expect(provider.payload['payload_omitted'], isTrue);
      expect(provider.payload.toString(), isNot(contains(_backupCredential())));

      final pack = target.packInstallations.readById('pack.default')!;
      expect(pack.status, 'enabled');
      expect(pack.runtimeStatus, 'queued');
      expect(pack.version, '0.1.0');

      final grant = target.permissionGrants.readById('grant-backup')!;
      expect(grant.status, 'revoked');
      expect(grant.reason, 'user_revoked');
      expect(
        target.permissionGrants.isGranted('pack.default', 'model.complete'),
        isFalse,
      );

      final task = target.runtimeTasks.readById('task-backup')!;
      expect(task.status, 'denied');
      expect(task.packVersion, '0.1.0');
      expect(task.effectiveIdentityKey, contains('pack:pack.default@0.1.0'));
      expect(task.effectiveIdentityKey, contains('handler:agent.capture'));

      final run = target.runtimeRuns.readById('run-backup')!;
      expect(run.status, 'denied');
      expect(run.taskId, 'task-backup');

      final cache = target.contextPacketCaches.readById('cache-backup')!;
      expect(cache.status, 'active');
      expect(
        target.contextPacketCaches.readReusableByCacheKey(
          'chat/capture-backup',
          now: DateTime.utc(2026, 6, 24, 9),
        ),
        isNull,
      );

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

    test(
      'omits provider secrets from safe backup and blocks plaintext full export',
      () {
        final source = WideNoteLocalDatabase.inMemory();
        addTearDown(source.close);
        _seedBackupSource(source);

        final safeJson = LocalBackupService(source).exportJson();
        final safe = LocalBackupCodec.decode(safeJson);

        expect(safe.manifest.backupMode, LocalBackupMode.safe);
        expect(safe.manifest.includesSecrets, isFalse);
        expect(safe.modelProviderConfigs.single.hasApiKey, isTrue);
        expect(safe.modelProviderConfigs.single.apiKey, isEmpty);
        expect(
          safe.modelProviderConfigs.single.payload.toString(),
          isNot(contains(_backupCredential())),
        );
        expect(
          safe.modelProviderConfigs.single.payload['secret_storage'],
          'local_db_backup',
        );
        expect(
          safe.modelProviderConfigs.single.payload['payload_omitted'],
          isTrue,
        );
        expect(
          safe.modelProviderConfigs.single.payload,
          isNot(contains('nested')),
        );
        expect(
          safe.modelProviderConfigs.single.payload,
          isNot(contains('serialized_config')),
        );
        expect(safeJson, isNot(contains(_backupCredential())));
        expect(
          () => LocalBackupService(
            source,
          ).exportJson(mode: LocalBackupMode.encryptedFull),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    test('exports a human-readable Markdown projection without API keys', () {
      final source = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      _seedBackupSource(source);

      final backup = LocalBackupService(source).exportBackup();
      final markdown = const LocalMarkdownExportService().exportBackup(backup);

      expect(markdown, contains('# WideNote Owner Export'));
      expect(markdown, contains('## Export Boundary'));
      expect(markdown, contains('provider_keys_in_markdown: never'));
      expect(markdown, contains('restore_source: use the paired JSON backup'));
      expect(markdown, contains('## Records'));
      expect(markdown, contains('Remember the backup demo.'));
      expect(markdown, contains('## Memory'));
      expect(markdown, contains('WideNote has a local backup demo.'));
      expect(markdown, contains('## Model Providers'));
      expect(markdown, contains('api_key_present: true'));
      expect(markdown, contains('## Runtime State'));
      expect(markdown, contains('pack.default'));
      expect(markdown, isNot(contains('- context_packet_cache: 1')));
      expect(markdown, isNot(contains('Synthetic packet body')));
      expect(markdown, isNot(contains(_backupCredential())));
    });

    test('rejects secret-bearing full backup import in this build', () {
      final source = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      _seedBackupSource(source);

      final full = LocalBackupCodec.decode(_secretBearingBackupJson(source));
      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(target.close);

      expect(
        () => LocalBackupCodec.encode(full),
        throwsA(isA<UnsupportedError>()),
      );

      expect(
        () => LocalBackupService(target).importBackup(full),
        throwsA(isA<UnsupportedError>()),
      );
      expect(target.modelProviderConfigs.readAll(), isEmpty);
    });

    test(
      'rejects current encrypted full backup manifests without encryption',
      () {
        final source = WideNoteLocalDatabase.inMemory();
        addTearDown(source.close);
        _seedBackupSource(source);

        final edited = _editBackupJson(
          LocalBackupService(source).exportJson(),
          (root) {
            final manifest = root['manifest']! as Map<String, Object?>;
            manifest['backup_mode'] = LocalBackupMode.encryptedFull.wireName;
            manifest['includes_secrets'] = true;
            manifest.remove('encryption');
            final providers = root['model_provider_configs']! as List<Object?>;
            (providers.single as Map<String, Object?>)['api_key'] =
                _backupCredential();
          },
        );

        expect(
          () => LocalBackupCodec.decode(edited),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'exports empty Markdown sections without leaking absent provider keys',
      () {
        final source = WideNoteLocalDatabase.inMemory();
        addTearDown(source.close);

        final backup = LocalBackupService(source).exportBackup();
        final markdown = const LocalMarkdownExportService().exportBackup(
          backup,
        );

        expect(markdown, contains('_No local records exported._'));
        expect(markdown, contains('_No Memory exported._'));
        expect(markdown, contains('_No model providers exported._'));
        expect(markdown, isNot(contains('apiKey')));
      },
    );

    test(
      'exports readable Markdown for multiline records and no-key providers',
      () {
        final source = WideNoteLocalDatabase.inMemory();
        addTearDown(source.close);
        final createdAt = DateTime.utc(2026, 6, 24, 10);
        source.captures.insert(
          CaptureRecord(
            id: 'capture-multiline',
            sourceType: 'manual',
            payload: const <String, Object?>{
              'text': 'First line\nSecond line with unicode 你好',
            },
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
        source.modelProviderConfigs.insert(
          ModelProviderConfigRecord(
            id: 'provider-no-key',
            providerKind: 'openai_compatible',
            displayName: 'No Key Provider',
            endpoint: 'https://example.invalid/v1/chat/completions',
            model: 'local-test',
            isDefault: true,
            hasApiKey: false,
            apiKey: '',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );

        final backup = LocalBackupService(source).exportBackup();
        final markdown = const LocalMarkdownExportService().exportBackup(
          backup,
        );

        expect(markdown, contains('### capture-multiline'));
        expect(
          markdown,
          contains('> First line\n> Second line with unicode 你好'),
        );
        expect(markdown, contains('### No Key Provider'));
        expect(markdown, contains('api_key_present: false'));
        expect(markdown, isNot(contains('apiKey')));
      },
    );

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

    test('decodes but rejects v1 secret-bearing backups', () {
      final source = WideNoteLocalDatabase.inMemory();
      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      addTearDown(target.close);
      _seedBackupSource(source);

      final v1Json = _editBackupJson(LocalBackupService(source).exportJson(), (
        root,
      ) {
        final manifest = root['manifest']! as Map<String, Object?>;
        manifest['format_version'] = 1;
        manifest.remove('backup_mode');
        manifest.remove('includes_secrets');
        manifest.remove('encryption');
        final counts = manifest['record_counts']! as Map<String, Object?>;
        counts.remove('attachments');
        counts.remove('derived_artifacts');
        counts.remove('runtime_tasks');
        counts.remove('runtime_runs');
        counts.remove('pack_installations');
        counts.remove('permission_grants');
        counts.remove('context_packet_cache');
        root.remove('attachments');
        root.remove('derived_artifacts');
        root.remove('runtime_tasks');
        root.remove('runtime_runs');
        root.remove('pack_installations');
        root.remove('permission_grants');
        root.remove('context_packet_cache');
      });
      final backup = LocalBackupCodec.decode(v1Json);

      expect(backup.manifest.formatVersion, 1);
      expect(backup.manifest.backupMode, LocalBackupMode.encryptedFull);
      expect(backup.manifest.includesSecrets, isTrue);
      expect(backup.attachments, isEmpty);
      expect(backup.manifest.recordCounts, containsPair('attachments', 0));
      expect(backup.derivedArtifacts, isEmpty);
      expect(
        backup.manifest.recordCounts,
        containsPair('derived_artifacts', 0),
      );
      expect(backup.runtimeTasks, isEmpty);
      expect(backup.contextPacketCaches, isEmpty);

      expect(
        () => LocalBackupService(target).importBackup(backup),
        throwsA(isA<UnsupportedError>()),
      );
      expect(target.captures.readById('capture-backup'), isNull);
      expect(target.todos.readById('todo-backup'), isNull);
      expect(target.attachments.readAll(), isEmpty);
      expect(target.derivedArtifacts.readAll(), isEmpty);
      expect(target.runtimeTasks.readAll(), isEmpty);
      expect(target.contextPacketCaches.readAll(), isEmpty);
    });

    test('restores current backups with missing context packet cache', () {
      final source = WideNoteLocalDatabase.inMemory();
      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      addTearDown(target.close);
      _seedBackupSource(source);

      final edited = _editBackupJson(LocalBackupService(source).exportJson(), (
        root,
      ) {
        final manifest = root['manifest']! as Map<String, Object?>;
        final counts = manifest['record_counts']! as Map<String, Object?>;
        counts.remove('context_packet_cache');
        root.remove('context_packet_cache');
      });
      final backup = LocalBackupCodec.decode(edited);

      expect(backup.contextPacketCaches, isEmpty);
      expect(
        backup.manifest.recordCounts,
        containsPair('context_packet_cache', 0),
      );

      LocalBackupService(target).importBackup(backup);

      expect(target.packInstallations.readById('pack.default'), isNotNull);
      expect(target.runtimeTasks.readById('task-backup'), isNotNull);
      expect(target.contextPacketCaches.readAll(), isEmpty);
    });

    test('does not revive tombstoned content during backup restore', () {
      final source = WideNoteLocalDatabase.inMemory();
      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      addTearDown(target.close);
      final deletedAt = DateTime.utc(2026, 6, 24, 8);
      source.memoryItems.insert(
        MemoryItemRecord(
          id: 'memory-tombstone',
          key: 'deleted.preference',
          status: 'deleted',
          body: '',
          tombstone: true,
          revision: 4,
          payload: const <String, Object?>{
            'deleted_at': '2026-06-24T08:00:00.000Z',
            'purge_after': '2026-07-24T08:00:00.000Z',
          },
          createdAt: deletedAt,
          updatedAt: deletedAt,
        ),
      );

      final backup = LocalBackupService(source).exportBackup();
      LocalBackupService(target).importBackup(backup);
      final restored = target.memoryItems.readById('memory-tombstone')!;

      expect(restored.status, 'deleted');
      expect(restored.tombstone, isTrue);
      expect(restored.body, isEmpty);
      expect(restored.revision, 4);
      expect(restored.payload['purge_after'], '2026-07-24T08:00:00.000Z');
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

    test('rejects inconsistent secret-boundary manifest fields', () {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);

      final safeJson = LocalBackupService(database).exportJson();
      final edited = _editBackupJson(safeJson, (root) {
        final manifest = root['manifest']! as Map<String, Object?>;
        manifest['includes_secrets'] = true;
      });

      expect(
        () => LocalBackupCodec.decode(edited),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'decodes current safe manifests that predate secret-boundary fields',
      () {
        final source = WideNoteLocalDatabase.inMemory();
        final target = WideNoteLocalDatabase.inMemory();
        addTearDown(source.close);
        addTearDown(target.close);
        _seedBackupSource(source);

        final edited = _editBackupJson(
          LocalBackupService(source).exportJson(),
          (root) {
            final manifest = root['manifest']! as Map<String, Object?>;
            manifest.remove('kind');
            manifest.remove('schema_version');
            manifest.remove('includes_secrets');
            manifest.remove('encryption');
          },
        );
        final backup = LocalBackupCodec.decode(edited);

        expect(backup.manifest.kind, 'backup_manifest');
        expect(backup.manifest.schemaVersion, 1);
        expect(backup.manifest.backupMode, LocalBackupMode.safe);
        expect(backup.manifest.includesSecrets, isFalse);

        final report = LocalBackupService(target).importBackup(backup);

        expect(report.requiresCredentialReentry, isTrue);
        expect(target.captures.readById('capture-backup'), isNotNull);
      },
    );

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

    test('rejects current backups missing the derived artifacts section', () {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);

      final json = LocalBackupService(database).exportJson();
      final edited = _editBackupJson(json, (root) {
        root.remove('derived_artifacts');
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
  database.derivedArtifacts.insert(
    DerivedArtifactRecord(
      id: 'artifact-backup-ocr',
      sourceCaptureId: 'capture-backup',
      sourceAttachmentId: 'attachment-backup',
      sourceEventId: 'event-backup',
      artifactKind: 'ocr_text',
      title: 'Backup OCR text',
      body: 'The backup demo image says restore derived evidence too.',
      contentHash: 'hash-backup-artifact',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-backup'},
        <String, Object?>{'kind': 'file', 'id': 'attachment-backup'},
      ],
      confidence: 'high',
      sensitivity: 'low',
      generatorId: 'ocr.fake',
      generatorVersion: '1',
      payload: const <String, Object?>{'language': 'en'},
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
  database.packInstallations.insert(
    PackInstallationRecord(
      packId: 'pack.default',
      name: 'Default Capture Loop',
      version: '0.1.0',
      publisher: 'widenote',
      edition: 'official',
      status: 'enabled',
      runtimeStatus: 'queued',
      requestedPermissions: const <Object?>[
        'model.complete',
        'card.write',
        'memory.propose',
      ],
      enabledSubscriptionIds: const <Object?>['sub.capture_created'],
      manifest: const <String, Object?>{
        'id': 'pack.default',
        'version': '0.1.0',
        'schema_version': 1,
      },
      payload: const <String, Object?>{'official': true},
      installedAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.permissionGrants.insert(
    PermissionGrantRecord(
      id: 'grant-backup',
      packId: 'pack.default',
      permissionId: 'model.complete',
      status: 'revoked',
      grantKind: 'user',
      grantedAt: createdAt,
      revokedAt: updatedAt,
      reason: 'user_revoked',
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.runtimeTasks.insert(
    RuntimeTaskRecord(
      id: 'task-backup',
      packId: 'pack.default',
      packVersion: '0.1.0',
      agentId: 'agent.capture',
      handlerId: 'agent.capture',
      subscriptionId: 'sub.capture_created',
      triggerEventId: 'event-backup',
      status: 'denied',
      attempts: 1,
      maxAttempts: 2,
      error: 'permission_revoked:model.complete',
      dependencyTaskIds: const <Object?>[],
      missingDependencyIds: const <Object?>[],
      payload: const <String, Object?>{
        'required_permissions': <String>['model.complete'],
      },
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
  );
  database.runtimeRuns.insert(
    RuntimeRunRecord(
      id: 'run-backup',
      taskId: 'task-backup',
      packId: 'pack.default',
      packVersion: '0.1.0',
      agentId: 'agent.capture',
      handlerId: 'agent.capture',
      status: 'denied',
      attempt: 1,
      error: 'permission_revoked:model.complete',
      startedAt: createdAt,
      completedAt: updatedAt,
    ),
  );
  database.contextPacketCaches.insert(
    ContextPacketCacheRecord(
      id: 'cache-backup',
      surface: 'chat',
      requestRef: const <String, Object?>{
        'kind': 'chat',
        'id': 'session-backup',
      },
      subjectRef: const <String, Object?>{
        'kind': 'capture',
        'id': 'capture-backup',
      },
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-backup'},
      ],
      sourceVersions: const <Object?>[
        <String, Object?>{
          'kind': 'capture',
          'id': 'capture-backup',
          'hash': 'hash-capture-v1',
        },
        <String, Object?>{
          'kind': 'memory',
          'id': 'memory-backup',
          'revision': 3,
          'tombstone': false,
          'sensitivity': 'low',
        },
      ],
      permissionScope: 'pack.default:model.complete,memory.propose',
      disclosureLevel: 'memory_and_derived',
      generatorId: 'context.packet.builder',
      generatorVersion: '1',
      promptVersion: 'prompt-v1',
      packId: 'pack.default',
      packVersion: '0.1.0',
      agentId: 'agent.capture',
      localDate: '2026-06-24',
      privacyProfile: 'owner_export_safe',
      invalidationKeys: const <Object?>[
        'source:capture-backup:hash-capture-v1',
        'memory:memory-backup:revision:3',
        'memory:memory-backup:tombstone:false',
        'memory:memory-backup:sensitivity:low',
        'permission:pack.default:model.complete',
        'generator:context.packet.builder:1',
        'pack:pack.default:0.1.0',
        'prompt:prompt-v1',
        'local_date:2026-06-24',
        'privacy:owner_export_safe',
      ],
      cacheKey: 'chat/capture-backup',
      packet: const <String, Object?>{'text': 'Synthetic packet body'},
      expiresAt: DateTime.utc(2026, 6, 24, 8, 59),
      createdAt: createdAt,
      updatedAt: updatedAt,
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
      payload: <String, Object?>{
        'secret_storage': 'local_db_backup',
        'api_key_shadow': _backupCredential(),
        'nested': <String, Object?>{
          'access_token': _backupCredential(),
          'label': 'safe metadata',
        },
        'token_list': <Object?>[
          <String, Object?>{'refresh_token': _backupCredential()},
        ],
        'serialized_config':
            '{"api_key":"${_backupCredential()}","label":"safe metadata"}',
      },
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

String _secretBearingBackupJson(WideNoteLocalDatabase database) {
  return _editBackupJson(LocalBackupService(database).exportJson(), (root) {
    final manifest = root['manifest']! as Map<String, Object?>;
    manifest['backup_mode'] = LocalBackupMode.encryptedFull.wireName;
    manifest['includes_secrets'] = true;
    manifest['encryption'] = const <String, Object?>{
      'status': 'decrypted_test_fixture',
      'algorithm': 'test-only',
    };
    final providers = root['model_provider_configs']! as List<Object?>;
    (providers.single as Map<String, Object?>)['api_key'] = _backupCredential();
  });
}

String _editBackupJson(
  String json,
  void Function(Map<String, Object?> root) edit,
) {
  final root = jsonDecode(json) as Map<String, Object?>;
  edit(root);
  return jsonEncode(root);
}
