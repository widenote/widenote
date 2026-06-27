import 'package:sqlite3/sqlite3.dart';

import 'daos.dart';
import 'migration.dart';
import 'models.dart';

final class WideNoteLocalDatabase {
  WideNoteLocalDatabase._(this._database)
    : eventLog = EventLogDao(_database),
      captures = CapturesDao(_database),
      attachments = AttachmentsDao(_database),
      memoryItems = MemoryItemsDao(_database),
      memoryCandidates = MemoryCandidatesDao(_database),
      cards = CardsDao(_database),
      insights = InsightsDao(_database),
      chatSessions = ChatSessionsDao(_database),
      chatMessages = ChatMessagesDao(_database),
      modelProviderConfigs = ModelProviderConfigsDao(_database),
      todos = TodosDao(_database),
      runtimeTasks = RuntimeTasksDao(_database),
      runtimeRuns = RuntimeRunsDao(_database),
      runtimeApprovals = RuntimeApprovalsDao(_database),
      packInstallations = PackInstallationsDao(_database),
      permissionGrants = PermissionGrantsDao(_database),
      contextPacketCaches = ContextPacketCachesDao(_database),
      traceEvents = TraceEventsDao(_database);

  factory WideNoteLocalDatabase.open(
    Database database, {
    bool bootstrap = true,
  }) {
    if (bootstrap) {
      LocalDbMigrator.bootstrap(database);
    }
    return WideNoteLocalDatabase._(database);
  }

  factory WideNoteLocalDatabase.openPath(String path, {bool bootstrap = true}) {
    return WideNoteLocalDatabase.open(sqlite3.open(path), bootstrap: bootstrap);
  }

  factory WideNoteLocalDatabase.inMemory() {
    return WideNoteLocalDatabase.open(sqlite3.openInMemory());
  }

  final Database _database;

  final EventLogDao eventLog;
  final CapturesDao captures;
  final AttachmentsDao attachments;
  final MemoryItemsDao memoryItems;
  final MemoryCandidatesDao memoryCandidates;
  final CardsDao cards;
  final InsightsDao insights;
  final ChatSessionsDao chatSessions;
  final ChatMessagesDao chatMessages;
  final ModelProviderConfigsDao modelProviderConfigs;
  final TodosDao todos;
  final RuntimeTasksDao runtimeTasks;
  final RuntimeRunsDao runtimeRuns;
  final RuntimeApprovalsDao runtimeApprovals;
  final PackInstallationsDao packInstallations;
  final PermissionGrantsDao permissionGrants;
  final ContextPacketCachesDao contextPacketCaches;
  final TraceEventsDao traceEvents;

  int get schemaVersion => LocalDbMigrator.readSchemaVersion(_database);

  Database get rawDatabase => _database;

  void insertCaptureEventAndTasks({
    required CaptureRecord capture,
    required EventLogEntry event,
    required List<RuntimeTaskRecord> tasks,
  }) {
    _database.execute('BEGIN IMMEDIATE;');
    try {
      captures.insert(capture);
      eventLog.append(event);
      for (final task in tasks) {
        runtimeTasks.insert(task);
      }
      final foreignKeyErrors = _database.select('PRAGMA foreign_key_check;');
      if (foreignKeyErrors.isNotEmpty) {
        throw StateError(
          'Capture/event/task transaction failed foreign key validation '
          'for ${foreignKeyErrors.length} row(s).',
        );
      }
      _database.execute('COMMIT;');
    } catch (_) {
      _database.execute('ROLLBACK;');
      rethrow;
    }
  }

  void close() {
    _database.dispose();
  }
}

WideNoteLocalDatabase openInMemoryWideNoteLocalDatabase() {
  return WideNoteLocalDatabase.inMemory();
}
