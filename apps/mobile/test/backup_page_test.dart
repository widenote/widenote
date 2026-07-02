import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/backup/application/backup_controller.dart';
import 'package:widenote_mobile/features/backup/presentation/backup_page.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/features/location/domain/location_context.dart';
import 'package:widenote_mobile/features/transcription/transcription_service.dart';
import 'package:widenote_mobile/features/transcription/transcription_settings.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('backup page renders export and import controls', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpBackupPage(tester, database: database);

    expect(find.byKey(const Key('backup-page')), findsOneWidget);
    expect(find.text('Create .widenote backup'), findsOneWidget);
    expect(find.text('Replace with selected backup'), findsOneWidget);
  });

  testWidgets('backup page prepares a .widenote archive with manifest counts', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedLocalData(database);
    await _pumpBackupPage(tester, database: database);

    expect(
      find.textContaining('The .widenote archive restores a SQLite snapshot'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Backups are compressed directories'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Full .widenote backups include provider, AMap'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('backup-full-export-disabled-button')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('backup-export-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Provider keys omitted'), findsNothing);
    expect(find.text('captures: 1'), findsOneWidget);
    expect(find.text('todos: 1'), findsOneWidget);
    expect(find.text('model_provider_configs: 1'), findsOneWidget);
    expect(
      find.byKey(const Key('backup-open-share-file-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('backup-save-files-button')), findsOneWidget);
    expect(find.byKey(const Key('backup-export-json')), findsNothing);
    expect(find.byKey(const Key('backup-copy-markdown-button')), findsNothing);
    expect(find.byKey(const Key('backup-export-markdown')), findsNothing);
    expect(find.textContaining(_backupPageCredential()), findsNothing);
  });

  testWidgets(
    'backup page saves exported .widenote archive through file store',
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      _seedLocalData(database);
      final fileStore = _MemoryBackupFileStore();
      await _pumpBackupPage(
        tester,
        database: database,
        overrides: [backupFileStoreProvider.overrideWithValue(fileStore)],
      );

      await tester.tap(find.byKey(const Key('backup-export-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('backup-save-files-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-save-files-button')));
      await tester.pumpAndSettle();

      expect(fileStore.savedBackup, isNotNull);
      final provider = fileStore.savedBackup!.modelProviderConfigs.single;
      expect(provider.hasApiKey, isTrue);
      expect(provider.apiKey, _backupPageCredential());
      expect(provider.payload.toString(), contains(_backupPageCredential()));
      expect(
        find.textContaining('/tmp/widenote-backup.widenote'),
        findsOneWidget,
      );
      expect(find.textContaining('selected test destination'), findsOneWidget);
    },
  );

  testWidgets('import controls stay reachable after preparing export', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedLocalData(database);
    await _pumpBackupPage(tester, database: database);

    await tester.tap(find.byKey(const Key('backup-export-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('backup-page')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backup-import-file-button')), findsOneWidget);
    expect(find.byKey(const Key('backup-import-button')), findsOneWidget);
    expect(find.textContaining('Choose a .widenote file'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('backup-import-button'))).dy,
      greaterThan(
        tester
            .getBottomLeft(find.byKey(const Key('backup-import-file-button')))
            .dy,
      ),
    );
  });

  testWidgets('backup page imports selected backup into local DB', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);
    final payload = BackupImportPayload(
      backup: LocalBackupService(
        source,
      ).exportBackup(mode: LocalBackupMode.full),
      sourceLabel: '/tmp/source.widenote',
    );

    final target = WideNoteLocalDatabase.inMemory();
    _seedStaleLocalData(target);
    final fileStore = _MemoryBackupFileStore()..latestPayload = payload;
    await _pumpBackupPage(
      tester,
      database: target,
      overrides: [backupFileStoreProvider.overrideWithValue(fileStore)],
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-file-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('backup-page')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-file-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('backup-page')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();
    expect(find.text('Replace local data?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-confirm-replace-button')));
    await tester.pumpAndSettle();

    final capture = target.captures.readById('capture-backup-page')!;
    expect(capture.payload['text'], 'Portable local backup from widget test.');
    expect(target.captures.readById('capture-local-only'), isNull);
    final todo = target.todos.readById('todo-backup-page')!;
    expect(todo.payload['title'], 'Review portable local backup');
    final provider = target.modelProviderConfigs.readDefault()!;
    expect(provider.hasApiKey, isTrue);
    expect(provider.apiKey, _backupPageCredential());
    expect(find.text('Backup replaced local storage.'), findsOneWidget);
    expect(
      find.text('Provider credentials restored and ready to use.'),
      findsOneWidget,
    );
  });

  testWidgets('backup page loads a selected .widenote file before importing', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);
    final fileStore = _MemoryBackupFileStore()
      ..latestPayload = BackupImportPayload(
        backup: LocalBackupService(
          source,
        ).exportBackup(mode: LocalBackupMode.full),
        sourceLabel: '/tmp/widenote-backup.widenote',
      );

    final target = WideNoteLocalDatabase.inMemory();
    await _pumpBackupPage(
      tester,
      database: target,
      overrides: [backupFileStoreProvider.overrideWithValue(fileStore)],
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-file-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('backup-import-file-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-file-button')));
    await tester.pumpAndSettle();

    expect(target.captures.readById('capture-backup-page'), isNull);
    expect(
      find.text('Backup is loaded and ready to replace local data.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-confirm-replace-button')));
    await tester.pumpAndSettle();

    expect(
      target.captures.readById('capture-backup-page')!.payload['text'],
      'Portable local backup from widget test.',
    );
    expect(find.text('Backup replaced local storage.'), findsOneWidget);
  });

  testWidgets('backup import restores core records and provider credentials', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);
    final fileStore = _MemoryBackupFileStore()
      ..latestPayload = BackupImportPayload(
        backup: LocalBackupService(
          source,
        ).exportBackup(mode: LocalBackupMode.full),
        sourceLabel: '/tmp/widenote-backup.widenote',
      );

    final target = WideNoteLocalDatabase.inMemory();
    await _pumpBackupPage(
      tester,
      database: target,
      overrides: [backupFileStoreProvider.overrideWithValue(fileStore)],
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-file-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-file-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-confirm-replace-button')));
    await tester.pumpAndSettle();

    expect(
      target.captures.readById('capture-backup-page')!.payload['text'],
      'Portable local backup from widget test.',
    );
    expect(
      target.todos.readById('todo-backup-page')!.payload['title'],
      'Review portable local backup',
    );
    final provider = target.modelProviderConfigs.readDefault()!;
    expect(provider.displayName, 'MIMO test');
    expect(provider.hasApiKey, isTrue);
    expect(provider.apiKey, _backupPageCredential());
    expect(find.byKey(const Key('backup-import-report')), findsOneWidget);
  });

  testWidgets('backup import restores allowlisted secure app settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final source = WideNoteLocalDatabase.inMemory();
    final target = WideNoteLocalDatabase.inMemory();
    final locationRepository = InMemoryLocationSettingsRepository();
    final voiceRepository = MemoryVoiceTranscriptionSettingsRepository();
    final credentials = MemoryTranscriptionCredentialStore('old-key');
    _seedLocalData(source);
    final fileStore = _MemoryBackupFileStore()
      ..latestPayload = BackupImportPayload(
        backup: LocalBackupService(
          source,
        ).exportBackup(mode: LocalBackupMode.full),
        sourceLabel: '/tmp/widenote-backup.widenote',
        supportSettings: const BackupSupportSettingsBundle(
          locationSettings: LocationCaptureSettings(
            saveGps: true,
            useAmapReverseGeocode: true,
            amapApiKey: 'amap-secret',
          ),
          hasVoiceTranscriptionSettings: true,
          voiceTranscriptionSettings: VoiceTranscriptionSettings(
            engine: VoiceTranscriptionEngine.xiaomiMimo,
            remoteConsentGranted: true,
            localModelState: LocalTranscriptionModelState.notDownloaded,
          ),
          hasMimoAsrApiKey: true,
          mimoAsrApiKey: 'mimo-secret',
        ),
      );
    await _pumpBackupPage(
      tester,
      database: target,
      overrides: [
        backupFileStoreProvider.overrideWithValue(fileStore),
        locationSettingsRepositoryProvider.overrideWithValue(
          locationRepository,
        ),
        voiceTranscriptionSettingsRepositoryProvider.overrideWithValue(
          voiceRepository,
        ),
        transcriptionCredentialStoreProvider.overrideWithValue(credentials),
      ],
    );

    await tester.tap(find.byKey(const Key('backup-import-file-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-confirm-replace-button')));
    await tester.pumpAndSettle();

    final location = await locationRepository.load();
    expect(location.useAmapReverseGeocode, isTrue);
    expect(location.amapApiKey, 'amap-secret');
    final voice = await voiceRepository.load();
    expect(voice.engine, VoiceTranscriptionEngine.xiaomiMimo);
    expect(voice.remoteAsrEnabled, isTrue);
    expect(voice.localModelState, LocalTranscriptionModelState.notDownloaded);
    expect(await credentials.readMimoAsrApiKey(), 'mimo-secret');
  });

  testWidgets('backup import error recovers after valid file is selected', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);

    final target = WideNoteLocalDatabase.inMemory();
    final fileStore = _MemoryBackupFileStore()..failNextPick = true;
    await _pumpBackupPage(
      tester,
      database: target,
      overrides: [backupFileStoreProvider.overrideWithValue(fileStore)],
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-file-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-file-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No saved backup file found'), findsOneWidget);
    expect(target.captures.readAll(), isEmpty);

    fileStore.latestPayload = BackupImportPayload(
      backup: LocalBackupService(
        source,
      ).exportBackup(mode: LocalBackupMode.full),
      sourceLabel: '/tmp/widenote-backup.widenote',
    );
    await tester.ensureVisible(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-file-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-confirm-replace-button')));
    await tester.pumpAndSettle();

    expect(find.text('Backup replaced local storage.'), findsOneWidget);
    expect(target.captures.readById('capture-backup-page'), isNotNull);
  });
}

Future<void> _pumpBackupPage(
  WidgetTester tester, {
  required WideNoteLocalDatabase database,
  Locale locale = const Locale('en'),
  List<Override> overrides = const <Override>[],
}) async {
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        ...overrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: BackupPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _MemoryBackupFileStore implements BackupFileStore {
  BackupImportPayload? latestPayload;
  LocalDataBackup? savedBackup;
  bool failNextPick = false;
  bool shared = false;

  @override
  Future<BackupFileResult> shareExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    savedBackup = backup;
    latestPayload = BackupImportPayload(
      backup: backup,
      sourceLabel: '/tmp/widenote-backup.widenote',
    );
    shared = true;
    return const BackupFileResult(
      archivePath: '/tmp/widenote-backup.widenote',
      archiveSizeBytes: 42,
      destinationLabel: 'system share sheet',
    );
  }

  @override
  Future<BackupFileResult> saveExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    savedBackup = backup;
    latestPayload = BackupImportPayload(
      backup: backup,
      sourceLabel: '/tmp/widenote-backup.widenote',
    );
    return const BackupFileResult(
      archivePath: '/tmp/widenote-backup.widenote',
      archiveSizeBytes: 42,
      destinationLabel: 'selected test destination',
    );
  }

  @override
  Future<BackupImportPayload> readLatestBackup() async {
    return _payloadOrThrow();
  }

  @override
  Future<BackupImportPayload> readArchive(String archivePath) {
    return readLatestBackup();
  }

  @override
  Future<BackupImportPayload> pickArchive() async {
    if (failNextPick) {
      failNextPick = false;
      throw const FileSystemException('No WideNote backup file selected.');
    }
    return _payloadOrThrow();
  }

  @override
  Future<void> restorePreparedMedia(BackupImportPayload payload) async {}

  @override
  Future<void> discardPreparedImport(BackupImportPayload payload) async {}

  BackupImportPayload _payloadOrThrow() {
    final payload = latestPayload;
    if (payload == null) {
      throw StateError('No backup payload seeded.');
    }
    return payload;
  }
}

void _seedLocalData(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 6, 24, 10);
  database.captures.insert(
    CaptureRecord(
      id: 'capture-backup-page',
      sourceType: 'manual',
      sourceId: 'widget-test',
      payload: const <String, Object?>{
        'text': 'Portable local backup from widget test.',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.modelProviderConfigs.insert(
    ModelProviderConfigRecord(
      id: 'provider-backup-page',
      providerKind: 'mimo',
      displayName: 'MIMO test',
      endpoint: 'https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages',
      model: 'mimo-v2.5-pro',
      isDefault: true,
      hasApiKey: true,
      apiKey: _backupPageCredential(),
      capabilities: const <Object?>['chat', 'completion'],
      payload: <String, Object?>{
        'secret_storage': 'local_db_backup',
        'api_key_shadow': _backupPageCredential(),
        'serialized_config':
            '{"api_key":"${_backupPageCredential()}","label":"safe metadata"}',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.todos.insert(
    TodoRecord(
      id: 'todo-backup-page',
      sourceCaptureId: 'capture-backup-page',
      payload: const <String, Object?>{
        'title': 'Review portable local backup',
        'source_label': 'source: capture-backup-page',
        'status_label': 'suggested action',
        'suggestion_kind': 'action',
        'suggestion_confidence': 'high',
        'suggestion_reason': 'explicit_action',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _seedStaleLocalData(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 6, 23, 10);
  database.captures
    ..insert(
      CaptureRecord(
        id: 'capture-backup-page',
        sourceType: 'manual',
        sourceId: 'stale-widget-test',
        payload: const <String, Object?>{'text': 'stale local backup row'},
        createdAt: now,
        updatedAt: now,
      ),
    )
    ..insert(
      CaptureRecord(
        id: 'capture-local-only',
        sourceType: 'manual',
        sourceId: 'stale-widget-test',
        payload: const <String, Object?>{'text': 'local only row'},
        createdAt: now,
        updatedAt: now,
      ),
    );
}

String _backupPageCredential() {
  return String.fromCharCodes(<int>[
    119,
    105,
    100,
    103,
    101,
    116,
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
