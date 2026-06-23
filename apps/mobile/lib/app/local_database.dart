import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';

final localDatabaseProvider = Provider<WideNoteLocalDatabase>((ref) {
  throw StateError('localDatabaseProvider must be provided by app bootstrap.');
});

final localEventStoreProvider = Provider<runtime.EventStore>((ref) {
  return LocalDbEventStore(ref.watch(localDatabaseProvider));
});

final localTraceSinkProvider = Provider<runtime.TraceSink>((ref) {
  return LocalDbTraceSink(ref.watch(localDatabaseProvider));
});

final class WideNoteMobileBootstrap {
  const WideNoteMobileBootstrap._({required this.database});

  final WideNoteLocalDatabase database;

  static Future<WideNoteMobileBootstrap> production({
    Directory? supportDirectory,
  }) async {
    final root = supportDirectory ?? await getApplicationSupportDirectory();
    final dataDirectory = Directory(_joinPath(root.path, 'local-data'))
      ..createSync(recursive: true);
    final databasePath = _joinPath(dataDirectory.path, 'widenote.sqlite');

    return WideNoteMobileBootstrap._(
      database: WideNoteLocalDatabase.openPath(databasePath),
    );
  }

  List<Override> get providerOverrides {
    return <Override>[localDatabaseProvider.overrideWithValue(database)];
  }

  void close() {
    database.close();
  }
}

String _joinPath(String directory, String child) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$child';
  }
  return '$directory${Platform.pathSeparator}$child';
}
