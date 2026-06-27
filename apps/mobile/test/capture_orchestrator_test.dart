import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_memory/memory.dart' as memory;
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';
import 'package:widenote_mobile/features/plugins/application/official_pack_manifests.dart';

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
    },
  );

  test('quick capture runs runtime and silently auto-accepts Memory', () async {
    final model = _SequenceMetadataModel(
      responses: <String>['Lin prefers source-linked WideNote todos.'],
    );
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 1)),
      idGenerator: SequenceWnIdGenerator(seed: 'app'),
      model: model,
    );

    final result = await orchestrator.processCapture(
      'Met Lin about WideNote source-linked todos.',
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
    ]);
    expect(
      result.insights.map((insight) => insight.sourceLabel),
      everyElement(startsWith('source:')),
    );
    expect(model.requests.single.prompt, contains('Met Lin'));
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
    expect(
      result.traces.map((trace) => trace.label),
      contains('runtime.run.completed'),
    );
    expect(
      result.traces.where((trace) => trace.label == 'runtime.run.completed'),
      hasLength(2),
    );
    expect(
      result.traces
          .where((trace) => trace.label == 'runtime.run.completed')
          .map((trace) => trace.packId),
      containsAll(<String>['pack.default', 'pack.todo']),
    );
  });

  test('fresh orchestrators do not reuse accepted Memory ids', () async {
    final repository = memory.InMemoryMemoryRepository();
    final first = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 1)),
      idGenerator: SequenceWnIdGenerator(seed: 'restart'),
      memoryRepository: repository,
      model: _SequenceMetadataModel(
        responses: <String>['First durable memory.'],
      ),
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
        responses: <String>['Second durable memory.'],
      ),
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

  test(
    'capture content keywords do not drive Memory metadata or Todo branching',
    () async {
      final orchestrator = CaptureOrchestrator.local(
        clock: TickingWnClock(DateTime.utc(2026, 6, 23, 2)),
        idGenerator: SequenceWnIdGenerator(seed: 'secret'),
        model: _SequenceMetadataModel(
          responses: <String>['The user pasted an API token.'],
        ),
      );

      final result = await orchestrator.processCapture(
        'My API token is sk-demo-secret and should not be auto stored.',
      );

      expect(result.acceptedMemoryCount, 1);
      expect(result.reviewMemoryCount, 0);
      expect(result.memoryItem.title, 'memory.auto_saved');
      expect(result.memoryItem.statusLabel, 'auto-accepted');
      expect(result.memoryItem.confidenceLabel, 'high confidence');
      final memoryEvent = result.events.singleWhere(
        (event) => event.type == runtime.WnEventTypes.memoryProposed,
      );
      expect(memoryEvent.payload['memory_type'], 'task_context');
      expect(memoryEvent.payload['confidence'], 'high');
      expect(memoryEvent.payload['sensitivity'], 'low');
      expect(result.cards.map((card) => card.kindLabel), [
        'capture card',
        'Memory card',
      ]);
      expect(result.insights, hasLength(3));
      expect(result.todo.isSuggested, isTrue);
      expect(result.todo.statusLabel, 'suggested by agent');
      expect(result.eventTypes, contains(runtime.WnEventTypes.todoSuggested));
      expect(result.reviewCandidate, isNull);
    },
  );

  test('multiple captures do not duplicate registered pack runs', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 6)),
      idGenerator: SequenceWnIdGenerator(seed: 'repeat'),
      model: _SequenceMetadataModel(
        responses: <String>['First summary.', 'Second summary.'],
      ),
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
        hasLength(1),
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
        runtime.WnEventTypes.todoSuggested,
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
    'media attachments are preserved on source-linked capture event',
    () async {
      final model = runtime.FakeModel(
        responses: <String>['Capture combines text, media, and voice.'],
      );
      final orchestrator = CaptureOrchestrator.local(
        clock: TickingWnClock(DateTime.utc(2026, 6, 24, 6)),
        idGenerator: SequenceWnIdGenerator(seed: 'media'),
        model: model,
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
      expect(model.requests.single.prompt, contains('Gallery photo'));
      expect(model.requests.single.prompt, contains('Voice recording'));
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
          displayName: 'Voice review.m4a',
          mimeType: 'audio/m4a',
          sourceUri: 'fake://voice/review.m4a',
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
      model: runtime.FakeModel(responses: <String>['Persisted record id.']),
    );

    final result = await orchestrator.processCapture(
      'Persist this capture id.',
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
      model: runtime.FakeModel(
        responses: <String>[
          'The user pasted an API token.',
          'The user discussed medication timing.',
        ],
      ),
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
  _SequenceMetadataModel({required List<String> responses})
    : _responses = responses;

  final List<String> _responses;
  final requests = <runtime.ModelRequest>[];
  var _index = 0;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    requests.add(request);
    if (_index >= _responses.length) {
      throw StateError('No fake model response configured.');
    }
    return runtime.ModelResponse(
      text: _responses[_index++],
      raw: const <String, Object?>{
        'memory_type': 'task_context',
        'confidence': 'high',
        'sensitivity': 'low',
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
