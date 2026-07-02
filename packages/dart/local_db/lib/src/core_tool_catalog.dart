import 'dart:convert';

import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_memory/memory.dart' as memory;

import 'context_packet_builder.dart';
import 'database.dart';
import 'json.dart';
import 'memory_repository_adapter.dart';
import 'models.dart';
import 'runtime_run_mode_codec.dart';

typedef LocalDbCoreToolClock = DateTime Function();
typedef LocalDbCoreToolIdFactory = String Function(String prefix);

final class LocalDbCoreToolCatalog {
  LocalDbCoreToolCatalog(
    WideNoteLocalDatabase database, {
    ContextPacketBuilder? contextPacketBuilder,
    memory.MemoryRepository? memoryRepository,
    LocalDbCoreToolClock? clock,
    LocalDbCoreToolIdFactory? idFactory,
  }) : _database = database,
       _contextPacketBuilder =
           contextPacketBuilder ?? ContextPacketBuilder(database),
       _memoryRepository =
           memoryRepository ?? LocalDbMemoryRepository(database),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _idFactory = idFactory;

  static const contextPacketBuildTool = 'context_packet.build';
  static const timelineReadTool = 'timeline.read';
  static const knowledgeReadTool = 'knowledge.read';
  static const semanticSearchQueryTool = 'semantic_search.query';
  static const memoryReadTool = 'memory.read';
  static const memoryProposeTool = 'memory.propose';
  static const todoSuggestTool = 'todo.suggest';
  static const traceReadTool = 'trace.read';
  static const audioTranscribeLocalFakeTool = 'audio.transcribe.local_fake';
  static const imageOcrLocalFakeTool = 'image.ocr.local_fake';
  static const imageDescribeLocalFakeTool = 'image.describe.local_fake';

  final WideNoteLocalDatabase _database;
  final ContextPacketBuilder _contextPacketBuilder;
  final memory.MemoryRepository _memoryRepository;
  final LocalDbCoreToolClock _clock;
  final LocalDbCoreToolIdFactory? _idFactory;
  var _generatedIdCounter = 0;

  List<runtime.ToolDefinition> get definitions {
    return <runtime.ToolDefinition>[
      runtime.ToolDefinition(
        name: contextPacketBuildTool,
        description:
            'Builds a scoped local Context Packet summary from safe DB-backed inputs.',
        requiredPermissions: const <String>{contextPacketBuildTool},
        handler: _handleContextPacketBuild,
      ),
      runtime.ToolDefinition(
        name: memoryReadTool,
        description:
            'Reads accepted active local Memory items with source references.',
        requiredPermissions: const <String>{memoryReadTool},
        handler: _handleMemoryRead,
      ),
      runtime.ToolDefinition(
        name: timelineReadTool,
        description:
            'Reads local timeline captures with attachment and derived artifact summaries.',
        requiredPermissions: const <String>{timelineReadTool},
        handler: _handleTimelineRead,
      ),
      runtime.ToolDefinition(
        name: knowledgeReadTool,
        description:
            'Reads local Knowledge outputs: Memory, cards, insights, todos, and derived artifacts.',
        requiredPermissions: const <String>{knowledgeReadTool},
        handler: _handleKnowledgeRead,
      ),
      runtime.ToolDefinition(
        name: semanticSearchQueryTool,
        description:
            'Builds a model-ready local retrieval packet for a user query without mutating data.',
        requiredPermissions: const <String>{semanticSearchQueryTool},
        handler: _handleSemanticSearchQuery,
      ),
      runtime.ToolDefinition(
        name: memoryProposeTool,
        description:
            'Creates a source-linked local Memory proposal for user review.',
        requiredPermissions: const <String>{memoryProposeTool},
        access: runtime.ToolAccess.write,
        handler: _handleMemoryPropose,
      ),
      runtime.ToolDefinition(
        name: todoSuggestTool,
        description:
            'Creates a source-linked local todo suggestion for review.',
        requiredPermissions: const <String>{todoSuggestTool},
        access: runtime.ToolAccess.write,
        handler: _handleTodoSuggest,
      ),
      runtime.ToolDefinition(
        name: audioTranscribeLocalFakeTool,
        description:
            'Creates a source-linked local fake transcript derived artifact from capture or attachment refs.',
        requiredPermissions: const <String>{audioTranscribeLocalFakeTool},
        access: runtime.ToolAccess.write,
        handler: _handleAudioTranscribeLocalFake,
      ),
      runtime.ToolDefinition(
        name: imageOcrLocalFakeTool,
        description:
            'Creates a source-linked local fake OCR derived artifact from capture or attachment refs.',
        requiredPermissions: const <String>{imageOcrLocalFakeTool},
        access: runtime.ToolAccess.write,
        handler: _handleImageOcrLocalFake,
      ),
      runtime.ToolDefinition(
        name: imageDescribeLocalFakeTool,
        description:
            'Creates a source-linked local fake image description derived artifact from capture or attachment refs.',
        requiredPermissions: const <String>{imageDescribeLocalFakeTool},
        access: runtime.ToolAccess.write,
        handler: _handleImageDescribeLocalFake,
      ),
      runtime.ToolDefinition(
        name: traceReadTool,
        description: 'Reads redacted local runtime trace and run summaries.',
        requiredPermissions: const <String>{traceReadTool},
        handler: _handleTraceRead,
      ),
    ];
  }

  void registerInto(runtime.ToolRegistry registry) {
    for (final definition in definitions) {
      registry.register(definition);
    }
  }

  void registerAll(runtime.ToolRegistry registry) => registerInto(registry);

  Future<JsonMap> _handleContextPacketBuild(
    runtime.ToolInvocation invocation,
  ) async {
    return _guard(contextPacketBuildTool, () async {
      final input = invocation.input;
      _ensureAllowedKeys(contextPacketBuildTool, input, const <String>{
        'surface',
        'intent',
        'request_ref',
        'subject_ref',
        'source_refs',
        'cache_key',
        'max_items',
        'cacheable',
        'ttl_seconds',
        'permission_mode',
        'permissions',
        'grant_snapshot_id',
        'redaction_policy',
        'disclosure_level',
        'pack_id',
        'pack_version',
        'agent_id',
        'local_date',
        'privacy_profile',
        'include_attachment_metadata',
        'allow_attachment_expansion',
      });

      final ttl = input.containsKey('ttl_seconds')
          ? _nullableDurationSeconds(input['ttl_seconds'], 'ttl_seconds')
          : const Duration(minutes: 15);
      final packId = _contextPacketPackId(input, invocation);
      final result = _contextPacketBuilder.build(
        ContextPacketBuildRequest(
          surface: _requiredString(input, 'surface'),
          intent: _optionalString(input['intent'], 'intent'),
          requestRef: _objectRefInput(input['request_ref'], 'request_ref'),
          subjectRef: _objectRefInput(input['subject_ref'], 'subject_ref'),
          sourceRefs: _sourceRefsInput(input),
          cacheKey: _optionalString(input['cache_key'], 'cache_key'),
          maxItems: _limitInput(
            input['max_items'],
            field: 'max_items',
            defaultValue: 12,
            maxValue: 50,
          ),
          cacheable: _optionalBool(
            input['cacheable'],
            'cacheable',
            defaultValue: true,
          ),
          ttl: ttl,
          permissionMode:
              _optionalString(input['permission_mode'], 'permission_mode') ??
              'local_only',
          permissions: _stringListInput(
            input['permissions'],
            'permissions',
            defaultValue: const <String>[],
          ),
          grantSnapshotId: _optionalString(
            input['grant_snapshot_id'],
            'grant_snapshot_id',
          ),
          redactionPolicy:
              _optionalString(input['redaction_policy'], 'redaction_policy') ??
              'redact_sensitive',
          disclosureLevel:
              _optionalString(input['disclosure_level'], 'disclosure_level') ??
              'targeted_excerpt',
          packId: packId,
          packVersion:
              _optionalString(input['pack_version'], 'pack_version') ??
              (packId == null
                  ? null
                  : _database.packInstallations.readById(packId)?.version),
          agentId: _optionalString(input['agent_id'], 'agent_id'),
          localDate: _optionalString(input['local_date'], 'local_date'),
          privacyProfile:
              _optionalString(input['privacy_profile'], 'privacy_profile') ??
              'default',
          includeAttachmentMetadata: _optionalBool(
            input['include_attachment_metadata'],
            'include_attachment_metadata',
            defaultValue: false,
          ),
          allowAttachmentExpansion: _optionalBool(
            input['allow_attachment_expansion'],
            'allow_attachment_expansion',
            defaultValue: false,
          ),
        ),
      );

      return _success(contextPacketBuildTool, <String, Object?>{
        'packet_summary': _packetSummary(result),
        'source_refs': result.packet['source_refs'] ?? const <Object?>[],
        'cache_key': result.cacheKey,
        'reused_cache': result.reusedCache,
        'cacheable': result.cacheable,
      });
    });
  }

  Future<JsonMap> _handleMemoryRead(runtime.ToolInvocation invocation) async {
    return _guard(memoryReadTool, () async {
      final input = invocation.input;
      _ensureAllowedKeys(memoryReadTool, input, const <String>{
        'limit',
        'source_event_id',
        'source_capture_id',
        'type',
        'memory_type',
        'sensitivity',
      });
      final limit = _limitInput(
        input['limit'],
        field: 'limit',
        defaultValue: 20,
        maxValue: 50,
      );
      final sourceEventId = _optionalString(
        input['source_event_id'],
        'source_event_id',
      );
      final sourceCaptureId = _optionalString(
        input['source_capture_id'],
        'source_capture_id',
      );
      final memoryType = _optionalMemoryTypeName(
        input['memory_type'] ?? input['type'],
        'memory_type',
      );
      final sensitivity = _optionalSensitivityName(
        input['sensitivity'],
        'sensitivity',
      );

      final items =
          _database.memoryItems
              .readAll(status: 'active')
              .where((item) => !item.tombstone)
              .where(
                (item) =>
                    sourceEventId == null ||
                    item.sourceEventId == sourceEventId ||
                    _hasSourceRef(item.sourceRefs, 'event', sourceEventId),
              )
              .where(
                (item) =>
                    sourceCaptureId == null ||
                    item.sourceCaptureId == sourceCaptureId ||
                    _hasSourceRef(item.sourceRefs, 'capture', sourceCaptureId),
              )
              .where(
                (item) => memoryType == null || item.memoryType == memoryType,
              )
              .where(
                (item) =>
                    sensitivity == null || item.sensitivity == sensitivity,
              )
              .toList(growable: false)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final limited = items
          .take(limit)
          .map(_memoryItemOutput)
          .toList(growable: false);

      return _success(memoryReadTool, <String, Object?>{
        'items': limited,
        'count': limited.length,
        'limit': limit,
        'filters': <String, Object?>{
          if (sourceEventId != null) 'source_event_id': sourceEventId,
          if (sourceCaptureId != null) 'source_capture_id': sourceCaptureId,
          if (memoryType != null) 'memory_type': memoryType,
          if (sensitivity != null) 'sensitivity': sensitivity,
        },
      });
    });
  }

  Future<JsonMap> _handleTimelineRead(runtime.ToolInvocation invocation) async {
    return _guard(timelineReadTool, () async {
      final input = invocation.input;
      _ensureAllowedKeys(timelineReadTool, input, const <String>{
        'limit',
        'source_capture_id',
        'include_attachments',
        'include_artifacts',
      });
      final limit = _limitInput(
        input['limit'],
        field: 'limit',
        defaultValue: 20,
        maxValue: 100,
      );
      final sourceCaptureId = _optionalString(
        input['source_capture_id'],
        'source_capture_id',
      );
      final includeAttachments = _optionalBool(
        input['include_attachments'],
        'include_attachments',
        defaultValue: true,
      );
      final includeArtifacts = _optionalBool(
        input['include_artifacts'],
        'include_artifacts',
        defaultValue: true,
      );

      final captures =
          _database.captures
              .readAll()
              .where((capture) => capture.status != 'deleted')
              .where(
                (capture) =>
                    sourceCaptureId == null || capture.id == sourceCaptureId,
              )
              .toList(growable: false)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final items = captures
          .take(limit)
          .map(
            (capture) => _captureOutput(
              capture,
              includeAttachments: includeAttachments,
              includeArtifacts: includeArtifacts,
              database: _database,
            ),
          )
          .toList(growable: false);

      return _success(timelineReadTool, <String, Object?>{
        'items': items,
        'count': items.length,
        'limit': limit,
        'filters': <String, Object?>{
          if (sourceCaptureId != null) 'source_capture_id': sourceCaptureId,
        },
      });
    });
  }

  Future<JsonMap> _handleKnowledgeRead(
    runtime.ToolInvocation invocation,
  ) async {
    return _guard(knowledgeReadTool, () async {
      final input = invocation.input;
      _ensureAllowedKeys(knowledgeReadTool, input, const <String>{
        'limit',
        'kind',
        'source_capture_id',
        'source_event_id',
      });
      final limit = _limitInput(
        input['limit'],
        field: 'limit',
        defaultValue: 20,
        maxValue: 100,
      );
      final kind = _optionalString(input['kind'], 'kind');
      final sourceCaptureId = _optionalString(
        input['source_capture_id'],
        'source_capture_id',
      );
      final sourceEventId = _optionalString(
        input['source_event_id'],
        'source_event_id',
      );

      final items =
          <JsonMap>[
            if (kind == null || kind == 'memory')
              ..._database.memoryItems
                  .readAll(status: 'active')
                  .where((item) => !item.tombstone)
                  .where(
                    (item) => _matchesSourceFilters(
                      item.sourceRefs,
                      sourceCaptureId: sourceCaptureId,
                      sourceEventId: sourceEventId,
                      directSourceCaptureId: item.sourceCaptureId,
                      directSourceEventId: item.sourceEventId,
                    ),
                  )
                  .map(
                    (item) => _knowledgeOutput(
                      'memory',
                      item.updatedAt,
                      _memoryItemOutput(item),
                    ),
                  ),
            if (kind == null || kind == 'card')
              ..._database.cards
                  .readAll(status: 'active')
                  .where(
                    (card) => _matchesSourceFilters(
                      card.sourceRefs,
                      sourceCaptureId: sourceCaptureId,
                      sourceEventId: sourceEventId,
                    ),
                  )
                  .map(
                    (card) => _knowledgeOutput(
                      'card',
                      card.updatedAt,
                      _cardOutput(card),
                    ),
                  ),
            if (kind == null || kind == 'insight')
              ..._database.insights
                  .readAll(status: 'active')
                  .where(
                    (insight) => _matchesSourceFilters(
                      insight.sourceRefs,
                      sourceCaptureId: sourceCaptureId,
                      sourceEventId: sourceEventId,
                    ),
                  )
                  .map(
                    (insight) => _knowledgeOutput(
                      'insight',
                      insight.updatedAt,
                      _insightOutput(insight),
                    ),
                  ),
            if (kind == null || kind == 'todo')
              ..._database.todos
                  .readAll()
                  .where(_isReadableTodo)
                  .where(
                    (todo) => _matchesSourceFilters(
                      _listValue(todo.payload['source_refs']),
                      sourceCaptureId: sourceCaptureId,
                      sourceEventId: sourceEventId,
                      directSourceCaptureId: todo.sourceCaptureId,
                      directSourceEventId: todo.sourceEventId,
                    ),
                  )
                  .map(
                    (todo) => _knowledgeOutput(
                      'todo',
                      todo.updatedAt,
                      _todoOutput(todo),
                    ),
                  ),
            if (kind == null || kind == 'artifact')
              ..._database.derivedArtifacts
                  .readAll()
                  .where(_isReadableArtifact)
                  .where(
                    (artifact) => _matchesSourceFilters(
                      artifact.sourceRefs,
                      sourceCaptureId: sourceCaptureId,
                      sourceEventId: sourceEventId,
                      directSourceCaptureId: artifact.sourceCaptureId,
                      directSourceEventId: artifact.sourceEventId,
                    ),
                  )
                  .map(
                    (artifact) => _knowledgeOutput(
                      'artifact',
                      artifact.updatedAt,
                      _artifactOutput(artifact),
                    ),
                  ),
          ]..sort(
            (a, b) => (b['_updated_at_sort']! as String).compareTo(
              a['_updated_at_sort']! as String,
            ),
          );
      final limited = items
          .take(limit)
          .map(
            (item) => <String, Object?>{
              for (final entry in item.entries)
                if (entry.key != '_updated_at_sort') entry.key: entry.value,
            },
          )
          .toList(growable: false);

      return _success(knowledgeReadTool, <String, Object?>{
        'items': limited,
        'count': limited.length,
        'limit': limit,
        'filters': <String, Object?>{
          if (kind != null) 'kind': kind,
          if (sourceCaptureId != null) 'source_capture_id': sourceCaptureId,
          if (sourceEventId != null) 'source_event_id': sourceEventId,
        },
      });
    });
  }

  Future<JsonMap> _handleSemanticSearchQuery(
    runtime.ToolInvocation invocation,
  ) async {
    return _guard(semanticSearchQueryTool, () async {
      final input = invocation.input;
      _ensureAllowedKeys(semanticSearchQueryTool, input, const <String>{
        'query',
        'limit',
        'kind',
        'kinds',
        'object_kinds',
        'status',
        'statuses',
        'since',
        'until',
        'source_refs',
        'source_capture_id',
        'source_attachment_id',
        'source_event_id',
        'include_attachment_metadata',
        'include_deleted',
        'include_tombstones',
        'include_high_sensitivity',
        'permission_mode',
        'sensitivity_scope',
        'privacy_profile',
      });
      final request = _candidateRetrievalRequest(input);
      final candidates = _collectLocalCandidates(_database, request);
      return _success(semanticSearchQueryTool, <String, Object?>{
        'query': request.query,
        'query_used_for_candidate_selection': false,
        'selection_strategy': 'local_candidate_retrieval_nonsemantic',
        'candidates': candidates
            .map((candidate) => candidate.output)
            .toList(growable: false),
        'sources': candidates
            .map((candidate) => candidate.sourceSummary)
            .toList(growable: false),
        'source_refs': _dedupeSourceRefs(
          candidates.expand((candidate) => candidate.sourceRefs),
        ),
        'count': candidates.length,
        'limit': request.limit,
        'filters': request.filters,
        'raw_media_included': false,
      });
    });
  }

  String? _contextPacketPackId(
    JsonMap input,
    runtime.ToolInvocation invocation,
  ) {
    final explicit = _optionalString(input['pack_id'], 'pack_id');
    final candidate = explicit ?? invocation.packId;
    if (_database.packInstallations.readById(candidate) != null) {
      return candidate;
    }
    if (explicit != null) {
      throw _ToolInputException(
        'invalid_input',
        'pack_id must refer to an installed local pack.',
        details: const <String, Object?>{'field': 'pack_id'},
      );
    }
    return null;
  }

  Future<JsonMap> _handleMemoryPropose(
    runtime.ToolInvocation invocation,
  ) async {
    return _guard(memoryProposeTool, () async {
      final input = invocation.input;
      _ensureAllowedKeys(memoryProposeTool, input, const <String>{
        'id',
        'key',
        'body',
        'source_refs',
        'source_event_id',
        'source_capture_id',
        'type',
        'memory_type',
        'confidence',
        'sensitivity',
        'durability',
      });
      final refs = _sourceRefsInput(input);
      if (refs.isEmpty) {
        return _reviewFailure(
          memoryProposeTool,
          'missing_source_refs',
          'Memory proposals must include at least one source ref.',
        );
      }

      final proposal = memory.MemoryProposal(
        id: _optionalString(input['id'], 'id') ?? _nextId('memory_proposal'),
        key: _requiredString(input, 'key'),
        body: _requiredString(input, 'body'),
        evidence: refs.map(_memorySourceRef).toList(growable: false),
        memoryType: _memoryType(input['memory_type'] ?? input['type']),
        confidence: _confidence(input['confidence']),
        sensitivity: _sensitivity(input['sensitivity']),
        durability: _durability(input['durability']),
      );
      final result = await memory.MemoryService(
        repository: _memoryRepository,
        clock: _clock,
        idFactory: () => _nextId('memory_item'),
      ).submitProposal(proposal);

      final acceptedRecord = result.item == null
          ? null
          : _database.memoryItems.readById(result.item!.id);
      return _success(memoryProposeTool, <String, Object?>{
        'proposal': _memoryProposalOutput(result.proposal),
        'review_required': result.needsReview,
        'accepted_memory_id': result.item?.id,
        if (acceptedRecord != null) 'memory': _memoryItemOutput(acceptedRecord),
        'policy_reasons': result.proposal.policyReasons,
        'conflicting_memory_ids': result.proposal.conflictingMemoryIds,
      });
    });
  }

  Future<JsonMap> _handleTodoSuggest(runtime.ToolInvocation invocation) async {
    return _guard(todoSuggestTool, () async {
      final input = invocation.input;
      _ensureAllowedKeys(todoSuggestTool, input, const <String>{
        'id',
        'title',
        'body',
        'source_refs',
        'source_event_id',
        'source_capture_id',
        'due_at',
        'due_label',
        'scheduled_at_label',
        'scheduled_start',
        'scheduled_end',
        'priority',
        'sort_order',
        'indent_level',
        'subtasks',
      });
      final refs = _sourceRefsInput(input);
      if (refs.isEmpty) {
        return _reviewFailure(
          todoSuggestTool,
          'missing_source_refs',
          'Todo suggestions must include at least one source ref.',
        );
      }
      final now = _clock().toUtc();
      final priority = _todoPriority(input['priority']);
      final subtasks = _todoSubtasks(input['subtasks']);
      final record = TodoRecord(
        id: _optionalString(input['id'], 'id') ?? _nextId('todo_suggestion'),
        sourceEventId: _firstSourceId(refs, 'event'),
        sourceCaptureId: _firstSourceId(refs, 'capture'),
        status: 'suggested',
        payload: <String, Object?>{
          'todo_schema_version': 1,
          'title': _requiredString(input, 'title'),
          if (_optionalString(input['body'], 'body') != null)
            'body': _optionalString(input['body'], 'body'),
          if (_optionalString(input['due_at'], 'due_at') != null)
            'due_at': _optionalString(input['due_at'], 'due_at'),
          if (_optionalString(input['due_label'], 'due_label') != null)
            'due_label': _optionalString(input['due_label'], 'due_label'),
          if (_optionalString(
                input['scheduled_at_label'],
                'scheduled_at_label',
              ) !=
              null)
            'scheduled_at_label': _optionalString(
              input['scheduled_at_label'],
              'scheduled_at_label',
            ),
          if (_optionalString(input['scheduled_start'], 'scheduled_start') !=
              null)
            'scheduled_start': _optionalString(
              input['scheduled_start'],
              'scheduled_start',
            ),
          if (_optionalString(input['scheduled_end'], 'scheduled_end') != null)
            'scheduled_end': _optionalString(
              input['scheduled_end'],
              'scheduled_end',
            ),
          if (priority != null) 'priority': priority,
          if (_optionalInt(input['sort_order'], 'sort_order') != null)
            'sort_order': _optionalInt(input['sort_order'], 'sort_order'),
          if (_optionalInt(input['indent_level'], 'indent_level') != null)
            'indent_level': _optionalInt(
              input['indent_level'],
              'indent_level',
            )!.clamp(0, 3),
          if (subtasks.isNotEmpty) 'subtasks': subtasks,
          'source_refs': refs,
          'agent_generated': true,
          'review_state': 'needs_review',
          'suggested_by_pack_id': invocation.packId,
          if (invocation.runId != null) 'source_run_id': invocation.runId,
        },
        createdAt: now,
        updatedAt: now,
      );
      _database.todos.insert(record);

      return _success(todoSuggestTool, <String, Object?>{
        'todo': _todoOutput(record),
        'review_required': true,
      });
    });
  }

  Future<JsonMap> _handleAudioTranscribeLocalFake(
    runtime.ToolInvocation invocation,
  ) async {
    return _handleLocalFakeDerivedArtifact(
      invocation,
      toolName: audioTranscribeLocalFakeTool,
      artifactKind: 'transcript',
      title: 'Local fake transcript',
      bodyPrefix: 'Local fake transcript generated for',
    );
  }

  Future<JsonMap> _handleImageOcrLocalFake(
    runtime.ToolInvocation invocation,
  ) async {
    return _handleLocalFakeDerivedArtifact(
      invocation,
      toolName: imageOcrLocalFakeTool,
      artifactKind: 'ocr_text',
      title: 'Local fake OCR text',
      bodyPrefix: 'Local fake OCR text generated for',
    );
  }

  Future<JsonMap> _handleImageDescribeLocalFake(
    runtime.ToolInvocation invocation,
  ) async {
    return _handleLocalFakeDerivedArtifact(
      invocation,
      toolName: imageDescribeLocalFakeTool,
      artifactKind: 'image_description',
      title: 'Local fake image description',
      bodyPrefix: 'Local fake image description generated for',
    );
  }

  Future<JsonMap> _handleLocalFakeDerivedArtifact(
    runtime.ToolInvocation invocation, {
    required String toolName,
    required String artifactKind,
    required String title,
    required String bodyPrefix,
  }) async {
    return _guard(toolName, () async {
      final input = invocation.input;
      _ensureAllowedKeys(toolName, input, const <String>{
        'artifact_id',
        'source_refs',
        'source_capture_id',
        'source_attachment_id',
        'source_event_id',
        'confidence',
        'sensitivity',
      });
      final source = _resolveDerivedArtifactSource(input, _database);
      final now = _clock().toUtc();
      final body = '$bodyPrefix ${source.description}.';
      final artifact = DerivedArtifactRecord(
        id:
            _optionalString(input['artifact_id'], 'artifact_id') ??
            _nextId(artifactKind),
        sourceCaptureId: source.capture.id,
        sourceAttachmentId: source.attachment?.id,
        sourceEventId: source.eventId,
        artifactKind: artifactKind,
        status: 'ready',
        title: title,
        body: body,
        contentHash: _localContentHash(<String, Object?>{
          'tool': toolName,
          'artifact_kind': artifactKind,
          'body': body,
          'source_refs': source.sourceRefs,
        }),
        sourceRefs: source.sourceRefs,
        sensitivity:
            _optionalSensitivityName(input['sensitivity'], 'sensitivity') ??
            'low',
        confidence:
            _optionalConfidenceName(input['confidence'], 'confidence') ??
            'medium',
        generatorId: toolName,
        generatorVersion: 'local-fake-v1',
        payload: <String, Object?>{
          'local_fake': true,
          'raw_media_included': false,
          'source_input_kind': source.attachment == null
              ? 'capture_ref'
              : 'attachment_ref',
          if (invocation.runId != null) 'source_run_id': invocation.runId,
        },
        createdAt: now,
        updatedAt: now,
      );
      _database.derivedArtifacts.save(artifact);

      return _success(toolName, <String, Object?>{
        'artifact': _artifactOutput(artifact),
        'source_refs': _safeSourceRefs(artifact.sourceRefs),
        'raw_media_included': false,
      });
    });
  }

  Future<JsonMap> _handleTraceRead(runtime.ToolInvocation invocation) async {
    return _guard(traceReadTool, () async {
      final input = invocation.input;
      _ensureAllowedKeys(traceReadTool, input, const <String>{
        'run_id',
        'pack_id',
        'limit',
      });
      final runId = _optionalString(input['run_id'], 'run_id');
      final packId = _optionalString(input['pack_id'], 'pack_id');
      final limit = _limitInput(
        input['limit'],
        field: 'limit',
        defaultValue: 20,
        maxValue: 100,
      );

      final runRecords = _runsForTraceRead(runId: runId, packId: packId);
      final runPackIds = <String, String>{
        for (final run in runRecords) run.id: run.packId,
      };
      final traceRecords =
          (runId == null
                  ? _database.traceEvents.readAll()
                  : _database.traceEvents.readByRun(runId))
              .where(
                (trace) =>
                    packId == null ||
                    trace.packId == packId ||
                    trace.payload['pack_id'] == packId ||
                    (trace.runId != null && runPackIds[trace.runId] == packId),
              )
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final traces = traceRecords
          .take(limit)
          .map(_traceOutput)
          .toList(growable: false);
      final runs = runRecords
          .take(limit)
          .map(_runOutput)
          .toList(growable: false);

      return _success(traceReadTool, <String, Object?>{
        'runs': runs,
        'traces': traces,
        'count': traces.length,
        'limit': limit,
        'filters': <String, Object?>{
          if (runId != null) 'run_id': runId,
          if (packId != null) 'pack_id': packId,
        },
      });
    });
  }

  List<RuntimeRunRecord> _runsForTraceRead({String? runId, String? packId}) {
    final records = runId == null
        ? _database.runtimeRuns.readAll()
        : <RuntimeRunRecord>[
            if (_database.runtimeRuns.readById(runId) != null)
              _database.runtimeRuns.readById(runId)!,
          ];
    final filtered = records
        .where((run) => packId == null || run.packId == packId)
        .toList(growable: false);
    filtered.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return filtered;
  }

  String _nextId(String prefix) {
    final generated = _idFactory?.call(prefix);
    if (generated != null && generated.trim().isNotEmpty) {
      return _safeId(generated.trim());
    }
    _generatedIdCounter += 1;
    return '${_safeId(prefix)}_${_clock().microsecondsSinceEpoch}_$_generatedIdCounter';
  }
}

Future<JsonMap> _guard(
  String toolName,
  Future<JsonMap> Function() action,
) async {
  try {
    return await action();
  } on _ToolInputException catch (error) {
    return _failure(
      toolName,
      error.code,
      error.message,
      details: error.details,
    );
  } on ArgumentError catch (error) {
    return _failure(
      toolName,
      'invalid_input',
      'Tool input failed validation.',
      details: <String, Object?>{'error_type': error.runtimeType.toString()},
    );
  } on StateError catch (error) {
    return _failure(
      toolName,
      'local_state_error',
      'The local database state does not support this tool request.',
      details: <String, Object?>{'error_type': error.runtimeType.toString()},
    );
  } on Exception catch (error) {
    return _failure(
      toolName,
      'local_tool_error',
      'The local tool could not complete this request.',
      details: <String, Object?>{'error_type': error.runtimeType.toString()},
    );
  }
}

JsonMap _success(String toolName, JsonMap data) {
  return <String, Object?>{
    'success': true,
    'tool': toolName,
    'schema_version': 1,
    ...data,
  };
}

JsonMap _failure(
  String toolName,
  String code,
  String message, {
  JsonMap details = const <String, Object?>{},
}) {
  return <String, Object?>{
    'success': false,
    'tool': toolName,
    'schema_version': 1,
    'error': <String, Object?>{
      'code': code,
      'message': message,
      if (details.isNotEmpty) 'details': details,
    },
  };
}

JsonMap _reviewFailure(String toolName, String code, String message) {
  return <String, Object?>{
    ..._failure(toolName, code, message),
    'review': <String, Object?>{
      'required': true,
      'state': 'needs_source_refs',
      'reason': code,
    },
  };
}

JsonMap _packetSummary(ContextPacketBuildResult result) {
  final packet = result.packet;
  final sections = _mapList(packet['sections']);
  final sourceRefs = _mapList(packet['source_refs']);
  return <String, Object?>{
    'id': packet['id'],
    'surface': packet['surface'],
    'created_at': packet['created_at'],
    'expires_at': packet['expires_at'],
    'source_ref_count': sourceRefs.length,
    'section_count': sections.length,
    'source_backed_section_count': result.sourceBackedSectionCount,
    'section_kinds': sections
        .map((section) => section['kind'])
        .whereType<String>()
        .toList(growable: false),
    'redaction_count': sections.fold<int>(
      0,
      (count, section) => count + _listValue(section['redactions']).length,
    ),
  };
}

JsonMap _memoryItemOutput(MemoryItemRecord item) {
  final sourceRefs = _sourceRefsFromRecord(
    item.sourceRefs,
    sourceEventId: item.sourceEventId,
    sourceCaptureId: item.sourceCaptureId,
  );
  return <String, Object?>{
    'id': item.id,
    'key': item.key,
    'body': item.body,
    'memory_type': item.memoryType,
    'confidence': item.confidence,
    'sensitivity': item.sensitivity,
    'revision': item.revision,
    'source_event_id': item.sourceEventId,
    'source_capture_id': item.sourceCaptureId,
    'source_refs': sourceRefs,
    'created_at': item.createdAt.toUtc().toIso8601String(),
    'updated_at': item.updatedAt.toUtc().toIso8601String(),
  };
}

JsonMap _memoryProposalOutput(memory.MemoryProposal proposal) {
  return <String, Object?>{
    'id': proposal.id,
    'key': proposal.key,
    'body': proposal.body,
    'status': _proposalStatusName(proposal.status),
    'memory_type': _memoryTypeName(proposal.memoryType),
    'confidence': proposal.confidence.name,
    'sensitivity': proposal.sensitivity.name,
    'durability': proposal.durability.name,
    'policy_reasons': proposal.policyReasons,
    'conflicting_memory_ids': proposal.conflictingMemoryIds,
    'source_refs': proposal.evidence
        .map(_sourceRefOutput)
        .toList(growable: false),
  };
}

JsonMap _todoOutput(TodoRecord todo) {
  final sourceRefs = _sourceRefsFromRecord(
    _listValue(todo.payload['source_refs']),
    sourceEventId: todo.sourceEventId,
    sourceCaptureId: todo.sourceCaptureId,
  );
  return <String, Object?>{
    'id': todo.id,
    'status': todo.status,
    'title': todo.payload['title'],
    'body': todo.payload['body'],
    'suggestion_kind': todo.payload['suggestion_kind'],
    'suggestion_confidence': todo.payload['suggestion_confidence'],
    'suggestion_reason': todo.payload['suggestion_reason'],
    'due_at': todo.payload['due_at'],
    'due_label': todo.payload['due_label'],
    'scheduled_at_label': todo.payload['scheduled_at_label'],
    'scheduled_start': todo.payload['scheduled_start'],
    'scheduled_end': todo.payload['scheduled_end'],
    'priority': todo.payload['priority'],
    'sort_order': todo.payload['sort_order'],
    'indent_level': todo.payload['indent_level'],
    'completed_at': todo.payload['completed_at'],
    'completed_by': todo.payload['completed_by'],
    'user_overrides': _listValue(todo.payload['user_overrides']),
    'subtasks': _listValue(todo.payload['subtasks']),
    'source_event_id': todo.sourceEventId,
    'source_capture_id': todo.sourceCaptureId,
    'source_refs': sourceRefs,
    'created_at': todo.createdAt.toUtc().toIso8601String(),
    'updated_at': todo.updatedAt.toUtc().toIso8601String(),
  };
}

JsonMap _captureOutput(
  CaptureRecord capture, {
  required bool includeAttachments,
  required bool includeArtifacts,
  required WideNoteLocalDatabase database,
}) {
  final attachments = includeAttachments
      ? database.attachments
            .readByCapture(capture.id)
            .where((attachment) => attachment.status != 'deleted')
            .map(_attachmentOutput)
            .toList(growable: false)
      : const <JsonMap>[];
  final artifacts = includeArtifacts
      ? database.derivedArtifacts
            .readByCapture(capture.id)
            .where((artifact) => artifact.status != 'deleted')
            .map(_artifactOutput)
            .toList(growable: false)
      : const <JsonMap>[];
  return <String, Object?>{
    'id': capture.id,
    'source_type': capture.sourceType,
    'source_id': capture.sourceId,
    'status': capture.status,
    'text': capture.payload['text'],
    'payload': _redactJsonMap(capture.payload),
    'source_refs': _sourceRefsFromRecord(
      const <Object?>[],
      sourceCaptureId: capture.id,
      sourceEventId: capture.sourceId,
    ),
    if (includeAttachments) 'attachments': attachments,
    if (includeArtifacts) 'derived_artifacts': artifacts,
    'created_at': capture.createdAt.toUtc().toIso8601String(),
    'updated_at': capture.updatedAt.toUtc().toIso8601String(),
  };
}

JsonMap _attachmentOutput(AttachmentRecord attachment) {
  return <String, Object?>{
    'id': attachment.id,
    'capture_id': attachment.captureId,
    'source_event_id': attachment.sourceEventId,
    'asset_kind': attachment.assetKind,
    'mime_type': attachment.mimeType,
    'storage_path': _redactedLocalPath,
    'original_file_name': attachment.originalFileName == null
        ? null
        : _safeFileName(attachment.originalFileName!),
    'sha256': attachment.sha256,
    'byte_length': attachment.byteLength,
    'status': attachment.status,
    'payload': _redactJsonMap(attachment.payload),
    'created_at': attachment.createdAt.toUtc().toIso8601String(),
    'updated_at': attachment.updatedAt.toUtc().toIso8601String(),
  };
}

JsonMap _cardOutput(CardRecord card) {
  return <String, Object?>{
    'id': card.id,
    'card_kind': card.cardKind,
    'title': card.title,
    'body': card.body,
    'status': card.status,
    'source_refs': _sourceRefsFromRecord(card.sourceRefs),
    'payload': _redactJsonMap(card.payload),
    'created_at': card.createdAt.toUtc().toIso8601String(),
    'updated_at': card.updatedAt.toUtc().toIso8601String(),
  };
}

JsonMap _insightOutput(InsightRecord insight) {
  return <String, Object?>{
    'id': insight.id,
    'insight_kind': insight.insightKind,
    'title': insight.title,
    'summary': insight.summary,
    'metric_label': insight.metricLabel,
    'metric_value': insight.metricValue,
    'status': insight.status,
    'source_refs': _sourceRefsFromRecord(insight.sourceRefs),
    'payload': _redactJsonMap(insight.payload),
    'created_at': insight.createdAt.toUtc().toIso8601String(),
    'updated_at': insight.updatedAt.toUtc().toIso8601String(),
  };
}

JsonMap _artifactOutput(DerivedArtifactRecord artifact) {
  return <String, Object?>{
    'id': artifact.id,
    'source_capture_id': artifact.sourceCaptureId,
    'source_attachment_id': artifact.sourceAttachmentId,
    'source_event_id': artifact.sourceEventId,
    'artifact_kind': artifact.artifactKind,
    'status': artifact.status,
    'title': artifact.title,
    'body': artifact.body,
    'mime_type': artifact.mimeType,
    'storage_path': artifact.storagePath == null ? null : _redactedLocalPath,
    'content_hash': artifact.contentHash,
    'source_refs': _sourceRefsFromRecord(artifact.sourceRefs),
    'sensitivity': artifact.sensitivity,
    'confidence': artifact.confidence,
    'generator_id': artifact.generatorId,
    'generator_version': artifact.generatorVersion,
    'payload': _redactJsonMap(artifact.payload),
    'created_at': artifact.createdAt.toUtc().toIso8601String(),
    'updated_at': artifact.updatedAt.toUtc().toIso8601String(),
  };
}

JsonMap _knowledgeOutput(String kind, DateTime updatedAt, JsonMap value) {
  return <String, Object?>{
    'kind': kind,
    'item': value,
    '_updated_at_sort': updatedAt.toUtc().toIso8601String(),
  };
}

bool _isReadableTodo(TodoRecord todo) {
  return !_terminalStatuses.contains(todo.status);
}

bool _isReadableArtifact(DerivedArtifactRecord artifact) {
  return artifact.status == 'active' || artifact.status == 'ready';
}

bool _matchesSourceFilters(
  JsonList sourceRefs, {
  String? sourceCaptureId,
  String? sourceEventId,
  String? directSourceCaptureId,
  String? directSourceEventId,
}) {
  final captureMatches =
      sourceCaptureId == null ||
      directSourceCaptureId == sourceCaptureId ||
      _hasSourceRef(sourceRefs, 'capture', sourceCaptureId);
  final eventMatches =
      sourceEventId == null ||
      directSourceEventId == sourceEventId ||
      _hasSourceRef(sourceRefs, 'event', sourceEventId);
  return captureMatches && eventMatches;
}

_CandidateRetrievalRequest _candidateRetrievalRequest(JsonMap input) {
  final permissionMode =
      _optionalString(input['permission_mode'], 'permission_mode') ??
      'local_only';
  if (!_candidatePermissionModes.contains(permissionMode)) {
    throw _ToolInputException(
      'invalid_input',
      'permission_mode is not supported for local candidate retrieval.',
      details: const <String, Object?>{'field': 'permission_mode'},
    );
  }
  final sensitivityScope =
      _optionalString(input['sensitivity_scope'], 'sensitivity_scope') ??
      'default';
  return _CandidateRetrievalRequest(
    query: _requiredString(input, 'query'),
    limit: _limitInput(
      input['limit'],
      field: 'limit',
      defaultValue: 12,
      maxValue: 50,
    ),
    kinds: _candidateKindSet(input),
    statuses: _optionalStringSet(
      input['statuses'] ?? input['status'],
      'statuses',
    ),
    sourceRefs: _candidateSourceRefsInput(input),
    since: _optionalDateTime(input['since'], 'since'),
    until: _optionalDateTime(input['until'], 'until'),
    includeDeleted: _optionalBool(
      input['include_deleted'],
      'include_deleted',
      defaultValue: false,
    ),
    includeTombstones: _optionalBool(
      input['include_tombstones'],
      'include_tombstones',
      defaultValue: false,
    ),
    includeHighSensitivity:
        _optionalBool(
          input['include_high_sensitivity'],
          'include_high_sensitivity',
          defaultValue: false,
        ) ||
        permissionMode == 'trace_review' ||
        sensitivityScope == 'include_high',
    permissionMode: permissionMode,
    sensitivityScope: sensitivityScope,
    privacyProfile:
        _optionalString(input['privacy_profile'], 'privacy_profile') ??
        'chat_local',
    includeAttachmentMetadata: _optionalBool(
      input['include_attachment_metadata'],
      'include_attachment_metadata',
      defaultValue: false,
    ),
  );
}

List<_LocalCandidate> _collectLocalCandidates(
  WideNoteLocalDatabase database,
  _CandidateRetrievalRequest request,
) {
  final filter = _CandidateSourceFilter(request.sourceRefs);
  final candidates = <_LocalCandidate>[
    if (request.allowsKind('memory'))
      ...database.memoryItems
          .readAll()
          .where((item) => request.allowsMemory(item))
          .where(
            (item) => filter.matches(
              'memory',
              item.id,
              item.sourceRefs,
              sourceCaptureId: item.sourceCaptureId,
              sourceEventId: item.sourceEventId,
            ),
          )
          .map((item) => _memoryCandidate(item, request)),
    if (request.allowsKind('capture'))
      ...database.captures
          .readAll()
          .where(request.allowsCapture)
          .where(
            (capture) => filter.matches(
              'capture',
              capture.id,
              _captureCandidateRefs(capture),
            ),
          )
          .map((capture) => _captureCandidate(capture, request)),
    if (request.allowsKind('card'))
      ...database.cards
          .readAll()
          .where(
            (card) => request.allowsSimpleStatus(card.status, card.updatedAt),
          )
          .where((card) => filter.matches('card', card.id, card.sourceRefs))
          .map((card) => _cardCandidate(card, request)),
    if (request.allowsKind('insight'))
      ...database.insights
          .readAll()
          .where(
            (insight) =>
                request.allowsSimpleStatus(insight.status, insight.updatedAt),
          )
          .where(
            (insight) =>
                filter.matches('insight', insight.id, insight.sourceRefs),
          )
          .map((insight) => _insightCandidate(insight, request)),
    if (request.allowsKind('todo'))
      ...database.todos
          .readAll()
          .where(request.allowsTodo)
          .where(
            (todo) => filter.matches(
              'todo',
              todo.id,
              _listValue(todo.payload['source_refs']),
              sourceCaptureId: todo.sourceCaptureId,
              sourceEventId: todo.sourceEventId,
            ),
          )
          .map((todo) => _todoCandidate(todo, request)),
    if (request.allowsKind('derived_artifact'))
      ...database.derivedArtifacts
          .readAll()
          .where(request.allowsArtifact)
          .where(
            (artifact) => filter.matches(
              'derived_artifact',
              artifact.id,
              artifact.sourceRefs,
              sourceCaptureId: artifact.sourceCaptureId,
              sourceEventId: artifact.sourceEventId,
              sourceAttachmentId: artifact.sourceAttachmentId,
            ),
          )
          .map((artifact) => _artifactCandidate(artifact, request)),
  ]..sort(_compareCandidates);
  return candidates.take(request.limit).toList(growable: false);
}

_LocalCandidate _memoryCandidate(
  MemoryItemRecord item,
  _CandidateRetrievalRequest request,
) {
  final sourceRefs = _candidateSourceRefs(
    kind: 'memory',
    id: item.id,
    sourceVersion: item.revision,
    contentHash: _localContentHash(<String, Object?>{
      'body': item.body,
      'source_refs': item.sourceRefs,
      'payload': item.payload,
    }),
    sensitivity: item.sensitivity,
    linkedRefs: item.sourceRefs,
    sourceCaptureId: item.sourceCaptureId,
    sourceEventId: item.sourceEventId,
  );
  return _candidate(
    kind: 'memory',
    id: item.id,
    title: item.key,
    status: item.status,
    sensitivity: item.sensitivity,
    snippetText: item.body,
    sourceRefs: sourceRefs,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    request: request,
    provenance: <String, Object?>{
      'memory_type': item.memoryType,
      'confidence': item.confidence,
      'revision': item.revision,
      'source_capture_id': item.sourceCaptureId,
      'source_event_id': item.sourceEventId,
      'tombstone': item.tombstone,
    },
  );
}

_LocalCandidate _captureCandidate(
  CaptureRecord capture,
  _CandidateRetrievalRequest request,
) {
  final sourceRefs = _candidateSourceRefs(
    kind: 'capture',
    id: capture.id,
    sourceVersion: capture.updatedAt.toUtc().toIso8601String(),
    contentHash: _localContentHash(capture.payload),
    sensitivity: _captureSensitivity(capture),
    linkedRefs: _captureCandidateRefs(capture),
  );
  return _candidate(
    kind: 'capture',
    id: capture.id,
    title: 'Capture ${capture.id}',
    status: capture.status,
    sensitivity: _captureSensitivity(capture),
    snippetText: _captureSnippetText(capture),
    sourceRefs: sourceRefs,
    createdAt: capture.createdAt,
    updatedAt: capture.updatedAt,
    request: request,
    provenance: <String, Object?>{
      'source_type': capture.sourceType,
      if (capture.sourceId != null) 'source_id': capture.sourceId,
    },
  );
}

_LocalCandidate _cardCandidate(
  CardRecord card,
  _CandidateRetrievalRequest request,
) {
  final sourceRefs = _candidateSourceRefs(
    kind: 'card',
    id: card.id,
    sourceVersion: card.updatedAt.toUtc().toIso8601String(),
    contentHash: _localContentHash(<String, Object?>{
      'title': card.title,
      'body': card.body,
      'source_refs': card.sourceRefs,
      'payload': card.payload,
    }),
    sensitivity: 'low',
    linkedRefs: card.sourceRefs,
  );
  return _candidate(
    kind: 'card',
    id: card.id,
    title: card.title,
    status: card.status,
    sensitivity: 'low',
    snippetText: _lines(<String>[card.title, card.body]),
    sourceRefs: sourceRefs,
    createdAt: card.createdAt,
    updatedAt: card.updatedAt,
    request: request,
    provenance: <String, Object?>{'card_kind': card.cardKind},
  );
}

_LocalCandidate _insightCandidate(
  InsightRecord insight,
  _CandidateRetrievalRequest request,
) {
  final sourceRefs = _candidateSourceRefs(
    kind: 'insight',
    id: insight.id,
    sourceVersion: insight.updatedAt.toUtc().toIso8601String(),
    contentHash: _localContentHash(<String, Object?>{
      'title': insight.title,
      'summary': insight.summary,
      'source_refs': insight.sourceRefs,
      'payload': insight.payload,
    }),
    sensitivity: 'low',
    linkedRefs: insight.sourceRefs,
  );
  return _candidate(
    kind: 'insight',
    id: insight.id,
    title: insight.title,
    status: insight.status,
    sensitivity: 'low',
    snippetText: _lines(<String>[insight.title, insight.summary]),
    sourceRefs: sourceRefs,
    createdAt: insight.createdAt,
    updatedAt: insight.updatedAt,
    request: request,
    provenance: <String, Object?>{
      'insight_kind': insight.insightKind,
      if (insight.metricLabel != null) 'metric_label': insight.metricLabel,
      if (insight.metricValue != null) 'metric_value': insight.metricValue,
    },
  );
}

_LocalCandidate _todoCandidate(
  TodoRecord todo,
  _CandidateRetrievalRequest request,
) {
  final sourceRefs = _candidateSourceRefs(
    kind: 'todo',
    id: todo.id,
    sourceVersion: todo.updatedAt.toUtc().toIso8601String(),
    contentHash: _localContentHash(todo.payload),
    sensitivity: 'low',
    linkedRefs: _listValue(todo.payload['source_refs']),
    sourceCaptureId: todo.sourceCaptureId,
    sourceEventId: todo.sourceEventId,
  );
  return _candidate(
    kind: 'todo',
    id: todo.id,
    title: _optionalString(todo.payload['title'], 'todo.title') ?? todo.id,
    status: todo.status,
    sensitivity: 'low',
    snippetText: _lines(<String>[
      _optionalString(todo.payload['title'], 'todo.title') ?? '',
      _optionalString(todo.payload['body'], 'todo.body') ?? '',
    ]),
    sourceRefs: sourceRefs,
    createdAt: todo.createdAt,
    updatedAt: todo.updatedAt,
    request: request,
    provenance: <String, Object?>{
      'source_capture_id': todo.sourceCaptureId,
      'source_event_id': todo.sourceEventId,
      if (todo.payload['review_state'] != null)
        'review_state': todo.payload['review_state'],
    },
  );
}

_LocalCandidate _artifactCandidate(
  DerivedArtifactRecord artifact,
  _CandidateRetrievalRequest request,
) {
  final sourceRefs = _candidateSourceRefs(
    kind: 'artifact',
    id: artifact.id,
    sourceVersion: artifact.updatedAt.toUtc().toIso8601String(),
    contentHash:
        artifact.contentHash ??
        _localContentHash(<String, Object?>{
          'title': artifact.title,
          'body': artifact.body,
          'source_refs': artifact.sourceRefs,
          'payload': artifact.payload,
        }),
    sensitivity: artifact.sensitivity,
    linkedRefs: artifact.sourceRefs,
    sourceCaptureId: artifact.sourceCaptureId,
    sourceEventId: artifact.sourceEventId,
    sourceAttachmentId: artifact.sourceAttachmentId,
  );
  return _candidate(
    kind: 'derived_artifact',
    id: artifact.id,
    title: artifact.title,
    status: artifact.status,
    sensitivity: artifact.sensitivity,
    snippetText: _lines(<String>[artifact.title, artifact.body]),
    sourceRefs: sourceRefs,
    createdAt: artifact.createdAt,
    updatedAt: artifact.updatedAt,
    request: request,
    provenance: <String, Object?>{
      'artifact_kind': artifact.artifactKind,
      'confidence': artifact.confidence,
      'source_capture_id': artifact.sourceCaptureId,
      'source_attachment_id': artifact.sourceAttachmentId,
      'source_event_id': artifact.sourceEventId,
      'generator_id': artifact.generatorId,
      'generator_version': artifact.generatorVersion,
      if (artifact.invalidatedAt != null)
        'invalidated_at': artifact.invalidatedAt!.toUtc().toIso8601String(),
    },
  );
}

_LocalCandidate _candidate({
  required String kind,
  required String id,
  required String title,
  required String status,
  required String sensitivity,
  required String snippetText,
  required List<JsonMap> sourceRefs,
  required DateTime createdAt,
  required DateTime updatedAt,
  required _CandidateRetrievalRequest request,
  required JsonMap provenance,
}) {
  final redactedBySensitivity =
      _schemaSensitivityName(sensitivity) == 'high' &&
      request.includeHighSensitivity;
  final snippet = redactedBySensitivity
      ? null
      : _excerpt(_redactString(snippetText));
  final safeSourceRefs = _safeSourceRefs(sourceRefs);
  final output = <String, Object?>{
    'kind': kind,
    'id': id,
    'title': title,
    'status': status,
    'sensitivity': _schemaSensitivityName(sensitivity),
    'snippet': snippet,
    'source_refs': safeSourceRefs,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'provenance': <String, Object?>{
      ...provenance,
      'candidate_collector': 'local_db_candidate_retrieval.v1',
      'selection_dimensions': _candidateSelectionDimensions,
      'query_used_for_candidate_selection': false,
      'privacy_profile': request.privacyProfile,
      'permission_mode': request.permissionMode,
      'invalidation_reason': 'source_version_or_permission_scope_change',
    },
    'redactions': <Object?>[
      if (redactedBySensitivity)
        <String, Object?>{
          'reason': 'sensitivity_high',
          'source_ref': safeSourceRefs.isEmpty ? null : safeSourceRefs.first,
        },
    ],
  };
  return _LocalCandidate(output: output, sourceRefs: safeSourceRefs);
}

int _compareCandidates(_LocalCandidate a, _LocalCandidate b) {
  final updated = (b.output['updated_at']! as String).compareTo(
    a.output['updated_at']! as String,
  );
  if (updated != 0) {
    return updated;
  }
  final kind = _candidateKindRank(a.kind).compareTo(_candidateKindRank(b.kind));
  if (kind != 0) {
    return kind;
  }
  return a.id.compareTo(b.id);
}

int _candidateKindRank(String kind) {
  return _candidateKindOrder[kind] ?? _candidateKindOrder.length;
}

Set<String>? _candidateKindSet(JsonMap input) {
  final rawKinds = input['object_kinds'] ?? input['kinds'] ?? input['kind'];
  final values = _optionalStringSet(rawKinds, 'object_kinds');
  if (values == null) {
    return null;
  }
  final normalized = <String>{};
  for (final value in values) {
    final kind = _normalizeCandidateKind(value);
    if (kind == null) {
      throw _ToolInputException(
        'invalid_input',
        'object_kinds contains an unsupported candidate kind.',
        details: <String, Object?>{'kind': value},
      );
    }
    normalized.add(kind);
  }
  return Set<String>.unmodifiable(normalized);
}

String? _normalizeCandidateKind(String value) {
  return switch (value) {
    'memory' => 'memory',
    'capture' || 'record' => 'capture',
    'card' => 'card',
    'insight' => 'insight',
    'todo' => 'todo',
    'artifact' ||
    'derived_artifact' ||
    'derived_artifacts' => 'derived_artifact',
    _ => null,
  };
}

Set<String>? _optionalStringSet(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : <String>{trimmed};
  }
  if (value is! List) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be a string or list of strings.',
      details: <String, Object?>{'field': field},
    );
  }
  final strings = <String>{};
  for (final item in value) {
    if (item is! String) {
      throw _ToolInputException(
        'invalid_input',
        '$field must contain only strings.',
        details: <String, Object?>{'field': field},
      );
    }
    final trimmed = item.trim();
    if (trimmed.isNotEmpty) {
      strings.add(trimmed);
    }
  }
  return strings.isEmpty ? null : Set<String>.unmodifiable(strings);
}

DateTime? _optionalDateTime(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be an ISO-8601 timestamp string.',
      details: <String, Object?>{'field': field},
    );
  }
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be an ISO-8601 timestamp string.',
      details: <String, Object?>{'field': field},
    );
  }
  return parsed.toUtc();
}

List<JsonMap> _candidateSourceRefsInput(JsonMap input) {
  final refs = <JsonMap>[..._sourceRefsInput(input)];
  final attachmentId = _optionalString(
    input['source_attachment_id'],
    'source_attachment_id',
  );
  if (attachmentId != null) {
    refs.add(<String, Object?>{
      'kind': 'file',
      'id': attachmentId,
      'source_type': 'file',
      'source_id': attachmentId,
    });
  }
  return _dedupeSourceRefs(refs.map(_safeSourceRef).whereType<JsonMap>());
}

List<JsonMap> _candidateSourceRefs({
  required String kind,
  required String id,
  required Object? sourceVersion,
  required String contentHash,
  required String sensitivity,
  JsonList linkedRefs = const <Object?>[],
  String? sourceCaptureId,
  String? sourceEventId,
  String? sourceAttachmentId,
}) {
  return _safeSourceRefs(<JsonMap>[
    <String, Object?>{
      'kind': kind,
      'id': id,
      'source_type': kind,
      'source_id': id,
      if (sourceVersion != null) 'source_version': sourceVersion,
      'content_hash': contentHash,
      'sensitivity': _schemaSensitivityName(sensitivity),
    },
    ...linkedRefs
        .whereType<Map>()
        .map(_safeStoredSourceRef)
        .whereType<JsonMap>(),
    if (sourceCaptureId != null) _sourceRefForKind('capture', sourceCaptureId),
    if (sourceEventId != null) _sourceRefForKind('event', sourceEventId),
    if (sourceAttachmentId != null)
      _sourceRefForKind('file', sourceAttachmentId),
  ]);
}

JsonMap _sourceRefForKind(String kind, String id) {
  return <String, Object?>{
    'kind': kind,
    'id': id,
    'source_type': kind,
    'source_id': id,
  };
}

JsonMap? _safeStoredSourceRef(Map<dynamic, dynamic> value) {
  final normalized = _storedSourceRef(value);
  return normalized == null ? null : _safeSourceRef(normalized);
}

JsonMap? _safeSourceRef(JsonMap value) {
  final kind = _normalizedSourceKind(value['kind'] ?? value['source_type']);
  final id = value['id'] ?? value['source_id'];
  if (kind == null || id is! String || id.trim().isEmpty) {
    return null;
  }
  return <String, Object?>{
    'kind': kind,
    'id': id,
    'source_type': kind,
    'source_id': id,
    if (value['event_id'] is String) 'event_id': value['event_id'],
    if (value['source_version'] != null)
      'source_version': value['source_version'],
    if (value['content_hash'] is String) 'content_hash': value['content_hash'],
    if (value['sensitivity'] is String)
      'sensitivity': _schemaSensitivityName(value['sensitivity']! as String),
  };
}

List<JsonMap> _safeSourceRefs(Iterable<Object?> refs) {
  return _dedupeSourceRefs(
    refs.whereType<Map>().map(_safeStoredSourceRef).whereType<JsonMap>(),
  );
}

String? _normalizedSourceKind(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim() == 'attachment' ? 'file' : value.trim();
}

JsonList _captureCandidateRefs(CaptureRecord capture) {
  return <Object?>[
    <String, Object?>{'kind': 'capture', 'id': capture.id},
    if (capture.sourceId != null)
      <String, Object?>{'kind': capture.sourceType, 'id': capture.sourceId},
  ];
}

String _captureSnippetText(CaptureRecord capture) {
  return _firstPayloadText(capture.payload, const <String>[
    'text',
    'raw_text',
    'body',
    'summary',
    'title',
    'preview_text',
    'excerpt',
  ]);
}

String _firstPayloadText(JsonMap payload, List<String> keys) {
  for (final key in keys) {
    final value = payload[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

String _captureSensitivity(CaptureRecord capture) {
  final sensitivity = capture.payload['sensitivity'];
  return sensitivity is String ? _schemaSensitivityName(sensitivity) : 'low';
}

String _lines(Iterable<String> lines) {
  return lines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

String _schemaSensitivityName(String sensitivity) {
  return sensitivity == 'high'
      ? 'high'
      : sensitivity == 'medium'
      ? 'medium'
      : 'low';
}

String _localContentHash(Object? value) {
  final canonical = jsonEncode(_stableJson(value));
  var hash = 0xcbf29ce484222325;
  for (final unit in canonical.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return 'local-${hash.toRadixString(16).padLeft(16, '0')}';
}

Object? _stableJson(Object? value) {
  if (value is Map) {
    final result = <String, Object?>{};
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    for (final key in keys) {
      result[key] = _stableJson(value[key]);
    }
    return result;
  }
  if (value is Iterable) {
    return value.map(_stableJson).toList(growable: false);
  }
  return value;
}

_DerivedArtifactSource _resolveDerivedArtifactSource(
  JsonMap input,
  WideNoteLocalDatabase database,
) {
  final refs = _candidateSourceRefsInput(input);
  final attachmentId = _firstSourceId(refs, 'file');
  final explicitCaptureId = _firstSourceId(refs, 'capture');
  final explicitEventId = _firstSourceId(refs, 'event');
  final attachment = attachmentId == null
      ? null
      : database.attachments.readById(attachmentId);
  if (attachmentId != null && attachment == null) {
    throw _ToolInputException(
      'invalid_input',
      'source_attachment_id must refer to an existing local attachment.',
      details: const <String, Object?>{'field': 'source_attachment_id'},
    );
  }
  if (attachment != null && attachment.status != 'available') {
    throw _ToolInputException(
      'source_not_ready',
      'The referenced attachment is not available for local fake derivation.',
      details: <String, Object?>{'attachment_status': attachment.status},
    );
  }
  final captureId = attachment?.captureId ?? explicitCaptureId;
  if (captureId == null) {
    throw _ToolInputException(
      'missing_source_refs',
      'Local fake derived artifact tools require a capture or attachment source ref.',
      details: const <String, Object?>{'field': 'source_refs'},
    );
  }
  final capture = database.captures.readById(captureId);
  if (capture == null) {
    throw _ToolInputException(
      'invalid_input',
      'source_capture_id must refer to an existing local capture.',
      details: const <String, Object?>{'field': 'source_capture_id'},
    );
  }
  if (_terminalStatuses.contains(capture.status)) {
    throw _ToolInputException(
      'source_not_ready',
      'The referenced capture is not active for local fake derivation.',
      details: <String, Object?>{'capture_status': capture.status},
    );
  }
  final eventId = explicitEventId ?? attachment?.sourceEventId;
  final sourceRefs = _safeSourceRefs(<Object?>[
    ...refs,
    _sourceRefForKind('capture', capture.id),
    if (attachment != null) _sourceRefForKind('file', attachment.id),
    if (eventId != null) _sourceRefForKind('event', eventId),
  ]);
  return _DerivedArtifactSource(
    capture: capture,
    attachment: attachment,
    eventId: eventId,
    sourceRefs: sourceRefs,
  );
}

final class _DerivedArtifactSource {
  const _DerivedArtifactSource({
    required this.capture,
    required this.attachment,
    required this.eventId,
    required this.sourceRefs,
  });

  final CaptureRecord capture;
  final AttachmentRecord? attachment;
  final String? eventId;
  final List<JsonMap> sourceRefs;

  String get description {
    final source = attachment;
    if (source == null) {
      return 'capture ${capture.id}';
    }
    return '${source.assetKind} attachment ${source.id} on capture ${capture.id}';
  }
}

final class _CandidateRetrievalRequest {
  const _CandidateRetrievalRequest({
    required this.query,
    required this.limit,
    required this.kinds,
    required this.statuses,
    required this.sourceRefs,
    required this.since,
    required this.until,
    required this.includeDeleted,
    required this.includeTombstones,
    required this.includeHighSensitivity,
    required this.permissionMode,
    required this.sensitivityScope,
    required this.privacyProfile,
    required this.includeAttachmentMetadata,
  });

  final String query;
  final int limit;
  final Set<String>? kinds;
  final Set<String>? statuses;
  final List<JsonMap> sourceRefs;
  final DateTime? since;
  final DateTime? until;
  final bool includeDeleted;
  final bool includeTombstones;
  final bool includeHighSensitivity;
  final String permissionMode;
  final String sensitivityScope;
  final String privacyProfile;
  final bool includeAttachmentMetadata;

  JsonMap get filters {
    return <String, Object?>{
      if (kinds != null) 'object_kinds': _sorted(kinds!),
      if (statuses != null) 'statuses': _sorted(statuses!),
      if (sourceRefs.isNotEmpty) 'source_refs': sourceRefs,
      if (since != null) 'since': since!.toIso8601String(),
      if (until != null) 'until': until!.toIso8601String(),
      'include_deleted': includeDeleted,
      'include_tombstones': includeTombstones,
      'include_high_sensitivity': includeHighSensitivity,
      'permission_mode': permissionMode,
      'sensitivity_scope': sensitivityScope,
      'privacy_profile': privacyProfile,
      'include_attachment_metadata': includeAttachmentMetadata,
    };
  }

  bool allowsKind(String kind) {
    return kinds == null || kinds!.contains(kind);
  }

  bool allowsMemory(MemoryItemRecord item) {
    if (!allowsUpdatedAt(item.updatedAt) ||
        !allowsSensitivity(item.sensitivity)) {
      return false;
    }
    if (item.tombstone && !includeTombstones) {
      return false;
    }
    return allowsStatus(
      item.status,
      defaultAllowedStatuses: const <String>{'active'},
    );
  }

  bool allowsCapture(CaptureRecord capture) {
    if (!allowsUpdatedAt(capture.updatedAt)) {
      return false;
    }
    if (!allowsSensitivity(_captureSensitivity(capture))) {
      return false;
    }
    return allowsStatus(
      capture.status,
      defaultBlockedStatuses: _terminalStatuses,
    );
  }

  bool allowsTodo(TodoRecord todo) {
    if (!allowsUpdatedAt(todo.updatedAt)) {
      return false;
    }
    return allowsStatus(
      todo.status,
      defaultBlockedStatuses: const <String>{
        'completed',
        'deleted',
        'tombstoned',
        'archived',
        'inactive',
      },
    );
  }

  bool allowsArtifact(DerivedArtifactRecord artifact) {
    if (!allowsUpdatedAt(artifact.updatedAt)) {
      return false;
    }
    if (!allowsSensitivity(artifact.sensitivity)) {
      return false;
    }
    return allowsStatus(
      artifact.status,
      defaultAllowedStatuses: const <String>{'active', 'ready'},
    );
  }

  bool allowsSimpleStatus(String status, DateTime updatedAt) {
    if (!allowsUpdatedAt(updatedAt)) {
      return false;
    }
    return allowsStatus(
      status,
      defaultAllowedStatuses: const <String>{'active'},
    );
  }

  bool allowsStatus(
    String status, {
    Set<String>? defaultAllowedStatuses,
    Set<String>? defaultBlockedStatuses,
  }) {
    if (statuses != null) {
      return statuses!.contains(status);
    }
    if (includeDeleted) {
      return true;
    }
    if (defaultAllowedStatuses != null) {
      return defaultAllowedStatuses.contains(status);
    }
    return !(defaultBlockedStatuses ?? _terminalStatuses).contains(status);
  }

  bool allowsUpdatedAt(DateTime updatedAt) {
    final value = updatedAt.toUtc();
    if (since != null && value.isBefore(since!)) {
      return false;
    }
    if (until != null && value.isAfter(until!)) {
      return false;
    }
    return true;
  }

  bool allowsSensitivity(String sensitivity) {
    return _schemaSensitivityName(sensitivity) != 'high' ||
        includeHighSensitivity;
  }
}

final class _CandidateSourceFilter {
  _CandidateSourceFilter(List<JsonMap> refs)
    : _keys = refs.expand(_sourceRefIdentityKeys).toSet();

  final Set<String> _keys;

  bool get isEmpty => _keys.isEmpty;

  bool matches(
    String kind,
    String id,
    JsonList linkedRefs, {
    String? sourceCaptureId,
    String? sourceEventId,
    String? sourceAttachmentId,
  }) {
    if (isEmpty || _contains(kind, id)) {
      return true;
    }
    if (sourceCaptureId != null && _contains('capture', sourceCaptureId)) {
      return true;
    }
    if (sourceEventId != null && _contains('event', sourceEventId)) {
      return true;
    }
    if (sourceAttachmentId != null && _contains('file', sourceAttachmentId)) {
      return true;
    }
    return linkedRefs.whereType<Map>().any((ref) {
      final normalized = _safeStoredSourceRef(ref);
      return normalized != null &&
          _sourceRefIdentityKeys(normalized).any(_keys.contains);
    });
  }

  bool _contains(String kind, String id) {
    return _sourceRefIdentityKeys(<String, Object?>{
      'kind': kind,
      'id': id,
    }).any(_keys.contains);
  }
}

final class _LocalCandidate {
  const _LocalCandidate({required this.output, required this.sourceRefs});

  final JsonMap output;
  final List<JsonMap> sourceRefs;

  String get kind => output['kind']! as String;
  String get id => output['id']! as String;

  JsonMap get sourceSummary {
    return <String, Object?>{
      'kind': kind,
      'id': id,
      'title': output['title'],
      'status': output['status'],
      'sensitivity': output['sensitivity'],
      'source_ref': sourceRefs.isEmpty ? null : sourceRefs.first,
      'excerpt': output['snippet'],
    };
  }
}

Iterable<String> _sourceRefIdentityKeys(JsonMap ref) sync* {
  final kind = _normalizedSourceKind(ref['kind'] ?? ref['source_type']);
  final id = ref['id'] ?? ref['source_id'];
  if (kind is! String || id is! String || id.isEmpty) {
    return;
  }
  yield '$kind/$id';
  if (kind == 'file') {
    yield 'attachment/$id';
  } else if (kind == 'artifact') {
    yield 'derived_artifact/$id';
  } else if (kind == 'derived_artifact') {
    yield 'artifact/$id';
  }
}

List<String> _sorted(Set<String> values) {
  return values.toList(growable: false)..sort();
}

const _candidatePermissionModes = <String>{
  'local_only',
  'user_granted',
  'trace_review',
};

const _candidateKindOrder = <String, int>{
  'memory': 0,
  'capture': 1,
  'card': 2,
  'insight': 3,
  'todo': 4,
  'derived_artifact': 5,
};

const _candidateSelectionDimensions = <Object?>[
  'object_kind',
  'recency',
  'time_window',
  'source_refs',
  'explicit_filters',
  'source_link_adjacency',
  'status',
  'tombstone_deletion_state',
  'permission_sensitivity_scope',
];

const _terminalStatuses = <String>{
  'deleted',
  'tombstoned',
  'archived',
  'inactive',
};

JsonMap _runOutput(RuntimeRunRecord run) {
  return <String, Object?>{
    'id': run.id,
    'task_id': run.taskId,
    'pack_id': run.packId,
    'agent_id': run.agentId,
    'handler_id': run.handlerId,
    'status': run.status,
    'run_mode': storedRuntimeRunMode(run.payload, runtimeRunModeKey),
    'attempt': run.attempt,
    'output_event_count': run.outputEventIds.length,
    'error': run.error == null ? null : _redactString(run.error!),
    'started_at': run.startedAt.toUtc().toIso8601String(),
    'completed_at': run.completedAt?.toUtc().toIso8601String(),
  };
}

JsonMap _traceOutput(TraceEventRecord trace) {
  return <String, Object?>{
    'id': trace.id,
    'name': trace.name,
    'level': trace.level,
    'trace_type': trace.traceType,
    'run_id': trace.runId,
    'severity': trace.severity,
    'message': _redactString(trace.message),
    'source_event_id': trace.sourceEventId,
    'source_run_id': trace.sourceRunId,
    'source_task_id': trace.sourceTaskId,
    'pack_id': trace.packId,
    'agent_id': trace.agentId,
    'parent_trace_id': trace.parentTraceId,
    'duration_ms': trace.durationMs,
    'status': trace.status,
    'payload': _redactJsonMap(trace.payload),
    'created_at': trace.createdAt.toUtc().toIso8601String(),
  };
}

void _ensureAllowedKeys(
  String toolName,
  JsonMap input,
  Set<String> allowedKeys,
) {
  final unsupported =
      input.keys
          .where((key) => !allowedKeys.contains(key))
          .toList(growable: false)
        ..sort();
  if (unsupported.isNotEmpty) {
    throw _ToolInputException(
      'unsupported_input',
      '$toolName only accepts its documented safe input fields.',
      details: <String, Object?>{'unsupported_keys': unsupported},
    );
  }
}

String _requiredString(JsonMap input, String field) {
  final value = _optionalString(input[field], field);
  if (value == null) {
    throw _ToolInputException(
      'missing_required_input',
      'Missing required string field: $field.',
      details: <String, Object?>{'field': field},
    );
  }
  return value;
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be a string.',
      details: <String, Object?>{'field': field},
    );
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _optionalInt(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  throw _ToolInputException(
    'invalid_input',
    '$field must be an integer.',
    details: <String, Object?>{'field': field},
  );
}

String? _todoPriority(Object? value) {
  final priority = _optionalString(value, 'priority');
  return switch (priority) {
    'high' => 'high',
    'medium' => 'medium',
    'low' => 'low',
    null => null,
    _ => throw _ToolInputException(
      'invalid_input',
      'priority must be high, medium, or low.',
      details: <String, Object?>{'field': 'priority'},
    ),
  };
}

JsonList _todoSubtasks(Object? value) {
  if (value == null) {
    return const <Object?>[];
  }
  if (value is! List) {
    throw _ToolInputException(
      'invalid_input',
      'subtasks must be an array.',
      details: const <String, Object?>{'field': 'subtasks'},
    );
  }
  final subtasks = <Object?>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final map = _normalizeMap(item);
    final title = _optionalString(map['title'], 'subtasks.title');
    if (title == null) {
      continue;
    }
    subtasks.add(<String, Object?>{
      'id':
          _optionalString(map['id'], 'subtasks.id') ??
          'subtask-${subtasks.length + 1}',
      'title': title,
      'completed': map['completed'] == true,
    });
  }
  return subtasks;
}

bool _optionalBool(Object? value, String field, {required bool defaultValue}) {
  if (value == null) {
    return defaultValue;
  }
  if (value is bool) {
    return value;
  }
  throw _ToolInputException(
    'invalid_input',
    '$field must be a boolean.',
    details: <String, Object?>{'field': field},
  );
}

int _limitInput(
  Object? value, {
  required String field,
  required int defaultValue,
  required int maxValue,
}) {
  if (value == null) {
    return defaultValue;
  }
  if (value is! int) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be an integer.',
      details: <String, Object?>{'field': field},
    );
  }
  if (value < 0) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be non-negative.',
      details: <String, Object?>{'field': field},
    );
  }
  return value > maxValue ? maxValue : value;
}

Duration? _nullableDurationSeconds(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be an integer number of seconds or null.',
      details: <String, Object?>{'field': field},
    );
  }
  if (value < 0) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be non-negative.',
      details: <String, Object?>{'field': field},
    );
  }
  return Duration(seconds: value);
}

List<String> _stringListInput(
  Object? value,
  String field, {
  required List<String> defaultValue,
}) {
  if (value == null) {
    return defaultValue;
  }
  if (value is! List) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be a list of strings.',
      details: <String, Object?>{'field': field},
    );
  }
  final strings = <String>[];
  for (final item in value) {
    if (item is! String) {
      throw _ToolInputException(
        'invalid_input',
        '$field must contain only strings.',
        details: <String, Object?>{'field': field},
      );
    }
    final trimmed = item.trim();
    if (trimmed.isNotEmpty) {
      strings.add(trimmed);
    }
  }
  return List<String>.unmodifiable(strings);
}

JsonMap _objectRefInput(Object? value, String field) {
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is! Map) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be an object ref.',
      details: <String, Object?>{'field': field},
    );
  }
  final normalized = _normalizeMap(value);
  final kind = _optionalString(normalized['kind'], '$field.kind');
  final id = _optionalString(normalized['id'], '$field.id');
  if (kind == null || id == null) {
    return const <String, Object?>{};
  }
  return <String, Object?>{
    'kind': kind,
    'id': id,
    if (_optionalString(normalized['uri'], '$field.uri') != null)
      'uri': _optionalString(normalized['uri'], '$field.uri'),
  };
}

List<JsonMap> _sourceRefsInput(JsonMap input) {
  final refs = <JsonMap>[];
  final rawRefs = input['source_refs'];
  if (rawRefs != null) {
    if (rawRefs is! List) {
      throw _ToolInputException(
        'invalid_input',
        'source_refs must be a list of source refs.',
        details: const <String, Object?>{'field': 'source_refs'},
      );
    }
    for (var index = 0; index < rawRefs.length; index += 1) {
      final ref = _sourceRefInput(rawRefs[index], 'source_refs[$index]');
      if (ref != null) {
        refs.add(ref);
      }
    }
  }
  final sourceEventId = _optionalString(
    input['source_event_id'],
    'source_event_id',
  );
  if (sourceEventId != null) {
    refs.add(<String, Object?>{'kind': 'event', 'id': sourceEventId});
  }
  final sourceCaptureId = _optionalString(
    input['source_capture_id'],
    'source_capture_id',
  );
  if (sourceCaptureId != null) {
    refs.add(<String, Object?>{'kind': 'capture', 'id': sourceCaptureId});
  }
  return _dedupeSourceRefs(refs);
}

JsonMap? _sourceRefInput(Object? value, String field) {
  if (value is! Map) {
    throw _ToolInputException(
      'invalid_input',
      '$field must be a source ref object.',
      details: <String, Object?>{'field': field},
    );
  }
  final normalized = _normalizeMap(value);
  final rawKind =
      _optionalString(normalized['kind'], '$field.kind') ??
      _optionalString(normalized['source_type'], '$field.source_type');
  final kind = rawKind == 'attachment' ? 'file' : rawKind;
  final id =
      _optionalString(normalized['id'], '$field.id') ??
      _optionalString(normalized['source_id'], '$field.source_id');
  if (kind == null || id == null) {
    return null;
  }
  if (!_allowedSourceRefKinds.contains(kind)) {
    throw _ToolInputException(
      'invalid_input',
      '$field has an unsupported source ref kind.',
      details: <String, Object?>{'field': field, 'kind': kind},
    );
  }
  return <String, Object?>{
    'kind': kind,
    'id': id,
    'source_type': kind,
    'source_id': id,
    if (_optionalString(normalized['event_id'], '$field.event_id') != null)
      'event_id': _optionalString(normalized['event_id'], '$field.event_id'),
    if (_optionalString(
          normalized['source_version'],
          '$field.source_version',
        ) !=
        null)
      'source_version': _optionalString(
        normalized['source_version'],
        '$field.source_version',
      ),
    if (_optionalString(normalized['content_hash'], '$field.content_hash') !=
        null)
      'content_hash': _optionalString(
        normalized['content_hash'],
        '$field.content_hash',
      ),
    if (_optionalString(normalized['excerpt'], '$field.excerpt') != null)
      'excerpt': _optionalString(normalized['excerpt'], '$field.excerpt'),
    if (_optionalString(normalized['evidence_text'], '$field.evidence_text') !=
        null)
      'evidence_text': _optionalString(
        normalized['evidence_text'],
        '$field.evidence_text',
      ),
    if (_optionalString(normalized['uri'], '$field.uri') != null)
      'uri': _optionalString(normalized['uri'], '$field.uri'),
    if (_optionalSensitivityName(
          normalized['sensitivity'],
          '$field.sensitivity',
        ) !=
        null)
      'sensitivity': _optionalSensitivityName(
        normalized['sensitivity'],
        '$field.sensitivity',
      ),
  };
}

memory.MemorySourceRef _memorySourceRef(JsonMap ref) {
  final uri = _optionalString(ref['uri'], 'source_ref.uri');
  return memory.MemorySourceRef(
    sourceType: ref['kind']! as String,
    sourceId: ref['id']! as String,
    excerpt:
        _optionalString(ref['excerpt'], 'source_ref.excerpt') ??
        _optionalString(ref['evidence_text'], 'source_ref.evidence_text'),
    uri: uri == null ? null : Uri.tryParse(uri),
  );
}

JsonMap _sourceRefOutput(memory.MemorySourceRef ref) {
  return <String, Object?>{
    'kind': ref.sourceType,
    'id': ref.sourceId,
    'source_type': ref.sourceType,
    'source_id': ref.sourceId,
    if (ref.excerpt != null) 'excerpt': ref.excerpt,
    if (ref.uri != null) 'uri': ref.uri.toString(),
  };
}

List<JsonMap> _sourceRefsFromRecord(
  JsonList refs, {
  String? sourceEventId,
  String? sourceCaptureId,
}) {
  final normalized = <JsonMap>[];
  for (final ref in refs) {
    if (ref is Map) {
      final sourceRef = _storedSourceRef(ref);
      if (sourceRef != null) {
        normalized.add(sourceRef);
      }
    }
  }
  if (sourceEventId != null) {
    normalized.add(<String, Object?>{
      'kind': 'event',
      'id': sourceEventId,
      'source_type': 'event',
      'source_id': sourceEventId,
    });
  }
  if (sourceCaptureId != null) {
    normalized.add(<String, Object?>{
      'kind': 'capture',
      'id': sourceCaptureId,
      'source_type': 'capture',
      'source_id': sourceCaptureId,
    });
  }
  return _dedupeSourceRefs(normalized);
}

JsonMap? _storedSourceRef(Map<dynamic, dynamic> value) {
  final normalized = _normalizeMap(value);
  final kind = normalized['kind'] ?? normalized['source_type'];
  final id = normalized['id'] ?? normalized['source_id'];
  if (kind is! String || id is! String || kind.isEmpty || id.isEmpty) {
    return null;
  }
  return <String, Object?>{
    'kind': kind,
    'id': id,
    'source_type': kind,
    'source_id': id,
    if (normalized['event_id'] is String) 'event_id': normalized['event_id'],
    if (normalized['source_version'] != null)
      'source_version': normalized['source_version'],
    if (normalized['content_hash'] is String)
      'content_hash': normalized['content_hash'],
    if (normalized['excerpt'] is String) 'excerpt': normalized['excerpt'],
    if (normalized['evidence_text'] is String)
      'evidence_text': normalized['evidence_text'],
    if (normalized['uri'] is String) 'uri': normalized['uri'],
    if (normalized['sensitivity'] is String)
      'sensitivity': normalized['sensitivity'],
  };
}

bool _hasSourceRef(JsonList refs, String kind, String id) {
  return refs.whereType<Map>().any((ref) {
    final normalized = _storedSourceRef(ref);
    return normalized != null &&
        normalized['kind'] == kind &&
        normalized['id'] == id;
  });
}

String? _firstSourceId(List<JsonMap> refs, String kind) {
  for (final ref in refs) {
    if (ref['kind'] == kind && ref['id'] is String) {
      return ref['id']! as String;
    }
  }
  return null;
}

String? _optionalMemoryTypeName(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return _memoryTypeName(_memoryType(value, field: field));
}

memory.MemoryType _memoryType(Object? value, {String field = 'memory_type'}) {
  final normalized =
      _optionalString(value, field)?.replaceAll('-', '_') ?? 'project';
  return switch (normalized) {
    'preference' => memory.MemoryType.preference,
    'project' => memory.MemoryType.project,
    'task_context' || 'taskContext' => memory.MemoryType.taskContext,
    'person' => memory.MemoryType.person,
    'health' => memory.MemoryType.health,
    'finance' => memory.MemoryType.finance,
    'location' => memory.MemoryType.location,
    'credential' => memory.MemoryType.credential,
    'insight' => memory.MemoryType.insight,
    _ => throw _ToolInputException(
      'invalid_input',
      '$field has an unsupported Memory type.',
      details: <String, Object?>{'field': field},
    ),
  };
}

String _memoryTypeName(memory.MemoryType value) {
  return switch (value) {
    memory.MemoryType.taskContext => 'task_context',
    _ => value.name,
  };
}

memory.MemoryConfidence _confidence(Object? value) {
  final normalized = _optionalString(value, 'confidence') ?? 'medium';
  return switch (normalized) {
    'low' => memory.MemoryConfidence.low,
    'medium' => memory.MemoryConfidence.medium,
    'high' => memory.MemoryConfidence.high,
    _ => throw _ToolInputException(
      'invalid_input',
      'confidence must be low, medium, or high.',
      details: const <String, Object?>{'field': 'confidence'},
    ),
  };
}

String? _optionalConfidenceName(Object? value, String field) {
  if (value == null) {
    return null;
  }
  final normalized = _optionalString(value, field);
  return switch (normalized) {
    'low' || 'medium' || 'high' => normalized,
    _ => throw _ToolInputException(
      'invalid_input',
      '$field must be low, medium, or high.',
      details: <String, Object?>{'field': field},
    ),
  };
}

String? _optionalSensitivityName(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return _sensitivity(value, field: field).name;
}

memory.MemorySensitivity _sensitivity(
  Object? value, {
  String field = 'sensitivity',
}) {
  final normalized = _optionalString(value, field) ?? 'low';
  return switch (normalized) {
    'low' => memory.MemorySensitivity.low,
    'medium' => memory.MemorySensitivity.medium,
    'high' => memory.MemorySensitivity.high,
    _ => throw _ToolInputException(
      'invalid_input',
      '$field must be low, medium, or high.',
      details: <String, Object?>{'field': field},
    ),
  };
}

memory.MemoryDurability _durability(Object? value) {
  final normalized = _optionalString(value, 'durability') ?? 'durable';
  return switch (normalized) {
    'durable' => memory.MemoryDurability.durable,
    'transient' => memory.MemoryDurability.transient,
    _ => throw _ToolInputException(
      'invalid_input',
      'durability must be durable or transient.',
      details: const <String, Object?>{'field': 'durability'},
    ),
  };
}

String _proposalStatusName(memory.MemoryProposalStatus value) {
  return switch (value) {
    memory.MemoryProposalStatus.autoAccepted => 'auto_accepted',
    memory.MemoryProposalStatus.needsReview => 'needs_review',
    _ => value.name,
  };
}

JsonMap _redactJsonMap(JsonMap value) {
  return _redactJson(value) as JsonMap;
}

Object? _redactJson(Object? value, {String? key}) {
  if (key != null && _isRawMediaKey(key)) {
    return '[redacted:raw_media]';
  }
  if (key != null && _isPathKey(key)) {
    return value == null ? null : _redactedLocalPath;
  }
  if (key != null && _isSecretKey(key)) {
    return '[redacted]';
  }
  if (value is String) {
    return _redactString(value);
  }
  if (value is Map) {
    final redacted = <String, Object?>{};
    for (final entry in value.entries) {
      final entryKey = entry.key.toString();
      redacted[entryKey] = _redactJson(entry.value, key: entryKey);
    }
    return redacted;
  }
  if (value is Iterable) {
    return value.map(_redactJson).toList(growable: false);
  }
  return value;
}

bool _isSecretKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return normalized.contains('api_key') ||
      normalized.contains('access_token') ||
      normalized.contains('refresh_token') ||
      normalized.contains('auth_token') ||
      normalized.contains('client_secret') ||
      normalized.contains('private_key') ||
      normalized.contains('credential') ||
      normalized == 'token' ||
      normalized == 'secret' ||
      normalized == 'password' ||
      normalized == 'authorization';
}

bool _isPathKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return normalized == 'storage_path' ||
      normalized == 'absolute_path' ||
      normalized == 'raw_path' ||
      normalized == 'file_path' ||
      normalized == 'local_path';
}

bool _isRawMediaKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return normalized == 'raw_media' ||
      normalized == 'media_bytes' ||
      normalized == 'raw_bytes' ||
      normalized == 'audio_bytes' ||
      normalized == 'image_bytes';
}

String _redactString(String value) {
  var redacted = value.replaceAllMapped(
    RegExp(r'sk-[A-Za-z0-9_-]{6,}'),
    (_) => 'sk-[redacted]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'(bearer\s+)[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    (match) => '${match.group(1)}[redacted]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(
      r'((api[_-]?key|token|secret|password|authorization)\s*[:=]\s*)([^\s,;]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[redacted]',
  );
  redacted = redacted.replaceAll(
    RegExp(r'file://[^\s,;)]+', caseSensitive: false),
    _redactedLocalPath,
  );
  redacted = redacted.replaceAll(
    RegExp(r'(/Users|/private|/var|/tmp|/Volumes)/[^\s,;)]+'),
    _redactedLocalPath,
  );
  redacted = redacted.replaceAll(
    RegExp(r'[A-Za-z]:\\[^\s,;)]+'),
    _redactedLocalPath,
  );
  return redacted;
}

String? _safeFileName(String path) {
  final normalized = path.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) {
    return null;
  }
  final segments = normalized.split('/').where((part) => part.isNotEmpty);
  final name = segments.isEmpty ? normalized : segments.last;
  return _redactString(name);
}

String? _excerpt(Object? value) {
  if (value is! String) {
    return null;
  }
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) {
    return null;
  }
  return text.length <= 240 ? text : '${text.substring(0, 237)}...';
}

List<JsonMap> _mapList(Object? value) {
  return _listValue(
    value,
  ).whereType<Map>().map(_normalizeMap).toList(growable: false);
}

JsonList _listValue(Object? value) {
  if (value is List) {
    return value;
  }
  return const <Object?>[];
}

List<JsonMap> _dedupeSourceRefs(Iterable<JsonMap> refs) {
  final byIdentity = <String, JsonMap>{};
  for (final ref in refs) {
    final kind = ref['kind'];
    final id = ref['id'];
    if (kind is! String || id is! String) {
      continue;
    }
    byIdentity['$kind/$id'] = ref;
  }
  final result = byIdentity.values.toList(growable: false)
    ..sort(
      (a, b) => '${a['kind']}/${a['id']}'.compareTo('${b['kind']}/${b['id']}'),
    );
  return List<JsonMap>.unmodifiable(result);
}

JsonMap _normalizeMap(Map<dynamic, dynamic> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) {
      result[key] = entry.value;
    }
  }
  return result;
}

String _safeId(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  if (sanitized.isEmpty) {
    return 'unknown';
  }
  return sanitized.length <= 96 ? sanitized : sanitized.substring(0, 96);
}

const _allowedSourceRefKinds = <String>{
  'event',
  'record',
  'capture',
  'memory',
  'card',
  'insight',
  'artifact',
  'recap',
  'todo',
  'conversation',
  'message',
  'file',
  'uri',
  'manual',
};

const _redactedLocalPath = '[redacted:local_path]';

final class _ToolInputException implements Exception {
  const _ToolInputException(this.code, this.message, {this.details = const {}});

  final String code;
  final String message;
  final JsonMap details;
}
