import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/agent_status/application/agent_status_platform.dart';
import 'package:widenote_mobile/features/backup/application/backup_controller.dart';
import 'package:widenote_mobile/features/backup/application/backup_import_intent_service.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/features/system_permissions/application/system_permissions_controller.dart';

import 'support/fake_system_permission_adapter.dart';

void main() {
  testWidgets('initial .widenote intent opens backup page with ready import', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    final importService = _FakeBackupImportIntentService(
      initialPath: '/tmp/widenote-intent-smoke.widenote',
    );
    final backup = _emptyBackup();
    final fileStore = _IntentBackupFileStore(
      payload: BackupImportPayload(
        backup: backup,
        sourceLabel: '/tmp/widenote-intent-smoke.widenote',
      ),
    );

    await _pumpWideNoteApp(
      tester,
      database: database,
      importService: importService,
      fileStore: fileStore,
    );

    expect(
      fileStore.requestedArchivePath,
      '/tmp/widenote-intent-smoke.widenote',
    );
    expect(find.byKey(const Key('backup-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.text('Backup file loaded. Confirm import to replace local data.'),
      findsOneWidget,
    );
    final readyState = _readBackupState(tester);
    expect(readyState.outcome, BackupOutcome.importReady);
    expect(readyState.preparedImport, isNotNull);
    expect(readyState.importSourceLabel, '/tmp/widenote-intent-smoke.widenote');

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('initial invalid .widenote intent still opens backup page', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    final importService = _FakeBackupImportIntentService(
      initialPath: '/tmp/not-a-backup.widenote',
    );
    final fileStore = _IntentBackupFileStore(error: const FormatException());

    await _pumpWideNoteApp(
      tester,
      database: database,
      importService: importService,
      fileStore: fileStore,
    );

    expect(fileStore.requestedArchivePath, '/tmp/not-a-backup.widenote');
    expect(find.byKey(const Key('backup-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Backup failed: Invalid backup format.'), findsWidgets);
    final failedState = _readBackupState(tester);
    expect(failedState.outcome, BackupOutcome.failed);
    expect(failedState.preparedImport, isNull);
    expect(failedState.errorDetails, 'Invalid backup format.');
  });
}

BackupState _readBackupState(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byKey(const Key('backup-page'))),
  ).read(backupControllerProvider);
}

LocalDataBackup _emptyBackup() {
  final database = WideNoteLocalDatabase.inMemory();
  try {
    return LocalBackupService(
      database,
    ).exportBackup(mode: LocalBackupMode.full);
  } finally {
    database.close();
  }
}

Future<void> _pumpWideNoteApp(
  WidgetTester tester, {
  required WideNoteLocalDatabase database,
  required BackupImportIntentService importService,
  required BackupFileStore fileStore,
}) async {
  addTearDown(database.close);
  if (importService case _FakeBackupImportIntentService fakeService) {
    addTearDown(fakeService.close);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        backupImportIntentServiceProvider.overrideWithValue(importService),
        backupFileStoreProvider.overrideWithValue(fileStore),
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
        systemPermissionAdapterProvider.overrideWithValue(
          FakeSystemPermissionAdapter.ready(),
        ),
        agentStatusPlatformClientProvider.overrideWithValue(
          const _NoopAgentStatusPlatformClient(),
        ),
      ],
      child: const WideNoteApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeBackupImportIntentService
    implements BackupImportIntentService {
  _FakeBackupImportIntentService({String? initialPath})
    : _initialPath = initialPath;

  String? _initialPath;
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Future<String?> consumeInitialBackupPath() async {
    final path = _initialPath;
    _initialPath = null;
    return path;
  }

  @override
  Stream<String> get backupPathStream => _controller.stream;

  Future<void> close() => _controller.close();
}

final class _IntentBackupFileStore implements BackupFileStore {
  _IntentBackupFileStore({this.payload, this.error});

  final BackupImportPayload? payload;
  final Object? error;
  String? requestedArchivePath;

  @override
  Future<BackupImportPayload> readArchive(String archivePath) async {
    requestedArchivePath = archivePath;
    final readError = error;
    if (readError != null) {
      throw readError;
    }
    final readPayload = payload;
    if (readPayload == null) {
      throw StateError('No backup payload seeded.');
    }
    return readPayload;
  }

  @override
  Future<void> discardPreparedImport(BackupImportPayload payload) async {}

  @override
  Future<BackupImportPayload> pickArchive() => readArchive('picked.widenote');

  @override
  Future<BackupImportPayload> readLatestBackup() =>
      readArchive('latest.widenote');

  @override
  Future<void> restorePreparedMedia(BackupImportPayload payload) async {}

  @override
  Future<BackupFileResult> saveExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    throw UnimplementedError('Export is not used by this test.');
  }

  @override
  Future<BackupFileResult> shareExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    throw UnimplementedError('Export is not used by this test.');
  }
}

final class _NoopAgentStatusPlatformClient
    implements AgentStatusPlatformClient {
  const _NoopAgentStatusPlatformClient();

  @override
  Future<AgentStatusPlatformResult> sync(
    AgentStatusPlatformPayload payload,
  ) async {
    return const AgentStatusPlatformResult();
  }
}
