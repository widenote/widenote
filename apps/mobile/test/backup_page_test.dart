import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/backup/application/backup_controller.dart';
import 'package:widenote_mobile/features/backup/presentation/backup_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('backup page renders export and import controls', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpBackupPage(tester, database: database);

    expect(find.byKey(const Key('backup-page')), findsOneWidget);
    expect(find.text('Create .widenote backup'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
  });

  testWidgets('backup page exports safe JSON with manifest counts', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedLocalData(database);
    await _pumpBackupPage(tester, database: database);

    expect(
      find.textContaining('The .widenote archive restores records'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Owner Export Markdown is for reading'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Encrypted full backup will be the secret-bearing'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('backup-full-export-disabled-button')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('backup-export-button')));
    await tester.pumpAndSettle();

    expect(find.text('Safe backup JSON'), findsOneWidget);
    expect(find.text('Owner Export Markdown'), findsOneWidget);
    expect(
      find.text('Provider keys omitted from safe export: 1'),
      findsOneWidget,
    );
    expect(find.text('captures: 1'), findsOneWidget);
    expect(find.text('todos: 1'), findsOneWidget);
    expect(find.text('model_provider_configs: 1'), findsOneWidget);
    expect(
      find.textContaining('"format": "widenote.local_data_backup"'),
      findsOneWidget,
    );
    expect(find.textContaining('"kind": "backup_manifest"'), findsOneWidget);
    expect(find.textContaining('"includes_secrets": false'), findsOneWidget);
    expect(find.textContaining('"backup_mode": "safe"'), findsOneWidget);
    expect(find.textContaining('"payload_omitted": true'), findsOneWidget);
    expect(find.textContaining('"local_db_schema_version"'), findsOneWidget);
    expect(find.textContaining(_backupPageCredential()), findsNothing);
    expect(find.byKey(const Key('backup-export-markdown')), findsOneWidget);
    expect(find.textContaining('# WideNote Owner Export'), findsOneWidget);
    expect(
      find.textContaining('provider_keys_in_markdown: never'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Portable local backup from widget test.'),
      findsWidgets,
    );
    expect(find.textContaining(_backupPageCredential()), findsNothing);
  });

  testWidgets('backup copy actions expose explicit JSON and Markdown exports', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedLocalData(database);
    await _pumpBackupPage(tester, database: database);

    await tester.tap(find.byKey(const Key('backup-export-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('backup-page')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('backup-copy-markdown-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-copy-markdown-button')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Export copied.'), findsOneWidget);
    expect(find.byKey(const Key('backup-copy-json-button')), findsOneWidget);
    expect(
      find.byKey(const Key('backup-copy-markdown-button')),
      findsOneWidget,
    );
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

      expect(
        fileStore.savedJson,
        contains('"format": "widenote.local_data_backup"'),
      );
      expect(fileStore.savedJson, isNot(contains(_backupPageCredential())));
      expect(fileStore.savedMarkdown, contains('Portable local backup'));
      expect(fileStore.savedMarkdown, isNot(contains(_backupPageCredential())));
      expect(
        find.textContaining('/tmp/widenote-backup.widenote'),
        findsOneWidget,
      );
    },
  );

  testWidgets('import controls stay reachable after exporting JSON', (
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

    expect(find.byKey(const Key('backup-import-field')), findsOneWidget);
    expect(find.byKey(const Key('backup-import-button')), findsOneWidget);
    final importField = tester.widget<TextField>(
      find.byKey(const Key('backup-import-field')),
    );
    expect(importField.keyboardType, TextInputType.multiline);
    expect(importField.autocorrect, isFalse);
    expect(importField.enableSuggestions, isTrue);
    expect(importField.enableIMEPersonalizedLearning, isFalse);
    expect(importField.smartDashesType, SmartDashesType.disabled);
    expect(importField.smartQuotesType, SmartQuotesType.disabled);
    expect(
      tester.getTopLeft(find.byKey(const Key('backup-import-button'))).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('backup-import-field'))).dy,
      ),
    );
  });

  testWidgets('backup page imports pasted backup JSON into local DB', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);
    final json = LocalBackupService(source).exportJson();

    final target = WideNoteLocalDatabase.inMemory();
    await _pumpBackupPage(tester, database: target);

    await tester.enterText(find.byKey(const Key('backup-import-field')), json);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();

    final capture = target.captures.readById('capture-backup-page')!;
    expect(capture.payload['text'], 'Portable local backup from widget test.');
    final todo = target.todos.readById('todo-backup-page')!;
    expect(todo.payload['title'], 'Review portable local backup');
    final provider = target.modelProviderConfigs.readDefault()!;
    expect(provider.hasApiKey, isTrue);
    expect(provider.apiKey, isEmpty);
    expect(find.text('Backup imported into local storage.'), findsOneWidget);
    expect(
      find.textContaining('Re-enter 1 provider key before model calls'),
      findsOneWidget,
    );
  });

  testWidgets('backup page imports latest saved .widenote file into local DB', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);
    final fileStore = _MemoryBackupFileStore()
      ..latestJson = LocalBackupService(source).exportJson();

    final target = WideNoteLocalDatabase.inMemory();
    await _pumpBackupPage(
      tester,
      database: target,
      overrides: [backupFileStoreProvider.overrideWithValue(fileStore)],
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-latest-file-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('backup-import-latest-file-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-latest-file-button')));
    await tester.pumpAndSettle();

    expect(
      target.captures.readById('capture-backup-page')!.payload['text'],
      'Portable local backup from widget test.',
    );
    expect(find.text('Backup imported into local storage.'), findsOneWidget);
  });

  testWidgets('backup import restores core records and provider metadata', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);
    final json = LocalBackupService(source).exportJson();

    final target = WideNoteLocalDatabase.inMemory();
    await _pumpBackupPage(tester, database: target);

    await tester.enterText(find.byKey(const Key('backup-import-field')), json);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-button')));
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
    expect(provider.apiKey, isEmpty);
    expect(find.byKey(const Key('backup-import-report')), findsOneWidget);
  });

  testWidgets('backup import error recovers after valid JSON is pasted', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);
    final json = LocalBackupService(source).exportJson();

    final target = WideNoteLocalDatabase.inMemory();
    await _pumpBackupPage(tester, database: target);

    await tester.enterText(
      find.byKey(const Key('backup-import-field')),
      '{bad',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Invalid backup format'), findsOneWidget);
    expect(target.captures.readAll(), isEmpty);

    await tester.enterText(find.byKey(const Key('backup-import-field')), json);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-import-button')));
    await tester.pumpAndSettle();

    expect(find.text('Backup imported into local storage.'), findsOneWidget);
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
  String? latestJson;
  String? savedJson;
  String? savedMarkdown;

  @override
  Future<BackupFileResult> saveExport({
    required String json,
    required String markdown,
    required DateTime createdAt,
  }) async {
    savedJson = json;
    savedMarkdown = markdown;
    latestJson = json;
    return const BackupFileResult(
      archivePath: '/tmp/widenote-backup.widenote',
      archiveSizeBytes: 42,
    );
  }

  @override
  Future<String> readLatestJson() async {
    final json = latestJson;
    if (json == null) {
      throw StateError('No backup JSON seeded.');
    }
    return json;
  }

  @override
  Future<String> readArchiveJson(String archivePath) {
    return readLatestJson();
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
        'status_label': 'suggested by agent',
      },
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
