import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';

void main() {
  testWidgets('plugins page opens pack library and permission gate', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDatabaseProvider.overrideWithValue(database)],
        child: const WideNoteApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pack-library-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pack-library-page')), findsOneWidget);
    expect(find.byKey(const Key('pack-row-pack.default')), findsOneWidget);
    expect(find.byKey(const Key('pack-row-pack.todo')), findsOneWidget);
    expect(find.text('Default Capture Loop'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('permission-gate-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('permission-gate-page')), findsOneWidget);
    expect(
      find.byKey(const Key('permission-row-model.complete')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('permission-row-script.execute')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('permission-row-script.execute')),
      findsOneWidget,
    );
    expect(find.text('Deferred high-risk permissions'), findsOneWidget);
  });
}
