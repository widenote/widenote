import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_memory/memory.dart' as memory;

import 'context_packet_builder.dart';
import 'database.dart';
import 'json.dart';
import 'memory_repository_adapter.dart';
import 'models.dart';

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
                  .readAll(status: 'active')
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
        'source_refs',
        'include_attachment_metadata',
      });
      final query = _requiredString(input, 'query');
      final limit = _limitInput(
        input['limit'],
        field: 'limit',
        defaultValue: 12,
        maxValue: 50,
      );
      final includeAttachmentMetadata = _optionalBool(
        input['include_attachment_metadata'],
        'include_attachment_metadata',
        defaultValue: true,
      );
      final result = _contextPacketBuilder.build(
        ContextPacketBuildRequest(
          surface: 'chat',
          intent: query,
          sourceRefs: _sourceRefsInput(input),
          cacheKey: 'semantic_search:${_safeId(query)}:$limit',
          maxItems: limit,
          permissionMode: 'local_only',
          permissions: const <String>[
            timelineReadTool,
            knowledgeReadTool,
            memoryReadTool,
            'record.read',
            'card.read',
            'insight.read',
            'todo.read',
            'artifact.read',
          ],
          redactionPolicy: 'redact_sensitive',
          disclosureLevel: 'targeted_excerpt',
          privacyProfile: 'chat_local',
          includeAttachmentMetadata: includeAttachmentMetadata,
          allowAttachmentExpansion: false,
        ),
      );
      return _success(semanticSearchQueryTool, <String, Object?>{
        'query': query,
        'packet_summary': _packetSummary(result),
        'sources': _packetSourceSummaries(result.packet),
        'source_refs': result.packet['source_refs'] ?? const <Object?>[],
        'selection_strategy': 'context_packet_model_ready',
        'reused_cache': result.reusedCache,
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
      final record = TodoRecord(
        id: _optionalString(input['id'], 'id') ?? _nextId('todo_suggestion'),
        sourceEventId: _firstSourceId(refs, 'event'),
        sourceCaptureId: _firstSourceId(refs, 'capture'),
        status: 'suggested',
        payload: <String, Object?>{
          'title': _requiredString(input, 'title'),
          if (_optionalString(input['body'], 'body') != null)
            'body': _optionalString(input['body'], 'body'),
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
    'storage_path': _redactString(attachment.storagePath),
    'original_file_name': attachment.originalFileName == null
        ? null
        : _redactString(attachment.originalFileName!),
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
    'storage_path': artifact.storagePath == null
        ? null
        : _redactString(artifact.storagePath!),
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
  return todo.status != 'completed' && todo.status != 'deleted';
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

List<JsonMap> _packetSourceSummaries(JsonMap packet) {
  final summaries = <JsonMap>[];
  final sections = _mapList(packet['sections']);
  for (final section in sections) {
    final citations = _mapList(section['citations']);
    for (final citation in citations) {
      final sourceRef = citation['source_ref'];
      if (sourceRef is! Map) {
        continue;
      }
      final normalizedRef = _storedSourceRef(sourceRef);
      if (normalizedRef == null) {
        continue;
      }
      summaries.add(<String, Object?>{
        'section_kind': section['kind'],
        'title': section['title'],
        'source_ref': normalizedRef,
        'excerpt': citation['excerpt'] ?? _excerpt(section['content']),
      });
    }
  }
  return summaries.take(20).toList(growable: false);
}

JsonMap _runOutput(RuntimeRunRecord run) {
  return <String, Object?>{
    'id': run.id,
    'task_id': run.taskId,
    'pack_id': run.packId,
    'agent_id': run.agentId,
    'handler_id': run.handlerId,
    'status': run.status,
    'run_mode': _storedRunMode(run.payload),
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

String _storedRunMode(JsonMap payload) {
  final value = payload['runtime_run_mode'];
  return value is String && value.isNotEmpty ? value : 'auto';
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
  final kind =
      _optionalString(normalized['kind'], '$field.kind') ??
      _optionalString(normalized['source_type'], '$field.source_type');
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
  return redacted;
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

final class _ToolInputException implements Exception {
  const _ToolInputException(this.code, this.message, {this.details = const {}});

  final String code;
  final String message;
  final JsonMap details;
}
