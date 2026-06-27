import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_model_providers/model_providers.dart';
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';
import 'package:widenote_mobile/features/model_providers/application/model_provider_settings_controller.dart';

void main() {
  const apiKey = String.fromEnvironment('WIDENOTE_QA_DEEPSEEK_API_KEY');
  const endpointValue = String.fromEnvironment(
    'WIDENOTE_QA_DEEPSEEK_ENDPOINT',
    defaultValue: 'https://api.deepseek.com/anthropic',
  );
  const model = String.fromEnvironment(
    'WIDENOTE_QA_DEEPSEEK_MODEL',
    defaultValue: 'deepseek-v4-flash',
  );
  final hasApiKey = apiKey.trim().isNotEmpty;

  group(
    'DeepSeek Anthropic-compatible agent orchestration live QA',
    skip: hasApiKey
        ? null
        : 'Pass --dart-define=WIDENOTE_QA_DEEPSEEK_API_KEY to run live QA.',
    () {
      late DartIoModelProviderHttpClient httpClient;

      setUp(() {
        httpClient = DartIoModelProviderHttpClient();
      });

      tearDown(() {
        httpClient.close();
      });

      test(
        'runs realistic quick captures through live agent orchestration',
        () async {
          final endpoint = Uri.parse(endpointValue);
          final provider = modelProviderFromConfig(
            config: ModelProviderConfig(
              id: 'deepseek-live',
              kind: ModelProviderKind.anthropicCompatible,
              displayName: 'DeepSeek Live QA',
              endpoint: endpoint,
              model: model,
              apiKey: apiKey,
            ),
            httpClient: httpClient,
          );
          final modelClient = RuntimeModelClientAdapter(
            provider: provider,
            model: model,
          );
          final eventStore = runtime.InMemoryEventStore();
          final traceSink = runtime.InMemoryTraceSink();
          final clock = const SystemWnClock();
          final orchestrator = CaptureOrchestrator.local(
            eventStore: eventStore,
            traceSink: traceSink,
            clock: clock,
            idGenerator: MonotonicWnIdGenerator(clock: clock),
            model: modelClient,
          );
          final scenarios = _liveCaptureScenarios();
          final allExclusiveNeedles = scenarios
              .expand((scenario) => scenario.exclusiveNeedles)
              .toSet();

          for (final indexed in scenarios.indexed) {
            final index = indexed.$1;
            final scenario = indexed.$2;
            final result = await orchestrator.processCapture(
              scenario.input,
              captureId: 'capture-deepseek-live-${scenario.id}',
            );

            debugPrint(
              '[DeepSeek live QA] ${scenario.id}: '
              '${result.memoryItem.statusLabel} | '
              '${result.memoryItem.summary}',
              wrapWidth: 1024,
            );

            expect(result.record.status, 'Processed locally');
            expect(result.record.id, 'capture-deepseek-live-${scenario.id}');
            expect(result.record.body, scenario.input);
            expect(result.memoryItem.summary.trim(), isNotEmpty);
            expect(result.memoryItem.summary.length, lessThanOrEqualTo(240));
            expect(result.memoryItem.sourceRecordId, isNotEmpty);
            expect(result.memoryItem.needsReview, isTrue);
            expect(result.memoryItem.statusLabel, 'needs review');
            expect(result.reviewCandidate, isNotNull);
            expect(result.todo.isSuggested, isTrue);
            expect(
              result.todo.title,
              contains(scenario.input.substring(0, 20)),
            );
            expect(result.acceptedMemoryCount, 0);
            expect(result.reviewMemoryCount, index + 1);
            _expectSummaryMatchesScenario(
              result.memoryItem.summary,
              scenario,
              forbiddenNeedles: allExclusiveNeedles.difference(
                scenario.exclusiveNeedles.toSet(),
              ),
            );
            _expectScenarioEventShape(result, scenario);
          }

          final events = await eventStore.readAll();
          expect(
            events
                .where(
                  (event) => event.type == runtime.WnEventTypes.memoryProposed,
                )
                .length,
            scenarios.length,
          );
          expect(
            events
                .where(
                  (event) => event.type == runtime.WnEventTypes.todoSuggested,
                )
                .length,
            scenarios.length,
          );

          final traces = await traceSink.readAll();
          expect(
            traces
                .where((trace) => trace.name == 'runtime.run.completed')
                .map((trace) => trace.packId),
            containsAll(<String>['pack.default', 'pack.todo']),
          );
          expect(
            traces
                .where((trace) => trace.name == 'runtime.model.completed')
                .length,
            scenarios.length,
          );

          for (final modelCompletedTrace in traces.where(
            (trace) => trace.name == 'runtime.model.completed',
          )) {
            expect(modelCompletedTrace.details['provider_id'], 'deepseek-live');
            expect(modelCompletedTrace.details['model'], model);
            expect(
              modelCompletedTrace.details.toString(),
              isNot(contains(apiKey)),
            );
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
  );
}

List<_LiveCaptureScenario> _liveCaptureScenarios() {
  return const <_LiveCaptureScenario>[
    _LiveCaptureScenario(
      id: 'work',
      input:
          '今天和张雨讨论 Project Atlas，下周三前我负责把 ADR-12 的 Agent Runtime '
          '决策摘要发给她，重点是 local-first 和后端扩展点。',
      expectedNeedles: <String>['张雨', 'Project Atlas', 'ADR-12'],
      exclusiveNeedles: <String>['张雨', 'Project Atlas', 'ADR-12'],
    ),
    _LiveCaptureScenario(
      id: 'health',
      input:
          '昨晚 23:40 才睡，今天咖啡喝了两杯，下午焦虑感 6/10，跑步 20 分钟后缓解。'
          '以后晚上 10 点半提醒自己停工。',
      expectedNeedles: <String>['23:40', '焦虑', '跑步', '10 点半'],
      exclusiveNeedles: <String>['23:40', '6/10', '跑步'],
    ),
    _LiveCaptureScenario(
      id: 'home',
      input: '家里低糖酸奶只剩一盒，周末去山姆买蓝莓、燕麦和无糖苏打水；别买榴莲味零食，我不喜欢。',
      expectedNeedles: <String>['低糖酸奶', '蓝莓', '榴莲', '山姆'],
      exclusiveNeedles: <String>['低糖酸奶', '蓝莓', '榴莲'],
    ),
    _LiveCaptureScenario(
      id: 'product',
      input:
          '试用 WideNote 捕捉语音时发现，嘈杂咖啡馆里转写会漏掉人名；后续 Agent '
          '要在生成 Memory 前保留原始音频引用。',
      expectedNeedles: <String>['WideNote', '嘈杂咖啡馆', '原始音频', 'Memory'],
      exclusiveNeedles: <String>['嘈杂咖啡馆', '原始音频引用'],
    ),
  ];
}

void _expectScenarioEventShape(
  CapturePipelineResult result,
  _LiveCaptureScenario scenario,
) {
  final sourceEventId = result.record.sourceEventId;
  expect(sourceEventId, isNotNull);
  final checkedSourceEventId = sourceEventId!;
  expect(
    result.eventTypes,
    containsAllInOrder(<String>[
      runtime.WnEventTypes.captureCreated,
      runtime.WnEventTypes.memoryProposed,
      runtime.WnEventTypes.cardCreated,
      runtime.WnEventTypes.insightCreated,
      runtime.WnEventTypes.todoSuggested,
    ]),
  );
  for (final type in <String>[
    runtime.WnEventTypes.memoryProposed,
    runtime.WnEventTypes.cardCreated,
    runtime.WnEventTypes.insightCreated,
    runtime.WnEventTypes.todoSuggested,
  ]) {
    expect(
      result.eventTypes.where((eventType) => eventType == type),
      hasLength(1),
    );
  }

  final memoryEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.memoryProposed,
  );
  expect(memoryEvent.packId, 'pack.default');
  expect(memoryEvent.agentId, 'agent.capture_loop');
  expect(memoryEvent.payload['text'], result.memoryItem.summary);
  expect(
    memoryEvent.payload['source_excerpt'],
    contains(scenario.input.substring(0, 20)),
  );
  final memorySourceRefs = memoryEvent.payload['source_refs'];
  expect(memorySourceRefs, isA<List<Object?>>());
  expect(
    _sourceRefIds(memorySourceRefs as List<Object?>),
    containsAll(<String>[result.record.id, checkedSourceEventId]),
  );

  final cardEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.cardCreated,
  );
  expect(cardEvent.payload['source_capture_id'], result.record.id);
  expect(cardEvent.payload['source_event_id'], checkedSourceEventId);
  expect(
    _sourceRefIds(cardEvent.payload['source_refs']! as List<Object?>),
    containsAll(<String>[result.record.id, checkedSourceEventId]),
  );

  final insightEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.insightCreated,
  );
  expect(insightEvent.payload['source_capture_id'], result.record.id);
  expect(insightEvent.payload['source_event_id'], checkedSourceEventId);
  expect(
    _sourceRefIds(insightEvent.payload['source_refs']! as List<Object?>),
    containsAll(<String>[result.record.id, checkedSourceEventId]),
  );

  final todoEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.todoSuggested,
  );
  expect(todoEvent.packId, 'pack.todo');
  expect(todoEvent.agentId, 'agent.todo_loop');
  expect(todoEvent.payload['source_event_id'], checkedSourceEventId);
  expect(result.todo.sourceCaptureId, result.record.id);
  expect(result.todo.sourceEventId, checkedSourceEventId);
}

void _expectSummaryMatchesScenario(
  String summary,
  _LiveCaptureScenario scenario, {
  required Set<String> forbiddenNeedles,
}) {
  final matchedNeedles = scenario.expectedNeedles
      .where((needle) => summary.contains(needle))
      .toList(growable: false);
  expect(
    matchedNeedles,
    isNotEmpty,
    reason:
        'Memory summary should retain at least one scenario anchor for '
        '${scenario.id}. Summary: $summary',
  );
  for (final needle in forbiddenNeedles) {
    expect(
      summary,
      isNot(contains(needle)),
      reason:
          'Memory summary for ${scenario.id} appears to include another '
          'scenario anchor "$needle". Summary: $summary',
    );
  }
}

final class _LiveCaptureScenario {
  const _LiveCaptureScenario({
    required this.id,
    required this.input,
    required this.expectedNeedles,
    required this.exclusiveNeedles,
  });

  final String id;
  final String input;
  final List<String> expectedNeedles;
  final List<String> exclusiveNeedles;
}

Set<String> _sourceRefIds(List<Object?> sourceRefs) {
  return sourceRefs
      .whereType<Map>()
      .map((sourceRef) => sourceRef['id'])
      .whereType<String>()
      .toSet();
}
