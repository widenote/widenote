import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.enterText(
      find.byKey(const Key('memory-search-field')),
      'source-linked',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('memory-list-row-memory-page-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('memory-edit-memory-page-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('memory-edit-field')),
      'Edited source-linked Memory body.',
    );
    await tester.tap(find.byKey(const Key('memory-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Edited source-linked Memory body.'), findsOneWidget);
    expect(database.memoryItems.readById('memory-page-1')!.revision, 2);

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
    expect(find.byKey(const Key('memory-edit-memory-page-1')), findsOneWidget);
  });
}

Future<void> _pumpMemoryPage(
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
        home: Scaffold(body: MemoryPage()),
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
