import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_memory/memory.dart' as memory;

import '../domain/capture_models.dart';

final class CapturePipelineResult {
  const CapturePipelineResult({
    required this.record,
    required this.memoryItem,
    required this.todo,
    required this.traces,
    required this.eventTypes,
    required this.events,
    required this.acceptedMemoryCount,
    required this.reviewMemoryCount,
  });

  final CaptureRecord record;
  final CaptureMemoryItem memoryItem;
  final SourceTodo todo;
  final List<TraceEvent> traces;
  final List<String> eventTypes;
  final List<CapturePipelineEvent> events;
  final int acceptedMemoryCount;
  final int reviewMemoryCount;
}

final class CapturePipelineEvent {
  const CapturePipelineEvent({
    required this.type,
    required this.packId,
    required this.agentId,
  });

  final String type;
  final String? packId;
  final String? agentId;
}

final class CapturePipelineException implements Exception {
  const CapturePipelineException(this.message);

  final String message;

  @override
  String toString() => 'CapturePipelineException: $message';
}

final class CaptureOrchestrator {
  CaptureOrchestrator._({
    required runtime.RuntimeKernel kernel,
    required runtime.EventStore eventStore,
    required runtime.TraceSink traceSink,
    required memory.MemoryService memoryService,
    required memory.MemoryRepository memoryRepository,
  }) : _kernel = kernel,
       _eventStore = eventStore,
       _traceSink = traceSink,
       _memoryService = memoryService,
       _memoryRepository = memoryRepository;

  factory CaptureOrchestrator.local({
    WnClock? clock,
    WnIdGenerator? idGenerator,
    runtime.ModelClient? model,
    runtime.EventStore? eventStore,
    runtime.TraceSink? traceSink,
  }) {
    final localClock = clock ?? const SystemWnClock();
    final runtimeEventStore = eventStore ?? runtime.InMemoryEventStore();
    final runtimeTraceSink = traceSink ?? runtime.InMemoryTraceSink();
    final permissions = runtime.InMemoryPermissionBroker()
      ..grantAll(_defaultPackId, _defaultRequiredPermissions)
      ..grantAll(_todoPackId, _todoRequiredPermissions);
    final kernel = runtime.RuntimeKernel(
      eventStore: runtimeEventStore,
      traceSink: runtimeTraceSink,
      permissionBroker: permissions,
      toolRegistry: runtime.InMemoryToolRegistry(),
      idGenerator: idGenerator ?? MonotonicWnIdGenerator(clock: localClock),
      clock: localClock,
      model: model ?? const _CaptureSummaryModel(),
      deviceId: 'local-device',
    );
    kernel
      ..registerPack(_defaultPack)
      ..registerPack(_todoPack);

    final memoryRepository = memory.InMemoryMemoryRepository();
    final memoryService = memory.MemoryService(
      repository: memoryRepository,
      clock: localClock.now,
    );

    return CaptureOrchestrator._(
      kernel: kernel,
      eventStore: kernel.eventStore,
      traceSink: kernel.traceSink,
      memoryService: memoryService,
      memoryRepository: memoryRepository,
    );
  }

  static const _defaultPackId = 'pack.default';
  static const _defaultAgentId = 'agent.capture_loop';
  static const _todoPackId = 'pack.todo';
  static const _todoAgentId = 'agent.todo_loop';

  static const _defaultRequiredPermissions = <String>{
    'model.complete',
    'memory.propose',
    'card.write',
    'insight.write',
  };

  static const _todoRequiredPermissions = <String>{'todo.suggest'};

  static const _defaultPack = runtime.AgentPack(
    id: _defaultPackId,
    name: 'Default capture loop',
    version: '0.1.0',
    requiredPermissions: _defaultRequiredPermissions,
    subscriptions: <runtime.Subscription>[
      runtime.Subscription(
        id: 'sub.capture_created',
        agentId: _defaultAgentId,
        eventTypes: <String>{runtime.WnEventTypes.captureCreated},
      ),
    ],
    agents: <String, runtime.AgentHandler>{_defaultAgentId: _CaptureAgent()},
  );

  static const _todoPack = runtime.AgentPack(
    id: _todoPackId,
    name: 'Todo extraction loop',
    version: '0.1.0',
    requiredPermissions: _todoRequiredPermissions,
    subscriptions: <runtime.Subscription>[
      runtime.Subscription(
        id: 'sub.todo_capture_created',
        agentId: _todoAgentId,
        eventTypes: <String>{runtime.WnEventTypes.captureCreated},
      ),
    ],
    agents: <String, runtime.AgentHandler>{_todoAgentId: _TodoAgent()},
  );

  final runtime.RuntimeKernel _kernel;
  final runtime.EventStore _eventStore;
  final runtime.TraceSink _traceSink;
  final memory.MemoryService _memoryService;
  final memory.MemoryRepository _memoryRepository;

  Future<CapturePipelineResult> processCapture(String body) async {
    final priorEventCount = (await _eventStore.readAll()).length;
    final priorTraceCount = (await _traceSink.readAll()).length;

    final capture = await _kernel.publish(
      runtime.WnEventDraft(
        type: runtime.WnEventTypes.captureCreated,
        actor: runtime.WnActor.user,
        subjectRef: runtime.SubjectRef(
          kind: 'capture',
          id: _kernel.idGenerator.nextId('capture'),
        ),
        payload: <String, Object?>{'text': body, 'source': 'manual'},
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

    return CapturePipelineResult(
      record: CaptureRecord(
        id: capture.id,
        body: body,
        createdAt: capture.createdAt,
        status: 'Processed locally',
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
            ),
          )
          .toList(growable: false),
      acceptedMemoryCount: activeMemories.length,
      reviewMemoryCount: reviewProposals.length,
    );
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
    final sourceId = _string(
      payload['source_event_id'],
      fallback: event.causationId ?? event.id,
    );

    return memory.MemoryProposal(
      id: 'proposal-${event.id}',
      key: _string(
        payload['key'],
        fallback: 'capture.${event.subjectRef?.id ?? event.id}.summary',
      ),
      body: body,
      evidence: <memory.MemorySourceRef>[
        memory.MemorySourceRef(
          sourceType: 'capture',
          sourceId: sourceId,
          excerpt: _string(payload['source_excerpt'], fallback: body),
        ),
      ],
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
        title: 'Memory 自动入库',
        summary: item.body,
        sourceRecordId: capture.id,
        confidenceLabel: '${item.confidence.name} confidence',
        statusLabel: 'auto-accepted',
      );
    }

    return CaptureMemoryItem(
      id: result.proposal.id,
      title: 'Memory 待复核',
      summary: result.proposal.body,
      sourceRecordId: capture.id,
      confidenceLabel: result.decision.reasons.join(', '),
      statusLabel: 'needs review',
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
      throw const CapturePipelineException(
        'Todo pack did not emit a Todo suggestion.',
      );
    }
    return SourceTodo(
      id: todoEvent.id,
      title: _string(todoEvent.payload['text'], fallback: 'Review capture'),
      sourceLabel: 'source: ${todoEvent.causationId ?? capture.id}',
      statusLabel: 'suggested by agent',
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

final class _CaptureAgent implements runtime.AgentHandler {
  const _CaptureAgent();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    final text = _string(event.payload['text'], fallback: '');
    final subject =
        event.subjectRef ?? runtime.SubjectRef(kind: 'capture', id: event.id);
    final policy = _policyForCaptureText(text);
    final summary = await context.model.complete(
      runtime.ModelRequest(
        prompt: 'Summarize capture for Memory: $text',
        context: <String, Object?>{'source_event_id': event.id},
      ),
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
            'source_excerpt': _preview(text),
            'memory_type': policy.memoryType,
            'confidence': policy.confidence,
            'sensitivity': policy.sensitivity,
          },
        ),
        context.emit(
          type: runtime.WnEventTypes.cardCreated,
          subjectRef: subject,
          payload: <String, Object?>{
            'title': 'Capture summary',
            'body': summary.text,
          },
        ),
        context.emit(
          type: runtime.WnEventTypes.insightCreated,
          subjectRef: subject,
          payload: <String, Object?>{
            'kind': 'capture_reflection',
            'text': 'This capture can be recalled through Memory.',
          },
        ),
      ],
    );
  }
}

final class _MemoryPolicyFields {
  const _MemoryPolicyFields({
    required this.memoryType,
    required this.confidence,
    required this.sensitivity,
  });

  final String memoryType;
  final String confidence;
  final String sensitivity;
}

final class _TodoAgent implements runtime.AgentHandler {
  const _TodoAgent();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    final text = _string(event.payload['text'], fallback: '');
    final subject =
        event.subjectRef ?? runtime.SubjectRef(kind: 'capture', id: event.id);

    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.todoSuggested,
          subjectRef: subject,
          payload: <String, Object?>{
            'text': 'Follow up: ${_preview(text)}',
            'source_event_id': event.id,
          },
        ),
      ],
    );
  }
}

final class _CaptureSummaryModel implements runtime.ModelClient {
  const _CaptureSummaryModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    final text = request.prompt.replaceFirst(
      'Summarize capture for Memory: ',
      '',
    );
    return runtime.ModelResponse(text: _preview(text));
  }
}

String _preview(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= 80) {
    return trimmed;
  }
  return '${trimmed.substring(0, 80)}...';
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

_MemoryPolicyFields _policyForCaptureText(String text) {
  final lower = text.toLowerCase();
  if (_containsAny(lower, const [
    'api key',
    'apikey',
    'access token',
    'token',
    'password',
    'secret',
    'credential',
    '密钥',
    '密码',
    '令牌',
  ])) {
    return const _MemoryPolicyFields(
      memoryType: 'credential',
      confidence: 'high',
      sensitivity: 'high',
    );
  }
  if (_containsAny(lower, const [
    'doctor',
    'medical',
    'health',
    'diagnosis',
    'medication',
    'hospital',
    '健康',
    '医生',
    '诊断',
    '用药',
  ])) {
    return const _MemoryPolicyFields(
      memoryType: 'health',
      confidence: 'medium',
      sensitivity: 'high',
    );
  }
  if (_containsAny(lower, const [
    'bank',
    'salary',
    'income',
    'tax',
    'credit card',
    'invoice',
    '银行',
    '薪资',
    '收入',
    '税',
    '信用卡',
  ])) {
    return const _MemoryPolicyFields(
      memoryType: 'finance',
      confidence: 'medium',
      sensitivity: 'high',
    );
  }
  if (_containsAny(lower, const [
    'home address',
    'current location',
    'gps',
    '住址',
    '地址',
    '定位',
  ])) {
    return const _MemoryPolicyFields(
      memoryType: 'location',
      confidence: 'medium',
      sensitivity: 'high',
    );
  }
  return const _MemoryPolicyFields(
    memoryType: 'task_context',
    confidence: 'high',
    sensitivity: 'low',
  );
}

bool _containsAny(String text, Iterable<String> needles) {
  return needles.any(text.contains);
}

String _timeLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute local';
}
