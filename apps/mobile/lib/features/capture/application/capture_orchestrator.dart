import 'dart:convert';

import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_cards/widenote_cards.dart' as cards;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_memory/memory.dart' as memory;

import '../../../shared/text_preview.dart';
import '../../plugins/application/official_pack_manifests.dart';
import 'capture_agent_prompts.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';

const captureAlreadyQueuedMessage = 'Capture is already queued for processing.';

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
    required this.memoryGenerated,
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
  final bool memoryGenerated;
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
  Future<void> saveArtifacts(List<CaptureDerivedArtifact> artifacts);
}

final class CaptureDerivedArtifact {
  const CaptureDerivedArtifact({
    required this.id,
    required this.sourceCaptureId,
    required this.sourceEventId,
    required this.artifactKind,
    required this.title,
    required this.body,
    required this.sourceRefs,
    required this.generatorId,
    required this.generatorVersion,
    required this.payload,
    required this.createdAt,
    this.sensitivity = 'low',
    this.confidence = 'medium',
  });

  final String id;
  final String sourceCaptureId;
  final String sourceEventId;
  final String artifactKind;
  final String title;
  final String body;
  final List<Object?> sourceRefs;
  final String sensitivity;
  final String confidence;
  final String generatorId;
  final String generatorVersion;
  final Map<String, Object?> payload;
  final DateTime createdAt;
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
    Iterable<String>? enabledPackIds,
    int maxConcurrentTasks = 4,
  }) {
    final localClock = clock ?? const SystemWnClock();
    final runtimeEventStore = eventStore ?? runtime.InMemoryEventStore();
    final runtimeTraceSink = traceSink ?? runtime.InMemoryTraceSink();
    final runtimeIdGenerator =
        idGenerator ?? MonotonicWnIdGenerator(clock: localClock);
    final permissions = permissionBroker ?? runtime.InMemoryPermissionBroker();
    final registeredManifests = _enabledOfficialManifests(enabledPackIds);
    final registeredPackIds = registeredManifests
        .map((manifest) => manifest.id)
        .toSet();
    if (autoGrantOfficialPermissions &&
        permissions is runtime.InMemoryPermissionBroker) {
      for (final manifest in registeredManifests) {
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
      maxConcurrentTasks: maxConcurrentTasks,
    );
    registerOfficialNativePacks(
      kernel,
      manifests: registeredManifests,
      nativeHandlersByPackId: <String, Map<String, runtime.AgentHandler>>{
        for (final entry in _officialNativeHandlersByPackId.entries)
          if (registeredPackIds.contains(entry.key)) entry.key: entry.value,
      },
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
  static const _pkmPackId = 'pack.pkm_library';
  static const _pkmAgentId = 'agent.pkm_profile_builder';
  static const _transcriptCorrectionPackId = 'pack.transcript_correction';
  static const _transcriptCorrectionAgentId = 'agent.transcript_correction';
  static const _officialNativeHandlersByPackId =
      <String, Map<String, runtime.AgentHandler>>{
        _defaultPackId: <String, runtime.AgentHandler>{
          _defaultAgentId: _CaptureAgent(),
        },
        _todoPackId: <String, runtime.AgentHandler>{_todoAgentId: _TodoAgent()},
        _pkmPackId: <String, runtime.AgentHandler>{
          _pkmAgentId: _PkmProfileAgent(),
        },
        _transcriptCorrectionPackId: <String, runtime.AgentHandler>{
          _transcriptCorrectionAgentId: _TranscriptCorrectionAgent(),
        },
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

  Future<int> restoreAndDrainRuntimeQueue() async {
    await _kernel.restoreRuntimeState();
    return _kernel.drainQueue();
  }

  Future<bool> hasPublishedCapture(String captureId) async {
    return _latestCaptureEventFor(await _eventStore.readAll(), captureId) !=
        null;
  }

  Future<CapturePipelineResult?> materializePublishedCapture(
    String captureId,
  ) async {
    await _kernel.restoreRuntimeState();
    final allEvents = await _eventStore.readAll();
    final capture = _latestCaptureEventFor(allEvents, captureId);
    if (capture == null) {
      return null;
    }
    final relatedEvents = _captureRelatedEvents(
      allEvents,
      capture: capture,
      captureSubjectId: captureId,
    );
    if (_coreCaptureTaskIsActive(relatedEvents)) {
      return null;
    }
    final traces = await _relatedTraceViews(capture, relatedEvents);
    return _buildResultForCapture(
      captureSubjectId: captureId,
      capture: capture,
      relatedEvents: relatedEvents,
      traces: traces,
    );
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
    final captureSubjectId = captureId ?? _kernel.idGenerator.nextId('capture');
    if (await hasPublishedCapture(captureSubjectId)) {
      final materialized = await materializePublishedCapture(captureSubjectId);
      if (materialized != null) {
        return materialized;
      }
      throw const CapturePipelineException(captureAlreadyQueuedMessage);
    }

    late final runtime.WnEvent capture;
    try {
      capture = await _kernel.publish(
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
    } on StateError catch (error) {
      if (!_isDuplicateCaptureCreatedError(error)) {
        rethrow;
      }
      final materialized = await materializePublishedCapture(captureSubjectId);
      if (materialized != null) {
        return materialized;
      }
      throw const CapturePipelineException(captureAlreadyQueuedMessage);
    }

    final allEvents = await _eventStore.readAll();
    final newEvents = _captureRelatedEvents(
      allEvents,
      capture: capture,
      captureSubjectId: captureSubjectId,
    );
    final trustedOutputEventIds = _trustedBuiltInOutputEventIds(newEvents);
    await _knowledgeSink?.saveArtifacts(
      _derivedArtifactsFromEvents(newEvents, trustedOutputEventIds),
    );
    final traces = await _relatedTraceViews(capture, newEvents);
    return _buildResultForCapture(
      captureSubjectId: captureSubjectId,
      capture: capture,
      relatedEvents: newEvents,
      traces: traces,
    );
  }

  Future<CapturePipelineResult?> retryCaptureTasks(String captureId) async {
    await _kernel.restoreRuntimeState();
    final allEvents = await _eventStore.readAll();
    final capture = _latestCaptureEventFor(allEvents, captureId);
    if (capture == null) {
      return null;
    }
    final relatedEvents = _captureRelatedEvents(
      allEvents,
      capture: capture,
      captureSubjectId: captureId,
    );
    final retryTask = _retryableCoreTask(relatedEvents);
    if (retryTask == null) {
      return null;
    }
    final retried = await _kernel.retryTask(retryTask.id);
    if (!retried) {
      return null;
    }

    final refreshedEvents = _captureRelatedEvents(
      await _eventStore.readAll(),
      capture: capture,
      captureSubjectId: captureId,
    );
    final traces = await _relatedTraceViews(capture, refreshedEvents);
    return _buildResultForCapture(
      captureSubjectId: captureId,
      capture: capture,
      relatedEvents: refreshedEvents,
      traces: traces,
    );
  }

  Future<CapturePipelineResult> _buildResultForCapture({
    required String captureSubjectId,
    required runtime.WnEvent capture,
    required List<runtime.WnEvent> relatedEvents,
    required List<TraceEvent> traces,
  }) async {
    final trustedOutputEventIds = _trustedBuiltInOutputEventIds(relatedEvents);
    await _knowledgeSink?.saveArtifacts(
      _derivedArtifactsFromEvents(relatedEvents, trustedOutputEventIds),
    );
    final memoryResult = await _writeFirstMemoryProposal(
      relatedEvents,
      trustedOutputEventIds,
    );
    if (memoryResult == null && _defaultCaptureRunFailed(traces)) {
      throw const CapturePipelineException('Capture Memory generation failed.');
    }
    final todo = _todoFromEvents(relatedEvents, capture, trustedOutputEventIds);
    final activeMemories = await _memoryRepository.listItems(
      status: memory.MemoryItemStatus.active,
    );
    final reviewProposals = await _memoryRepository.listProposals(
      status: memory.MemoryProposalStatus.needsReview,
    );
    final knowledgeLayer = await buildKnowledgeLayer();
    final captureBody = _string(capture.payload['text'], fallback: '');

    return CapturePipelineResult(
      record: CaptureRecord(
        id: captureSubjectId,
        body: captureBody,
        createdAt: capture.createdAt,
        status: 'Processed locally',
        sourceEventId: capture.id,
      ),
      memoryItem: memoryResult == null
          ? _memorySkippedView(capture)
          : _memoryView(memoryResult, capture),
      todo: todo,
      traces: traces,
      eventTypes: relatedEvents
          .map((event) => event.type)
          .toList(growable: false),
      events: relatedEvents
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
      memoryGenerated: memoryResult != null,
      reviewCandidate: memoryResult != null && memoryResult.needsReview
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

  Future<memory.MemoryWriteResult?> _writeFirstMemoryProposal(
    List<runtime.WnEvent> events,
    Set<String> trustedOutputEventIds,
  ) async {
    final event = _firstTrustedBuiltInEventOfType(
      events,
      runtime.WnEventTypes.memoryProposed,
      trustedOutputEventIds,
    );
    if (event == null) {
      return null;
    }
    final proposal = _proposalFromEvent(event);
    final existing = await _existingMemoryResult(proposal);
    if (existing != null) {
      return existing;
    }
    return _memoryService.submitProposal(proposal);
  }

  Future<memory.MemoryWriteResult?> _existingMemoryResult(
    memory.MemoryProposal proposal,
  ) async {
    final activeItems = await _memoryRepository.listItems(
      status: memory.MemoryItemStatus.active,
    );
    for (final item in activeItems) {
      if (item.key == proposal.key &&
          item.body.trim() == proposal.body.trim() &&
          _sharesMemorySource(item.evidence, proposal.evidence)) {
        return memory.MemoryWriteResult(
          proposal: proposal.copyWith(
            status: memory.MemoryProposalStatus.autoAccepted,
          ),
          decision: const memory.MemoryPolicyDecision(
            action: memory.MemoryPolicyAction.autoAccept,
            reasons: <String>['existing_source_memory'],
          ),
          conflicts: const <memory.MemoryItem>[],
          item: item,
        );
      }
    }

    final proposals = await _memoryRepository.listProposals();
    for (final existing in proposals) {
      if (existing.key == proposal.key &&
          existing.body.trim() == proposal.body.trim() &&
          _sharesMemorySource(existing.evidence, proposal.evidence)) {
        return memory.MemoryWriteResult(
          proposal: existing,
          decision: memory.MemoryPolicyDecision(
            action: existing.status == memory.MemoryProposalStatus.needsReview
                ? memory.MemoryPolicyAction.review
                : memory.MemoryPolicyAction.autoAccept,
            reasons: const <String>['existing_source_proposal'],
          ),
          conflicts: const <memory.MemoryItem>[],
        );
      }
    }
    return null;
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
      durability: _durability(payload['durability']),
      policyReasons: _stringList(payload['policy_reasons']),
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

  CaptureMemoryItem _memorySkippedView(runtime.WnEvent capture) {
    return CaptureMemoryItem(
      id: 'memory.skipped.${capture.subjectRef?.id ?? capture.id}',
      title: 'memory.not_generated',
      summary: 'No Memory generated for this capture.',
      sourceRecordId: capture.id,
      confidenceLabel: 'not generated',
      statusLabel: 'not generated',
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
    Set<String> trustedOutputEventIds,
  ) {
    final todoEvent = _firstTrustedBuiltInEventOfType(
      events,
      runtime.WnEventTypes.todoSuggested,
      trustedOutputEventIds,
    );
    if (todoEvent == null) {
      final sourceCaptureId = capture.subjectRef?.id ?? capture.id;
      return SourceTodo(
        id: 'todo.skipped.$sourceCaptureId',
        title: 'No todo suggested',
        sourceLabel: 'source: $sourceCaptureId',
        statusLabel: 'not suggested',
        suggestionKind: 'quiet',
        confidenceLabel: 'low',
        reasonLabel: 'model_no_suggestion',
        sourceCaptureId: sourceCaptureId,
        sourceEventId: capture.id,
        sourceRefs: _todoSourceRefs(
          const <Object?>[],
          sourceCaptureId: sourceCaptureId,
          sourceEventId: capture.id,
          excerpt: _string(capture.payload['text'], fallback: ''),
        ),
        isSuggested: false,
      );
    }
    final suggestionKind = _string(
      todoEvent.payload['suggestion_kind'],
      fallback: 'quiet',
    );
    final sourceCaptureId = todoEvent.subjectRef?.kind == 'capture'
        ? todoEvent.subjectRef!.id
        : _nullableString(todoEvent.payload['source_capture_id']);
    final sourceEventId = _string(
      todoEvent.payload['source_event_id'],
      fallback: todoEvent.causationId ?? capture.id,
    );
    return SourceTodo(
      id: todoEvent.id,
      title: _string(todoEvent.payload['text'], fallback: 'Review capture'),
      sourceLabel:
          'source: ${todoEvent.subjectRef?.id ?? todoEvent.causationId ?? capture.id}',
      statusLabel: _string(
        todoEvent.payload['status_label'],
        fallback: suggestionKind == 'schedule'
            ? 'schedule candidate'
            : 'suggested action',
      ),
      suggestionKind: suggestionKind,
      confidenceLabel: _string(
        todoEvent.payload['suggestion_confidence'],
        fallback: 'high',
      ),
      reasonLabel: _nullableString(todoEvent.payload['suggestion_reason']),
      scheduledAtLabel: _nullableString(
        todoEvent.payload['scheduled_at_label'],
      ),
      dueAt: _nullableString(todoEvent.payload['due_at']),
      dueLabel: _nullableString(todoEvent.payload['due_label']),
      scheduledStart: _nullableString(todoEvent.payload['scheduled_start']),
      scheduledEnd: _nullableString(todoEvent.payload['scheduled_end']),
      priority: _nullableString(todoEvent.payload['priority']),
      subtasks: todoEvent.payload['subtasks'] is List
          ? List<Object?>.from(todoEvent.payload['subtasks']! as List)
          : const <Object?>[],
      sourceCaptureId: sourceCaptureId,
      sourceEventId: sourceEventId,
      sourceRefs: _todoSourceRefs(
        todoEvent.payload['source_refs'],
        sourceCaptureId: sourceCaptureId,
        sourceEventId: sourceEventId,
        excerpt: _string(
          todoEvent.payload['source_excerpt'],
          fallback: _string(todoEvent.payload['text'], fallback: ''),
        ),
      ),
    );
  }

  Future<List<TraceEvent>> _relatedTraceViews(
    runtime.WnEvent capture,
    List<runtime.WnEvent> relatedEvents,
  ) async {
    final eventIds = relatedEvents.map((event) => event.id).toSet();
    final taskIds = _kernel.tasks
        .where((task) => eventIds.contains(task.triggerEventId))
        .map((task) => task.id)
        .toSet();
    final runIds = _kernel.runs
        .where((run) => taskIds.contains(run.taskId))
        .map((run) => run.id)
        .toSet();
    final traces = await _traceSink.readAll();
    return traces
        .where(
          (trace) =>
              (trace.eventId != null && eventIds.contains(trace.eventId)) ||
              (trace.taskId != null && taskIds.contains(trace.taskId)) ||
              (trace.runId != null && runIds.contains(trace.runId)),
        )
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

  runtime.RuntimeTask? _retryableCoreTask(List<runtime.WnEvent> events) {
    final eventIds = events.map((event) => event.id).toSet();
    for (final task in _kernel.tasks.reversed) {
      if (!eventIds.contains(task.triggerEventId) ||
          task.packId != _defaultPackId ||
          task.agentId != _defaultAgentId ||
          task.status == runtime.RuntimeTaskStatus.running ||
          task.status == runtime.RuntimeTaskStatus.succeeded) {
        continue;
      }
      return task;
    }
    return null;
  }

  bool _coreCaptureTaskIsActive(List<runtime.WnEvent> events) {
    final eventIds = events.map((event) => event.id).toSet();
    return _kernel.tasks.any(
      (task) =>
          eventIds.contains(task.triggerEventId) &&
          task.packId == _defaultPackId &&
          task.agentId == _defaultAgentId &&
          (task.status == runtime.RuntimeTaskStatus.queued ||
              task.status == runtime.RuntimeTaskStatus.waiting ||
              task.status == runtime.RuntimeTaskStatus.running),
    );
  }

  Set<String> _trustedBuiltInOutputEventIds(List<runtime.WnEvent> events) {
    final relatedIds = events.map((event) => event.id).toSet();
    final trustedIds = <String>{};
    for (final run in _kernel.runs) {
      if (run.status != runtime.RuntimeRunStatus.succeeded ||
          !_isTrustedBuiltInRun(run.packId, run.agentId)) {
        continue;
      }
      final task = _taskById(run.taskId);
      if (task == null ||
          task.status != runtime.RuntimeTaskStatus.succeeded ||
          !relatedIds.contains(task.triggerEventId)) {
        continue;
      }
      trustedIds.addAll(run.outputEventIds.where(relatedIds.contains));
    }
    return trustedIds;
  }

  runtime.RuntimeTask? _taskById(String taskId) {
    for (final task in _kernel.tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }
}

bool _isDuplicateCaptureCreatedError(StateError error) {
  return error.message.contains('Capture event already exists for subject:');
}

List<runtime.AgentPackManifestSnapshot> _enabledOfficialManifests(
  Iterable<String>? enabledPackIds,
) {
  if (enabledPackIds == null) {
    return officialPackManifestSnapshots;
  }
  final enabled = enabledPackIds.toSet();
  final unknown = enabled.difference(
    officialPackManifestSnapshotsById.keys.toSet(),
  );
  if (unknown.isNotEmpty) {
    throw ArgumentError(
      'Unknown official pack id(s): ${unknown.toList(growable: false).join(', ')}.',
    );
  }
  return officialPackManifestSnapshots
      .where((manifest) => enabled.contains(manifest.id))
      .toList(growable: false);
}

runtime.WnEvent? _firstTrustedBuiltInEventOfType(
  List<runtime.WnEvent> events,
  String type,
  Set<String> trustedOutputEventIds,
) {
  for (final event in events) {
    if (event.type == type &&
        trustedOutputEventIds.contains(event.id) &&
        _isTrustedBuiltInOutputEvent(event)) {
      return event;
    }
  }
  return null;
}

bool _isTrustedBuiltInRun(String packId, String agentId) {
  return (packId == CaptureOrchestrator._defaultPackId &&
          agentId == CaptureOrchestrator._defaultAgentId) ||
      (packId == CaptureOrchestrator._todoPackId &&
          agentId == CaptureOrchestrator._todoAgentId) ||
      (packId == CaptureOrchestrator._pkmPackId &&
          agentId == CaptureOrchestrator._pkmAgentId) ||
      (packId == CaptureOrchestrator._transcriptCorrectionPackId &&
          agentId == CaptureOrchestrator._transcriptCorrectionAgentId);
}

bool _isTrustedBuiltInOutputEvent(runtime.WnEvent event) {
  if (event.actor != runtime.WnActor.agent) {
    return false;
  }
  if (event.type == runtime.WnEventTypes.memoryProposed ||
      event.type == runtime.WnEventTypes.cardCreated ||
      event.type == runtime.WnEventTypes.insightCreated) {
    return event.packId == CaptureOrchestrator._defaultPackId &&
        event.agentId == CaptureOrchestrator._defaultAgentId;
  }
  if (event.type == runtime.WnEventTypes.todoSuggested) {
    return event.packId == CaptureOrchestrator._todoPackId &&
        event.agentId == CaptureOrchestrator._todoAgentId;
  }
  if (event.type == runtime.WnEventTypes.artifactCreated) {
    return event.packId == CaptureOrchestrator._pkmPackId &&
        event.agentId == CaptureOrchestrator._pkmAgentId;
  }
  if (event.type == runtime.WnEventTypes.transcriptCorrected) {
    return event.packId == CaptureOrchestrator._transcriptCorrectionPackId &&
        event.agentId == CaptureOrchestrator._transcriptCorrectionAgentId;
  }
  return false;
}

runtime.WnEvent? _latestCaptureEventFor(
  List<runtime.WnEvent> events,
  String captureId,
) {
  for (final event in events.reversed) {
    if (event.type == runtime.WnEventTypes.captureCreated &&
        event.subjectRef?.kind == 'capture' &&
        event.subjectRef?.id == captureId) {
      return event;
    }
  }
  return null;
}

List<runtime.WnEvent> _captureRelatedEvents(
  List<runtime.WnEvent> events, {
  required runtime.WnEvent capture,
  required String captureSubjectId,
}) {
  final relatedIds = <String>{capture.id};
  var changed = true;
  while (changed) {
    changed = false;
    for (final event in events) {
      if (relatedIds.contains(event.id)) {
        continue;
      }
      if (_isCaptureRelatedEvent(event, captureSubjectId, relatedIds)) {
        relatedIds.add(event.id);
        changed = true;
      }
    }
  }
  return events
      .where((event) => relatedIds.contains(event.id))
      .toList(growable: false);
}

bool _isCaptureRelatedEvent(
  runtime.WnEvent event,
  String captureSubjectId,
  Set<String> relatedEventIds,
) {
  final subject = event.subjectRef;
  if (subject?.kind == 'capture' && subject?.id == captureSubjectId) {
    return true;
  }
  final causationId = event.causationId;
  if (causationId != null && relatedEventIds.contains(causationId)) {
    return true;
  }
  if (_string(event.payload['source_capture_id'], fallback: '') ==
      captureSubjectId) {
    return true;
  }
  final sourceEventId = _string(event.payload['source_event_id'], fallback: '');
  if (sourceEventId.isNotEmpty && relatedEventIds.contains(sourceEventId)) {
    return true;
  }
  final refs = event.payload['source_refs'];
  if (refs is List) {
    for (final ref in refs) {
      if (ref is! Map) {
        continue;
      }
      final kind = ref['kind'] ?? ref['source_type'];
      final id = ref['id'] ?? ref['source_id'];
      if (kind == 'capture' && id == captureSubjectId) {
        return true;
      }
      if (kind == 'event' && id is String && relatedEventIds.contains(id)) {
        return true;
      }
    }
  }
  return false;
}

bool _defaultCaptureRunFailed(List<TraceEvent> traces) {
  return traces.any(
    (trace) =>
        trace.label == 'runtime.run.failed' &&
        trace.packId == CaptureOrchestrator._defaultPackId &&
        trace.agentId == CaptureOrchestrator._defaultAgentId,
  );
}

bool _sharesMemorySource(
  List<memory.MemorySourceRef> left,
  List<memory.MemorySourceRef> right,
) {
  final rightKeys = right
      .map((ref) => '${ref.sourceType}:${ref.sourceId}')
      .toSet();
  return left.any(
    (ref) => rightKeys.contains('${ref.sourceType}:${ref.sourceId}'),
  );
}

List<CaptureDerivedArtifact> _derivedArtifactsFromEvents(
  List<runtime.WnEvent> events,
  Set<String> trustedOutputEventIds,
) {
  return events
      .where(
        (event) =>
            event.type == runtime.WnEventTypes.artifactCreated &&
            trustedOutputEventIds.contains(event.id) &&
            _isTrustedBuiltInOutputEvent(event),
      )
      .map(_derivedArtifactFromEvent)
      .whereType<CaptureDerivedArtifact>()
      .toList(growable: false);
}

CaptureDerivedArtifact? _derivedArtifactFromEvent(runtime.WnEvent event) {
  final subject = event.subjectRef;
  final payload = event.payload;
  final sourceCaptureId =
      _string(payload['source_capture_id'], fallback: '') == ''
      ? subject?.kind == 'capture'
            ? subject!.id
            : ''
      : _string(payload['source_capture_id'], fallback: '');
  final sourceEventId = _string(
    payload['source_event_id'],
    fallback: event.causationId ?? event.id,
  );
  if (sourceCaptureId.isEmpty || sourceEventId.isEmpty) {
    return null;
  }
  final sourceRefs = _artifactSourceRefs(
    payload['source_refs'],
    sourceCaptureId: sourceCaptureId,
    sourceEventId: sourceEventId,
    excerpt: _string(payload['source_excerpt'], fallback: ''),
  );
  return CaptureDerivedArtifact(
    id: _string(payload['artifact_id'], fallback: 'artifact.${event.id}'),
    sourceCaptureId: sourceCaptureId,
    sourceEventId: sourceEventId,
    artifactKind: _string(
      payload['artifact_kind'],
      fallback: 'generated_artifact',
    ),
    title: _string(payload['title'], fallback: 'Generated artifact'),
    body: _string(payload['body'], fallback: 'Generated artifact body.'),
    sourceRefs: sourceRefs,
    sensitivity: _string(payload['sensitivity'], fallback: 'low'),
    confidence: _string(payload['confidence'], fallback: 'medium'),
    generatorId: _string(
      payload['generator_id'],
      fallback:
          '${event.packId ?? 'pack.unknown'}/${event.agentId ?? 'agent.unknown'}',
    ),
    generatorVersion: _string(payload['generator_version'], fallback: '0.1.0'),
    payload: <String, Object?>{
      for (final entry in payload.entries)
        if (!const <String>{
          'artifact_id',
          'artifact_kind',
          'title',
          'body',
          'source_capture_id',
          'source_event_id',
          'source_refs',
          'source_excerpt',
          'sensitivity',
          'confidence',
          'generator_id',
          'generator_version',
        }.contains(entry.key))
          entry.key: entry.value,
    },
    createdAt: event.createdAt,
  );
}

List<Object?> _artifactSourceRefs(
  Object? value, {
  required String sourceCaptureId,
  required String sourceEventId,
  required String excerpt,
}) {
  final refs = value is List<Object?> ? value : const <Object?>[];
  final ids = refs
      .whereType<Map>()
      .map((ref) => ref['id'])
      .whereType<String>()
      .toSet();
  return <Object?>[
    ...refs,
    if (!ids.contains(sourceCaptureId))
      <String, Object?>{
        'kind': 'capture',
        'id': sourceCaptureId,
        if (excerpt.isNotEmpty) 'excerpt': excerpt,
      },
    if (!ids.contains(sourceEventId))
      <String, Object?>{
        'kind': 'event',
        'id': sourceEventId,
        if (excerpt.isNotEmpty) 'excerpt': excerpt,
      },
  ];
}

List<Object?> _todoSourceRefs(
  Object? value, {
  required String? sourceCaptureId,
  required String sourceEventId,
  required String excerpt,
}) {
  final refs = <Object?>[];
  if (value is List) {
    for (final ref in value) {
      final normalized = _sourceRefMap(ref);
      if (normalized != null) {
        refs.add(normalized);
      }
    }
  }
  _addSourceRefIfMissing(
    refs,
    kind: 'capture',
    id: sourceCaptureId,
    excerpt: excerpt,
  );
  _addSourceRefIfMissing(
    refs,
    kind: 'event',
    id: sourceEventId,
    excerpt: excerpt,
  );
  return List<Object?>.unmodifiable(refs);
}

Map<String, Object?>? _sourceRefMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final kind =
      _nullableString(value['kind']) ?? _nullableString(value['source_type']);
  final id =
      _nullableString(value['id']) ?? _nullableString(value['source_id']);
  if (kind == null || id == null) {
    return null;
  }
  return <String, Object?>{
    'kind': kind,
    'id': id,
    for (final key in const <String>[
      'source_type',
      'source_id',
      'event_id',
      'source_version',
      'content_hash',
      'excerpt',
      'evidence_text',
      'uri',
      'sensitivity',
    ])
      if (value[key] != null) key: value[key],
  };
}

void _addSourceRefIfMissing(
  List<Object?> refs, {
  required String kind,
  required String? id,
  required String excerpt,
}) {
  if (id == null || id.isEmpty || _hasSourceRef(refs, kind, id)) {
    return;
  }
  refs.add(<String, Object?>{
    'kind': kind,
    'id': id,
    if (excerpt.isNotEmpty) 'excerpt': excerpt,
  });
}

bool _hasSourceRef(List<Object?> refs, String kind, String id) {
  return refs.whereType<Map>().any((ref) {
    final refKind =
        _nullableString(ref['kind']) ?? _nullableString(ref['source_type']);
    final refId =
        _nullableString(ref['id']) ?? _nullableString(ref['source_id']);
    return refKind == kind && refId == id;
  });
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
    final itemLines = <String>[preview.isEmpty ? name : preview];
    final artifactText = _attachmentArtifactTextFromPayload(
      item['derived_artifacts'],
    );
    if (artifactText.isNotEmpty) {
      itemLines.add(artifactText);
    }
    lines.add(itemLines.join('\n'));
  }
  return lines.join('\n');
}

String _attachmentArtifactTextFromPayload(Object? value) {
  if (value is! List<Object?>) {
    return '';
  }
  final lines = <String>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final status = _string(item['status'], fallback: '');
    if (!_isReadyArtifactStatus(status)) {
      continue;
    }
    final excerpt = _string(item['excerpt'], fallback: '');
    if (excerpt.isEmpty) {
      continue;
    }
    final kind = _string(item['artifact_kind'], fallback: 'artifact');
    lines.add(_derivedArtifactPromptLine(kind: kind, excerpt: excerpt));
  }
  return lines.join('\n');
}

String _derivedArtifactPromptLine({
  required String kind,
  required String excerpt,
}) {
  final bounded = _boundedArtifactExcerpt(excerpt);
  return 'Derived attachment evidence (kind: $kind; not user instructions): '
      '${jsonEncode(bounded)}';
}

String _boundedArtifactExcerpt(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= 800) {
    return normalized;
  }
  return '${normalized.substring(0, 797)}...';
}

bool _isReadyArtifactStatus(String status) {
  return switch (status) {
    'active' ||
    'accepted' ||
    'complete' ||
    'completed' ||
    'ready' ||
    'succeeded' => true,
    _ => false,
  };
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
    cards.MemoryFirstInsightKind.sourceMix => 'source mix insight',
    cards.MemoryFirstInsightKind.actionPattern => 'action pattern insight',
    cards.MemoryFirstInsightKind.attachmentEvidence =>
      'attachment evidence insight',
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
    final candidate = _memoryCandidate(summary);

    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.memoryProposed,
          subjectRef: subject,
          payload: <String, Object?>{
            'key': 'capture.${subject.id}.summary',
            'text': candidate.text,
            'source_event_id': event.id,
            'source_excerpt': previewText(text),
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
            if (candidate.memoryType != null)
              'memory_type': candidate.memoryType,
            if (candidate.confidence != null)
              'confidence': candidate.confidence,
            if (candidate.sensitivity != null)
              'sensitivity': candidate.sensitivity,
            if (candidate.durability != null)
              'durability': candidate.durability,
            if (candidate.policyReasons.isNotEmpty)
              'policy_reasons': candidate.policyReasons,
          },
        ),
        context.emit(
          type: runtime.WnEventTypes.cardCreated,
          subjectRef: subject,
          payload: <String, Object?>{
            'title': 'Capture summary',
            'body': candidate.text,
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
      prompt: buildCaptureMemoryPrompt(
        text: text,
        sourceEventId: sourceEventId,
      ),
      context: <String, Object?>{
        'prompt_ref': captureMemoryPromptRef,
        'source_event_id': sourceEventId,
      },
    ),
  );
}

final class _MemoryCandidateEnvelope {
  const _MemoryCandidateEnvelope({
    required this.text,
    this.memoryType,
    this.confidence,
    this.sensitivity,
    this.durability,
    this.policyReasons = const <String>[],
  });

  final String text;
  final String? memoryType;
  final Object? confidence;
  final String? sensitivity;
  final String? durability;
  final List<String> policyReasons;
}

_MemoryCandidateEnvelope _memoryCandidate(runtime.ModelResponse response) {
  final parsed = _jsonObject(response.text);
  final raw = response.raw;
  final text =
      _metadataString(parsed, 'text') ??
      _metadataString(raw, 'text') ??
      _legacyCandidateText(response.text);
  final memoryType =
      _metadataString(parsed, 'memory_type') ??
      _metadataString(raw, 'memory_type');
  final confidence =
      _metadataValue(parsed, 'confidence') ?? _metadataValue(raw, 'confidence');
  final sensitivity =
      _metadataString(parsed, 'sensitivity') ??
      _metadataString(raw, 'sensitivity');
  final durability =
      _metadataString(parsed, 'durability') ??
      _metadataString(raw, 'durability');
  final reasons = <String>[
    if (parsed == null && !_hasMemoryMetadata(raw)) 'model_output_unstructured',
    if (memoryType == null ||
        confidence == null ||
        sensitivity == null ||
        durability == null)
      'model_metadata_missing',
  ];

  return _MemoryCandidateEnvelope(
    text: text,
    memoryType: memoryType,
    confidence: confidence,
    sensitivity: sensitivity,
    durability: durability,
    policyReasons: reasons,
  );
}

final class _PkmProfileAgent implements runtime.AgentHandler {
  const _PkmProfileAgent();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    final text = _captureTextFromPayload(event.payload);
    final subject =
        event.subjectRef ?? runtime.SubjectRef(kind: 'capture', id: event.id);
    final response = await context.model.complete(
      runtime.ModelRequest(
        prompt: buildPkmProfilePrompt(text: text, sourceEventId: event.id),
        context: <String, Object?>{
          'prompt_ref': pkmProfilePromptRef,
          'source_event_id': event.id,
        },
      ),
    );
    final entry = _pkmProfileEntry(response, fallbackText: text);
    final sourceExcerpt = previewText(
      entry.sourceExcerpt.isEmpty ? text : entry.sourceExcerpt,
    );
    final sourceRefs = <Object?>[
      <String, Object?>{
        'kind': 'capture',
        'id': subject.id,
        'excerpt': sourceExcerpt,
      },
      <String, Object?>{
        'kind': 'event',
        'id': event.id,
        'excerpt': sourceExcerpt,
      },
    ];

    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.artifactCreated,
          subjectRef: subject,
          payload: <String, Object?>{
            'artifact_id': 'artifact.${subject.id}.pkm_profile_entry',
            'artifact_kind': 'pkm_profile_entry',
            'title': entry.title,
            'body': entry.body,
            'source_capture_id': subject.id,
            'source_event_id': event.id,
            'source_excerpt': sourceExcerpt,
            'source_refs': sourceRefs,
            'sensitivity': entry.sensitivity,
            'confidence': entry.confidence,
            'generator_id': 'pack.pkm_library/agent.pkm_profile_builder',
            'generator_version': '0.1.0',
            'topics': entry.topics,
            'people': entry.people,
            'projects': entry.projects,
            'derived_output': true,
            'source_truth': 'raw_capture_and_memory_remain_canonical',
            if (entry.policyReasons.isNotEmpty)
              'policy_reasons': entry.policyReasons,
          },
        ),
      ],
    );
  }
}

final class _PkmProfileEntry {
  const _PkmProfileEntry({
    required this.title,
    required this.body,
    required this.topics,
    required this.people,
    required this.projects,
    required this.sourceExcerpt,
    required this.confidence,
    required this.sensitivity,
    required this.policyReasons,
  });

  final String title;
  final String body;
  final List<String> topics;
  final List<String> people;
  final List<String> projects;
  final String sourceExcerpt;
  final String confidence;
  final String sensitivity;
  final List<String> policyReasons;
}

_PkmProfileEntry _pkmProfileEntry(
  runtime.ModelResponse response, {
  required String fallbackText,
}) {
  final parsed = _jsonObject(response.text);
  final raw = response.raw;
  final title =
      _metadataString(parsed, 'title') ??
      _metadataString(raw, 'title') ??
      'PKM profile entry';
  final summary =
      _metadataString(parsed, 'summary') ??
      _metadataString(raw, 'summary') ??
      _legacyCandidateText(response.text);
  final sourceExcerpt =
      _metadataString(parsed, 'source_excerpt') ??
      _metadataString(raw, 'source_excerpt') ??
      previewText(fallbackText);
  final confidence = _normalizedPkmValue(
    _metadataString(parsed, 'confidence') ?? _metadataString(raw, 'confidence'),
    const <String>{'high', 'medium', 'low'},
    fallback: 'medium',
  );
  final sensitivity = _normalizedPkmValue(
    _metadataString(parsed, 'sensitivity') ??
        _metadataString(raw, 'sensitivity'),
    const <String>{'high', 'medium', 'low'},
    fallback: 'low',
  );
  final reasons = <String>[
    if (parsed == null) 'model_output_unstructured',
    if (summary.trim().isEmpty) 'model_summary_missing',
  ];
  return _PkmProfileEntry(
    title: previewText(title, maxLength: 48),
    body: _pkmBody(
      title: title,
      summary: summary.trim().isEmpty ? previewText(fallbackText) : summary,
      topics: _metadataStringList(parsed, raw, 'topics'),
      people: _metadataStringList(parsed, raw, 'people'),
      projects: _metadataStringList(parsed, raw, 'projects'),
    ),
    topics: _metadataStringList(parsed, raw, 'topics'),
    people: _metadataStringList(parsed, raw, 'people'),
    projects: _metadataStringList(parsed, raw, 'projects'),
    sourceExcerpt: sourceExcerpt,
    confidence: confidence,
    sensitivity: sensitivity,
    policyReasons: reasons,
  );
}

String _pkmBody({
  required String title,
  required String summary,
  required List<String> topics,
  required List<String> people,
  required List<String> projects,
}) {
  final lines = <String>[
    '# ${previewText(title, maxLength: 64)}',
    '',
    summary,
    if (topics.isNotEmpty) '',
    if (topics.isNotEmpty) 'Topics: ${topics.join(', ')}',
    if (people.isNotEmpty) 'People: ${people.join(', ')}',
    if (projects.isNotEmpty) 'Projects: ${projects.join(', ')}',
  ];
  return lines.where((line) => line.trim().isNotEmpty).join('\n');
}

List<String> _metadataStringList(
  Map<String, Object?>? parsed,
  Map<String, Object?> raw,
  String key,
) {
  return <String>{
    ..._stringList(parsed?[key]),
    ..._stringList(raw[key]),
  }.toList(growable: false);
}

String _normalizedPkmValue(
  String? value,
  Set<String> allowed, {
  required String fallback,
}) {
  if (value != null && allowed.contains(value)) {
    return value;
  }
  return fallback;
}

Map<String, Object?>? _jsonObject(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  for (final candidate in <String?>[
    trimmed,
    _betweenJsonBraces(trimmed),
  ].whereType<String>()) {
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    } on FormatException {
      continue;
    }
  }
  return null;
}

String? _betweenJsonBraces(String value) {
  final start = value.indexOf('{');
  final end = value.lastIndexOf('}');
  if (start == -1 || end <= start) {
    return null;
  }
  return value.substring(start, end + 1);
}

String _legacyCandidateText(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return 'Memory candidate unavailable.';
  }
  return text;
}

bool _hasMemoryMetadata(Map<String, Object?> raw) {
  return raw.containsKey('memory_type') ||
      raw.containsKey('confidence') ||
      raw.containsKey('sensitivity') ||
      raw.containsKey('durability');
}

String? _metadataString(Map<String, Object?>? metadata, String key) {
  final value = metadata?[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

Object? _metadataValue(Map<String, Object?>? metadata, String key) {
  final value = metadata?[key];
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
    final response = await _suggestTodo(
      context.model,
      text: text,
      sourceEventId: event.id,
    );
    final suggestion = _todoSuggestion(response);
    if (!suggestion.isSuggested) {
      return const runtime.AgentHandlerResult();
    }
    final subject =
        event.subjectRef ?? runtime.SubjectRef(kind: 'capture', id: event.id);

    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.todoSuggested,
          subjectRef: subject,
          payload: <String, Object?>{
            'text': suggestion.title,
            'suggestion_kind': suggestion.kind,
            'status_label': suggestion.statusLabel,
            'suggestion_confidence': suggestion.confidence,
            'suggestion_reason': suggestion.reason,
            if (suggestion.scheduledAtLabel != null)
              'scheduled_at_label': suggestion.scheduledAtLabel,
            if (suggestion.dueAt != null) 'due_at': suggestion.dueAt,
            if (suggestion.dueLabel != null) 'due_label': suggestion.dueLabel,
            if (suggestion.scheduledStart != null)
              'scheduled_start': suggestion.scheduledStart,
            if (suggestion.scheduledEnd != null)
              'scheduled_end': suggestion.scheduledEnd,
            if (suggestion.priority != null) 'priority': suggestion.priority,
            if (suggestion.subtasks.isNotEmpty) 'subtasks': suggestion.subtasks,
            'todo_schema_version': 1,
            'source_capture_id': subject.id,
            'source_event_id': event.id,
            'source_excerpt': previewText(text),
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

Future<runtime.ModelResponse> _suggestTodo(
  runtime.ModelClient model, {
  required String text,
  required String sourceEventId,
}) async {
  return model.complete(
    runtime.ModelRequest(
      prompt: buildTodoSuggestionPrompt(
        text: text,
        sourceEventId: sourceEventId,
      ),
      context: <String, Object?>{
        'prompt_ref': todoSuggestionPromptRef,
        'source_event_id': sourceEventId,
      },
    ),
  );
}

final class _TodoSuggestionEnvelope {
  const _TodoSuggestionEnvelope({
    required this.kind,
    required this.title,
    required this.statusLabel,
    required this.confidence,
    required this.reason,
    this.dueAt,
    this.dueLabel,
    this.scheduledAtLabel,
    this.scheduledStart,
    this.scheduledEnd,
    this.priority,
    this.subtasks = const <Object?>[],
  });

  final String kind;
  final String title;
  final String statusLabel;
  final String confidence;
  final String reason;
  final String? dueAt;
  final String? dueLabel;
  final String? scheduledAtLabel;
  final String? scheduledStart;
  final String? scheduledEnd;
  final String? priority;
  final List<Object?> subtasks;

  bool get isSuggested => kind == 'action' || kind == 'schedule';
}

_TodoSuggestionEnvelope _todoSuggestion(runtime.ModelResponse response) {
  final parsed = _jsonObject(response.text);
  final raw = response.raw;
  final kind = _normalizedTodoKind(
    _metadataString(parsed, 'kind') ?? _metadataString(raw, 'kind'),
  );
  final title =
      _metadataString(parsed, 'title') ?? _metadataString(raw, 'title');
  final confidence =
      _normalizedTodoConfidence(
        _metadataString(parsed, 'confidence') ??
            _metadataString(raw, 'confidence'),
      ) ??
      'low';
  final reason =
      _metadataString(parsed, 'reason') ??
      _metadataString(raw, 'reason') ??
      (parsed == null ? 'model_output_unstructured' : 'model_metadata_missing');
  final scheduledAtLabel =
      _metadataString(parsed, 'scheduled_at_label') ??
      _metadataString(raw, 'scheduled_at_label');
  final dueAt =
      _metadataString(parsed, 'due_at') ?? _metadataString(raw, 'due_at');
  final dueLabel =
      _metadataString(parsed, 'due_label') ?? _metadataString(raw, 'due_label');
  final scheduledStart =
      _metadataString(parsed, 'scheduled_start') ??
      _metadataString(raw, 'scheduled_start');
  final scheduledEnd =
      _metadataString(parsed, 'scheduled_end') ??
      _metadataString(raw, 'scheduled_end');
  final priority = _normalizedTodoPriority(
    _metadataString(parsed, 'priority') ?? _metadataString(raw, 'priority'),
  );
  final subtasks = _todoSubtasks(parsed?['subtasks'] ?? raw['subtasks']);

  if (kind == null || kind == 'quiet') {
    return _TodoSuggestionEnvelope(
      kind: 'quiet',
      title: '',
      statusLabel: 'not suggested',
      confidence: confidence,
      reason: reason,
    );
  }
  if (title == null) {
    return _TodoSuggestionEnvelope(
      kind: 'quiet',
      title: '',
      statusLabel: 'not suggested',
      confidence: confidence,
      reason: 'model_title_missing',
    );
  }

  return _TodoSuggestionEnvelope(
    kind: kind,
    title: title,
    statusLabel: kind == 'schedule' ? 'schedule candidate' : 'suggested action',
    confidence: confidence,
    reason: reason,
    dueAt: dueAt,
    dueLabel: dueLabel,
    scheduledAtLabel: scheduledAtLabel,
    scheduledStart: scheduledStart,
    scheduledEnd: scheduledEnd,
    priority: priority,
    subtasks: subtasks,
  );
}

String? _normalizedTodoKind(String? value) {
  return switch (value) {
    'action' => 'action',
    'schedule' => 'schedule',
    'quiet' => 'quiet',
    _ => null,
  };
}

String? _normalizedTodoConfidence(String? value) {
  return switch (value) {
    'high' => 'high',
    'medium' => 'medium',
    'low' => 'low',
    _ => null,
  };
}

String? _normalizedTodoPriority(String? value) {
  return switch (value) {
    'high' => 'high',
    'medium' => 'medium',
    'low' => 'low',
    _ => null,
  };
}

List<Object?> _todoSubtasks(Object? value) {
  if (value is! List) {
    return const <Object?>[];
  }
  final subtasks = <Object?>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final map = item.cast<String, Object?>();
    final title = _nullableString(map['title']);
    if (title == null) {
      continue;
    }
    subtasks.add(<String, Object?>{
      'id': _nullableString(map['id']) ?? 'subtask-${subtasks.length + 1}',
      'title': title,
      'completed': map['completed'] == true,
    });
  }
  return subtasks;
}

final class _TranscriptCorrectionAgent implements runtime.AgentHandler {
  const _TranscriptCorrectionAgent();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    final transcriptId = _string(
      event.payload['transcript_id'],
      fallback: event.subjectRef?.id ?? event.id,
    );
    final sourceCaptureId = _string(
      event.payload['source_capture_id'],
      fallback: '',
    );
    final sourceAttachmentId = _string(
      event.payload['source_attachment_id'],
      fallback: '',
    );
    final correctionPatches = event.payload['correction_patches'] is List
        ? event.payload['correction_patches']! as List<Object?>
        : const <Object?>[];
    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.transcriptCorrected,
          subjectRef: runtime.SubjectRef(kind: 'transcript', id: transcriptId),
          payload: <String, Object?>{
            'source_transcript_id': transcriptId,
            if (sourceCaptureId.isNotEmpty)
              'source_capture_id': sourceCaptureId,
            if (sourceAttachmentId.isNotEmpty)
              'source_attachment_id': sourceAttachmentId,
            'status': _string(
              event.payload['correction_status'],
              fallback: 'recorded',
            ),
            'patches': correctionPatches,
            'auto_apply': event.payload['auto_apply'] == true,
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'transcript', 'id': transcriptId},
              <String, Object?>{'kind': 'event', 'id': event.id},
              if (sourceAttachmentId.isNotEmpty)
                <String, Object?>{
                  'kind': 'attachment',
                  'id': sourceAttachmentId,
                },
              if (sourceCaptureId.isNotEmpty)
                <String, Object?>{'kind': 'capture', 'id': sourceCaptureId},
            ],
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

String? _nullableString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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
  final normalized = value is String ? value.trim().toLowerCase() : null;
  if (normalized == 'low') {
    return memory.MemoryConfidence.low;
  }
  if (normalized == 'medium') {
    return memory.MemoryConfidence.medium;
  }
  if (normalized == 'high') {
    return memory.MemoryConfidence.high;
  }
  return memory.MemoryConfidence.medium;
}

memory.MemorySensitivity _sensitivity(Object? value) {
  final normalized = value is String ? value.trim().toLowerCase() : null;
  if (normalized == 'medium') {
    return memory.MemorySensitivity.medium;
  }
  if (normalized == 'high') {
    return memory.MemorySensitivity.high;
  }
  if (normalized == 'low') {
    return memory.MemorySensitivity.low;
  }
  return memory.MemorySensitivity.low;
}

memory.MemoryDurability _durability(Object? value) {
  final normalized = value is String ? value.trim().toLowerCase() : null;
  if (normalized == 'durable') {
    return memory.MemoryDurability.durable;
  }
  if (normalized == 'transient') {
    return memory.MemoryDurability.transient;
  }
  return memory.MemoryDurability.transient;
}

memory.MemoryType _memoryType(Object? value) {
  final normalized = value is String
      ? value.trim().replaceAll('-', '_').toLowerCase()
      : null;
  if (normalized == 'preference') {
    return memory.MemoryType.preference;
  }
  if (normalized == 'project') {
    return memory.MemoryType.project;
  }
  if (normalized == 'task_context' || normalized == 'taskcontext') {
    return memory.MemoryType.taskContext;
  }
  if (normalized == 'person') {
    return memory.MemoryType.person;
  }
  if (normalized == 'health') {
    return memory.MemoryType.health;
  }
  if (normalized == 'finance') {
    return memory.MemoryType.finance;
  }
  if (normalized == 'location') {
    return memory.MemoryType.location;
  }
  if (normalized == 'credential') {
    return memory.MemoryType.credential;
  }
  if (normalized == 'insight') {
    return memory.MemoryType.insight;
  }
  return memory.MemoryType.taskContext;
}

String _timeLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute local';
}
