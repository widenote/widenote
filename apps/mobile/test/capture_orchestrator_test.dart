import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_memory/memory.dart' as memory;
import 'package:widenote_mobile/features/capture/application/capture_agent_prompts.dart';
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';
import 'package:widenote_mobile/features/plugins/application/official_pack_manifests.dart';

const _corePackIds = <String>['pack.default', 'pack.todo'];
const _todoQuietJson =
    '{"kind":"quiet","title":"","confidence":"high","reason":"ordinary_record","scheduled_at_label":null}';
const _todoActionJson =
    '{"kind":"action","title":"Call Lin about WideNote source-linked todos","confidence":"high","reason":"explicit_action","scheduled_at_label":null}';
const _todoScheduleJson =
    '{"kind":"schedule","title":"Review launch issue tomorrow","confidence":"high","reason":"explicit_schedule","scheduled_at_label":"tomorrow"}';
const _pkmLinJson =
    '{"title":"Lin WideNote preference","summary":"Lin prefers source-linked WideNote todos.","topics":["WideNote","todos"],"people":["Lin"],"projects":["WideNote"],"source_excerpt":"Met Lin about WideNote source-linked todos.","confidence":"high","sensitivity":"low"}';

void main() {
  test(
    'orchestrator registers official native packs aligned with manifests',
    () {
      final orchestrator = CaptureOrchestrator.local(
        clock: TickingWnClock(DateTime.utc(2026, 6, 23, 0)),
        idGenerator: SequenceWnIdGenerator(seed: 'manifest'),
        model: runtime.FakeModel(responses: <String>['Manifest aligned.']),
      );

      final packs = orchestrator.debugRegisteredPacks();
      expect(packs.map((pack) => pack.id), <String>[
        'pack.default',
        'pack.todo',
        'pack.pkm_library',
        'pack.transcript_correction',
      ]);

      for (final pack in packs) {
        final manifest = officialPackManifestSnapshot(pack.id);
        expect(
          () => assertOfficialNativePackAlignment(pack, manifest),
          returnsNormally,
        );
        expect(pack.requiredPermissions, manifest.requiredPermissions);
        expect(
          pack.subscriptions
              .map((subscription) => subscription.id)
              .toList(growable: false),
          <String>[
            for (final subscription in manifest.subscriptions) subscription.id,
          ],
        );
        for (final definition in manifest.agentDefinitions.values) {
          final native = pack.definitionFor(definition.id);
          expect(native.outputEvents, definition.outputEvents);
          expect(
            native.retryPolicy.normalizedMaxAttempts,
            definition.retryPolicy.normalizedMaxAttempts,
          );
          expect(native.modelProfileRef, definition.modelProfileRef);
        }
      }

      expect(
        packs
            .singleWhere((pack) => pack.id == 'pack.default')
            .agents
            .keys
            .toList(growable: false),
        <String>['agent.capture_loop'],
      );
      expect(
        packs
            .singleWhere((pack) => pack.id == 'pack.todo')
            .agents
            .keys
            .toList(growable: false),
        <String>['agent.todo_loop'],
      );
      expect(
        packs
            .singleWhere((pack) => pack.id == 'pack.pkm_library')
            .agents
            .keys
            .toList(growable: false),
        <String>['agent.pkm_profile_builder'],
      );
    },
  );

  test('quick capture runs runtime and silently auto-accepts Memory', () async {
    final model = _SequenceMetadataModel(
      responses: <String>[
        'Lin prefers source-linked WideNote todos.',
        _todoActionJson,
        _pkmLinJson,
      ],
    );
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 1)),
      idGenerator: SequenceWnIdGenerator(seed: 'app'),
      model: model,
    );

    final result = await orchestrator.processCapture(
      'Call Lin about WideNote source-linked todos.',
    );

    expect(result.record.status, 'Processed locally');
    expect(result.memoryItem.title, 'memory.auto_saved');
    expect(result.memoryItem.statusLabel, 'auto-accepted');
    expect(
      result.memoryItem.summary,
      'Lin prefers source-linked WideNote todos.',
    );
    expect(result.acceptedMemoryCount, 1);
    expect(result.reviewMemoryCount, 0);
    expect(result.cards.map((card) => card.kindLabel), [
      'capture card',
      'Memory card',
    ]);
    expect(
      result.cards.map((card) => card.sourceLabel),
      everyElement(startsWith('source:')),
    );
    expect(result.insights.map((insight) => insight.kindLabel), [
      'summary insight',
      'count insight',
      'trend insight',
      'source mix insight',
      'action pattern insight',
    ]);
    expect(
      result.insights.map((insight) => insight.sourceLabel),
      everyElement(startsWith('source:')),
    );
    expect(model.requests, hasLength(3));
    expect(model.requests.first.prompt, contains('Call Lin'));
    expect(
      model.requests.first.prompt,
      contains(captureMemoryPromptCaptureTextMarker),
    );
    expect(model.requests.first.prompt, contains('Return exactly one JSON'));
    expect(model.requests.first.context['prompt_ref'], captureMemoryPromptRef);
    expect(model.requests[1].prompt, contains('WideNote Todo Loop Agent'));
    expect(model.requests[1].context['prompt_ref'], todoSuggestionPromptRef);
    expect(model.requests.last.prompt, contains('PKM Personal Library Agent'));
    expect(model.requests.last.context['prompt_ref'], pkmProfilePromptRef);
    expect(
      result.eventTypes,
      containsAllInOrder(<String>[
        runtime.WnEventTypes.captureCreated,
        runtime.WnEventTypes.memoryProposed,
        runtime.WnEventTypes.cardCreated,
        runtime.WnEventTypes.insightCreated,
        runtime.WnEventTypes.todoSuggested,
        runtime.WnEventTypes.artifactCreated,
      ]),
    );
    _expectEventOrigin(
      result.events,
      runtime.WnEventTypes.memoryProposed,
      packId: 'pack.default',
      agentId: 'agent.capture_loop',
    );
    final sourceEventId = result.record.sourceEventId;
    expect(sourceEventId, isNotNull);
    final memoryEvent = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.memoryProposed,
    );
    expect(
      _sourceRefIds(memoryEvent.payload['source_refs']! as List<Object?>),
      containsAll(<String>[result.record.id, sourceEventId!]),
    );
    _expectEventOrigin(
      result.events,
      runtime.WnEventTypes.cardCreated,
      packId: 'pack.default',
      agentId: 'agent.capture_loop',
    );
    _expectEventOrigin(
      result.events,
      runtime.WnEventTypes.insightCreated,
      packId: 'pack.default',
      agentId: 'agent.capture_loop',
    );
    _expectEventOrigin(
      result.events,
      runtime.WnEventTypes.todoSuggested,
      packId: 'pack.todo',
      agentId: 'agent.todo_loop',
    );
    _expectEventOrigin(
      result.events,
      runtime.WnEventTypes.artifactCreated,
      packId: 'pack.pkm_library',
      agentId: 'agent.pkm_profile_builder',
    );
    final artifactEvent = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.artifactCreated,
    );
    expect(artifactEvent.payload['artifact_kind'], 'pkm_profile_entry');
    expect(artifactEvent.payload['derived_output'], isTrue);
    expect(
      artifactEvent.payload['source_truth'],
      'raw_capture_and_memory_remain_canonical',
    );
    expect(
      _sourceRefIds(artifactEvent.payload['source_refs']! as List<Object?>),
      containsAll(<String>[result.record.id, sourceEventId]),
    );
    expect(
      result.traces.map((trace) => trace.label),
      contains('runtime.run.completed'),
    );
    expect(
      result.traces.where((trace) => trace.label == 'runtime.run.completed'),
      hasLength(3),
    );
    expect(
      result.traces
          .where((trace) => trace.label == 'runtime.run.completed')
          .map((trace) => trace.packId),
      containsAll(<String>['pack.default', 'pack.todo', 'pack.pkm_library']),
    );
  });

  test('disabled PKM pack skips artifact output', () async {
    final model = _SequenceMetadataModel(
      responses: <String>['Core capture memory only.', _todoQuietJson],
    );
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 1, 30)),
      idGenerator: SequenceWnIdGenerator(seed: 'pkm-disabled'),
      model: model,
      enabledPackIds: _corePackIds,
    );

    final result = await orchestrator.processCapture(
      'Do not project this capture into the PKM library.',
    );

    expect(
      result.eventTypes,
      isNot(contains(runtime.WnEventTypes.artifactCreated)),
    );
    expect(model.requests, hasLength(2));
    expect(
      result.traces
          .where((trace) => trace.label == 'runtime.run.completed')
          .map((trace) => trace.packId),
      containsAll(<String>['pack.default', 'pack.todo']),
    );
    expect(
      result.traces
          .where((trace) => trace.label == 'runtime.run.completed')
          .map((trace) => trace.packId),
      isNot(contains('pack.pkm_library')),
    );
  });

  test('todo agent uses model schedule output without local parsing', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 1, 45)),
      idGenerator: SequenceWnIdGenerator(seed: 'todo-schedule'),
      model: _SequenceMetadataModel(
        responses: <String>['Schedule memory.', _todoScheduleJson],
      ),
      enabledPackIds: _corePackIds,
    );

    final result = await orchestrator.processCapture(
      'Launch planning note for the model to classify.',
    );

    expect(result.todo.isSchedule, isTrue);
    expect(result.todo.statusLabel, 'schedule candidate');
    expect(result.todo.scheduledAtLabel, 'tomorrow');
    final todoEvent = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.todoSuggested,
    );
    expect(todoEvent.payload['suggestion_kind'], 'schedule');
    expect(todoEvent.payload['suggestion_reason'], 'explicit_schedule');
  });

  test('fresh orchestrators do not reuse accepted Memory ids', () async {
    final repository = memory.InMemoryMemoryRepository();
    final first = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 1)),
      idGenerator: SequenceWnIdGenerator(seed: 'restart'),
      memoryRepository: repository,
      model: _SequenceMetadataModel(
        responses: <String>['First durable memory.', _todoQuietJson],
      ),
      enabledPackIds: _corePackIds,
    );
    final firstResult = await first.processCapture(
      'First capture before restart.',
      captureId: 'capture-before-restart',
    );

    final second = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 2)),
      idGenerator: SequenceWnIdGenerator(seed: 'restart'),
      memoryRepository: repository,
      model: _SequenceMetadataModel(
        responses: <String>['Second durable memory.', _todoQuietJson],
      ),
      enabledPackIds: _corePackIds,
    );
    final secondResult = await second.processCapture(
      'Second capture after restart.',
      captureId: 'capture-after-restart',
    );

    final items = await repository.listItems(
      status: memory.MemoryItemStatus.active,
    );
    expect(items, hasLength(2));
    expect(secondResult.memoryItem.id, isNot(firstResult.memoryItem.id));
    expect(
      items.map((item) => item.body),
      containsAll(<String>['First durable memory.', 'Second durable memory.']),
    );
  });

  test('provider metadata routes credential-like capture to review', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 2)),
      idGenerator: SequenceWnIdGenerator(seed: 'secret'),
      model: runtime.FakeModel(
        responses: const <String>[
          '{"text":"The user pasted credential-like material that needs review.","memory_type":"credential","confidence":"high","sensitivity":"high","durability":"durable"}',
        ],
      ),
      enabledPackIds: _corePackIds,
    );

    final result = await orchestrator.processCapture(
      'My API token is sk-demo-secret and should not be auto stored.',
    );

    expect(result.acceptedMemoryCount, 0);
    expect(result.reviewMemoryCount, 1);
    expect(result.memoryItem.title, 'memory.needs_review');
    expect(result.memoryItem.statusLabel, 'needs review');
    expect(result.memoryItem.confidenceLabel, contains('sensitive'));
    expect(result.reviewCandidate, isNotNull);
    expect(result.reviewCandidate!.typeLabel, contains('credential'));
    expect(result.reviewCandidate!.reasonLabel, contains('sensitive'));
    final memoryEvent = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.memoryProposed,
    );
    expect(memoryEvent.payload['memory_type'], 'credential');
    expect(memoryEvent.payload['confidence'], 'high');
    expect(memoryEvent.payload['sensitivity'], 'high');
    expect(memoryEvent.payload['durability'], 'durable');
    expect(result.cards.map((card) => card.kindLabel), ['capture card']);
    expect(
      result.insights.map((insight) => insight.kindLabel),
      containsAll(<String>[
        'summary insight',
        'count insight',
        'trend insight',
        'source mix insight',
      ]),
    );
    expect(result.todo.isSuggested, isFalse);
    expect(result.todo.statusLabel, 'not suggested');
    expect(
      result.eventTypes,
      isNot(contains(runtime.WnEventTypes.todoSuggested)),
    );
  });

  test('multiple captures do not duplicate registered pack runs', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 6)),
      idGenerator: SequenceWnIdGenerator(seed: 'repeat'),
      model: _SequenceMetadataModel(
        responses: <String>[
          'First summary.',
          _todoQuietJson,
          'Second summary.',
          _todoQuietJson,
        ],
      ),
      enabledPackIds: _corePackIds,
    );

    final first = await orchestrator.processCapture('First repeat capture.');
    final second = await orchestrator.processCapture('Second repeat capture.');

    for (final result in <CapturePipelineResult>[first, second]) {
      expect(
        result.eventTypes.where(
          (type) => type == runtime.WnEventTypes.memoryProposed,
        ),
        hasLength(1),
      );
      expect(
        result.eventTypes.where(
          (type) => type == runtime.WnEventTypes.cardCreated,
        ),
        hasLength(1),
      );
      expect(
        result.eventTypes.where(
          (type) => type == runtime.WnEventTypes.insightCreated,
        ),
        hasLength(1),
      );
      expect(
        result.eventTypes.where(
          (type) => type == runtime.WnEventTypes.todoSuggested,
        ),
        isEmpty,
      );
      expect(
        result.traces.where((trace) => trace.label == 'runtime.run.completed'),
        hasLength(2),
      );
    }
  });

  test(
    'runtime fails closed when handler emits undeclared output event',
    () async {
      final defaultManifestJson = _mutableManifest('pack.default');
      final defaultAgents = defaultManifestJson['agents']! as List<Object?>;
      final defaultAgent = Map<String, Object?>.from(
        defaultAgents.first! as Map,
      );
      defaultAgent['output_events'] = <String>[
        runtime.WnEventTypes.memoryProposed,
      ];
      defaultManifestJson['agents'] = <Object?>[defaultAgent];
      final defaultManifest = _parseManifest(defaultManifestJson);
      final eventStore = runtime.InMemoryEventStore();
      final traceSink = runtime.InMemoryTraceSink();
      final permissions = runtime.InMemoryPermissionBroker()
        ..grantAll(defaultManifest.id, defaultManifest.requiredPermissions);
      final kernel = runtime.RuntimeKernel(
        eventStore: eventStore,
        traceSink: traceSink,
        permissionBroker: permissions,
        toolRegistry: runtime.InMemoryToolRegistry(),
        idGenerator: SequenceWnIdGenerator(seed: 'undeclared'),
        clock: TickingWnClock(DateTime.utc(2026, 6, 23, 7)),
        model: runtime.FakeModel(responses: <String>[]),
        deviceId: 'test-device',
      );
      registerOfficialNativePacks(
        kernel,
        manifests: <runtime.AgentPackManifestSnapshot>[defaultManifest],
        nativeHandlersByPackId: <String, Map<String, runtime.AgentHandler>>{
          'pack.default': <String, runtime.AgentHandler>{
            'agent.capture_loop': const _UndeclaredOutputAgent(),
          },
        },
      );

      await kernel.publish(
        runtime.WnEventDraft(
          type: runtime.WnEventTypes.captureCreated,
          actor: runtime.WnActor.user,
          subjectRef: runtime.SubjectRef(kind: 'capture', id: 'capture-1'),
          payload: const <String, Object?>{'text': 'Emit a todo.'},
        ),
      );

      expect(kernel.runs.single.status, runtime.RuntimeRunStatus.failed);
      expect(kernel.tasks.single.status, runtime.RuntimeTaskStatus.failed);
      expect((await eventStore.readAll()).map((event) => event.type), <String>[
        runtime.WnEventTypes.captureCreated,
      ]);
      final traces = await traceSink.readAll();
      expect(
        traces.map((trace) => trace.name),
        contains('runtime.handler.output_rejected'),
      );
      expect(
        traces
            .singleWhere(
              (trace) => trace.name == 'runtime.handler.output_rejected',
            )
            .details['event_type'],
        runtime.WnEventTypes.cardCreated,
      );
    },
  );

  test(
    'model failure fails model-backed capture derivation without local summary',
    () async {
      final eventStore = runtime.InMemoryEventStore();
      final traceSink = runtime.InMemoryTraceSink();
      final orchestrator = CaptureOrchestrator.local(
        eventStore: eventStore,
        traceSink: traceSink,
        clock: TickingWnClock(DateTime.utc(2026, 6, 23, 4)),
        idGenerator: SequenceWnIdGenerator(seed: 'fallback'),
        model: const _FailingModel(),
        enabledPackIds: _corePackIds,
      );

      await expectLater(
        () => orchestrator.processCapture(
          'Keep raw capture usable when the QA model is unavailable.',
        ),
        throwsA(isA<CapturePipelineException>()),
      );

      final events = await eventStore.readAll();
      expect(events.map((event) => event.type), <String>[
        runtime.WnEventTypes.captureCreated,
      ]);
      expect(
        events.map((event) => event.type),
        isNot(contains(runtime.WnEventTypes.memoryProposed)),
      );
      final traces = await traceSink.readAll();
      expect(traces.map((trace) => trace.name), contains('runtime.run.failed'));
      expect(
        traces
            .where((trace) => trace.name == 'runtime.run.failed')
            .map((trace) => trace.details['error'].toString()),
        everyElement(isNot(contains('model_fallback'))),
      );
    },
  );

  test('model status errors do not emit fallback Memory metadata', () async {
    final eventStore = runtime.InMemoryEventStore();
    final orchestrator = CaptureOrchestrator.local(
      eventStore: eventStore,
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 5)),
      idGenerator: SequenceWnIdGenerator(seed: 'rate'),
      model: const _StatusCodeFailingModel(),
      enabledPackIds: _corePackIds,
    );

    await expectLater(
      () => orchestrator.processCapture(
        'Keep rate limit diagnostics without exposing provider secrets.',
      ),
      throwsA(isA<CapturePipelineException>()),
    );

    final events = await eventStore.readAll();
    expect(
      events.map((event) => event.type),
      isNot(contains(runtime.WnEventTypes.memoryProposed)),
    );
  });

  test(
    'provider JSON Memory candidate auto-accepts without raw metadata',
    () async {
      final orchestrator = CaptureOrchestrator.local(
        clock: TickingWnClock(DateTime.utc(2026, 6, 23, 5)),
        idGenerator: SequenceWnIdGenerator(seed: 'json'),
        model: runtime.FakeModel(
          responses: const <String>[
            '{"text":"Lin prefers source-linked WideNote todos.","memory_type":"preference","confidence":"high","sensitivity":"low","durability":"durable"}',
          ],
        ),
        enabledPackIds: _corePackIds,
      );

      final result = await orchestrator.processCapture(
        'Lin prefers source-linked WideNote todos.',
      );

      expect(result.memoryItem.statusLabel, 'auto-accepted');
      expect(result.reviewCandidate, isNull);
      expect(result.acceptedMemoryCount, 1);
      expect(result.reviewMemoryCount, 0);
      expect(
        result.memoryItem.summary,
        'Lin prefers source-linked WideNote todos.',
      );
      final memoryEvent = result.events.singleWhere(
        (event) => event.type == runtime.WnEventTypes.memoryProposed,
      );
      expect(memoryEvent.payload['memory_type'], 'preference');
      expect(memoryEvent.payload['confidence'], 'high');
      expect(memoryEvent.payload['sensitivity'], 'low');
      expect(memoryEvent.payload['durability'], 'durable');
    },
  );

  test('unstructured provider output routes to exception review', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 5, 30)),
      idGenerator: SequenceWnIdGenerator(seed: 'plain'),
      model: runtime.FakeModel(
        responses: const <String>['Lin prefers source-linked WideNote todos.'],
      ),
      enabledPackIds: _corePackIds,
    );

    final result = await orchestrator.processCapture(
      'Synthetic credential-shaped capture sk-demo-secret should not be '
      'classified locally when provider metadata is missing.',
    );

    expect(result.memoryItem.statusLabel, 'needs review');
    expect(result.reviewCandidate, isNotNull);
    expect(result.acceptedMemoryCount, 0);
    expect(result.reviewMemoryCount, 1);
    expect(result.reviewCandidate!.reasonLabel, contains('policy_unclear'));
    final memoryEvent = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.memoryProposed,
    );
    expect(
      memoryEvent.payload['policy_reasons'],
      containsAll(<String>[
        'model_output_unstructured',
        'model_metadata_missing',
      ]),
    );
    expect(memoryEvent.payload['memory_type'], isNull);
    expect(memoryEvent.payload['sensitivity'], isNull);
  });

  test('provider metadata routes health capture to review', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 5, 45)),
      idGenerator: SequenceWnIdGenerator(seed: 'health-risk'),
      model: runtime.FakeModel(
        responses: const <String>[
          '{"text":"The user wants to remember a sleep and anxiety pattern.","memory_type":"health","confidence":"high","sensitivity":"medium","durability":"durable"}',
        ],
      ),
      enabledPackIds: _corePackIds,
    );

    final result = await orchestrator.processCapture(
      '昨晚 23:40 才睡，今天咖啡喝了两杯，下午焦虑感 6/10，'
      '跑步 20 分钟后缓解。以后晚上 10 点半提醒自己停工。',
    );

    expect(result.memoryItem.statusLabel, 'needs review');
    expect(result.reviewCandidate, isNotNull);
    expect(result.acceptedMemoryCount, 0);
    expect(result.reviewMemoryCount, 1);
    expect(result.reviewCandidate!.typeLabel, contains('health'));
    expect(result.reviewCandidate!.reasonLabel, contains('sensitive'));
    final memoryEvent = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.memoryProposed,
    );
    expect(memoryEvent.payload['memory_type'], 'health');
    expect(memoryEvent.payload['sensitivity'], 'medium');
  });

  test('mislabeled health capture is not rewritten by local keywords', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 5, 50)),
      idGenerator: SequenceWnIdGenerator(seed: 'local-health-risk'),
      model: runtime.FakeModel(
        responses: const <String>[
          '{"text":"A13-Run records a stable morning run pattern.","memory_type":"task_context","confidence":"high","sensitivity":"low","durability":"durable"}',
        ],
      ),
      enabledPackIds: _corePackIds,
    );

    final result = await orchestrator.processCapture(
      'A13-Run 今天晨跑配速 6 分 20 秒，膝盖没有不适；'
      '如果连续三次都稳定，再把周末长跑加到 8 公里。',
    );

    expect(result.memoryItem.statusLabel, 'auto-accepted');
    expect(result.reviewCandidate, isNull);
    expect(result.acceptedMemoryCount, 1);
    expect(result.reviewMemoryCount, 0);
    final memoryEvent = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.memoryProposed,
    );
    expect(memoryEvent.payload['memory_type'], 'task_context');
    expect(memoryEvent.payload['sensitivity'], 'low');
    expect(memoryEvent.payload['policy_reasons'], isNull);
  });

  test(
    'media attachments are preserved on source-linked capture event',
    () async {
      final model = runtime.FakeModel(
        responses: <String>['Capture combines text, media, and voice.'],
      );
      final orchestrator = CaptureOrchestrator.local(
        clock: TickingWnClock(DateTime.utc(2026, 6, 24, 6)),
        idGenerator: SequenceWnIdGenerator(seed: 'media'),
        model: model,
        enabledPackIds: _corePackIds,
      );
      const guard = AssetSafetyGuard();
      final photo = guard.buildAttachment(
        await FakePhotoCaptureAdapter(
          now: () => DateTime.utc(2026, 6, 24, 6, 1),
        ).pickFromGallery(),
      );
      final voiceAdapter = FakeVoiceCaptureAdapter(
        now: () => DateTime.utc(2026, 6, 24, 6, 2),
      );
      final voiceSession = await voiceAdapter.startRecording();
      final voiceReview = guard.buildAttachment(
        await voiceAdapter.stopRecording(voiceSession),
      );
      final voice = voiceReview.copyWith(
        state: CaptureAttachmentState.ready,
        reviewReason: null,
      );
      final result = await orchestrator.processCapture(
        'Compare clean-room capture inputs.',
        attachments: <CaptureAttachment>[photo, voice],
      );

      final captureEvent = result.events.singleWhere(
        (event) => event.type == runtime.WnEventTypes.captureCreated,
      );
      final payload = captureEvent.payload;
      final attachments = payload['attachments']! as List<Object?>;
      final sourceRefs = payload['source_refs']! as List<Object?>;

      expect(payload['raw_text'], 'Compare clean-room capture inputs.');
      expect(payload['source'], 'manual_with_attachments');
      expect(payload['attachment_count'], 2);
      expect(sourceRefs, hasLength(3));
      expect(attachments, hasLength(2));
      expect((attachments.first! as Map)['kind'], 'photo');
      expect(
        ((attachments.first! as Map)['raw_metadata']! as Map)['source_uri'],
        'fake://gallery/photo-sample.jpg',
      );
      expect(model.requests, hasLength(2));
      expect(model.requests.first.prompt, contains('Gallery photo'));
      expect(model.requests.first.prompt, contains('Voice recording'));
      expect(result.record.body, 'Compare clean-room capture inputs.');
    },
  );

  test(
    'blocked and review attachments are rejected before event publication',
    () async {
      final eventStore = runtime.InMemoryEventStore();
      final traceSink = runtime.InMemoryTraceSink();
      final orchestrator = CaptureOrchestrator.local(
        eventStore: eventStore,
        traceSink: traceSink,
        clock: TickingWnClock(DateTime.utc(2026, 6, 24, 7)),
        idGenerator: SequenceWnIdGenerator(seed: 'blocked-media'),
      );
      const guard = AssetSafetyGuard();
      final blocked = guard.buildAttachment(
        await FakePhotoCaptureAdapter(
          mode: FakePhotoMode.dangerous,
          now: () => DateTime.utc(2026, 6, 24, 7, 1),
        ).captureFromCamera(),
      );
      final review = guard.buildAttachment(
        RawCaptureAsset(
          id: 'voice-review',
          kind: CaptureAssetKind.voice,
          displayName: 'Voice review.wav',
          mimeType: 'audio/wav',
          sourceUri: 'fake://voice/review.wav',
          createdAt: DateTime.utc(2026, 6, 24, 7, 2),
          previewText: 'Voice transcript needs review.',
          rawMetadata: const <String, Object?>{
            'transcript_requires_review': true,
          },
        ),
      );

      for (final attachment in <CaptureAttachment>[blocked, review]) {
        await expectLater(
          () => orchestrator.processCapture(
            'Do not publish this attachment.',
            attachments: <CaptureAttachment>[attachment],
          ),
          throwsA(isA<CapturePipelineException>()),
        );
      }

      expect(await eventStore.readAll(), isEmpty);
      expect(await traceSink.readAll(), isEmpty);
    },
  );

  test('uses supplied capture id for record and todo source links', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 5)),
      idGenerator: SequenceWnIdGenerator(seed: 'capture-id'),
      model: runtime.FakeModel(
        responses: <String>['Persisted record id.', _todoActionJson],
      ),
      enabledPackIds: _corePackIds,
    );

    final result = await orchestrator.processCapture(
      'Review this capture id.',
      captureId: 'capture-row-1',
    );

    expect(result.record.id, 'capture-row-1');
    expect(result.record.sourceEventId, startsWith('evt-capture-id-'));
    expect(result.todo.sourceCaptureId, 'capture-row-1');
    expect(result.todo.sourceEventId, result.record.sourceEventId);
    expect(result.todo.sourceLabel, 'source: capture-row-1');
  });

  test('review candidates can be accepted or rejected after capture', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 3)),
      idGenerator: SequenceWnIdGenerator(seed: 'review'),
      model: _SequenceMetadataModel(
        responses: <String>[
          'The user pasted an API token.',
          _todoQuietJson,
          'The user discussed medication timing.',
          _todoQuietJson,
        ],
        metadata: const <Map<String, Object?>>[
          <String, Object?>{
            'memory_type': 'credential',
            'confidence': 'high',
            'sensitivity': 'high',
          },
          <String, Object?>{},
          <String, Object?>{
            'memory_type': 'health',
            'confidence': 'medium',
            'sensitivity': 'high',
          },
          <String, Object?>{},
        ],
      ),
      enabledPackIds: _corePackIds,
    );

    final first = await orchestrator.processCapture(
      'My API token should be reviewed before storage.',
    );
    final accepted = await orchestrator.acceptMemoryProposal(
      first.reviewCandidate!.id,
      editedBody: 'The user wants secrets reviewed before storage.',
    );

    expect(accepted.title, 'memory.accepted');
    expect(accepted.summary, 'The user wants secrets reviewed before storage.');
    expect(await orchestrator.listMemoryReviewQueue(), isEmpty);

    final second = await orchestrator.processCapture(
      'Doctor said medication timing should be checked.',
    );
    await orchestrator.rejectMemoryProposal(second.reviewCandidate!.id);

    expect(await orchestrator.listMemoryReviewQueue(), isEmpty);
  });
}

final class _SequenceMetadataModel implements runtime.ModelClient {
  _SequenceMetadataModel({
    required List<String> responses,
    List<Map<String, Object?>>? metadata,
  }) : _responses = responses,
       _metadata = metadata ?? const <Map<String, Object?>>[];

  final List<String> _responses;
  final List<Map<String, Object?>> _metadata;
  final requests = <runtime.ModelRequest>[];
  var _index = 0;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    requests.add(request);
    if (_index >= _responses.length) {
      throw StateError('No fake model response configured.');
    }
    final index = _index++;
    return runtime.ModelResponse(
      text: _responses[index],
      raw: index < _metadata.length
          ? _metadata[index]
          : const <String, Object?>{
              'memory_type': 'task_context',
              'confidence': 'high',
              'sensitivity': 'low',
              'durability': 'durable',
            },
    );
  }
}

final class _FailingModel implements runtime.ModelClient {
  const _FailingModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) {
    throw StateError('model unavailable');
  }
}

final class _StatusCodeFailingModel implements runtime.ModelClient {
  const _StatusCodeFailingModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) {
    throw const _StatusCodeError(429);
  }
}

final class _StatusCodeError implements Exception {
  const _StatusCodeError(this.statusCode);

  final int statusCode;
}

final class _UndeclaredOutputAgent implements runtime.AgentHandler {
  const _UndeclaredOutputAgent();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.cardCreated,
          subjectRef: event.subjectRef,
          payload: const <String, Object?>{'text': 'Undeclared card'},
        ),
      ],
    );
  }
}

void _expectEventOrigin(
  List<CapturePipelineEvent> events,
  String type, {
  required String packId,
  required String agentId,
}) {
  final event = events.singleWhere((event) => event.type == type);
  expect(event.packId, packId);
  expect(event.agentId, agentId);
}

Set<String> _sourceRefIds(List<Object?> sourceRefs) {
  return sourceRefs
      .whereType<Map>()
      .map((sourceRef) => sourceRef['id'])
      .whereType<String>()
      .toSet();
}

Map<String, Object?> _mutableManifest(String packId) {
  return (jsonDecode(officialPackManifestSource(packId)) as Map)
      .cast<String, Object?>();
}

runtime.AgentPackManifestSnapshot _parseManifest(
  Map<String, Object?> manifest,
) {
  return officialPackManifestBridge.parseJsonString(jsonEncode(manifest));
}
