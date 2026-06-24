import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/backup/presentation/backup_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('plugins entry opens backup route', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDatabaseProvider.overrideWithValue(database)],
        child: const WideNoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backup-page')), findsOneWidget);
    expect(find.text('Export JSON'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
  });

  testWidgets('backup page exports versioned JSON with manifest counts', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedLocalData(database);
    await _pumpBackupPage(tester, database: database);

    expect(
      find.text(
        'Backups include provider API keys. Keep exported JSON private.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('backup-export-button')));
    await tester.pumpAndSettle();

    expect(find.text('Backup JSON'), findsOneWidget);
    expect(find.text('captures: 1'), findsOneWidget);
    expect(find.text('todos: 1'), findsOneWidget);
    expect(find.text('model_provider_configs: 1'), findsOneWidget);
    expect(
      find.textContaining('"format": "widenote.local_data_backup"'),
      findsOneWidget,
    );
    expect(find.textContaining('"local_db_schema_version"'), findsOneWidget);
    expect(
      find.textContaining('"api_key": "${_backupPageCredential()}"'),
      findsOneWidget,
    );
  });

  testWidgets('import controls stay reachable after exporting JSON', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedLocalData(database);
    await _pumpBackupPage(tester, database: database);

    await tester.tap(find.byKey(const Key('backup-export-button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('backup-import-field')), findsOneWidget);
    expect(find.byKey(const Key('backup-import-button')), findsOneWidget);
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
    expect(provider.apiKey, _backupPageCredential());
    expect(find.text('Backup imported into local storage.'), findsOneWidget);
  });

  testWidgets('backup import refreshes app Home and Todos read models', (
    tester,
  ) async {
    final source = WideNoteLocalDatabase.inMemory();
    addTearDown(source.close);
    _seedLocalData(source);
    final json = LocalBackupService(source).exportJson();

    final target = WideNoteLocalDatabase.inMemory();
    addTearDown(target.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDatabaseProvider.overrideWithValue(target)],
        child: const WideNoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('No local records yet.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No local records yet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-entry')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Portable local backup from widget test.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Portable local backup from widget test.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('tab-todos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-row-todo-backup-page')), findsOneWidget);
    expect(find.text('Review portable local backup'), findsOneWidget);
  });
}

Future<void> _pumpBackupPage(
  WidgetTester tester, {
  required WideNoteLocalDatabase database,
  Locale locale = const Locale('en'),
}) async {
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
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
      payload: const <String, Object?>{'secret_storage': 'local_db_backup'},
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
