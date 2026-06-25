import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/todos/presentation/todos_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('todos page completes and reopens a source-linked todo', (
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
    expect(find.text('completed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-toggle-todo-page-1')));
    await tester.pumpAndSettle();

    expect(database.todos.readById('todo-page-1')!.status, 'open');
    expect(find.text('suggested by agent'), findsOneWidget);
  });
}

Future<void> _pumpTodosPage(
  WidgetTester tester,
  WideNoteLocalDatabase database,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TodosPage()),
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
