import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/todos/application/todo_controller.dart';

void main() {
  test('todo controller hides completed rows and can reopen durable rows', () {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 6, 25, 8);
    database.todos.insert(
      TodoRecord(
        id: 'todo-controller-1',
        sourceCaptureId: 'capture-1',
        payload: const <String, Object?>{
          'title': 'Review controller todo',
          'source_label': 'source: capture-1',
          'status_label': 'suggested by agent',
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    expect(container.read(todoControllerProvider).items.single.status, 'open');

    container
        .read(todoControllerProvider.notifier)
        .complete('todo-controller-1');

    expect(database.todos.readById('todo-controller-1')!.status, 'completed');
    expect(
      container.read(todoControllerProvider).items,
      isEmpty,
    );

    container.read(todoControllerProvider.notifier).reopen('todo-controller-1');

    expect(database.todos.readById('todo-controller-1')!.status, 'open');
    expect(
      container.read(todoControllerProvider).items.single.statusLabel,
      'suggested by agent',
    );
  });
}
