import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_mobile/features/capture/application/capture_replay_service.dart';
import 'package:widenote_mobile/features/settings/presentation/debugging_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('debugging page confirms Agent retry and shows summary', (
    tester,
  ) async {
    final service = _FakeCaptureReplayService(
      snapshot: const CaptureReplaySnapshot(
        retryableAgentTasks: 2,
        matchingCaptures: 3,
        agentBatchLimit: 100,
        captureBatchLimit: 50,
      ),
      agentResult: const AgentRetryBatchResult(
        retryableAgentTasks: 2,
        selectedAgentTasks: 2,
        retriedAgentTasks: 2,
        drainedRuntimeTasks: 2,
        refreshedCaptures: 1,
        failedRefreshes: 0,
        skippedRefreshes: 0,
        limited: false,
      ),
    );
    await _pumpDebuggingPage(tester, service);

    expect(find.byKey(const Key('debugging-page')), findsOneWidget);
    expect(find.text('Retry failed Agents'), findsWidgets);

    await tester.tap(find.byKey(const Key('debugging-retry-agents-button')));
    await tester.pumpAndSettle();
    expect(find.text('Retry failed Agents?'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.retryCalls, 1);
    await tester.drag(
      find.byKey(const Key('debugging-page')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Retried 2 of 2 tasks'), findsOneWidget);
  });

  testWidgets('debugging page confirms date replay and shows summary', (
    tester,
  ) async {
    final service = _FakeCaptureReplayService(
      snapshot: const CaptureReplaySnapshot(
        retryableAgentTasks: 0,
        matchingCaptures: 3,
        agentBatchLimit: 100,
        captureBatchLimit: 50,
      ),
      dateResult: const CaptureDateReplayResult(
        matchingCaptures: 3,
        selectedCaptures: 3,
        processedCaptures: 1,
        retriedCaptures: 1,
        refreshedCaptures: 1,
        failedCaptures: 0,
        skippedCaptures: 0,
        deferredCaptures: 0,
        limited: false,
      ),
    );
    await _pumpDebuggingPage(tester, service);

    await tester.tap(
      find.byKey(const Key('debugging-process-date-range-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Process historical inputs?'), findsOneWidget);

    await tester.tap(find.text('Process'));
    await tester.pumpAndSettle();

    expect(service.replayCalls, 1);
    await tester.drag(
      find.byKey(const Key('debugging-page')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Processed 1, retried 1'), findsOneWidget);
  });
}

Future<void> _pumpDebuggingPage(
  WidgetTester tester,
  CaptureReplayService service,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [captureReplayServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: DebuggingPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeCaptureReplayService implements CaptureReplayService {
  _FakeCaptureReplayService({
    required CaptureReplaySnapshot snapshot,
    AgentRetryBatchResult? agentResult,
    CaptureDateReplayResult? dateResult,
  }) : _snapshot = snapshot,
       _agentResult = agentResult,
       _dateResult = dateResult;

  CaptureReplaySnapshot _snapshot;
  final AgentRetryBatchResult? _agentResult;
  final CaptureDateReplayResult? _dateResult;
  var retryCalls = 0;
  var replayCalls = 0;

  @override
  CaptureReplaySnapshot snapshot(CaptureReplayDateRange range) => _snapshot;

  @override
  Future<AgentRetryBatchResult> retryFailedAgents() async {
    retryCalls += 1;
    _snapshot = CaptureReplaySnapshot(
      retryableAgentTasks: 0,
      matchingCaptures: _snapshot.matchingCaptures,
      agentBatchLimit: _snapshot.agentBatchLimit,
      captureBatchLimit: _snapshot.captureBatchLimit,
    );
    return _agentResult ??
        const AgentRetryBatchResult(
          retryableAgentTasks: 0,
          selectedAgentTasks: 0,
          retriedAgentTasks: 0,
          drainedRuntimeTasks: 0,
          refreshedCaptures: 0,
          failedRefreshes: 0,
          skippedRefreshes: 0,
          limited: false,
        );
  }

  @override
  Future<CaptureDateReplayResult> replayDateRange(
    CaptureReplayDateRange range,
  ) async {
    replayCalls += 1;
    return _dateResult ??
        const CaptureDateReplayResult(
          matchingCaptures: 0,
          selectedCaptures: 0,
          processedCaptures: 0,
          retriedCaptures: 0,
          refreshedCaptures: 0,
          failedCaptures: 0,
          skippedCaptures: 0,
          deferredCaptures: 0,
          limited: false,
        );
  }
}
