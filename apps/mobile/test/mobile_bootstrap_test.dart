import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';

void main() {
  test('production bootstrap opens a local SQLite database', () async {
    final directory = Directory.systemTemp.createTempSync(
      'widenote_mobile_bootstrap_',
    );
    addTearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final bootstrap = await WideNoteMobileBootstrap.production(
      supportDirectory: directory,
    );
    addTearDown(bootstrap.close);

    final databaseFile = File(
      '${directory.path}${Platform.pathSeparator}'
      'local-data${Platform.pathSeparator}'
      'widenote.sqlite',
    );

    expect(databaseFile.existsSync(), isTrue);
    expect(bootstrap.database.schemaVersion, LocalDbSchema.currentVersion);
    expect(bootstrap.providerOverrides, hasLength(1));
  });
}
