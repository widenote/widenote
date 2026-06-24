import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';

void main() {
  testWidgets('plugins tab shows agent platform queue and permissions', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('agent-platform-panel')),
      80,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('agent-platform-panel')), findsOneWidget);
    expect(
      find.byKey(const Key('agent-pack-status-pack-default')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('agent-run-task-queued-capture')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('agent-run-task-denied-permission')),
      findsOneWidget,
    );
    expect(find.text('permission denied'), findsWidgets);
    expect(
      find.text('Missing permission: model.complete · attempt 1/1'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('agent-run-task-script-denied')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Script runtime blocked until sandbox exists · attempt 1/1'),
      findsOneWidget,
    );
  });

  testWidgets('retry and cancel update runs and pack status sync', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('agent-run-retry-task-failed-retry')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('agent-run-retry-task-failed-retry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('agent-run-retry-task-failed-retry')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Retry queued for fake executor · attempt 1/2'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('agent-run-cancel-task-queued-capture')),
      -80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('agent-run-cancel-task-queued-capture')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('agent-run-cancel-task-queued-capture')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Canceled before local executor start · attempt 0/2'),
      findsOneWidget,
    );

    final defaultPack = find.byKey(const Key('agent-pack-status-pack-default'));
    expect(
      find.descendant(of: defaultPack, matching: find.text('canceled')),
      findsOneWidget,
    );

    final todoPack = find.byKey(const Key('agent-pack-status-pack-todo'));
    expect(
      find.descendant(of: todoPack, matching: find.text('queued')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  final database = WideNoteLocalDatabase.inMemory();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: const WideNoteApp(),
    ),
  );
  await tester.pumpAndSettle();
}
