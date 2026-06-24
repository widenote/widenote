import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';

void main() {
  test('quick capture runs runtime and silently auto-accepts Memory', () async {
    final model = runtime.FakeModel(
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

  test(
    'sensitive captures route Memory to review instead of auto-accept',
    () async {
      final orchestrator = CaptureOrchestrator.local(
        clock: TickingWnClock(DateTime.utc(2026, 6, 23, 2)),
        idGenerator: SequenceWnIdGenerator(seed: 'secret'),
        model: runtime.FakeModel(
          responses: <String>['The user pasted an API token.'],
        ),
      );

      final result = await orchestrator.processCapture(
        'My API token is sk-demo-secret and should not be auto stored.',
      );

      expect(result.acceptedMemoryCount, 0);
      expect(result.reviewMemoryCount, 1);
      expect(result.memoryItem.title, 'memory.needs_review');
      expect(result.memoryItem.statusLabel, 'needs review');
      expect(result.memoryItem.confidenceLabel, contains('review_only_type'));
      expect(result.cards.map((card) => card.kindLabel), ['capture card']);
      expect(result.insights, hasLength(3));
      expect(result.reviewCandidate, isNotNull);
      expect(result.reviewCandidate!.reasonLabel, contains('review_only_type'));
    },
  );

  test(
    'model failure falls back to local summary and completes chain',
    () async {
      final orchestrator = CaptureOrchestrator.local(
        clock: TickingWnClock(DateTime.utc(2026, 6, 23, 4)),
        idGenerator: SequenceWnIdGenerator(seed: 'fallback'),
        model: const _FailingModel(),
      );

      final result = await orchestrator.processCapture(
        'Keep raw capture usable when the QA model is unavailable.',
      );

      expect(result.record.status, 'Processed locally');
      expect(result.memoryItem.summary, contains('Keep raw capture usable'));
      expect(result.memoryItem.needsReview, isTrue);
      final memoryEvent = result.events.singleWhere(
        (event) => event.type == runtime.WnEventTypes.memoryProposed,
      );
      expect(memoryEvent.payload['model_fallback'], isTrue);
      expect(memoryEvent.payload['model_fallback_error_type'], 'StateError');
      expect(memoryEvent.payload['confidence'], 'low');
      expect(result.acceptedMemoryCount, 0);
      expect(result.reviewMemoryCount, 1);
      expect(result.cards, hasLength(1));
      expect(result.insights, hasLength(3));
      expect(
        result.eventTypes,
        containsAll(<String>[
          runtime.WnEventTypes.memoryProposed,
          runtime.WnEventTypes.cardCreated,
          runtime.WnEventTypes.insightCreated,
          runtime.WnEventTypes.todoSuggested,
        ]),
      );
      expect(
        result.traces.map((trace) => trace.label),
        isNot(contains('runtime.run.failed')),
      );
    },
  );

  test('model fallback records provider status code when available', () async {
    final orchestrator = CaptureOrchestrator.local(
      clock: TickingWnClock(DateTime.utc(2026, 6, 23, 5)),
      idGenerator: SequenceWnIdGenerator(seed: 'rate'),
      model: const _StatusCodeFailingModel(),
    );

    final result = await orchestrator.processCapture(
      'Keep rate limit diagnostics without exposing provider secrets.',
    );

    final memoryEvent = result.events.singleWhere(
      (event) => event.type == runtime.WnEventTypes.memoryProposed,
    );
    expect(memoryEvent.payload['model_fallback'], isTrue);
    expect(
      memoryEvent.payload['model_fallback_error_type'],
      '_StatusCodeError',
    );
    expect(memoryEvent.payload['model_fallback_status_code'], 429);
    expect(result.memoryItem.needsReview, isTrue);
  });

  test(
    'media attachments are preserved on source-linked capture event',
    () async {
      final model = runtime.FakeModel(
        responses: <String>['Capture combines text, media, voice, and share.'],
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
        ).pickPhoto(),
      );
      final voiceReview = guard.buildAttachment(
        await FakeVoiceCaptureAdapter(
          now: () => DateTime.utc(2026, 6, 24, 6, 2),
        ).captureVoiceTranscript(),
      );
      final voice = voiceReview.copyWith(
        state: CaptureAttachmentState.ready,
        reviewReason: null,
      );
      final share = guard.buildAttachment(
        await FakeShareImportAdapter(
          now: () => DateTime.utc(2026, 6, 24, 6, 3),
        ).importSharedItem(),
      );

      final result = await orchestrator.processCapture(
        'Compare clean-room capture inputs.',
        attachments: <CaptureAttachment>[photo, voice, share],
      );

      final captureEvent = result.events.singleWhere(
        (event) => event.type == runtime.WnEventTypes.captureCreated,
      );
      final payload = captureEvent.payload;
      final attachments = payload['attachments']! as List<Object?>;
      final sourceRefs = payload['source_refs']! as List<Object?>;

      expect(payload['raw_text'], 'Compare clean-room capture inputs.');
      expect(payload['source'], 'manual_with_attachments');
      expect(payload['attachment_count'], 3);
      expect(sourceRefs, hasLength(4));
      expect(attachments, hasLength(3));
      expect((attachments.first! as Map)['kind'], 'photo');
      expect(
        ((attachments.first! as Map)['raw_metadata']! as Map)['source_uri'],
        'fake://camera/field-photo.jpg',
      );
      expect(model.requests.single.prompt, contains('Photo sample'));
      expect(model.requests.single.prompt, contains('Shared link'));
      expect(result.record.body, 'Compare clean-room capture inputs.');
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
