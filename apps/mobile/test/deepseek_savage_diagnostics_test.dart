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
  const scenarioLimit = int.fromEnvironment(
    'WIDENOTE_QA_DEEPSEEK_SAVAGE_LIMIT',
  );
  final hasApiKey = apiKey.trim().isNotEmpty;

  group(
    'DeepSeek Savage diagnostics',
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
        'keeps source truth and blocks default lightweight insights across corner cases',
        () async {
          final provider = modelProviderFromConfig(
            config: ModelProviderConfig(
              id: 'deepseek-savage',
              kind: ModelProviderKind.anthropicCompatible,
              displayName: 'DeepSeek Savage Diagnostics',
              endpoint: Uri.parse(endpointValue),
              model: model,
              apiKey: apiKey.trim(),
            ),
            httpClient: httpClient,
          );
          final modelClient = RuntimeModelClientAdapter(
            provider: provider,
            model: model,
          );
          final eventStore = runtime.InMemoryEventStore();
          final traceSink = runtime.InMemoryTraceSink();
          final clock = TickingWnClock(DateTime.utc(2026, 7, 4, 8));
          final orchestrator = CaptureOrchestrator.local(
            eventStore: eventStore,
            traceSink: traceSink,
            clock: clock,
            idGenerator: SequenceWnIdGenerator(seed: 'deepseek-savage'),
            model: modelClient,
            enabledPackIds: const <String>[
              'pack.default',
              'pack.todo',
              'pack.pkm_library',
            ],
          );

          final scenarios = _limitedScenarios(scenarioLimit);
          final outcomes = <String>[];
          for (final scenario in scenarios) {
            final result = await orchestrator.processCapture(
              scenario.input,
              captureId: 'capture-savage-${scenario.id}',
            );
            final outcome =
                '${scenario.id}: memory=${result.memoryItem.statusLabel}; '
                'todo=${result.todo.statusLabel}; '
                'events=${result.eventTypes.join(",")}';
            outcomes.add(outcome);
            debugPrint('[DeepSeek Savage] $outcome', wrapWidth: 1024);
            _expectScenarioResult(result, scenario, apiKey: apiKey.trim());
          }

          final events = await eventStore.readAll();
          expect(
            events.map((event) => event.type),
            isNot(contains(runtime.WnEventTypes.insightCreated)),
          );
          expect(
            events
                .where(
                  (event) => event.type == runtime.WnEventTypes.cardCreated,
                )
                .length,
            scenarios.length,
          );
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
                  (event) => event.type == runtime.WnEventTypes.artifactCreated,
                )
                .length,
            scenarios.length,
          );

          final traces = await traceSink.readAll();
          expect(
            traces.map((trace) => trace.name),
            contains('runtime.model.completed'),
          );
          expect(
            traces.map((trace) => trace.name),
            isNot(contains('runtime.handler.output_rejected')),
          );
          for (final trace in traces) {
            expect(trace.details.toString(), isNot(contains(apiKey.trim())));
          }
          debugPrint(
            '[DeepSeek Savage diagnostics]\n${outcomes.join('\n')}',
            wrapWidth: 1024,
          );
        },
        timeout: const Timeout(Duration(minutes: 8)),
      );
    },
  );
}

List<_SavageScenario> _limitedScenarios(int limit) {
  if (limit <= 0) {
    return _scenarios;
  }
  return _scenarios.take(limit).toList(growable: false);
}

void _expectScenarioResult(
  CapturePipelineResult result,
  _SavageScenario scenario, {
  required String apiKey,
}) {
  expect(result.record.status, 'Processed locally');
  expect(result.record.body, scenario.input);
  expect(result.memoryGenerated, isTrue);
  expect(result.memoryItem.summary.trim(), isNotEmpty);
  expect(result.memoryItem.summary.length, lessThanOrEqualTo(240));
  expect(result.memoryItem.sourceRecordId, isNotEmpty);
  expect(result.cards, isNotEmpty);
  expect(result.insights, isEmpty);
  expect(
    result.eventTypes,
    containsAll(<String>[
      runtime.WnEventTypes.captureCreated,
      runtime.WnEventTypes.memoryProposed,
      runtime.WnEventTypes.cardCreated,
      runtime.WnEventTypes.artifactCreated,
    ]),
  );
  expect(
    result.eventTypes,
    isNot(contains(runtime.WnEventTypes.insightCreated)),
  );
  expect(result.memoryItem.summary, isNot(contains(apiKey)));

  if (scenario.mustSuggestTodo) {
    expect(
      result.todo.isSuggested,
      isTrue,
      reason: '${scenario.id} should become an explicit todo.',
    );
  }
  if (scenario.mustStayQuiet) {
    expect(
      result.todo.isSuggested,
      isFalse,
      reason: '${scenario.id} should not become a todo.',
    );
  }
  if (scenario.mustRouteMemoryToReview) {
    expect(
      result.memoryItem.needsReview,
      isTrue,
      reason: '${scenario.id} should route risky Memory to review.',
    );
  }
  if (scenario.forbiddenVerbatim != null) {
    expect(
      result.memoryItem.summary,
      isNot(contains(scenario.forbiddenVerbatim)),
    );
    final pkm = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.artifactCreated,
    );
    expect(pkm.payload.toString(), isNot(contains(scenario.forbiddenVerbatim)));
  }

  final sourceEventId = result.record.sourceEventId;
  expect(sourceEventId, isNotNull);
  final memoryEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.memoryProposed,
  );
  final cardEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.cardCreated,
  );
  final artifactEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.artifactCreated,
  );
  for (final event in <CapturePipelineEvent>[
    memoryEvent,
    cardEvent,
    artifactEvent,
  ]) {
    expect(event.payload.toString(), isNot(contains(apiKey)));
    final refs = event.payload['source_refs'];
    expect(refs, isA<List<Object?>>());
    expect(
      _sourceRefIds(refs as List<Object?>),
      containsAll(<String>[result.record.id, sourceEventId!]),
    );
  }

  for (final trace in result.traces) {
    expect(trace.detail, isNot(contains(apiKey)));
  }
}

Set<String> _sourceRefIds(List<Object?> sourceRefs) {
  return sourceRefs
      .whereType<Map>()
      .map((sourceRef) => sourceRef['id'])
      .whereType<String>()
      .toSet();
}

const _fakeSecret = 'sk-savage-demo-token-rotate-0000';

const _scenarios = <_SavageScenario>[
  _SavageScenario(
    id: 'real-work-schedule',
    input:
        'Savage A: 周三 16:00 前把 WideNote 洞察方案发给林舟，重点说明 pack.insight_depth 独立于默认捕捉链路。',
    mustSuggestTodo: true,
  ),
  _SavageScenario(
    id: 'quiet-reflection',
    input: 'Savage B: 今天的状态是先焦虑后平稳，散步以后思路清楚了；这只是观察，不需要创建任何待办。',
    mustStayQuiet: true,
    mustRouteMemoryToReview: true,
  ),
  _SavageScenario(
    id: 'credential-like',
    input: 'Savage C: 在测试日志里看到 $_fakeSecret，记住只需要轮换测试串，不能把完整 token 存进 Memory。',
    mustRouteMemoryToReview: true,
    forbiddenVerbatim: _fakeSecret,
  ),
  _SavageScenario(
    id: 'conflicting-preference',
    input: 'Savage D: 上周我说先做导入，今天决定先做快速捕捉和重度洞察；以后评审时要主动指出这种偏好变化。',
    mustSuggestTodo: false,
  ),
  _SavageScenario(
    id: 'mixed-language',
    input:
        'Savage E: 请把 Pack Library 卡片排序改成 source, trust, category, capability first；中文说明里明确不要再写轻量洞察。',
    mustSuggestTodo: true,
  ),
  _SavageScenario(
    id: 'noisy-symbols',
    input:
        'Savage F: keep /tmp/widenote-savage, literal quote "洞察不是统计", issue #INS-204, and tag @local-first unchanged.',
    mustStayQuiet: true,
  ),
];

final class _SavageScenario {
  const _SavageScenario({
    required this.id,
    required this.input,
    this.mustSuggestTodo = false,
    this.mustStayQuiet = false,
    this.mustRouteMemoryToReview = false,
    this.forbiddenVerbatim,
  }) : assert(!(mustSuggestTodo && mustStayQuiet));

  final String id;
  final String input;
  final bool mustSuggestTodo;
  final bool mustStayQuiet;
  final bool mustRouteMemoryToReview;
  final String? forbiddenVerbatim;
}
