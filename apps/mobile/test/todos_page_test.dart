import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/todos/application/todo_controller.dart';
import 'package:widenote_mobile/features/todos/presentation/todo_detail_page.dart';
import 'package:widenote_mobile/features/todos/presentation/todos_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('todos page completes, keeps, and reopens a source-linked todo', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedTodo(database);
    await _pumpTodosPage(tester, database);

    expect(find.byKey(const Key('todo-row-todo-page-1')), findsOneWidget);
    expect(find.text('Suggested action'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-checkbox-todo-page-1')));
    await tester.pumpAndSettle();

    expect(database.todos.readById('todo-page-1')!.status, 'completed');
    expect(
      database.todos.readById('todo-page-1')!.payload['completed_at'],
      isA<String>(),
    );
    expect(find.byKey(const Key('todo-row-todo-page-1')), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(
      find.byKey(const Key('todo-completed-at-todo-page-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('todo-reopen-todo-page-1')), findsOneWidget);
    final completedTitle = tester.widget<Text>(
      find.text('Review source-linked todo'),
    );
    expect(completedTitle.style?.decoration, TextDecoration.lineThrough);
    final completedBody = tester.widget<Text>(
      find.text('Keep source-linked context.'),
    );
    expect(completedBody.style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.byKey(const Key('todo-reopen-todo-page-1')));
    await tester.pumpAndSettle();

    expect(database.todos.readById('todo-page-1')!.status, 'open');
    expect(
      database.todos
          .readById('todo-page-1')!
          .payload
          .containsKey('completed_at'),
      isFalse,
    );

    expect(find.byKey(const Key('todo-source-todo-page-1')), findsNothing);

    await tester.tap(find.byKey(const Key('todo-row-todo-page-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-detail-page')), findsOneWidget);
    final sourceButton = find.byKey(
      const Key('todo-detail-source-todo-page-1'),
    );
    await tester.drag(
      find.byKey(const Key('todo-detail-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    expect(find.text('source: capture-todo-page'), findsOneWidget);
    await tester.tap(sourceButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-source-destination')), findsOneWidget);
    expect(find.text('capture-todo-page'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-detail-page')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todos-page')), findsOneWidget);
    expect(find.byKey(const Key('todo-source-destination')), findsNothing);
  });

  testWidgets('todos page localizes derived status and source labels', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedTodo(database);
    await _pumpTodosPage(tester, database, locale: const Locale('zh'));

    expect(find.text('智能体建议行动'), findsOneWidget);
    expect(find.text('来源：capture-todo-page'), findsNothing);
    expect(find.text('suggested by agent'), findsNothing);
  });

  testWidgets('todos page separates schedule candidates from actions', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedSchedule(database);
    await _pumpTodosPage(tester, database);

    expect(find.text('Schedule candidates'), findsOneWidget);
    expect(find.byKey(const Key('todo-row-schedule-page-1')), findsOneWidget);
    expect(
      find.byKey(const Key('todo-schedule-icon-schedule-page-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('todo-checkbox-schedule-page-1')),
      findsNothing,
    );
    expect(find.text('Schedule candidate'), findsOneWidget);
    expect(find.text('Time cue: tomorrow'), findsOneWidget);
    expect(find.byKey(const Key('todo-source-schedule-page-1')), findsNothing);
  });

  testWidgets('todo detail page edits local metadata', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedTodo(database);
    await _pumpTodosPage(tester, database);

    await tester.tap(find.byKey(const Key('todo-row-todo-page-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-detail-page')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('todo-detail-title-field')),
      'Updated detail title',
    );
    await tester.tap(find.byKey(const Key('todo-detail-save-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-priority-medium')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-due-tomorrow')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('todo-detail-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-indent-increase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-sort-later')));
    await tester.pumpAndSettle();

    final record = database.todos.readById('todo-page-1')!;
    expect(record.payload['title'], 'Updated detail title');
    expect(record.payload['priority'], 'medium');
    expect(record.payload['due_at'], isA<String>());
    expect(record.payload['indent_level'], 1);
    expect(record.payload['sort_order'], 100);
  });

  testWidgets('todo detail page reopens completed rows with crossed subtasks', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedCompletedTodo(database);
    await _pumpTodosPage(tester, database);

    await tester.tap(find.byKey(const Key('todo-row-todo-completed-page')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-detail-page')), findsOneWidget);
    expect(
      find.text(
        'Completed tasks stay at the bottom. Reopen to move this task back to active buckets.',
      ),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('todo-detail-scroll')),
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    final subtask = tester.widget<Text>(
      find.byKey(const Key('todo-detail-subtask-subtask-draft')),
    );
    expect(subtask.style?.decoration, TextDecoration.lineThrough);
    await tester.drag(
      find.byKey(const Key('todo-detail-scroll')),
      const Offset(0, 280),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('todo-detail-toggle-todo-completed-page')),
    );
    await tester.pumpAndSettle();

    final record = database.todos.readById('todo-completed-page')!;
    expect(record.status, 'open');
    expect(record.payload.containsKey('completed_at'), isFalse);
  });

  testWidgets('todos page pull-to-refresh reloads local todo rows', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpTodosPage(tester, database);

    expect(find.byKey(const Key('todo-row-todo-refresh-1')), findsNothing);

    final now = DateTime.utc(2026, 7, 2, 11);
    database.todos.insert(
      TodoRecord(
        id: 'todo-refresh-1',
        sourceCaptureId: 'capture-refresh-page',
        payload: const <String, Object?>{
          'title': 'Refresh visible todo',
          'source_label': 'source: capture-refresh-page',
          'status_label': 'suggested action',
          'suggestion_kind': 'action',
          'suggestion_confidence': 'high',
          'suggestion_reason': 'external_insert',
        },
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.drag(
      find.byKey(const Key('todos-page')),
      const Offset(0, 320),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-row-todo-refresh-1')), findsOneWidget);
    expect(find.text('Refresh visible todo'), findsOneWidget);
  });
}

Future<void> _pumpTodosPage(
  WidgetTester tester,
  WideNoteLocalDatabase database, {
  Locale locale = const Locale('en'),
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: TodosPage()),
      ),
      GoRoute(
        path: '/todos/:todoId',
        builder: (context, state) =>
            TodoDetailPage(todoId: state.pathParameters['todoId'] ?? ''),
      ),
      GoRoute(
        path: '/timeline/items/:itemId',
        builder: (context, state) => Scaffold(
          key: const Key('todo-source-destination'),
          body: Text(state.pathParameters['itemId'] ?? ''),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        todoNowProvider.overrideWithValue(DateTime(2026, 7, 3, 9)),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _seedTodo(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 6, 25, 10);
  database.todos.insert(
    TodoRecord(
      id: 'todo-page-1',
      sourceCaptureId: 'capture-todo-page',
      payload: const <String, Object?>{
        'title': 'Review source-linked todo',
        'source_label': 'source: capture-todo-page',
        'status_label': 'suggested action',
        'suggestion_kind': 'action',
        'suggestion_confidence': 'high',
        'suggestion_reason': 'explicit_action',
        'body': 'Keep source-linked context.',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _seedSchedule(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 6, 25, 11);
  database.todos.insert(
    TodoRecord(
      id: 'schedule-page-1',
      sourceCaptureId: 'capture-schedule-page',
      payload: const <String, Object?>{
        'title': 'Schedule: Fix launch bugs tomorrow',
        'source_label': 'source: capture-schedule-page',
        'status_label': 'schedule candidate',
        'suggestion_kind': 'schedule',
        'suggestion_confidence': 'high',
        'suggestion_reason': 'explicit_schedule',
        'scheduled_at_label': 'tomorrow',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _seedCompletedTodo(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 7, 2, 15);
  database.todos.insert(
    TodoRecord(
      id: 'todo-completed-page',
      sourceCaptureId: 'capture-completed-page',
      status: 'completed',
      payload: const <String, Object?>{
        'title': 'Completed launch task',
        'source_label': 'source: capture-completed-page',
        'status_label': 'suggested action',
        'suggestion_kind': 'action',
        'suggestion_confidence': 'high',
        'suggestion_reason': 'explicit_action',
        'completed_at': '2026-07-02T15:00:00.000Z',
        'completed_by': 'user',
        'subtasks': <Object?>[
          <String, Object?>{
            'id': 'subtask-draft',
            'title': 'Draft launch note',
            'completed': false,
          },
        ],
      },
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now,
    ),
  );
}
