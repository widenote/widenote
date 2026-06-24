import 'package:sqlite3/sqlite3.dart';

import 'daos.dart';
import 'migration.dart';

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
  final TraceEventsDao traceEvents;

  int get schemaVersion => LocalDbMigrator.readSchemaVersion(_database);

  Database get rawDatabase => _database;

  void close() {
    _database.dispose();
  }
}

WideNoteLocalDatabase openInMemoryWideNoteLocalDatabase() {
  return WideNoteLocalDatabase.inMemory();
}
