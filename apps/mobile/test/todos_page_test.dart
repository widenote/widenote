import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/todos/presentation/todos_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('todos page completes and hides a source-linked todo', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedTodo(database);
    await _pumpTodosPage(tester, database);

    expect(find.byKey(const Key('todo-row-todo-page-1')), findsOneWidget);
    expect(find.text('suggested by agent'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-checkbox-todo-page-1')));
    await tester.pumpAndSettle();

    expect(database.todos.readById('todo-page-1')!.status, 'completed');
    expect(find.byKey(const Key('todo-row-todo-page-1')), findsNothing);

    database.todos.updateStatus('todo-page-1', 'open');
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpTodosPage(tester, database);
    expect(find.text('suggested by agent'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-source-todo-page-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-source-destination')), findsOneWidget);
    expect(find.text('capture-todo-page'), findsOneWidget);

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

    expect(find.text('智能体建议'), findsOneWidget);
    expect(find.text('来源：capture-todo-page'), findsOneWidget);
    expect(find.text('suggested by agent'), findsNothing);
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
      overrides: [localDatabaseProvider.overrideWithValue(database)],
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
        'status_label': 'suggested by agent',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
}
