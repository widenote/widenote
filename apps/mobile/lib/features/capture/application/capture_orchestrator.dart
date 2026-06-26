import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_cards/widenote_cards.dart' as cards;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_memory/memory.dart' as memory;

import '../../../shared/text_preview.dart';
import '../../plugins/application/official_pack_manifests.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';

final class CapturePipelineResult {
  const CapturePipelineResult({
    required this.record,
    required this.memoryItem,
    required this.todo,
    required this.traces,
    required this.eventTypes,
    required this.events,
    required this.cards,
    required this.insights,
    required this.acceptedMemoryCount,
    required this.reviewMemoryCount,
    this.reviewCandidate,
  });

  final CaptureRecord record;
  final CaptureMemoryItem memoryItem;
  final SourceTodo todo;
  final List<TraceEvent> traces;
  final List<String> eventTypes;
  final List<CapturePipelineEvent> events;
  final List<SourceCard> cards;
  final List<SourceInsight> insights;
  final int acceptedMemoryCount;
  final int reviewMemoryCount;
  final MemoryReviewCandidate? reviewCandidate;
}

final class CapturePipelineEvent {
  const CapturePipelineEvent({
    required this.type,
    required this.packId,
    required this.agentId,
    required this.payload,
  });

  final String type;
  final String? packId;
  final String? agentId;
  final Map<String, Object?> payload;
}

final class CapturePipelineException implements Exception {
  const CapturePipelineException(this.message);

  final String message;

  @override
  String toString() => 'CapturePipelineException: $message';
}

abstract interface class CaptureKnowledgeSink {
  Future<void> save(cards.MemoryFirstCardBundle bundle);
}

final class CaptureOrchestrator {
  CaptureOrchestrator._({
    required runtime.RuntimeKernel kernel,
    required runtime.EventStore eventStore,
    required runtime.TraceSink traceSink,
    required memory.MemoryService memoryService,
    required memory.MemoryRepository memoryRepository,
    CaptureKnowledgeSink? knowledgeSink,
  }) : _kernel = kernel,
       _eventStore = eventStore,
       _traceSink = traceSink,
       _memoryService = memoryService,
       _memoryRepository = memoryRepository,
       _knowledgeSink = knowledgeSink;

  factory CaptureOrchestrator.local({
    WnClock? clock,
    WnIdGenerator? idGenerator,
    runtime.ModelClient? model,
    runtime.EventStore? eventStore,
    runtime.TraceSink? traceSink,
    runtime.PermissionBroker? permissionBroker,
    runtime.RuntimeStore? runtimeStore,
    memory.MemoryRepository? memoryRepository,
    CaptureKnowledgeSink? knowledgeSink,
    bool autoGrantOfficialPermissions = true,
  }) {
    final localClock = clock ?? const SystemWnClock();
    final runtimeEventStore = eventStore ?? runtime.InMemoryEventStore();
    final runtimeTraceSink = traceSink ?? runtime.InMemoryTraceSink();
    final runtimeIdGenerator =
        idGenerator ?? MonotonicWnIdGenerator(clock: localClock);
    final permissions = permissionBroker ?? runtime.InMemoryPermissionBroker();
    if (autoGrantOfficialPermissions &&
        permissions is runtime.InMemoryPermissionBroker) {
      for (final manifest in officialPackManifestSnapshots) {
        permissions.grantAll(manifest.id, manifest.requiredPermissions);
      }
    }
    final kernel = runtime.RuntimeKernel(
      eventStore: runtimeEventStore,
      traceSink: runtimeTraceSink,
      permissionBroker: permissions,
      toolRegistry: runtime.InMemoryToolRegistry(),
      idGenerator: runtimeIdGenerator,
      clock: localClock,
      model: model ?? const _ModelRequiredCaptureModel(),
      deviceId: 'local-device',
      runtimeStore: runtimeStore,
    );
    registerOfficialNativePacks(
      kernel,
      nativeHandlersByPackId: _officialNativeHandlersByPackId,
    );

    final localMemoryRepository =
        memoryRepository ?? memory.InMemoryMemoryRepository();
    final memoryService = memory.MemoryService(
      repository: localMemoryRepository,
      clock: localClock.now,
      idFactory: () => runtimeIdGenerator.nextId('memory'),
    );

    return CaptureOrchestrator._(
      kernel: kernel,
      eventStore: kernel.eventStore,
      traceSink: kernel.traceSink,
      memoryService: memoryService,
      memoryRepository: localMemoryRepository,
      knowledgeSink: knowledgeSink,
    );
  }

  static const _defaultPackId = 'pack.default';
  static const _defaultAgentId = 'agent.capture_loop';
  static const _todoPackId = 'pack.todo';
  static const _todoAgentId = 'agent.todo_loop';
  static const _officialNativeHandlersByPackId =
      <String, Map<String, runtime.AgentHandler>>{
        _defaultPackId: <String, runtime.AgentHandler>{
          _defaultAgentId: _CaptureAgent(),
        },
        _todoPackId: <String, runtime.AgentHandler>{_todoAgentId: _TodoAgent()},
      };

  final runtime.RuntimeKernel _kernel;
  final runtime.EventStore _eventStore;
  final runtime.TraceSink _traceSink;
  final memory.MemoryService _memoryService;
  final memory.MemoryRepository _memoryRepository;
  final CaptureKnowledgeSink? _knowledgeSink;

  List<runtime.AgentPack> debugRegisteredPacks() {
    return _kernel.packRegistry.list();
  }

  Future<CapturePipelineResult> processCapture(
    String body, {
    List<CaptureAttachment> attachments = const <CaptureAttachment>[],
    String? captureId,
  }) async {
    final rawText = body.trim();
    if (attachments.any((attachment) => !attachment.isReady)) {
      throw const CapturePipelineException(
        'Review or remove pending attachments before saving.',
      );
    }
    final captureBody = rawText.isEmpty
        ? _attachmentOnlyText(attachments)
        : rawText;
    final priorEventCount = (await _eventStore.readAll()).length;
    final priorTraceCount = (await _traceSink.readAll()).length;
    final captureSubjectId = captureId ?? _kernel.idGenerator.nextId('capture');

    final capture = await _kernel.publish(
      runtime.WnEventDraft(
        type: runtime.WnEventTypes.captureCreated,
        actor: runtime.WnActor.user,
        subjectRef: runtime.SubjectRef(kind: 'capture', id: captureSubjectId),
        payload: _capturePayload(
          text: captureBody,
          rawText: rawText,
          attachments: attachments,
        ),
      ),
    );

    final allEvents = await _eventStore.readAll();
    final newEvents = allEvents.skip(priorEventCount).toList(growable: false);
    final memoryResult = await _writeFirstMemoryProposal(newEvents);
    final todo = _todoFromEvents(newEvents, capture);
    final traces = await _newTraceViews(priorTraceCount, capture);
    final activeMemories = await _memoryRepository.listItems(
      status: memory.MemoryItemStatus.active,
    );
    final reviewProposals = await _memoryRepository.listProposals(
      status: memory.MemoryProposalStatus.needsReview,
    );
    final knowledgeLayer = await buildKnowledgeLayer();

    return CapturePipelineResult(
      record: CaptureRecord(
        id: captureSubjectId,
        body: captureBody,
        createdAt: capture.createdAt,
        status: 'Processed locally',
        sourceEventId: capture.id,
      ),
      memoryItem: _memoryView(memoryResult, capture),
      todo: todo,
      traces: traces,
      eventTypes: newEvents.map((event) => event.type).toList(growable: false),
      events: newEvents
          .map(
            (event) => CapturePipelineEvent(
              type: event.type,
              packId: event.packId,
              agentId: event.agentId,
              payload: event.payload,
            ),
          )
          .toList(growable: false),
      cards: knowledgeLayer.cards,
      insights: knowledgeLayer.insights,
      acceptedMemoryCount: activeMemories.length,
      reviewMemoryCount: reviewProposals.length,
      reviewCandidate: memoryResult.needsReview
          ? _reviewCandidateView(memoryResult.proposal, capture.id)
          : null,
    );
  }

  Future<List<MemoryReviewCandidate>> listMemoryReviewQueue() async {
    final proposals = await _memoryService.listReviewQueue();
    return proposals.map(_reviewCandidateView).toList(growable: false);
  }

  Future<CaptureKnowledgeLayer> buildKnowledgeLayer() async {
    final events = await _eventStore.readAll();
    final activeMemories = await _memoryRepository.listItems(
      status: memory.MemoryItemStatus.active,
    );
    final bundle = const cards.MemoryFirstCardService().generate(
      cards.MemoryFirstCardInput(
        now: _kernel.clock.now(),
        captures: _captureSources(events),
        memories: _memorySources(activeMemories),
      ),
    );
    await _knowledgeSink?.save(bundle);
    return _knowledgeLayerView(bundle);
  }

  Future<CaptureMemoryItem> acceptMemoryProposal(
    String proposalId, {
    String? editedBody,
  }) async {
    final result = await _memoryService.acceptProposal(
      proposalId,
      editedBody: editedBody,
    );
    final item = result.item;
    if (item == null) {
      throw StateError('Accepted proposal did not create Memory: $proposalId');
    }
    return _acceptedMemoryView(item);
  }

  Future<void> rejectMemoryProposal(String proposalId) async {
    await _memoryService.rejectProposal(proposalId);
  }

  Future<CaptureMemoryItem> mergeMemoryProposal(
    String proposalId, {
    required String targetMemoryId,
    String? mergedBody,
  }) async {
    final result = await _memoryService.mergeProposal(
      proposalId,
      targetMemoryId: targetMemoryId,
      mergedBody: mergedBody,
    );
    final item = result.item;
    if (item == null) {
      throw StateError('Merged proposal did not update Memory: $proposalId');
    }
    return _acceptedMemoryView(item);
  }

  Future<memory.MemoryWriteResult> _writeFirstMemoryProposal(
    List<runtime.WnEvent> events,
  ) async {
    final event = _firstEventOfType(
      events,
      runtime.WnEventTypes.memoryProposed,
    );
    if (event == null) {
      throw const CapturePipelineException(
        'Capture pack did not emit a Memory proposal.',
      );
    }
    return _memoryService.submitProposal(_proposalFromEvent(event));
  }

  memory.MemoryProposal _proposalFromEvent(runtime.WnEvent event) {
    final payload = event.payload;
    final body = _string(payload['text'], fallback: '');
    final sourceEventId = _string(
      payload['source_event_id'],
      fallback: event.causationId ?? event.id,
    );
    final sourceCaptureId = event.subjectRef?.kind == 'capture'
        ? event.subjectRef!.id
        : _string(payload['source_capture_id'], fallback: '');
    final sourceRefs = <memory.MemorySourceRef>[
      if (sourceCaptureId.isNotEmpty)
        memory.MemorySourceRef(
          sourceType: 'capture',
          sourceId: sourceCaptureId,
          excerpt: _string(payload['source_excerpt'], fallback: body),
        ),
      memory.MemorySourceRef(
        sourceType: 'event',
        sourceId: sourceEventId,
        excerpt: _string(payload['source_excerpt'], fallback: body),
      ),
    ];

    return memory.MemoryProposal(
      id: 'proposal-${event.id}',
      key: _string(
        payload['key'],
        fallback: 'capture.${event.subjectRef?.id ?? event.id}.summary',
      ),
      body: body,
      evidence: sourceRefs,
      memoryType: _memoryType(payload['memory_type']),
      confidence: _confidence(payload['confidence']),
      sensitivity: _sensitivity(payload['sensitivity']),
    );
  }

  CaptureMemoryItem _memoryView(
    memory.MemoryWriteResult result,
    runtime.WnEvent capture,
  ) {
    final item = result.item;
    if (item != null) {
      return CaptureMemoryItem(
        id: item.id,
        title: 'memory.auto_saved',
        summary: item.body,
        sourceRecordId: capture.id,
        confidenceLabel: '${item.confidence.name} confidence',
        statusLabel: 'auto-accepted',
        needsReview: false,
      );
    }

    return CaptureMemoryItem(
      id: result.proposal.id,
      title: 'memory.needs_review',
      summary: result.proposal.body,
      sourceRecordId: capture.id,
      confidenceLabel: result.decision.reasons.join(', '),
      statusLabel: 'needs review',
      needsReview: true,
    );
  }

  CaptureMemoryItem _acceptedMemoryView(memory.MemoryItem item) {
    return CaptureMemoryItem(
      id: item.id,
      title: 'memory.accepted',
      summary: item.body,
      sourceRecordId: _sourceLabel(item.evidence),
      confidenceLabel: '${item.confidence.name} confidence',
      statusLabel: 'accepted',
      needsReview: false,
    );
  }

  SourceTodo _todoFromEvents(
    List<runtime.WnEvent> events,
    runtime.WnEvent capture,
  ) {
    final todoEvent = _firstEventOfType(
      events,
      runtime.WnEventTypes.todoSuggested,
    );
    if (todoEvent == null) {
      final sourceCaptureId = capture.subjectRef?.id ?? capture.id;
      return SourceTodo(
        id: 'todo.skipped.$sourceCaptureId',
        title: 'No todo suggested',
        sourceLabel: 'source: $sourceCaptureId',
        statusLabel: 'not suggested',
        sourceCaptureId: sourceCaptureId,
        sourceEventId: capture.id,
        isSuggested: false,
      );
    }
    return SourceTodo(
      id: todoEvent.id,
      title: _string(todoEvent.payload['text'], fallback: 'Review capture'),
      sourceLabel:
          'source: ${todoEvent.subjectRef?.id ?? todoEvent.causationId ?? capture.id}',
      statusLabel: 'suggested by agent',
      sourceCaptureId: todoEvent.subjectRef?.id,
      sourceEventId: _string(
        todoEvent.payload['source_event_id'],
        fallback: todoEvent.causationId ?? capture.id,
      ),
    );
  }

  Future<List<TraceEvent>> _newTraceViews(
    int priorTraceCount,
    runtime.WnEvent capture,
  ) async {
    final traces = await _traceSink.readAll();
    return traces
        .skip(priorTraceCount)
        .map(
          (trace) => TraceEvent(
            id: trace.id,
            label: trace.name,
            detail: trace.message,
            sourceRecordId: trace.eventId ?? capture.id,
            timeLabel: _timeLabel(trace.createdAt.toLocal()),
            packId: trace.packId,
            agentId: trace.agentId,
            runId: trace.runId,
          ),
        )
        .toList(growable: false);
  }
}

runtime.WnEvent? _firstEventOfType(List<runtime.WnEvent> events, String type) {
  for (final event in events) {
    if (event.type == type) {
      return event;
    }
  }
  return null;
}

MemoryReviewCandidate _reviewCandidateView(
  memory.MemoryProposal proposal, [
  String? fallbackSourceId,
]) {
  return MemoryReviewCandidate(
    id: proposal.id,
    summary: proposal.body,
    sourceLabel: _sourceLabel(proposal.evidence, fallback: fallbackSourceId),
    reasonLabel: proposal.policyReasons.isEmpty
        ? 'needs review'
        : proposal.policyReasons.join(', '),
    typeLabel:
        '${_memoryTypeLabel(proposal.memoryType)} · '
        '${proposal.confidence.name} confidence · '
        '${proposal.sensitivity.name} sensitivity',
  );
}

String _sourceLabel(List<memory.MemorySourceRef> evidence, {String? fallback}) {
  if (evidence.isEmpty) {
    return fallback ?? 'unknown source';
  }
  final source = evidence.first;
  return '${source.sourceType}: ${source.sourceId}';
}

Map<String, Object?> _capturePayload({
  required String text,
  required String rawText,
  required List<CaptureAttachment> attachments,
}) {
  final attachmentPayloads = attachments
      .map((attachment) => attachment.toEventPayload())
      .toList(growable: false);
  final sourceRefs = <Object?>[
    if (rawText.isNotEmpty)
      <String, Object?>{'kind': 'raw_text', 'id': 'composer'},
    for (final attachment in attachments)
      <String, Object?>{
        'kind': 'capture_attachment',
        'id': attachment.id,
        'attachment_kind': attachment.kind.wireName,
      },
  ];
  return <String, Object?>{
    'text': text,
    'raw_text': rawText,
    'source': attachments.isEmpty ? 'manual' : 'manual_with_attachments',
    if (attachmentPayloads.isNotEmpty) 'attachments': attachmentPayloads,
    if (sourceRefs.isNotEmpty) 'source_refs': sourceRefs,
    'attachment_count': attachments.length,
    'modalities': <String>[
      if (rawText.isNotEmpty) 'text',
      for (final attachment in attachments) attachment.kind.wireName,
    ],
  };
}

String _attachmentOnlyText(List<CaptureAttachment> attachments) {
  final summaries = attachments
      .where((attachment) => attachment.state == CaptureAttachmentState.ready)
      .map(_attachmentSummary)
      .where((summary) => summary.isNotEmpty)
      .toList(growable: false);
  if (summaries.isEmpty) {
    return '';
  }
  return summaries.join('\n');
}

String _attachmentSummary(CaptureAttachment attachment) {
  final preview = attachment.previewText.trim();
  if (preview.isNotEmpty && attachment.canRenderPreview) {
    return preview;
  }
  return '${attachment.kind.wireName}: ${attachment.displayName}';
}

String _captureTextFromPayload(Map<String, Object?> payload) {
  final text = _string(payload['text'], fallback: '');
  final attachmentText = _attachmentTextFromPayload(payload['attachments']);
  if (attachmentText.isEmpty) {
    return text;
  }
  if (_string(payload['raw_text'], fallback: '').isEmpty &&
      text == attachmentText) {
    return text;
  }
  if (text.isEmpty) {
    return attachmentText;
  }
  return '$text\n$attachmentText';
}

String _attachmentTextFromPayload(Object? value) {
  if (value is! List<Object?>) {
    return '';
  }
  final lines = <String>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final state = item['state'];
    final name = _string(item['display_name'], fallback: 'attachment');
    if (state == CaptureAttachmentState.blocked.wireName) {
      lines.add('Blocked attachment: $name');
      continue;
    }
    final preview = _string(item['preview_text'], fallback: '');
    lines.add(preview.isEmpty ? name : preview);
  }
  return lines.join('\n');
}

final class CaptureKnowledgeLayer {
  const CaptureKnowledgeLayer({required this.cards, required this.insights});

  final List<SourceCard> cards;
  final List<SourceInsight> insights;
}

List<cards.CaptureCardSource> _captureSources(List<runtime.WnEvent> events) {
  return events
      .where((event) => event.type == runtime.WnEventTypes.captureCreated)
      .map(
        (event) => cards.CaptureCardSource(
          id: event.subjectRef?.kind == 'capture'
              ? event.subjectRef!.id
              : event.id,
          text: _captureTextFromPayload(event.payload),
          createdAt: event.createdAt,
        ),
      )
      .toList(growable: false);
}

List<cards.MemoryCardSource> _memorySources(List<memory.MemoryItem> items) {
  return items
      .map(
        (item) => cards.MemoryCardSource(
          id: item.id,
          key: item.key,
          body: item.body,
          memoryType: _memoryTypeLabel(item.memoryType),
          createdAt: item.createdAt,
          sourceLinks: _cardSourceLinks(item.evidence),
        ),
      )
      .toList(growable: false);
}

List<cards.SourceLink> _cardSourceLinks(List<memory.MemorySourceRef> refs) {
  return refs
      .map(
        (ref) => cards.SourceLink(
          kind: ref.sourceType,
          id: ref.sourceId,
          excerpt: ref.excerpt,
          uri: ref.uri,
        ),
      )
      .toList(growable: false);
}

CaptureKnowledgeLayer _knowledgeLayerView(cards.MemoryFirstCardBundle bundle) {
  return CaptureKnowledgeLayer(
    cards: bundle.cards.map(_cardView).toList(growable: false),
    insights: bundle.insights.map(_insightView).toList(growable: false),
  );
}

SourceCard _cardView(cards.MemoryFirstCard card) {
  return SourceCard(
    id: card.id,
    title: card.title,
    summary: card.body,
    sourceLabel: _sourceLinkLabel(card.sourceLinks),
    kindLabel: _cardKindLabel(card.kind),
    statusLabel: '${card.sourceLinks.length} source link(s)',
  );
}

SourceInsight _insightView(cards.MemoryFirstInsight insight) {
  return SourceInsight(
    id: insight.id,
    title: insight.title,
    summary: insight.summary,
    sourceLabel: _sourceLinkLabel(insight.sourceLinks),
    kindLabel: _insightKindLabel(insight.kind),
    metricLabel: _metricLabel(insight),
  );
}

String _sourceLinkLabel(List<cards.SourceLink> links) {
  final first = links.first;
  final extra = links.length == 1 ? '' : ' +${links.length - 1}';
  return 'source: ${first.kind}:${first.id}$extra';
}

String _metricLabel(cards.MemoryFirstInsight insight) {
  if (insight.metricLabel == null || insight.metricValue == null) {
    return 'source-linked';
  }
  return '${insight.metricValue} ${insight.metricLabel}';
}

String _cardKindLabel(cards.MemoryFirstCardKind kind) {
  return switch (kind) {
    cards.MemoryFirstCardKind.captureSummary => 'capture card',
    cards.MemoryFirstCardKind.memorySummary => 'Memory card',
  };
}

String _insightKindLabel(cards.MemoryFirstInsightKind kind) {
  return switch (kind) {
    cards.MemoryFirstInsightKind.summary => 'summary insight',
    cards.MemoryFirstInsightKind.count => 'count insight',
    cards.MemoryFirstInsightKind.trend => 'trend insight',
  };
}

String _memoryTypeLabel(memory.MemoryType type) {
  return switch (type) {
    memory.MemoryType.taskContext => 'task_context',
    _ => type.name,
  };
}

final class _CaptureAgent implements runtime.AgentHandler {
  const _CaptureAgent();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    final text = _captureTextFromPayload(event.payload);
    final subject =
        event.subjectRef ?? runtime.SubjectRef(kind: 'capture', id: event.id);
    final summary = await _summarizeCapture(
      context.model,
      text: text,
      sourceEventId: event.id,
    );

    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.memoryProposed,
          subjectRef: subject,
          payload: <String, Object?>{
            'key': 'capture.${subject.id}.summary',
            'text': summary.text,
            'source_event_id': event.id,
            'source_excerpt': previewText(text),
            if (_modelMetadataString(summary, 'memory_type') != null)
              'memory_type': _modelMetadataString(summary, 'memory_type'),
            if (_modelMetadataValue(summary, 'confidence') != null)
              'confidence': _modelMetadataValue(summary, 'confidence'),
            if (_modelMetadataString(summary, 'sensitivity') != null)
              'sensitivity': _modelMetadataString(summary, 'sensitivity'),
          },
        ),
        context.emit(
          type: runtime.WnEventTypes.cardCreated,
          subjectRef: subject,
          payload: <String, Object?>{
            'title': 'Capture summary',
            'body': summary.text,
            'source_capture_id': subject.id,
            'source_event_id': event.id,
            'source_refs': <Object?>[
              <String, Object?>{
                'kind': 'capture',
                'id': subject.id,
                'excerpt': previewText(text),
              },
              <String, Object?>{
                'kind': 'event',
                'id': event.id,
                'excerpt': previewText(text),
              },
            ],
          },
        ),
        context.emit(
          type: runtime.WnEventTypes.insightCreated,
          subjectRef: subject,
          payload: <String, Object?>{
            'kind': 'capture_reflection',
            'text': 'This capture can be recalled through Memory.',
            'source_capture_id': subject.id,
            'source_event_id': event.id,
            'source_refs': <Object?>[
              <String, Object?>{
                'kind': 'capture',
                'id': subject.id,
                'excerpt': previewText(text),
              },
              <String, Object?>{
                'kind': 'event',
                'id': event.id,
                'excerpt': previewText(text),
              },
            ],
          },
        ),
      ],
    );
  }
}

Future<runtime.ModelResponse> _summarizeCapture(
  runtime.ModelClient model, {
  required String text,
  required String sourceEventId,
}) async {
  return model.complete(
    runtime.ModelRequest(
      prompt: 'Summarize capture for Memory: $text',
      context: <String, Object?>{'source_event_id': sourceEventId},
    ),
  );
}

String? _modelMetadataString(runtime.ModelResponse response, String key) {
  final value = response.raw[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

Object? _modelMetadataValue(runtime.ModelResponse response, String key) {
  final value = response.raw[key];
  if (value is num) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

final class _ModelRequiredCaptureModel implements runtime.ModelClient {
  const _ModelRequiredCaptureModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    throw const CapturePipelineException(
      'Configure a model provider before running capture agents.',
    );
  }
}

final class _TodoAgent implements runtime.AgentHandler {
  const _TodoAgent();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    final text = _captureTextFromPayload(event.payload);
    final subject =
        event.subjectRef ?? runtime.SubjectRef(kind: 'capture', id: event.id);

    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.todoSuggested,
          subjectRef: subject,
          payload: <String, Object?>{
            'text': 'Follow up: ${previewText(text)}',
            'source_event_id': event.id,
          },
        ),
      ],
    );
  }
}

String _string(Object? value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}

memory.MemoryConfidence _confidence(Object? value) {
  if (value is num) {
    if (value >= 0.8) {
      return memory.MemoryConfidence.high;
    }
    if (value >= 0.5) {
      return memory.MemoryConfidence.medium;
    }
    return memory.MemoryConfidence.low;
  }
  if (value == 'low') {
    return memory.MemoryConfidence.low;
  }
  if (value == 'medium') {
    return memory.MemoryConfidence.medium;
  }
  if (value == 'high') {
    return memory.MemoryConfidence.high;
  }
  return memory.MemoryConfidence.low;
}

memory.MemorySensitivity _sensitivity(Object? value) {
  if (value == 'medium') {
    return memory.MemorySensitivity.medium;
  }
  if (value == 'high') {
    return memory.MemorySensitivity.high;
  }
  if (value == 'low') {
    return memory.MemorySensitivity.low;
  }
  return memory.MemorySensitivity.medium;
}

memory.MemoryType _memoryType(Object? value) {
  if (value == 'preference') {
    return memory.MemoryType.preference;
  }
  if (value == 'project') {
    return memory.MemoryType.project;
  }
  if (value == 'person') {
    return memory.MemoryType.person;
  }
  if (value == 'health') {
    return memory.MemoryType.health;
  }
  if (value == 'finance') {
    return memory.MemoryType.finance;
  }
  if (value == 'location') {
    return memory.MemoryType.location;
  }
  if (value == 'credential') {
    return memory.MemoryType.credential;
  }
  if (value == 'insight') {
    return memory.MemoryType.insight;
  }
  return memory.MemoryType.taskContext;
}

String _timeLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute local';
}
