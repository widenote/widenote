import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/usage_stats/application/usage_stats_controller.dart';
import 'package:widenote_mobile/features/usage_stats/presentation/usage_stats_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  test(
    'usage stats aggregate local input, model, tool, memory, and cache data',
    () {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _seedUsageStats(database);

      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          usageStatsClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 7, 3, 12),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = container.read(usageStatsControllerProvider);

      expect(snapshot.total.inputCount, 1);
      expect(snapshot.total.inputCharacters, 'WideNote local stats'.length);
      expect(snapshot.total.modelCallCount, 1);
      expect(snapshot.total.inputTokens, 100);
      expect(snapshot.total.outputTokens, 40);
      expect(snapshot.total.totalTokens, 140);
      expect(snapshot.total.cachedTokens, 25);
      expect(snapshot.total.cachedInputTokenRatio, 0.25);
      expect(snapshot.total.toolRequestCount, 1);
      expect(snapshot.total.toolCompletedCount, 1);
      expect(snapshot.total.toolFailedCount, 1);
      expect(snapshot.total.contextPacketCallCount, 1);
      expect(snapshot.total.contextPacketReuseHitCount, 1);
      expect(snapshot.total.contextPacketReuseRatio, 1);
      expect(snapshot.total.contextCacheRowCount, 2);
      expect(snapshot.total.contextCacheActiveCount, 1);
      expect(snapshot.total.contextCacheInvalidatedCount, 1);
      expect(snapshot.total.memoryProducedCount, 2);

      final agent = snapshot.agentSummaries.singleWhere(
        (summary) => summary.agentId == 'agent.capture_loop',
      );
      expect(agent.metrics.totalTokens, 140);
      expect(agent.metrics.toolRequestCount, 1);
      expect(agent.metrics.memoryProducedCount, 2);
      expect(
        snapshot.dailyBuckets.map((bucket) => bucket.key),
        contains('2026-07-01'),
      );
      expect(
        snapshot.dailyBuckets.map((bucket) => bucket.key),
        isNot(contains('2025-01-01')),
      );
      expect(
        snapshot.weeklyBuckets.map((bucket) => bucket.key),
        contains('2026-06-29'),
      );
    },
  );

  test('usage stats tracks model failures and unknown agent fallback', () {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    database.traceEvents.insert(
      TraceEventRecord(
        id: 'trace-model-failed',
        name: 'runtime.model.failed',
        level: 'error',
        status: 'failed',
        runIdOverride: 'run-orphan',
        payload: const <String, Object?>{
          'trace_type': 'model',
          'input_tokens': 12,
          'output_tokens': 0,
          'total_tokens': 12,
        },
        createdAt: DateTime.utc(2026, 7, 2, 12),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        usageStatsClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 3, 12),
        ),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = container.read(usageStatsControllerProvider);

    expect(snapshot.total.modelCallCount, 1);
    expect(snapshot.total.modelFailureCount, 1);
    final unknownAgent = snapshot.agentSummaries.singleWhere(
      (summary) => summary.agentId == usageStatsUnknownAgentId,
    );
    expect(unknownAgent.metrics.modelCallCount, 1);
    expect(unknownAgent.metrics.modelFailureCount, 1);
    expect(unknownAgent.metrics.totalTokens, 12);
  });

  testWidgets('usage stats page renders daily and weekly dashboard metrics', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedUsageStats(database);

    await _pumpUsageStatsPage(tester, database);

    expect(find.byKey(const Key('usage-stats-page')), findsOneWidget);
    expect(find.text('Usage Statistics'), findsOneWidget);
    expect(find.byKey(const Key('usage-stat-total-tokens')), findsOneWidget);
    expect(find.text('140'), findsWidgets);
    expect(find.text('25 · 25%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('usage-stat-context-reuse')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('1 reused / 1 context calls'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('usage-trend-2026-07-01')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('usage-trend-2026-07-01')), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('usage-trend-2026-06-29')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('usage-trend-2026-06-29')), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('usage-stats-agent-agent.capture_loop')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('usage-stat-input-count')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('usage-agent-row-agent.capture_loop')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('usage-agent-row-agent.capture_loop')),
      findsOneWidget,
    );
  });

  testWidgets('usage stats page renders empty state in Chinese', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();

    await _pumpUsageStatsPage(tester, database, locale: const Locale('zh'));

    expect(find.byKey(const Key('usage-stats-page')), findsOneWidget);
    expect(find.text('使用统计'), findsOneWidget);
    expect(find.text('按日'), findsOneWidget);
    expect(find.text('按周'), findsOneWidget);
    expect(find.text('还没有使用统计'), findsOneWidget);
    expect(find.byKey(const Key('usage-stat-total-tokens')), findsNothing);
  });
}

Future<void> _pumpUsageStatsPage(
  WidgetTester tester,
  WideNoteLocalDatabase database, {
  Locale locale = const Locale('en'),
}) async {
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        usageStatsClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 3, 12),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: UsageStatsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _seedUsageStats(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 7, 1, 12);
  database.captures.insert(
    CaptureRecord(
      id: 'capture-usage',
      sourceType: 'text',
      payload: const <String, Object?>{'text': 'WideNote local stats'},
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.memoryItems.insert(
    MemoryItemRecord(
      id: 'memory-accepted',
      key: 'usage.accepted',
      body: 'Usage stats should stay local.',
      status: 'active',
      payload: const <String, Object?>{'agent_id': 'agent.capture_loop'},
      createdAt: now.add(const Duration(minutes: 1)),
      updatedAt: now.add(const Duration(minutes: 1)),
    ),
  );
  database.memoryCandidates.insert(
    MemoryCandidateRecord(
      id: 'memory-candidate',
      key: 'usage.candidate',
      body: 'Token dashboards need review.',
      status: 'needs_review',
      payload: const <String, Object?>{'agent_id': 'agent.capture_loop'},
      createdAt: now.add(const Duration(minutes: 2)),
      updatedAt: now.add(const Duration(minutes: 2)),
    ),
  );
  database.traceEvents.insert(
    TraceEventRecord(
      id: 'trace-model',
      name: 'runtime.model.completed',
      level: 'info',
      runIdOverride: 'run-usage',
      packId: 'pack.default',
      agentId: 'agent.capture_loop',
      payload: const <String, Object?>{
        'trace_type': 'model',
        'input_tokens': 100,
        'output_tokens': 40,
        'total_tokens': 140,
        'cached_tokens': 25,
        'thought_tokens': 6,
        'estimated_cost_usd': 0.012,
      },
      createdAt: now.add(const Duration(minutes: 3)),
    ),
  );
  database.traceEvents.insert(
    TraceEventRecord(
      id: 'trace-tool-requested',
      name: 'runtime.tool.requested',
      level: 'info',
      runIdOverride: 'run-usage',
      packId: 'pack.default',
      agentId: 'agent.capture_loop',
      payload: const <String, Object?>{
        'trace_type': 'tool',
        'tool_name': 'context_packet.build',
      },
      createdAt: now.add(const Duration(minutes: 4)),
    ),
  );
  database.traceEvents.insert(
    TraceEventRecord(
      id: 'trace-tool-completed',
      name: 'runtime.tool.completed',
      level: 'info',
      runIdOverride: 'run-usage',
      packId: 'pack.default',
      agentId: 'agent.capture_loop',
      payload: const <String, Object?>{
        'trace_type': 'tool',
        'tool_name': 'context_packet.build',
        'raw_tool_result': <String, Object?>{'reused_cache': true},
      },
      createdAt: now.add(const Duration(minutes: 5)),
    ),
  );
  database.traceEvents.insert(
    TraceEventRecord(
      id: 'trace-tool-failed',
      name: 'runtime.tool.failed',
      level: 'warning',
      status: 'failed',
      runIdOverride: 'run-usage',
      packId: 'pack.default',
      agentId: 'agent.capture_loop',
      payload: const <String, Object?>{
        'trace_type': 'tool',
        'tool_name': 'memory.read',
      },
      createdAt: now.add(const Duration(minutes: 6)),
    ),
  );
  database.contextPacketCaches.insert(
    ContextPacketCacheRecord(
      id: 'cache-active',
      surface: 'chat',
      permissionScope: 'memory.read',
      disclosureLevel: 'targeted_excerpt',
      generatorId: 'test',
      generatorVersion: '1',
      promptVersion: 'prompt-v1',
      cacheKey: 'cache-active-key',
      packet: const <String, Object?>{'sections': <Object?>[]},
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
      ],
      sourceVersions: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-1', 'version': 1},
      ],
      createdAt: now.add(const Duration(minutes: 7)),
      updatedAt: now.add(const Duration(minutes: 7)),
    ),
  );
  database.contextPacketCaches.insert(
    ContextPacketCacheRecord(
      id: 'cache-invalidated',
      surface: 'chat',
      permissionScope: 'memory.read',
      disclosureLevel: 'targeted_excerpt',
      generatorId: 'test',
      generatorVersion: '1',
      promptVersion: 'prompt-v1',
      cacheKey: 'cache-invalidated-key',
      status: 'invalidated',
      packet: const <String, Object?>{'sections': <Object?>[]},
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
      ],
      sourceVersions: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-1', 'version': 1},
      ],
      createdAt: now.add(const Duration(minutes: 8)),
      updatedAt: now.add(const Duration(minutes: 8)),
      invalidatedAt: now.add(const Duration(minutes: 9)),
    ),
  );

  database.traceEvents.insert(
    TraceEventRecord(
      id: 'trace-old',
      name: 'runtime.model.completed',
      level: 'info',
      payload: const <String, Object?>{
        'trace_type': 'model',
        'total_tokens': 999,
      },
      createdAt: DateTime.utc(2025, 1, 1),
    ),
  );
}
