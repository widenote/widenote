import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/recap/application/daily_recap_repository.dart';
import 'package:widenote_mobile/features/recap/presentation/daily_recap_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('daily recap shows a natural empty state for today', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);

    await _pumpRecapPage(tester, database);

    expect(find.byKey(const Key('recap-page')), findsOneWidget);
    expect(find.text('Daily Recap'), findsOneWidget);
    expect(find.text('Nothing recorded today yet.'), findsOneWidget);
    expect(find.byKey(const Key('recap-stat-captures')), findsOneWidget);
    expect(find.byKey(const Key('recap-empty-state')), findsOneWidget);
  });

  testWidgets('daily recap summarizes local source-linked object truth', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedRecapData(database);

    await _pumpRecapPage(tester, database);

    expect(find.text('Daily Recap'), findsOneWidget);
    expect(
      find.text('Today from local object truth · 2026-06-26'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recap-empty-state')), findsNothing);
    expect(find.text('WideNote phase-one recap planning'), findsOneWidget);
    expect(find.text('Lin prefers source-linked Daily Recap'), findsOneWidget);

    await _scrollUntilText(tester, 'Follow up on recap source links');
    expect(find.text('Follow up on recap source links'), findsOneWidget);
    expect(find.text('Archive recap notes'), findsOneWidget);
    expect(find.text('Complete stale yesterday source'), findsNothing);

    await _scrollUntilText(tester, 'Daily Recap card');
    expect(find.text('Daily Recap card'), findsOneWidget);
    expect(
      find.text('Capture became Memory and insight today'),
      findsOneWidget,
    );

    await _scrollUntilText(tester, 'Insight says recap kept sources');
    expect(find.text('Insight says recap kept sources'), findsOneWidget);
    expect(find.text('Recap insight claim keeps source refs.'), findsOneWidget);
    expect(find.text('1 source-linked'), findsOneWidget);
    expect(find.text('Capture: capture-today'), findsWidgets);

    await _scrollUntilText(tester, '2 events · 1 trace');
    expect(find.text('2 events · 1 trace'), findsOneWidget);
  });

  testWidgets('home header opens Daily Recap as a second-level page', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          dailyRecapNowProvider.overrideWithValue(_today),
        ],
        child: const WideNoteApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-daily-recap-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recap-page')), findsOneWidget);
    expect(find.text('Daily Recap'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('recap-back-button'))).dx,
      lessThan(tester.getTopLeft(find.text('Daily Recap')).dx),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byKey(const Key('recap-page')), findsNothing);
  });

  testWidgets('daily recap exposes core Chinese copy', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);

    await _pumpRecapPage(tester, database, locale: const Locale('zh'));

    expect(find.text('每日回顾'), findsOneWidget);
    expect(find.text('今天还没有记录。'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('未完成待办'), findsOneWidget);
  });

  testWidgets('daily recap localizes derived entry and source labels', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _seedRecapData(database);

    await _pumpRecapPage(tester, database, locale: const Locale('zh'));

    expect(find.text('记录'), findsWidgets);
    expect(find.text('记忆'), findsWidgets);
    await _scrollUntilText(tester, '记录：capture-today');
    expect(find.text('记录：capture-today'), findsWidgets);
    expect(
      localizedSourceLabel(
        AppLocalizations.of(
          tester.element(find.byKey(const Key('recap-page'))),
        ),
        'capture: $_localCaptureId',
      ),
      '本地记录 · ${_timeLabel(_localCaptureTime)}',
    );
    expect(
      localizedSourceLabel(
        AppLocalizations.of(
          tester.element(find.byKey(const Key('recap-page'))),
        ),
        'source: capture:$_localCaptureId +1',
      ),
      '本地记录 · ${_timeLabel(_localCaptureTime)} +1',
    );
    await _scrollUntilText(tester, '1 可溯源');
    expect(find.text('1 可溯源'), findsOneWidget);
    expect(find.text('source: capture:capture-today'), findsNothing);
  });
}

Future<void> _pumpRecapPage(
  WidgetTester tester,
  WideNoteLocalDatabase database, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        dailyRecapNowProvider.overrideWithValue(_today),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: DailyRecapPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  final scrollable = find.byType(Scrollable).first;
  for (var attempt = 0; attempt < 10 && finder.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

void _seedRecapData(WideNoteLocalDatabase database) {
  final todayMorning = DateTime.utc(2026, 6, 26, 8);
  final todayMidday = DateTime.utc(2026, 6, 26, 12);
  final yesterday = DateTime.utc(2026, 6, 25, 12);

  database.captures.insert(
    CaptureRecord(
      id: 'capture-today',
      sourceType: 'manual',
      sourceId: 'event-capture-today',
      status: 'processed',
      payload: const <String, Object?>{
        'text': 'WideNote phase-one recap planning',
        'source_event_id': 'event-capture-today',
      },
      createdAt: todayMorning,
      updatedAt: todayMorning,
    ),
  );
  database.captures.insert(
    CaptureRecord(
      id: 'capture-yesterday',
      sourceType: 'manual',
      payload: const <String, Object?>{'text': 'Old note'},
      createdAt: yesterday,
      updatedAt: yesterday,
    ),
  );
  database.eventLog.append(
    EventLogEntry(
      id: 'event-capture-today',
      type: 'wn.capture.created',
      actor: 'user',
      subjectKind: 'capture',
      subjectId: 'capture-today',
      payload: const <String, Object?>{
        'text': 'WideNote phase-one recap planning',
      },
      createdAt: todayMorning,
    ),
  );
  database.eventLog.append(
    EventLogEntry(
      id: 'event-card-today',
      type: 'wn.card.created',
      actor: 'agent',
      sourceEventId: 'event-capture-today',
      subjectKind: 'capture',
      subjectId: 'capture-today',
      payload: const <String, Object?>{'title': 'Daily Recap card'},
      createdAt: todayMidday,
    ),
  );
  database.memoryItems.insert(
    MemoryItemRecord(
      id: 'memory-today',
      key: 'capture.capture-today.summary',
      sourceCaptureId: 'capture-today',
      sourceEventId: 'event-capture-today',
      body: 'Lin prefers source-linked Daily Recap',
      sourceRefs: const <Object?>[
        <String, Object?>{
          'kind': 'capture',
          'id': 'capture-today',
          'excerpt': 'WideNote phase-one recap planning',
        },
      ],
      createdAt: todayMidday,
      updatedAt: todayMidday,
    ),
  );
  database.cards.insert(
    CardRecord(
      id: 'card-today',
      cardKind: 'capture_summary',
      title: 'Daily Recap card',
      body: 'Capture became Memory and insight today',
      sourceRefs: const <Object?>[
        <String, Object?>{
          'kind': 'capture',
          'id': 'capture-today',
          'excerpt': 'WideNote phase-one recap planning',
        },
      ],
      createdAt: todayMidday,
      updatedAt: todayMidday,
    ),
  );
  database.insights.insert(
    InsightRecord(
      id: 'insight-today',
      insightKind: 'summary',
      title: 'Recap source coverage',
      summary: 'Insight says recap kept sources',
      sourceRefs: const <Object?>[
        <String, Object?>{
          'kind': 'capture',
          'id': 'capture-today',
          'excerpt': 'WideNote phase-one recap planning',
        },
      ],
      metricLabel: 'source-linked',
      metricValue: 1,
      payload: const <String, Object?>{
        'claims': <Object?>[
          <String, Object?>{
            'id': 'claim.recap.sources',
            'text': 'Recap insight claim keeps source refs.',
            'source_refs': <Object?>[
              <String, Object?>{
                'kind': 'capture',
                'id': 'capture-today',
                'excerpt': 'WideNote phase-one recap planning',
              },
            ],
          },
        ],
        'metrics': <Object?>[
          <String, Object?>{
            'label': 'source-linked',
            'value': 1,
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-today'},
            ],
          },
        ],
        'source_refs': <Object?>[
          <String, Object?>{'kind': 'capture', 'id': 'capture-today'},
        ],
        'ui_blocks': <Object?>[
          <String, Object?>{'kind': 'claim_list'},
          <String, Object?>{'kind': 'metric_row'},
          <String, Object?>{'kind': 'source_refs'},
          <String, Object?>{'kind': 'note'},
        ],
      },
      createdAt: todayMidday,
      updatedAt: todayMidday,
    ),
  );
  database.todos.insert(
    TodoRecord(
      id: 'todo-open',
      sourceCaptureId: 'capture-today',
      sourceEventId: 'event-capture-today',
      payload: const <String, Object?>{
        'title': 'Follow up on recap source links',
      },
      createdAt: todayMidday,
      updatedAt: todayMidday,
    ),
  );
  database.todos.insert(
    TodoRecord(
      id: 'todo-completed',
      sourceCaptureId: 'capture-today',
      sourceEventId: 'event-capture-today',
      status: 'completed',
      payload: const <String, Object?>{'title': 'Archive recap notes'},
      createdAt: todayMidday,
      updatedAt: todayMidday,
    ),
  );
  database.todos.insert(
    TodoRecord(
      id: 'todo-stale-completed',
      sourceCaptureId: 'capture-yesterday',
      status: 'completed',
      payload: const <String, Object?>{
        'title': 'Complete stale yesterday source',
      },
      createdAt: yesterday,
      updatedAt: todayMidday,
    ),
  );
  database.traceEvents.insert(
    TraceEventRecord(
      id: 'trace-today',
      name: 'agent.output',
      level: 'info',
      message: 'Generated synthetic recap data',
      sourceEventId: 'event-capture-today',
      packId: 'pack.default',
      agentId: 'agent.capture_loop',
      createdAt: todayMidday,
    ),
  );
}

final _today = DateTime(2026, 6, 26, 18);
final _localCaptureTime = DateTime(2026, 6, 26, 7, 30);
final _localCaptureId = 'local-${_localCaptureTime.microsecondsSinceEpoch}';

String _timeLabel(DateTime localTime) {
  final hour = localTime.hour.toString().padLeft(2, '0');
  final minute = localTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
