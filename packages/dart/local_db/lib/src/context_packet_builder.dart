import 'dart:convert';

import 'database.dart';
import 'json.dart';
import 'models.dart';

typedef ContextPacketClock = DateTime Function();

final class ContextPacketBuildRequest {
  const ContextPacketBuildRequest({
    required this.surface,
    this.intent,
    this.requestRef = const <String, Object?>{},
    this.subjectRef = const <String, Object?>{},
    this.sourceRefs = const <JsonMap>[],
    this.cacheKey,
    this.maxItems = 12,
    this.cacheable = true,
    this.ttl = const Duration(minutes: 15),
    this.permissionMode = 'local_only',
    this.permissions = const <String>[],
    this.grantSnapshotId,
    this.redactionPolicy = 'redact_sensitive',
    this.disclosureLevel = 'targeted_excerpt',
    this.generatorId = ContextPacketBuilder.defaultGeneratorId,
    this.generatorVersion = ContextPacketBuilder.defaultGeneratorVersion,
    this.promptVersion = ContextPacketBuilder.defaultPromptVersion,
    this.packId,
    this.packVersion,
    this.agentId,
    this.localDate,
    this.privacyProfile = 'default',
    this.includeAttachmentMetadata = false,
    this.allowAttachmentExpansion = false,
  });

  final String surface;
  final String? intent;
  final JsonMap requestRef;
  final JsonMap subjectRef;
  final List<JsonMap> sourceRefs;
  final String? cacheKey;
  final int maxItems;
  final bool cacheable;
  final Duration? ttl;
  final String permissionMode;
  final List<String> permissions;
  final String? grantSnapshotId;
  final String redactionPolicy;
  final String disclosureLevel;
  final String generatorId;
  final String generatorVersion;
  final String promptVersion;
  final String? packId;
  final String? packVersion;
  final String? agentId;
  final String? localDate;
  final String privacyProfile;
  final bool includeAttachmentMetadata;
  final bool allowAttachmentExpansion;

  void validate() {
    if (!_allowedSurfaces.contains(surface)) {
      throw ArgumentError.value(surface, 'surface', 'Unsupported surface.');
    }
    if (!_allowedDisclosureLevels.contains(disclosureLevel)) {
      throw ArgumentError.value(
        disclosureLevel,
        'disclosureLevel',
        'Unsupported disclosure level.',
      );
    }
    if (!_allowedPermissionModes.contains(permissionMode)) {
      throw ArgumentError.value(
        permissionMode,
        'permissionMode',
        'Unsupported permission mode.',
      );
    }
    if (!_allowedRedactionPolicies.contains(redactionPolicy)) {
      throw ArgumentError.value(
        redactionPolicy,
        'redactionPolicy',
        'Unsupported redaction policy.',
      );
    }
    if (maxItems < 0) {
      throw RangeError.value(maxItems, 'maxItems', 'must be non-negative');
    }
  }
}

final class ContextPacketBuildResult {
  const ContextPacketBuildResult({
    required this.packet,
    required this.cacheKey,
    required this.reusedCache,
    required this.cacheable,
    required this.sourceBackedSectionCount,
    this.cacheRecord,
  });

  final JsonMap packet;
  final String cacheKey;
  final bool reusedCache;
  final bool cacheable;
  final int sourceBackedSectionCount;
  final ContextPacketCacheRecord? cacheRecord;
}

final class ContextPacketBuilder {
  ContextPacketBuilder(this._database, {ContextPacketClock? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  static const defaultGeneratorId = 'context.packet.builder.local_db';
  static const defaultGeneratorVersion = '1';
  static const defaultPromptVersion = 'prompt-v1';

  final WideNoteLocalDatabase _database;
  final ContextPacketClock _clock;

  ContextPacketBuildResult build(ContextPacketBuildRequest request) {
    request.validate();
    final now = _clock().toUtc();
    final permissionGrantVersions = _permissionGrantVersions(request);
    final selection = _selectSources(request);
    final visibleSection = _visibleSection(request);
    final sourceRefs = _dedupeSourceRefs(<JsonMap>[
      if (visibleSection != null) ...visibleSection.sourceRefs,
      ...selection.sourceRefs,
    ]);
    final sourceVersions = _dedupeJsonMaps(<JsonMap>[
      if (visibleSection != null) ...visibleSection.sourceVersions,
      ...selection.sourceVersions,
    ]);
    final invalidationKeys = _invalidationKeys(
      request,
      sourceVersions,
      permissionGrantVersions,
    );
    final keyMaterial = <String, Object?>{
      'builder': 'local_db_context_packet',
      'builder_schema': 1,
      'cache_key_seed': request.cacheKey,
      'surface': request.surface,
      'intent_hash': _nullableHash(_normalizedIntent(request.intent)),
      'request_ref': _objectRefOrNull(request.requestRef),
      'subject_ref': _objectRefOrNull(request.subjectRef),
      'requested_source_refs': _dedupeSourceRefs(
        request.sourceRefs.map(_sanitizeSourceRef).whereType<JsonMap>(),
      ),
      'max_items': request.maxItems,
      'cacheable': request.cacheable,
      'ttl_seconds': request.ttl?.inSeconds,
      'permission': _permissionScope(request, permissionGrantVersions),
      'permission_grants': permissionGrantVersions,
      'disclosure_level': request.disclosureLevel,
      'generator_id': request.generatorId,
      'generator_version': request.generatorVersion,
      'prompt_version': request.promptVersion,
      'pack_id': request.packId,
      'pack_version': request.packVersion,
      'agent_id': request.agentId,
      'local_date': _effectiveLocalDate(request, now),
      'privacy_profile': request.privacyProfile,
      'include_attachment_metadata': request.includeAttachmentMetadata,
      'allow_attachment_expansion': request.allowAttachmentExpansion,
      'source_versions': sourceVersions,
    };
    final cacheKey = _cacheKeyFor(keyMaterial);
    final existingCache = _database.contextPacketCaches.readByCacheKey(
      cacheKey,
    );
    if (existingCache != null && existingCache.isReusableAt(now)) {
      return ContextPacketBuildResult(
        packet: existingCache.packet,
        cacheKey: cacheKey,
        reusedCache: true,
        cacheable: true,
        sourceBackedSectionCount: _sourceBackedSectionCount(
          existingCache.packet,
        ),
        cacheRecord: existingCache,
      );
    }

    final expiresAt = request.ttl == null ? null : now.add(request.ttl!);
    final sections = <JsonMap>[
      if (visibleSection != null) visibleSection.section,
      ...selection.sections,
    ];
    if (sections.isEmpty) {
      sections.add(_emptySection());
    }
    final packet = <String, Object?>{
      'id': 'ctx_${_stableHash(cacheKey)}',
      'schema_version': 1,
      'surface': request.surface,
      'request_ref': _objectRefOrNull(request.requestRef),
      'subject_ref': _objectRefOrNull(request.subjectRef),
      'source_refs': sourceRefs,
      'permission_scope': _permissionScope(request, permissionGrantVersions),
      'disclosure_level': request.disclosureLevel,
      'generator_id': request.generatorId,
      'generator_version': request.generatorVersion,
      'pack_id': request.packId,
      'agent_id': request.agentId,
      'cache_policy': <String, Object?>{
        'cacheable':
            request.cacheable && selection.sourceBackedSectionCount > 0,
        'ttl_seconds': request.ttl?.inSeconds,
        'invalidation_keys': invalidationKeys,
      },
      'created_at': now.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'sections': sections,
      'metadata': <String, Object?>{
        'intent_hash': _nullableHash(_normalizedIntent(request.intent)),
        'max_items': request.maxItems,
        'source_backed_section_count': selection.sourceBackedSectionCount,
        'privacy_profile': request.privacyProfile,
        'local_date': _effectiveLocalDate(request, now),
        'prompt_version': request.promptVersion,
        'pack_version': request.packVersion,
        'non_goals': const <Object?>[
          'no_chat_agent_execution',
          'no_raw_attachment_file_expansion',
          'no_canonical_source_mutation',
        ],
      },
    };

    final shouldCache =
        request.cacheable && selection.sourceBackedSectionCount > 0;
    ContextPacketCacheRecord? cacheRecord;
    if (shouldCache) {
      cacheRecord = ContextPacketCacheRecord(
        id: existingCache?.id ?? 'cache_${_stableHash(cacheKey)}',
        surface: request.surface,
        requestRef: _objectRefOrEmpty(request.requestRef),
        subjectRef: _objectRefOrEmpty(request.subjectRef),
        sourceRefs: sourceRefs,
        sourceVersions: sourceVersions,
        permissionScope: _permissionScopeKey(request, permissionGrantVersions),
        disclosureLevel: request.disclosureLevel,
        generatorId: request.generatorId,
        generatorVersion: request.generatorVersion,
        promptVersion: request.promptVersion,
        packId: request.packId,
        packVersion: request.packVersion,
        agentId: request.agentId,
        localDate: _effectiveLocalDate(request, now),
        privacyProfile: request.privacyProfile,
        invalidationKeys: invalidationKeys,
        cacheKey: cacheKey,
        status: 'active',
        packet: packet,
        expiresAt: expiresAt,
        invalidatedAt: null,
        createdAt: existingCache?.createdAt ?? now,
        updatedAt: now,
      );
      _database.contextPacketCaches.save(cacheRecord);
    }

    return ContextPacketBuildResult(
      packet: packet,
      cacheKey: cacheKey,
      reusedCache: false,
      cacheable: shouldCache,
      sourceBackedSectionCount: selection.sourceBackedSectionCount,
      cacheRecord: cacheRecord,
    );
  }

  _SourceSelection _selectSources(ContextPacketBuildRequest request) {
    final filter = _SourceFilter(request.sourceRefs);
    final budget = _SectionBudget(request.maxItems);
    final sections = <JsonMap>[];
    final sourceRefs = <JsonMap>[];
    final sourceVersions = <JsonMap>[];
    var sourceBackedSectionCount = 0;

    void add(_SectionBuildResult result) {
      if (!budget.take()) {
        return;
      }
      sections.add(result.section);
      sourceRefs.addAll(result.sourceRefs);
      sourceVersions.addAll(result.sourceVersions);
      sourceBackedSectionCount++;
    }

    if (_disclosureAllows(request.disclosureLevel, 'accepted_memory')) {
      final memories =
          _database.memoryItems
              .readAll(status: 'active')
              .where((item) => !item.tombstone)
              .where(
                (item) => filter.matches('memory', item.id, item.sourceRefs),
              )
              .toList(growable: false)
            ..sort(_compareUpdatedDesc);
      for (final memory in memories) {
        if (!budget.hasRoom) {
          break;
        }
        final result = _memorySection(memory, request);
        if (result != null) {
          add(result);
        }
      }
    }

    if (_disclosureAllows(request.disclosureLevel, 'derived_summary')) {
      final derived = <_DerivedSource>[
        ..._database.cards
            .readAll(status: 'active')
            .where((card) => filter.matches('card', card.id, card.sourceRefs))
            .map(_DerivedSource.card),
        ..._database.insights
            .readAll(status: 'active')
            .where(
              (insight) =>
                  filter.matches('insight', insight.id, insight.sourceRefs),
            )
            .map(_DerivedSource.insight),
        ..._database.todos
            .readAll()
            .where(_isLiveTodo)
            .where((todo) => filter.matches('todo', todo.id, _todoRefs(todo)))
            .map(_DerivedSource.todo),
        ..._database.derivedArtifacts
            .readAll(status: 'active')
            .where(
              (artifact) =>
                  filter.matches('artifact', artifact.id, artifact.sourceRefs),
            )
            .map(_DerivedSource.artifact),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      for (final source in derived) {
        if (!budget.hasRoom) {
          break;
        }
        final result = switch (source.kind) {
          _DerivedKind.card => _cardSection(source.card!, request),
          _DerivedKind.insight => _insightSection(source.insight!, request),
          _DerivedKind.todo => _todoSection(source.todo!, request),
          _DerivedKind.artifact => _artifactSection(source.artifact!, request),
        };
        if (result != null) {
          add(result);
        }
      }
    }

    if (_disclosureAllows(request.disclosureLevel, 'targeted_excerpt')) {
      final captures =
          _database.captures
              .readAll()
              .where(_isLiveCapture)
              .where(
                (capture) => filter.matches(
                  'capture',
                  capture.id,
                  _captureRefs(capture),
                ),
              )
              .toList(growable: false)
            ..sort(_compareUpdatedDesc);
      for (final capture in captures) {
        if (!budget.hasRoom) {
          break;
        }
        final result = _captureSection(capture, request);
        if (result != null) {
          add(result);
        }
      }
    }

    if (request.includeAttachmentMetadata &&
        _disclosureAllows(request.disclosureLevel, 'attachment_expansion')) {
      final captureIds = sourceRefs
          .where((ref) => ref['kind'] == 'capture')
          .map((ref) => ref['id'])
          .whereType<String>()
          .toSet();
      final attachments = <AttachmentRecord>[];
      for (final captureId in captureIds) {
        attachments.addAll(
          _database.attachments.readByCapture(captureId, status: 'available'),
        );
      }
      attachments.sort(_compareUpdatedDesc);
      for (final attachment in attachments) {
        if (!budget.hasRoom) {
          break;
        }
        final result = _attachmentSection(attachment, request);
        if (result != null) {
          add(result);
        }
      }
    }

    return _SourceSelection(
      sections: sections,
      sourceRefs: _dedupeSourceRefs(sourceRefs),
      sourceVersions: _dedupeJsonMaps(sourceVersions),
      sourceBackedSectionCount: sourceBackedSectionCount,
    );
  }

  _SectionBuildResult? _visibleSection(ContextPacketBuildRequest request) {
    final normalizedIntent = _normalizedIntent(request.intent);
    if (normalizedIntent == null &&
        request.requestRef.isEmpty &&
        request.subjectRef.isEmpty) {
      return null;
    }
    final content = <String>[
      if (normalizedIntent != null) 'intent: $normalizedIntent',
      if (request.requestRef.isNotEmpty)
        'request: ${_objectRefLabel(request.requestRef)}',
      if (request.subjectRef.isNotEmpty)
        'subject: ${_objectRefLabel(request.subjectRef)}',
    ].join('\n');
    final manualId = 'visible_${_stableHash(content)}';
    final sourceRef = _sourceRef(
      'manual',
      manualId,
      sourceVersion: _stableHash(content),
      contentHash: _stableHash(content),
      sensitivity: 'low',
    );
    final section = <String, Object?>{
      'id': 'section_visible_context',
      'kind': 'visible_context',
      'title': 'Visible context',
      'content': content,
      'citations': <Object?>[
        <String, Object?>{
          'source_ref': sourceRef,
          'evidence_hash': _stableHash(content),
          'excerpt': _excerpt(content),
        },
      ],
      'redactions': const <Object?>[],
      'sensitivity': 'low',
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: <JsonMap>[sourceRef],
      sourceVersions: <JsonMap>[
        <String, Object?>{
          'kind': 'manual',
          'id': manualId,
          'source_version': _stableHash(content),
          'content_hash': _stableHash(content),
        },
      ],
    );
  }

  _SectionBuildResult? _memorySection(
    MemoryItemRecord memory,
    ContextPacketBuildRequest request,
  ) {
    final ownSourceRef = _memorySourceRef(memory);
    final ownVersion = _memorySourceVersion(memory);
    final linkedVersions = _linkedSourceVersions(memory.sourceRefs);
    final linkedRefs = linkedVersions.map(_sourceRefFromVersion);
    if (_shouldRedactSensitivity(memory.sensitivity, request)) {
      return _redactedSection(
        sectionId: 'section_memory_${_safeId(memory.id)}',
        title: 'Memory redacted',
        sourceRef: ownSourceRef,
        sourceVersions: <JsonMap>[ownVersion, ...linkedVersions],
        reason: 'sensitivity_${memory.sensitivity}',
        content:
            'High-sensitivity Memory is redacted by the current context policy.',
        sensitivity: 'high',
        extraSourceRefs: linkedRefs,
      );
    }
    final body = _truncate(memory.body, _memoryExcerptLimit);
    if (body.trim().isEmpty) {
      return null;
    }
    final content = _lines(<String>[
      'Memory (${memory.memoryType}, confidence: ${memory.confidence}, sensitivity: ${memory.sensitivity})',
      body,
    ]);
    final section = <String, Object?>{
      'id': 'section_memory_${_safeId(memory.id)}',
      'kind': 'memory',
      'title': memory.key,
      'content': content,
      'citations': <Object?>[
        <String, Object?>{
          'source_ref': ownSourceRef,
          'evidence_hash': _stableHash(body),
          'excerpt': _excerpt(body),
        },
      ],
      'redactions': const <Object?>[],
      'sensitivity': _schemaSensitivity(memory.sensitivity),
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: _dedupeSourceRefs(<JsonMap>[ownSourceRef, ...linkedRefs]),
      sourceVersions: _dedupeJsonMaps(<JsonMap>[ownVersion, ...linkedVersions]),
    );
  }

  _SectionBuildResult? _cardSection(
    CardRecord card,
    ContextPacketBuildRequest request,
  ) {
    final body = _truncate(
      _lines(<String>[card.title, card.body]),
      _derivedExcerptLimit,
    );
    if (body.trim().isEmpty) {
      return null;
    }
    final ownSourceRef = _cardSourceRef(card);
    final ownVersion = _cardSourceVersion(card);
    final linkedVersions = _linkedSourceVersions(card.sourceRefs);
    final section = <String, Object?>{
      'id': 'section_card_${_safeId(card.id)}',
      'kind': 'derived_summary',
      'title': card.title,
      'content': _lines(<String>['Card (${card.cardKind})', body]),
      'citations': <Object?>[
        <String, Object?>{
          'source_ref': ownSourceRef,
          'evidence_hash': _stableHash(body),
          'excerpt': _excerpt(body),
        },
      ],
      'redactions': const <Object?>[],
      'sensitivity': 'low',
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: _dedupeSourceRefs(<JsonMap>[
        ownSourceRef,
        ...linkedVersions.map(_sourceRefFromVersion),
      ]),
      sourceVersions: _dedupeJsonMaps(<JsonMap>[ownVersion, ...linkedVersions]),
    );
  }

  _SectionBuildResult? _insightSection(
    InsightRecord insight,
    ContextPacketBuildRequest request,
  ) {
    final metric = insight.metricLabel == null
        ? null
        : 'Metric: ${insight.metricValue ?? ''} ${insight.metricLabel}';
    final body = _truncate(
      _lines(<String>[insight.title, insight.summary, ?metric]),
      _derivedExcerptLimit,
    );
    if (body.trim().isEmpty) {
      return null;
    }
    final ownSourceRef = _insightSourceRef(insight);
    final ownVersion = _insightSourceVersion(insight);
    final linkedVersions = _linkedSourceVersions(insight.sourceRefs);
    final section = <String, Object?>{
      'id': 'section_insight_${_safeId(insight.id)}',
      'kind': 'derived_summary',
      'title': insight.title,
      'content': _lines(<String>['Insight (${insight.insightKind})', body]),
      'citations': <Object?>[
        <String, Object?>{
          'source_ref': ownSourceRef,
          'evidence_hash': _stableHash(body),
          'excerpt': _excerpt(body),
        },
      ],
      'redactions': const <Object?>[],
      'sensitivity': 'low',
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: _dedupeSourceRefs(<JsonMap>[
        ownSourceRef,
        ...linkedVersions.map(_sourceRefFromVersion),
      ]),
      sourceVersions: _dedupeJsonMaps(<JsonMap>[ownVersion, ...linkedVersions]),
    );
  }

  _SectionBuildResult? _todoSection(
    TodoRecord todo,
    ContextPacketBuildRequest request,
  ) {
    final title = _firstText(todo.payload, const <String>['title', 'text']);
    final body = _firstText(todo.payload, const <String>['body', 'summary']);
    final content = _truncate(
      _lines(<String>['Todo (${todo.status})', title, if (body != title) body]),
      _derivedExcerptLimit,
    );
    if (content.trim().isEmpty || content == 'Todo (${todo.status})') {
      return null;
    }
    final ownSourceRef = _todoSourceRef(todo);
    final ownVersion = _todoSourceVersion(todo);
    final linkedVersions = _linkedSourceVersions(_todoRefs(todo));
    final section = <String, Object?>{
      'id': 'section_todo_${_safeId(todo.id)}',
      'kind': 'derived_summary',
      'title': title.isEmpty ? todo.id : title,
      'content': content,
      'citations': <Object?>[
        <String, Object?>{
          'source_ref': ownSourceRef,
          'evidence_hash': _stableHash(content),
          'excerpt': _excerpt(content),
        },
      ],
      'redactions': const <Object?>[],
      'sensitivity': 'low',
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: _dedupeSourceRefs(<JsonMap>[
        ownSourceRef,
        ...linkedVersions.map(_sourceRefFromVersion),
      ]),
      sourceVersions: _dedupeJsonMaps(<JsonMap>[ownVersion, ...linkedVersions]),
    );
  }

  _SectionBuildResult? _artifactSection(
    DerivedArtifactRecord artifact,
    ContextPacketBuildRequest request,
  ) {
    final ownSourceRef = _artifactSourceRef(artifact);
    final ownVersion = _artifactSourceVersion(artifact);
    final linkedVersions = _linkedSourceVersions(artifact.sourceRefs);
    final linkedRefs = linkedVersions.map(_sourceRefFromVersion);
    if (_shouldRedactSensitivity(artifact.sensitivity, request)) {
      return _redactedSection(
        sectionId: 'section_artifact_${_safeId(artifact.id)}',
        title: 'Derived artifact redacted',
        sourceRef: ownSourceRef,
        sourceVersions: <JsonMap>[ownVersion, ...linkedVersions],
        reason: 'sensitivity_${artifact.sensitivity}',
        content:
            'High-sensitivity derived artifact is redacted by the current context policy.',
        sensitivity: artifact.sensitivity,
        extraSourceRefs: linkedRefs,
      );
    }
    final body = _truncate(
      _lines(<String>[
        'Derived artifact (${artifact.artifactKind}, confidence: ${artifact.confidence})',
        artifact.title,
        artifact.body,
      ]),
      _derivedExcerptLimit,
    );
    if (body.trim().isEmpty) {
      return null;
    }
    final section = <String, Object?>{
      'id': 'section_artifact_${_safeId(artifact.id)}',
      'kind': 'derived_artifact',
      'title': artifact.title,
      'content': body,
      'citations': <Object?>[
        <String, Object?>{
          'source_ref': ownSourceRef,
          'evidence_hash': artifact.contentHash ?? _stableHash(body),
          'excerpt': _excerpt(body),
        },
      ],
      'redactions': const <Object?>[],
      'sensitivity': _schemaSensitivity(artifact.sensitivity),
      'metadata': <String, Object?>{
        'artifact_kind': artifact.artifactKind,
        'source_capture_id': artifact.sourceCaptureId,
        if (artifact.sourceAttachmentId != null)
          'source_attachment_id': artifact.sourceAttachmentId,
        'generator_id': artifact.generatorId,
        'generator_version': artifact.generatorVersion,
      },
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: _dedupeSourceRefs(<JsonMap>[ownSourceRef, ...linkedRefs]),
      sourceVersions: _dedupeJsonMaps(<JsonMap>[ownVersion, ...linkedVersions]),
    );
  }

  _SectionBuildResult? _captureSection(
    CaptureRecord capture,
    ContextPacketBuildRequest request,
  ) {
    final rawText = _firstText(capture.payload, const <String>[
      'text',
      'raw_text',
      'body',
      'summary',
      'title',
      'preview_text',
      'excerpt',
    ]);
    final text = _truncate(rawText, _captureExcerptLimit);
    if (text.trim().isEmpty) {
      return null;
    }
    final ownSourceRef = _captureSourceRef(capture);
    final ownVersion = _captureSourceVersion(capture);
    final section = <String, Object?>{
      'id': 'section_capture_${_safeId(capture.id)}',
      'kind': 'raw_excerpt',
      'title': 'Capture ${capture.id}',
      'content': _lines(<String>[
        'Capture (${capture.sourceType}, status: ${capture.status})',
        text,
      ]),
      'citations': <Object?>[
        <String, Object?>{
          'source_ref': ownSourceRef,
          'evidence_hash': _stableHash(text),
          'excerpt': _excerpt(text),
        },
      ],
      'redactions': const <Object?>[],
      'sensitivity': 'low',
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: <JsonMap>[ownSourceRef],
      sourceVersions: <JsonMap>[ownVersion],
    );
  }

  _SectionBuildResult? _attachmentSection(
    AttachmentRecord attachment,
    ContextPacketBuildRequest request,
  ) {
    final ownSourceRef = _attachmentSourceRef(attachment);
    final ownVersion = _attachmentSourceVersion(attachment);
    final metadata = _lines(<String>[
      'Attachment metadata (${attachment.assetKind})',
      if (attachment.mimeType != null) 'mime_type: ${attachment.mimeType}',
      if (_safeFileName(attachment.originalFileName) != null)
        'file_name: ${_safeFileName(attachment.originalFileName)}',
      if (attachment.byteLength != null)
        'byte_length: ${attachment.byteLength}',
      if (attachment.sha256 != null) 'sha256: ${attachment.sha256}',
      'raw_file: not included',
    ]);
    final section = <String, Object?>{
      'id': 'section_attachment_${_safeId(attachment.id)}',
      'kind': 'attachment_metadata',
      'title': 'Attachment ${attachment.id}',
      'content': metadata,
      'citations': <Object?>[
        <String, Object?>{
          'source_ref': ownSourceRef,
          'evidence_hash': _stableHash(metadata),
          'excerpt': _excerpt(metadata),
        },
      ],
      'redactions': <Object?>[
        if (!request.allowAttachmentExpansion)
          <String, Object?>{
            'reason': 'attachment_raw_expansion_not_allowed',
            'source_ref': _objectRef('file', attachment.id),
          },
      ],
      'sensitivity': 'medium',
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: <JsonMap>[ownSourceRef],
      sourceVersions: <JsonMap>[ownVersion],
    );
  }

  _SectionBuildResult _redactedSection({
    required String sectionId,
    required String title,
    required JsonMap sourceRef,
    required List<JsonMap> sourceVersions,
    required String reason,
    required String content,
    required String sensitivity,
    Iterable<JsonMap> extraSourceRefs = const <JsonMap>[],
  }) {
    final section = <String, Object?>{
      'id': sectionId,
      'kind': 'redaction_notice',
      'title': title,
      'content': content,
      'citations': <Object?>[
        <String, Object?>{'source_ref': sourceRef, 'excerpt': null},
      ],
      'redactions': <Object?>[
        <String, Object?>{
          'reason': reason,
          'source_ref': _objectRef(
            sourceRef['kind']! as String,
            sourceRef['id']! as String,
          ),
        },
      ],
      'sensitivity': _schemaSensitivity(sensitivity),
    };
    return _SectionBuildResult(
      section: section,
      sourceRefs: _dedupeSourceRefs(<JsonMap>[sourceRef, ...extraSourceRefs]),
      sourceVersions: _dedupeJsonMaps(sourceVersions),
    );
  }

  List<JsonMap> _permissionGrantVersions(ContextPacketBuildRequest request) {
    final packId = request.packId;
    if (packId == null || request.permissions.isEmpty) {
      return const <JsonMap>[];
    }
    final versions = <JsonMap>[];
    for (final permission in _sortedStrings(request.permissions)) {
      final grant = _database.permissionGrants.readByPackAndPermission(
        packId,
        permission,
      );
      versions.add(<String, Object?>{
        'pack_id': packId,
        'permission_id': permission,
        'grant_id': grant?.id,
        'status': grant?.status ?? 'missing',
        'updated_at': grant?.updatedAt.toUtc().toIso8601String(),
        'granted_at': grant?.grantedAt?.toUtc().toIso8601String(),
        'revoked_at': grant?.revokedAt?.toUtc().toIso8601String(),
        'reason_hash': _nullableHash(grant?.reason),
      });
    }
    return List<JsonMap>.unmodifiable(versions);
  }

  List<JsonMap> _linkedSourceVersions(JsonList sourceRefs) {
    final versions = <JsonMap>[];
    for (final sourceRef in sourceRefs) {
      final ref = sourceRef is Map ? _normalizeMap(sourceRef) : null;
      final kind = ref?['kind'];
      final id = ref?['id'];
      if (kind is! String || id is! String) {
        continue;
      }
      final version = _sourceVersionFor(kind, id);
      if (version != null) {
        versions.add(version);
      } else {
        final sanitized = _sanitizeSourceRef(ref!);
        if (sanitized != null) {
          versions.add(<String, Object?>{...sanitized, 'status': 'unresolved'});
        }
      }
    }
    return _dedupeJsonMaps(versions);
  }

  JsonMap? _sourceVersionFor(String kind, String id) {
    return switch (kind) {
      'capture' =>
        _database.captures.readById(id) == null
            ? null
            : _captureSourceVersion(_database.captures.readById(id)!),
      'memory' =>
        _database.memoryItems.readById(id) == null
            ? null
            : _memorySourceVersion(_database.memoryItems.readById(id)!),
      'card' =>
        _database.cards.readById(id) == null
            ? null
            : _cardSourceVersion(_database.cards.readById(id)!),
      'insight' =>
        _database.insights.readById(id) == null
            ? null
            : _insightSourceVersion(_database.insights.readById(id)!),
      'todo' =>
        _database.todos.readById(id) == null
            ? null
            : _todoSourceVersion(_database.todos.readById(id)!),
      'artifact' =>
        _database.derivedArtifacts.readById(id) == null
            ? null
            : _artifactSourceVersion(_database.derivedArtifacts.readById(id)!),
      'event' =>
        _database.eventLog.readById(id) == null
            ? null
            : _eventSourceVersion(_database.eventLog.readById(id)!),
      'file' =>
        _database.attachments.readById(id) == null
            ? null
            : _attachmentSourceVersion(_database.attachments.readById(id)!),
      _ => null,
    };
  }
}

final class _SourceSelection {
  const _SourceSelection({
    required this.sections,
    required this.sourceRefs,
    required this.sourceVersions,
    required this.sourceBackedSectionCount,
  });

  final List<JsonMap> sections;
  final List<JsonMap> sourceRefs;
  final List<JsonMap> sourceVersions;
  final int sourceBackedSectionCount;
}

final class _SectionBuildResult {
  const _SectionBuildResult({
    required this.section,
    required this.sourceRefs,
    required this.sourceVersions,
  });

  final JsonMap section;
  final List<JsonMap> sourceRefs;
  final List<JsonMap> sourceVersions;
}

final class _SourceFilter {
  _SourceFilter(List<JsonMap> refs)
    : _keys = refs
          .map(_sanitizeSourceRef)
          .whereType<JsonMap>()
          .map((ref) => '${ref['kind']}/${ref['id']}')
          .toSet();

  final Set<String> _keys;

  bool get isEmpty => _keys.isEmpty;

  bool matches(String kind, String id, JsonList linkedRefs) {
    if (isEmpty || _keys.contains('$kind/$id')) {
      return true;
    }
    for (final linkedRef in linkedRefs) {
      if (linkedRef is! Map) {
        continue;
      }
      final normalized = _normalizeMap(linkedRef);
      final linkedKind = normalized['kind'];
      final linkedId = normalized['id'];
      if (linkedKind is String &&
          linkedId is String &&
          _keys.contains('$linkedKind/$linkedId')) {
        return true;
      }
    }
    return false;
  }
}

final class _SectionBudget {
  _SectionBudget(this.maxItems);

  final int maxItems;
  var _used = 0;

  bool get hasRoom => _used < maxItems;

  bool take() {
    if (!hasRoom) {
      return false;
    }
    _used++;
    return true;
  }
}

enum _DerivedKind { card, insight, todo, artifact }

final class _DerivedSource {
  _DerivedSource.card(CardRecord this.card)
    : kind = _DerivedKind.card,
      insight = null,
      todo = null,
      artifact = null,
      updatedAt = card.updatedAt;

  _DerivedSource.insight(InsightRecord this.insight)
    : kind = _DerivedKind.insight,
      card = null,
      todo = null,
      artifact = null,
      updatedAt = insight.updatedAt;

  _DerivedSource.todo(TodoRecord this.todo)
    : kind = _DerivedKind.todo,
      card = null,
      insight = null,
      artifact = null,
      updatedAt = todo.updatedAt;

  _DerivedSource.artifact(DerivedArtifactRecord this.artifact)
    : kind = _DerivedKind.artifact,
      card = null,
      insight = null,
      todo = null,
      updatedAt = artifact.updatedAt;

  final _DerivedKind kind;
  final CardRecord? card;
  final InsightRecord? insight;
  final TodoRecord? todo;
  final DerivedArtifactRecord? artifact;
  final DateTime updatedAt;
}

const _allowedSurfaces = <String>{
  'home',
  'chat',
  'recap',
  'pack_run',
  'export_preview',
  'trace_review',
};

const _allowedDisclosureLevels = <String>{
  'visible_context',
  'accepted_memory',
  'derived_summary',
  'targeted_excerpt',
  'attachment_expansion',
};

const _allowedPermissionModes = <String>{
  'local_only',
  'user_granted',
  'export_safe',
  'trace_review',
};

const _allowedRedactionPolicies = <String>{
  'none',
  'redact_sensitive',
  'redact_attachments',
};

const _memoryExcerptLimit = 1200;
const _derivedExcerptLimit = 900;
const _captureExcerptLimit = 800;
const _citationExcerptLimit = 240;

JsonMap _emptySection() {
  return const <String, Object?>{
    'id': 'section_empty_context',
    'kind': 'redaction_notice',
    'title': 'No source-backed context',
    'content': 'No local source-backed context matched this request.',
    'citations': <Object?>[],
    'redactions': <Object?>[],
    'sensitivity': 'low',
  };
}

JsonMap _permissionScope(
  ContextPacketBuildRequest request,
  List<JsonMap> permissionGrantVersions,
) {
  return <String, Object?>{
    'mode': request.permissionMode,
    'permissions': _sortedStrings(request.permissions),
    'grant_snapshot_id':
        request.grantSnapshotId ??
        (permissionGrantVersions.isEmpty
            ? null
            : 'grant_${_stableHash(permissionGrantVersions)}'),
    'redaction_policy': request.redactionPolicy,
  };
}

String _permissionScopeKey(
  ContextPacketBuildRequest request,
  List<JsonMap> permissionGrantVersions,
) {
  return _canonicalJson(_permissionScope(request, permissionGrantVersions));
}

List<Object?> _invalidationKeys(
  ContextPacketBuildRequest request,
  List<JsonMap> sourceVersions,
  List<JsonMap> permissionGrantVersions,
) {
  final keys = <String>{
    'surface:${request.surface}',
    'permission_scope:${_stableHash(_permissionScope(request, permissionGrantVersions))}',
    'disclosure:${request.disclosureLevel}',
    'generator:${request.generatorId}:${request.generatorVersion}',
    'prompt:${request.promptVersion}',
    'privacy:${request.privacyProfile}',
    if (request.packId != null) 'pack:${request.packId}:${request.packVersion}',
    if (request.agentId != null) 'agent:${request.agentId}',
    if (request.localDate != null) 'local_date:${request.localDate}',
  };
  for (final version in sourceVersions) {
    final kind = version['kind'];
    final id = version['id'];
    if (kind is! String || id is! String) {
      continue;
    }
    keys.add('source:$kind:$id:${_stableHash(version)}');
    if (kind == 'memory') {
      keys.add(
        'memory:$id:revision:${version['revision']}:'
        'tombstone:${version['tombstone']}:'
        'sensitivity:${version['sensitivity']}',
      );
    }
  }
  for (final grant in permissionGrantVersions) {
    final packId = grant['pack_id'];
    final permissionId = grant['permission_id'];
    if (packId is String && permissionId is String) {
      keys.add('permission:$packId:$permissionId');
      keys.add('permission:$packId:$permissionId:${grant['status']}');
    }
  }
  return _sortedStrings(keys).cast<Object?>();
}

String _cacheKeyFor(JsonMap keyMaterial) {
  final seed = keyMaterial['cache_key_seed'];
  final prefix = seed is String && seed.trim().isNotEmpty
      ? _safeId(seed.trim())
      : 'auto';
  return 'context_packet_builder.v1/$prefix/${_stableHash(keyMaterial)}';
}

String? _effectiveLocalDate(ContextPacketBuildRequest request, DateTime now) {
  return request.localDate ??
      (request.surface == 'recap' ? _dateOnly(now) : null);
}

String _dateOnly(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
}

bool _disclosureAllows(String requested, String needed) {
  return _disclosureRank(requested) >= _disclosureRank(needed);
}

int _disclosureRank(String value) {
  return switch (value) {
    'visible_context' => 0,
    'accepted_memory' => 1,
    'derived_summary' => 2,
    'targeted_excerpt' => 3,
    'attachment_expansion' => 4,
    _ => -1,
  };
}

bool _shouldRedactSensitivity(
  String sensitivity,
  ContextPacketBuildRequest request,
) {
  if (_schemaSensitivity(sensitivity) != 'high') {
    return false;
  }
  return request.redactionPolicy != 'none' ||
      request.permissionMode == 'export_safe' ||
      request.permissionMode == 'trace_review';
}

JsonMap _memorySourceRef(MemoryItemRecord memory) {
  return _sourceRef(
    'memory',
    memory.id,
    sourceVersion: memory.revision,
    contentHash: _stableHash(<String, Object?>{
      'body': memory.body,
      'source_refs': memory.sourceRefs,
    }),
    eventId: memory.sourceEventId,
    sensitivity: _schemaSensitivity(memory.sensitivity),
  );
}

JsonMap _memorySourceVersion(MemoryItemRecord memory) {
  return <String, Object?>{
    'kind': 'memory',
    'id': memory.id,
    'revision': memory.revision,
    'source_version': memory.revision,
    'updated_at': memory.updatedAt.toUtc().toIso8601String(),
    'status': memory.status,
    'tombstone': memory.tombstone,
    'sensitivity': _schemaSensitivity(memory.sensitivity),
    'content_hash': _stableHash(<String, Object?>{
      'body': memory.body,
      'source_refs': memory.sourceRefs,
      'payload': memory.payload,
    }),
  };
}

JsonMap _captureSourceRef(CaptureRecord capture) {
  return _sourceRef(
    'capture',
    capture.id,
    sourceVersion: capture.updatedAt.toUtc().toIso8601String(),
    contentHash: _stableHash(capture.payload),
    sensitivity: 'low',
  );
}

JsonMap _captureSourceVersion(CaptureRecord capture) {
  return <String, Object?>{
    'kind': 'capture',
    'id': capture.id,
    'source_version': capture.updatedAt.toUtc().toIso8601String(),
    'updated_at': capture.updatedAt.toUtc().toIso8601String(),
    'status': capture.status,
    'content_hash': _stableHash(<String, Object?>{
      'source_type': capture.sourceType,
      'payload': capture.payload,
    }),
  };
}

JsonMap _cardSourceRef(CardRecord card) {
  return _sourceRef(
    'card',
    card.id,
    sourceVersion: card.updatedAt.toUtc().toIso8601String(),
    contentHash: _stableHash(<String, Object?>{
      'title': card.title,
      'body': card.body,
    }),
    sensitivity: 'low',
  );
}

JsonMap _cardSourceVersion(CardRecord card) {
  return <String, Object?>{
    'kind': 'card',
    'id': card.id,
    'source_version': card.updatedAt.toUtc().toIso8601String(),
    'updated_at': card.updatedAt.toUtc().toIso8601String(),
    'status': card.status,
    'content_hash': _stableHash(<String, Object?>{
      'title': card.title,
      'body': card.body,
      'source_refs': card.sourceRefs,
      'payload': card.payload,
    }),
  };
}

JsonMap _insightSourceRef(InsightRecord insight) {
  return _sourceRef(
    'insight',
    insight.id,
    sourceVersion: insight.updatedAt.toUtc().toIso8601String(),
    contentHash: _stableHash(<String, Object?>{
      'title': insight.title,
      'summary': insight.summary,
    }),
    sensitivity: 'low',
  );
}

JsonMap _insightSourceVersion(InsightRecord insight) {
  return <String, Object?>{
    'kind': 'insight',
    'id': insight.id,
    'source_version': insight.updatedAt.toUtc().toIso8601String(),
    'updated_at': insight.updatedAt.toUtc().toIso8601String(),
    'status': insight.status,
    'content_hash': _stableHash(<String, Object?>{
      'title': insight.title,
      'summary': insight.summary,
      'metric_label': insight.metricLabel,
      'metric_value': insight.metricValue,
      'source_refs': insight.sourceRefs,
      'payload': insight.payload,
    }),
  };
}

JsonMap _todoSourceRef(TodoRecord todo) {
  return _sourceRef(
    'todo',
    todo.id,
    sourceVersion: todo.updatedAt.toUtc().toIso8601String(),
    contentHash: _stableHash(todo.payload),
    eventId: todo.sourceEventId,
    sensitivity: 'low',
  );
}

JsonMap _todoSourceVersion(TodoRecord todo) {
  return <String, Object?>{
    'kind': 'todo',
    'id': todo.id,
    'source_version': todo.updatedAt.toUtc().toIso8601String(),
    'updated_at': todo.updatedAt.toUtc().toIso8601String(),
    'status': todo.status,
    'source_capture_id': todo.sourceCaptureId,
    'source_event_id': todo.sourceEventId,
    'content_hash': _stableHash(todo.payload),
  };
}

JsonMap _artifactSourceRef(DerivedArtifactRecord artifact) {
  return _sourceRef(
    'artifact',
    artifact.id,
    sourceVersion: artifact.updatedAt.toUtc().toIso8601String(),
    contentHash:
        artifact.contentHash ??
        _stableHash(<String, Object?>{
          'title': artifact.title,
          'body': artifact.body,
          'payload': artifact.payload,
        }),
    eventId: artifact.sourceEventId,
    sensitivity: _schemaSensitivity(artifact.sensitivity),
  );
}

JsonMap _artifactSourceVersion(DerivedArtifactRecord artifact) {
  return <String, Object?>{
    'kind': 'artifact',
    'id': artifact.id,
    'source_version': artifact.updatedAt.toUtc().toIso8601String(),
    'updated_at': artifact.updatedAt.toUtc().toIso8601String(),
    'status': artifact.status,
    'artifact_kind': artifact.artifactKind,
    'source_capture_id': artifact.sourceCaptureId,
    'source_attachment_id': artifact.sourceAttachmentId,
    'sensitivity': _schemaSensitivity(artifact.sensitivity),
    'confidence': artifact.confidence,
    'content_hash':
        artifact.contentHash ??
        _stableHash(<String, Object?>{
          'title': artifact.title,
          'body': artifact.body,
          'source_refs': artifact.sourceRefs,
          'payload': artifact.payload,
        }),
    if (artifact.invalidatedAt != null)
      'invalidated_at': artifact.invalidatedAt!.toUtc().toIso8601String(),
  };
}

JsonMap _eventSourceVersion(EventLogEntry event) {
  return <String, Object?>{
    'kind': 'event',
    'id': event.id,
    'source_version': event.createdAt.toUtc().toIso8601String(),
    'created_at': event.createdAt.toUtc().toIso8601String(),
    'status': event.status,
    'content_hash': _stableHash(<String, Object?>{
      'type': event.type,
      'subject_ref': event.subjectRef,
      'payload': event.payload,
    }),
  };
}

JsonMap _attachmentSourceRef(AttachmentRecord attachment) {
  return _sourceRef(
    'file',
    attachment.id,
    sourceVersion: attachment.updatedAt.toUtc().toIso8601String(),
    contentHash:
        attachment.sha256 ?? _stableHash(_attachmentSafeMetadata(attachment)),
    eventId: attachment.sourceEventId,
    sensitivity: 'medium',
  );
}

JsonMap _attachmentSourceVersion(AttachmentRecord attachment) {
  return <String, Object?>{
    'kind': 'file',
    'id': attachment.id,
    'source_version': attachment.updatedAt.toUtc().toIso8601String(),
    'updated_at': attachment.updatedAt.toUtc().toIso8601String(),
    'status': attachment.status,
    'content_hash':
        attachment.sha256 ?? _stableHash(_attachmentSafeMetadata(attachment)),
    'capture_id': attachment.captureId,
    'asset_kind': attachment.assetKind,
  };
}

JsonMap _attachmentSafeMetadata(AttachmentRecord attachment) {
  return <String, Object?>{
    'asset_kind': attachment.assetKind,
    'mime_type': attachment.mimeType,
    'sha256': attachment.sha256,
    'byte_length': attachment.byteLength,
    'status': attachment.status,
  };
}

JsonMap _sourceRefFromVersion(JsonMap version) {
  return _sourceRef(
    version['kind']! as String,
    version['id']! as String,
    sourceVersion: version['source_version'] ?? version['revision'],
    contentHash: version['content_hash'] as String?,
    sensitivity: version['sensitivity'] as String?,
  );
}

JsonMap _sourceRef(
  String kind,
  String id, {
  Object? sourceVersion,
  String? contentHash,
  String? eventId,
  String? uri,
  String? sensitivity,
}) {
  return <String, Object?>{
    'kind': kind,
    'id': id,
    if (sourceVersion != null) 'source_version': sourceVersion,
    if (contentHash != null) 'content_hash': contentHash,
    if (eventId != null) 'event_id': eventId,
    if (uri != null) 'uri': uri,
    if (sensitivity != null) 'sensitivity': _schemaSensitivity(sensitivity),
  };
}

JsonMap? _sanitizeSourceRef(Object? value) {
  if (value is! Map) {
    return null;
  }
  final normalized = _normalizeMap(value);
  final kind = normalized['kind'];
  final id = normalized['id'];
  if (kind is! String || id is! String || kind.isEmpty || id.isEmpty) {
    return null;
  }
  if (!_allowedSourceRefKinds.contains(kind)) {
    return null;
  }
  return _sourceRef(
    kind,
    id,
    sourceVersion: normalized['source_version'],
    contentHash: normalized['content_hash'] as String?,
    eventId: normalized['event_id'] as String?,
    uri: normalized['uri'] as String?,
    sensitivity: normalized['sensitivity'] as String?,
  );
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

JsonMap _objectRef(String kind, String id, {String? uri}) {
  return <String, Object?>{'kind': kind, 'id': id, if (uri != null) 'uri': uri};
}

JsonMap? _objectRefOrNull(JsonMap value) {
  if (value.isEmpty) {
    return null;
  }
  final kind = value['kind'];
  final id = value['id'];
  if (kind is! String || id is! String || kind.isEmpty || id.isEmpty) {
    return null;
  }
  return _objectRef(kind, id, uri: value['uri'] as String?);
}

JsonMap _objectRefOrEmpty(JsonMap value) {
  return _objectRefOrNull(value) ?? const <String, Object?>{};
}

String _objectRefLabel(JsonMap value) {
  final ref = _objectRefOrNull(value);
  if (ref == null) {
    return 'unknown';
  }
  return '${ref['kind']}/${ref['id']}';
}

JsonList _captureRefs(CaptureRecord capture) {
  return <Object?>[
    <String, Object?>{'kind': 'capture', 'id': capture.id},
  ];
}

JsonList _todoRefs(TodoRecord todo) {
  return <Object?>[
    <String, Object?>{'kind': 'todo', 'id': todo.id},
    if (todo.sourceCaptureId != null)
      <String, Object?>{'kind': 'capture', 'id': todo.sourceCaptureId},
    if (todo.sourceEventId != null)
      <String, Object?>{'kind': 'event', 'id': todo.sourceEventId},
  ];
}

bool _isLiveCapture(CaptureRecord capture) {
  return !_terminalStatuses.contains(capture.status);
}

bool _isLiveTodo(TodoRecord todo) {
  return !_terminalStatuses.contains(todo.status);
}

const _terminalStatuses = <String>{
  'deleted',
  'tombstoned',
  'archived',
  'inactive',
};

String _firstText(JsonMap payload, List<String> keys) {
  for (final key in keys) {
    final value = payload[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

String? _safeFileName(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final pieces = trimmed.split(RegExp(r'[/\\]+'));
  final basename = pieces.isEmpty ? trimmed : pieces.last;
  final fileName = basename.trim();
  return fileName.isEmpty ? null : fileName;
}

String _lines(List<String?> lines) {
  return lines
      .whereType<String>()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

String? _normalizedIntent(String? intent) {
  final trimmed = intent?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _truncate(String value, int maxCharacters) {
  if (value.length <= maxCharacters) {
    return value;
  }
  return '${value.substring(0, maxCharacters).trimRight()}\n[truncated]';
}

String _excerpt(String value) {
  return _truncate(
    value.replaceAll(RegExp(r'\s+'), ' ').trim(),
    _citationExcerptLimit,
  );
}

String _schemaSensitivity(String value) {
  return switch (value) {
    'high' => 'high',
    'medium' => 'medium',
    _ => 'low',
  };
}

int _compareUpdatedDesc(dynamic a, dynamic b) {
  return (b.updatedAt as DateTime).compareTo(a.updatedAt as DateTime);
}

int _sourceBackedSectionCount(JsonMap packet) {
  final metadata = packet['metadata'];
  if (metadata is Map) {
    final count = metadata['source_backed_section_count'];
    if (count is int) {
      return count;
    }
  }
  final sections = packet['sections'];
  if (sections is! List) {
    return 0;
  }
  return sections
      .whereType<Map>()
      .where((section) => section['kind'] != 'visible_context')
      .where((section) => (section['citations'] as List?)?.isNotEmpty ?? false)
      .length;
}

List<JsonMap> _dedupeJsonMaps(Iterable<JsonMap> values) {
  final byKey = <String, JsonMap>{};
  for (final value in values) {
    byKey[_canonicalJson(value)] = value;
  }
  final result = byKey.values.toList(growable: false);
  result.sort((a, b) => _canonicalJson(a).compareTo(_canonicalJson(b)));
  return List<JsonMap>.unmodifiable(result);
}

List<JsonMap> _dedupeSourceRefs(Iterable<JsonMap> values) {
  final byIdentity = <String, JsonMap>{};
  final sorted = values.toList(growable: false)
    ..sort((a, b) => _canonicalJson(a).compareTo(_canonicalJson(b)));
  for (final value in sorted) {
    final kind = value['kind'];
    final id = value['id'];
    if (kind is! String || id is! String) {
      continue;
    }
    final key = '$kind/$id';
    final existing = byIdentity[key];
    if (existing == null ||
        value.length > existing.length ||
        (value.length == existing.length &&
            _canonicalJson(value).compareTo(_canonicalJson(existing)) < 0)) {
      byIdentity[key] = value;
    }
  }
  final result = byIdentity.values.toList(growable: false)
    ..sort((a, b) => _canonicalJson(a).compareTo(_canonicalJson(b)));
  return List<JsonMap>.unmodifiable(result);
}

List<String> _sortedStrings(Iterable<String> values) {
  final result = values.toSet().toList(growable: false)..sort();
  return List<String>.unmodifiable(result);
}

String? _nullableHash(String? value) {
  if (value == null) {
    return null;
  }
  return _stableHash(value);
}

String _stableHash(Object? value) {
  final text = _canonicalJson(value);
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final codeUnit in text.codeUnits) {
    hash = hash ^ BigInt.from(codeUnit);
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String _canonicalJson(Object? value) {
  return jsonEncode(_canonicalValue(value));
}

Object? _canonicalValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Map) {
    final result = <String, Object?>{};
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    for (final key in keys) {
      result[key] = _canonicalValue(value[key]);
    }
    return result;
  }
  if (value is Iterable) {
    return value.map(_canonicalValue).toList(growable: false);
  }
  return value.toString();
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
  return sanitized.length <= 80 ? sanitized : sanitized.substring(0, 80);
}
