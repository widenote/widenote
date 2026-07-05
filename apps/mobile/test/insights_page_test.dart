import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/app_router.dart';
import 'package:widenote_mobile/app/app_theme.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/insights/application/insights_controller.dart';
import 'package:widenote_mobile/features/insights/presentation/insights_page.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/features/system_permissions/application/system_permissions_controller.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

import 'support/fake_system_permission_adapter.dart';

void main() {
  testWidgets('insights page shows empty active state without bottom tabs', (
    tester,
  ) async {
    await _pumpRoute(tester, '/insights');

    expect(find.byKey(const Key('insights-page')), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('No source-linked insights yet.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('insights page renders detail evidence and source refs', (
    tester,
  ) async {
    await _pumpRoute(tester, '/insights', seed: _seedInsight);

    expect(
      find.byKey(const Key('insight-row-insight-depth-1')),
      findsOneWidget,
    );
    expect(find.text('Review rhythm'), findsOneWidget);
    expect(find.text('3 source links'), findsOneWidget);

    await tester.tap(find.byKey(const Key('insight-row-insight-depth-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('insight-detail-page')), findsOneWidget);
    expect(find.text('Insight detail'), findsOneWidget);
    expect(
      find.text('Capture and Memory agree on review rhythm.'),
      findsOneWidget,
    );
    expect(find.text('Review follows capture.'), findsOneWidget);
    expect(find.text('78% confidence'), findsWidgets);

    await _scrollUntilFinder(
      tester,
      find.byKey(const Key('insight-evidence-section')),
    );
    expect(find.text('Evidence'), findsOneWidget);
    expect(find.text('Same project context'), findsOneWidget);

    await _scrollUntilFinder(
      tester,
      find.byKey(const Key('insight-counter-evidence-section')),
    );
    expect(find.text('Counter-evidence'), findsOneWidget);
    expect(find.text('Short window'), findsOneWidget);

    await _scrollUntilFinder(
      tester,
      find.byKey(const Key('source-ref-capture-capture-insight-1')),
    );
    expect(find.text('Capture: capture-insight-1'), findsWidgets);
  });

  testWidgets('insights page does not expose archive or restore actions', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedInsight(database);

    await _pumpRoute(tester, '/insights', database: database);

    expect(database.insights.readById('insight-depth-1')!.status, 'active');
    expect(
      find.byKey(const Key('insight-row-insight-depth-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('insight-row-archive-insight-depth-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('insight-row-restore-insight-depth-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('insights-archived-section')), findsNothing);
    expect(database.eventLog.readByType('wn.insight.archived'), isEmpty);
    expect(database.eventLog.readByType('wn.insight.restored'), isEmpty);
  });

  testWidgets('insights page hides legacy archived rows', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedInsight(database, status: 'archived');

    await _pumpRoute(tester, '/insights', database: database);

    expect(database.insights.readById('insight-depth-1')!.status, 'archived');
    expect(find.byKey(const Key('insight-row-insight-depth-1')), findsNothing);
    expect(find.text('No source-linked insights yet.'), findsOneWidget);

    await _pumpRoute(tester, '/insights/insight-depth-1', database: database);

    expect(find.byKey(const Key('insight-detail-missing')), findsOneWidget);
    expect(find.byKey(const Key('insight-detail-page')), findsNothing);
  });

  testWidgets('home insight teaser opens the insight detail page', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedInsight(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          locationSettingsRepositoryProvider.overrideWithValue(
            InMemoryLocationSettingsRepository(),
          ),
          systemPermissionAdapterProvider.overrideWithValue(
            FakeSystemPermissionAdapter.ready(),
          ),
        ],
        child: const WideNoteApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-open-insight-insight-depth-1')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('home-page')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('home-open-insight-insight-depth-1')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('insight-detail-page')), findsOneWidget);
    expect(find.text('Insight detail'), findsOneWidget);
    expect(
      find.text('Capture and Memory agree on review rhythm.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'insight detail reads local DB when controller snapshot is stale',
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      final container = ProviderContainer(
        overrides: [localDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() {
        container.dispose();
        database.close();
      });
      expect(
        container.read(insightsControllerProvider).itemById('insight-depth-1'),
        isNull,
      );

      _seedInsight(database);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InsightDetailPage(insightId: 'insight-depth-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('insight-detail-page')), findsOneWidget);
      expect(
        find.text('Capture and Memory agree on review rhythm.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('insight-detail-missing')), findsNothing);
    },
  );
}

Future<void> _scrollUntilFinder(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRoute(
  WidgetTester tester,
  String initialLocation, {
  WideNoteLocalDatabase? database,
  void Function(WideNoteLocalDatabase database)? seed,
}) async {
  final ownedDatabase = database ?? WideNoteLocalDatabase.inMemory();
  seed?.call(ownedDatabase);
  final router = createAppRouter(initialLocation: initialLocation);
  if (database == null) {
    addTearDown(ownedDatabase.close);
  }
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(ownedDatabase),
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
        systemPermissionAdapterProvider.overrideWithValue(
          FakeSystemPermissionAdapter.ready(),
        ),
      ],
      child: MaterialApp.router(
        title: 'WideNote',
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: WideNoteAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _seedInsight(WideNoteLocalDatabase database, {String status = 'active'}) {
  final now = DateTime.utc(2026, 7, 3, 9);
  database.captures.insert(
    CaptureRecord(
      id: 'capture-insight-1',
      sourceType: 'manual',
      status: 'processed',
      payload: const <String, Object?>{
        'text': 'Synthetic review rhythm capture.',
      },
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
  );
  database.memoryItems.insert(
    MemoryItemRecord(
      id: 'memory-insight-1',
      key: 'project.review.rhythm',
      body: 'Synthetic Memory keeps the project review context.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-insight-1'},
      ],
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now.subtract(const Duration(hours: 1)),
    ),
  );
  database.insights.insert(
    InsightRecord(
      id: 'insight-depth-1',
      insightKind: 'behavior_loop',
      title: 'Review rhythm',
      summary: 'Capture and Memory agree on review rhythm.',
      sourceRefs: const <Object?>[
        <String, Object?>{
          'kind': 'capture',
          'id': 'capture-insight-1',
          'excerpt': 'Synthetic review rhythm capture.',
        },
        <String, Object?>{'kind': 'memory', 'id': 'memory-insight-1'},
        <String, Object?>{'kind': 'todo', 'id': 'todo-insight-1'},
      ],
      metricLabel: 'source-linked',
      metricValue: 3,
      status: status,
      payload: const <String, Object?>{
        'confidence': 0.78,
        'sensitivity': 'low',
        'evidence_density': 'medium',
        'claims': <Object?>[
          <String, Object?>{
            'id': 'claim.review.rhythm',
            'text': 'Review follows capture.',
            'confidence': 0.78,
            'source_refs': <Object?>[
              <String, Object?>{
                'kind': 'capture',
                'id': 'capture-insight-1',
                'excerpt': 'Synthetic review rhythm capture.',
              },
            ],
          },
        ],
        'metrics': <Object?>[
          <String, Object?>{
            'label': 'source-linked',
            'value': 3,
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-insight-1'},
            ],
          },
        ],
        'source_refs': <Object?>[
          <String, Object?>{'kind': 'capture', 'id': 'capture-insight-1'},
          <String, Object?>{'kind': 'memory', 'id': 'memory-insight-1'},
          <String, Object?>{'kind': 'todo', 'id': 'todo-insight-1'},
        ],
        'evidence': <Object?>[
          <String, Object?>{
            'id': 'evidence.same.project',
            'kind': 'supporting',
            'label': 'Same project context',
            'text': 'The capture and Memory cite the same review project.',
            'confidence': 0.8,
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-insight-1'},
              <String, Object?>{'kind': 'memory', 'id': 'memory-insight-1'},
            ],
          },
        ],
        'counter_evidence': <Object?>[
          <String, Object?>{
            'id': 'counter.short.window',
            'kind': 'counter',
            'label': 'Short window',
            'text': 'The fixture covers a short synthetic window.',
            'confidence': 0.7,
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-insight-1'},
            ],
          },
        ],
        'ui_blocks': <Object?>[
          <String, Object?>{'kind': 'claim_list'},
          <String, Object?>{'kind': 'metric_row'},
          <String, Object?>{'kind': 'evidence_list'},
          <String, Object?>{'kind': 'counter_evidence'},
          <String, Object?>{'kind': 'source_refs'},
        ],
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
}
