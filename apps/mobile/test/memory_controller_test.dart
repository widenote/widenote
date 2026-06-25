import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/memory/application/memory_controller.dart';

void main() {
  test('memory controller edits tombstones and restores with revisions', () {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 6, 25, 9);
    database.memoryItems.insert(
      MemoryItemRecord(
        id: 'memory-controller-1',
        key: 'project.controller',
        body: 'Original Memory body.',
        sourceRefs: const <Object?>[
          <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
        ],
        memoryType: 'project',
        confidence: 'high',
        sensitivity: 'low',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    container
        .read(memoryControllerProvider.notifier)
        .editMemory('memory-controller-1', 'Updated Memory body.');

    var record = database.memoryItems.readById('memory-controller-1')!;
    expect(record.body, 'Updated Memory body.');
    expect(record.revision, 2);
    expect(record.tombstone, isFalse);

    container
        .read(memoryControllerProvider.notifier)
        .deleteMemory('memory-controller-1');

    record = database.memoryItems.readById('memory-controller-1')!;
    expect(record.status, 'deleted');
    expect(record.tombstone, isTrue);
    expect(record.revision, 3);
    expect(container.read(memoryControllerProvider).deletedItems, hasLength(1));

    container
        .read(memoryControllerProvider.notifier)
        .restoreMemory('memory-controller-1');

    record = database.memoryItems.readById('memory-controller-1')!;
    expect(record.status, 'active');
    expect(record.tombstone, isFalse);
    expect(record.revision, 4);
    expect(container.read(memoryControllerProvider).activeItems, hasLength(1));
  });
}
