import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/todos/application/todo_controller.dart';

void main() {
  test('todo controller keeps completed rows visible and can reopen them', () {
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
          'status_label': 'suggested action',
          'suggestion_kind': 'action',
          'suggestion_confidence': 'high',
          'suggestion_reason': 'explicit_action',
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

    final completedRecord = database.todos.readById('todo-controller-1')!;
    expect(completedRecord.status, 'completed');
    expect(completedRecord.payload['completed_at'], isA<String>());
    expect(completedRecord.payload['completed_by'], 'user');
    expect(
      container.read(todoControllerProvider).completedItems.single.id,
      'todo-controller-1',
    );

    container.read(todoControllerProvider.notifier).reopen('todo-controller-1');

    final reopenedRecord = database.todos.readById('todo-controller-1')!;
    expect(reopenedRecord.status, 'open');
    expect(reopenedRecord.payload.containsKey('completed_at'), isFalse);
    expect(
      container.read(todoControllerProvider).items.single.statusLabel,
      'suggested action',
    );
  });

  test('todo controller sinks completed rows and sorts by completed time', () {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 3, 9);
    void insertTodo(
      String id, {
      String status = 'open',
      DateTime? completedAt,
      DateTime? dueAt,
    }) {
      database.todos.insert(
        TodoRecord(
          id: id,
          sourceCaptureId: 'capture-$id',
          status: status,
          payload: <String, Object?>{
            'title': 'Task $id',
            'source_label': 'source: capture-$id',
            'status_label': 'suggested action',
            'suggestion_kind': 'action',
            'suggestion_confidence': 'high',
            'suggestion_reason': 'explicit_action',
            if (dueAt != null) 'due_at': dueAt.toIso8601String(),
            if (completedAt != null)
              'completed_at': completedAt.toIso8601String(),
          },
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: completedAt ?? now,
        ),
      );
    }

    insertTodo('active', dueAt: DateTime.utc(2026, 7, 10));
    insertTodo(
      'done-old',
      status: 'completed',
      completedAt: DateTime.utc(2026, 7, 2, 8),
      dueAt: DateTime.utc(2026, 7, 1),
    );
    insertTodo(
      'done-new',
      status: 'completed',
      completedAt: DateTime.utc(2026, 7, 3, 8),
      dueAt: DateTime.utc(2026, 7, 20),
    );
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final state = container.read(todoControllerProvider);

    expect(state.actionItems.map((item) => item.id), ['active']);
    expect(state.completedItems.map((item) => item.id), [
      'done-new',
      'done-old',
    ]);
    expect(state.items.map((item) => item.id), [
      'active',
      'done-new',
      'done-old',
    ]);
  });

  test('todo controller groups model-suggested rows without local parsing', () {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 2, 8);
    database.todos.insert(
      TodoRecord(
        id: 'legacy-missing-kind',
        sourceCaptureId: 'capture-neutral',
        payload: const <String, Object?>{
          'title': 'Urgent: review launch checklist tomorrow',
          'source_label': 'source: capture-neutral',
          'status_label': 'suggested by agent',
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    database.todos.insert(
      TodoRecord(
        id: 'model-action',
        sourceCaptureId: 'capture-action',
        payload: const <String, Object?>{
          'title': 'Review launch checklist',
          'source_label': 'source: capture-action',
          'status_label': 'suggested action',
          'suggestion_kind': 'action',
          'suggestion_confidence': 'high',
          'suggestion_reason': 'explicit_action',
        },
        createdAt: now.add(const Duration(minutes: 1)),
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    database.todos.insert(
      TodoRecord(
        id: 'model-schedule',
        sourceCaptureId: 'capture-schedule',
        payload: const <String, Object?>{
          'title': 'Review launch issue tomorrow',
          'source_label': 'source: capture-schedule',
          'status_label': 'schedule candidate',
          'suggestion_kind': 'schedule',
          'suggestion_confidence': 'high',
          'suggestion_reason': 'explicit_schedule',
          'scheduled_at_label': 'tomorrow',
        },
        createdAt: now.add(const Duration(minutes: 2)),
        updatedAt: now.add(const Duration(minutes: 2)),
      ),
    );
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final state = container.read(todoControllerProvider);

    expect(state.actionItems.map((item) => item.id), ['model-action']);
    expect(state.scheduleItems.map((item) => item.id), ['model-schedule']);
    expect(state.quietItems.map((item) => item.id), ['legacy-missing-kind']);
    expect(
      state.items.map((item) => item.id),
      unorderedEquals(<String>['model-schedule', 'model-action']),
    );
    expect(state.quietCount, 1);
    expect(state.actionItems.single.statusLabel, 'suggested action');
    expect(state.scheduleItems.single.statusLabel, 'schedule candidate');
    expect(state.scheduleItems.single.scheduledAtLabel, 'tomorrow');

    container.read(todoControllerProvider.notifier).complete('model-schedule');

    expect(database.todos.readById('model-schedule')!.status, 'open');
  });

  test('todo controller refresh rehydrates externally inserted rows', () async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    expect(container.read(todoControllerProvider).items, isEmpty);

    final now = DateTime.utc(2026, 7, 2, 10);
    database.todos.insert(
      TodoRecord(
        id: 'external-refresh-todo',
        sourceCaptureId: 'capture-refresh-todo',
        payload: const <String, Object?>{
          'title': 'Refresh externally inserted todo',
          'source_label': 'source: capture-refresh-todo',
          'status_label': 'suggested action',
          'suggestion_kind': 'action',
          'suggestion_confidence': 'high',
          'suggestion_reason': 'external_insert',
        },
        createdAt: now,
        updatedAt: now,
      ),
    );

    await container.read(todoControllerProvider.notifier).refresh();

    expect(
      container.read(todoControllerProvider).items.single.id,
      'external-refresh-todo',
    );
  });

  test('todo controller buckets and filters structured task metadata', () {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 3, 8);
    void insertAction(String id, DateTime? dueAt, {String title = 'Task'}) {
      database.todos.insert(
        TodoRecord(
          id: id,
          sourceCaptureId: 'capture-$id',
          payload: <String, Object?>{
            'title': '$title $id',
            'source_label': 'source: capture-$id',
            'status_label': 'suggested action',
            'suggestion_kind': 'action',
            'suggestion_confidence': 'high',
            'suggestion_reason': 'explicit_action',
            if (dueAt != null) 'due_at': dueAt.toIso8601String(),
            'priority': 'high',
            'sort_order': 10,
            'indent_level': 2,
          },
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    insertAction('overdue', DateTime.utc(2026, 7, 2, 9));
    insertAction('today', DateTime.utc(2026, 7, 3, 9));
    insertAction('tomorrow', DateTime.utc(2026, 7, 4, 9));
    insertAction('later', DateTime.utc(2026, 7, 9, 9), title: 'Launch');
    insertAction('none', null);

    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        todoNowProvider.overrideWithValue(now),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(todoControllerProvider);
    expect(state.overdueItems.single.id, 'overdue');
    expect(state.todayItems.single.id, 'today');
    expect(state.tomorrowItems.single.id, 'tomorrow');
    expect(state.laterItems.single.id, 'later');
    expect(state.noDeadlineItems.single.id, 'none');
    expect(state.actionItems.first.priority, 'high');
    expect(state.actionItems.first.indentLevel, 2);

    container.read(todoControllerProvider.notifier).setSearchQuery('launch');

    expect(
      container.read(todoControllerProvider).actionItems.single.id,
      'later',
    );
  });

  test('todo controller only writes completion overrides from the UI', () {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 3, 8);
    database.todos.insert(
      TodoRecord(
        id: 'completion-todo',
        sourceCaptureId: 'capture-completion',
        payload: const <String, Object?>{
          'title': 'Model-provided action',
          'source_label': 'source: capture-completion',
          'status_label': 'suggested action',
          'suggestion_kind': 'action',
          'suggestion_confidence': 'high',
          'suggestion_reason': 'explicit_action',
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        todoNowProvider.overrideWithValue(now),
      ],
    );
    addTearDown(container.dispose);

    container.read(todoControllerProvider.notifier).complete('completion-todo');

    final record = database.todos.readById('completion-todo')!;
    expect(record.payload['title'], 'Model-provided action');
    expect(record.payload['completed_at'], isA<String>());
    expect(record.payload['completed_by'], 'user');
    expect(record.payload['user_overrides'], contains('status'));
    expect(record.payload.containsKey('priority'), isFalse);
    expect(record.payload.containsKey('due_at'), isFalse);
    expect(record.payload.containsKey('indent_level'), isFalse);
    expect(record.payload.containsKey('sort_order'), isFalse);
  });
}
