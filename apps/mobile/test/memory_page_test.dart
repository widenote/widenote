import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/memory/presentation/memory_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('memory page searches edits tombstones and restores Memory', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedMemory(database);
    await _pumpMemoryPage(tester, database);

    expect(find.byKey(const Key('memory-page')), findsOneWidget);
    expect(find.text('Source-linked Memory body.'), findsOneWidget);
    final searchField = tester.widget<TextField>(
      find.byKey(const Key('memory-search-field')),
    );
    expect(searchField.keyboardType, TextInputType.text);
    expect(searchField.textInputAction, TextInputAction.search);

    await tester.enterText(
      find.byKey(const Key('memory-search-field')),
      'source-linked',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('memory-search-requires-retriever')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('memory-list-row-memory-page-1')),
      findsNothing,
    );

    await tester.enterText(find.byKey(const Key('memory-search-field')), '');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('memory-list-row-memory-page-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('memory-edit-memory-page-1')));
    await tester.pumpAndSettle();
    final editField = tester.widget<TextField>(
      find.byKey(const Key('memory-edit-field')),
    );
    expect(editField.keyboardType, TextInputType.multiline);
    expect(editField.textCapitalization, TextCapitalization.sentences);
    await tester.enterText(
      find.byKey(const Key('memory-edit-field')),
      'Edited source-linked Memory body.',
    );
    await tester.tap(find.byKey(const Key('memory-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Edited source-linked Memory body.'), findsOneWidget);
    expect(database.memoryItems.readById('memory-page-1')!.revision, 2);
    expect(
      database.eventLog.readByType(runtime.WnEventTypes.memoryEdited),
      hasLength(1),
    );
    expect(
      database.traceEvents.readAll().map((trace) => trace.name),
      contains('memory.lifecycle.edited'),
    );

    await tester.tap(find.byKey(const Key('memory-delete-memory-page-1')));
    await tester.pumpAndSettle();

    expect(database.memoryItems.readById('memory-page-1')!.tombstone, isTrue);
    await tester.enterText(find.byKey(const Key('memory-search-field')), '');
    await tester.pumpAndSettle();
    expect(find.text('Deleted Memory'), findsOneWidget);
    expect(
      find.byKey(const Key('memory-restore-memory-page-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('memory-restore-memory-page-1')));
    await tester.pumpAndSettle();

    final restored = database.memoryItems.readById('memory-page-1')!;
    expect(restored.tombstone, isFalse);
    expect(restored.status, 'active');
    expect(restored.revision, 4);
    expect(
      database.eventLog.readByType(runtime.WnEventTypes.memoryDeleted),
      hasLength(1),
    );
    expect(
      database.eventLog.readByType(runtime.WnEventTypes.memoryRestored),
      hasLength(1),
    );
    expect(
      database.traceEvents.readAll().map((trace) => trace.name),
      containsAll(<String>[
        'memory.lifecycle.deleted',
        'memory.lifecycle.restored',
      ]),
    );
    expect(find.byKey(const Key('memory-edit-memory-page-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('memory-source-memory-page-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('memory-source-destination')), findsOneWidget);
    expect(find.text('capture-memory-page'), findsOneWidget);
  });

  testWidgets('memory page localizes derived tags and source labels', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedMemory(database);
    await _pumpMemoryPage(tester, database, locale: const Locale('zh'));

    expect(find.text('项目'), findsOneWidget);
    expect(find.text('低敏感度'), findsOneWidget);
    expect(find.text('记录：capture-memory-page'), findsOneWidget);
    expect(find.text('capture: capture-memory-page'), findsNothing);
  });
}

Future<void> _pumpMemoryPage(
  WidgetTester tester,
  WideNoteLocalDatabase database, {
  Locale locale = const Locale('en'),
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: MemoryPage()),
      ),
      GoRoute(
        path: '/timeline/items/:itemId',
        builder: (context, state) => Scaffold(
          key: const Key('memory-source-destination'),
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

void _seedMemory(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 6, 25, 9);
  database.memoryItems.insert(
    MemoryItemRecord(
      id: 'memory-page-1',
      key: 'project.memory_page',
      body: 'Source-linked Memory body.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-memory-page'},
      ],
      memoryType: 'project',
      confidence: 'high',
      sensitivity: 'low',
      createdAt: now,
      updatedAt: now,
    ),
  );
}
