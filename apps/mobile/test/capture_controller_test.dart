import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/capture/application/capture_controller.dart';
import 'package:widenote_mobile/features/capture/domain/capture_models.dart';

void main() {
  test('capture controller refresh rehydrates local DB records', () async {
    final database = localdb.WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final firstCreatedAt = DateTime.utc(2026, 7, 2, 9);
    database.captures.insert(
      localdb.CaptureRecord(
        id: 'capture-refresh-first',
        sourceType: 'manual',
        status: captureStatusProcessed,
        payload: const <String, Object?>{
          'text': 'First visible capture.',
          'raw_text': 'First visible capture.',
        },
        createdAt: firstCreatedAt,
        updatedAt: firstCreatedAt,
      ),
    );
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(captureControllerProvider)
          .records
          .map((record) => record.id),
      ['capture-refresh-first'],
    );

    final secondCreatedAt = firstCreatedAt.add(const Duration(minutes: 1));
    database.captures.insert(
      localdb.CaptureRecord(
        id: 'capture-refresh-second',
        sourceType: 'manual',
        status: captureStatusProcessed,
        payload: const <String, Object?>{
          'text': 'Second external capture.',
          'raw_text': 'Second external capture.',
        },
        createdAt: secondCreatedAt,
        updatedAt: secondCreatedAt,
      ),
    );

    await container.read(captureControllerProvider.notifier).refresh();

    expect(
      container
          .read(captureControllerProvider)
          .records
          .map((record) => record.id),
      ['capture-refresh-second', 'capture-refresh-first'],
    );
  });
}
