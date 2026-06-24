import 'dart:convert';

import 'database.dart';
import 'json.dart';
import 'json_codec.dart';
import 'migration.dart';
import 'models.dart';

const _eventLogSection = 'event_log';
const _capturesSection = 'captures';
const _attachmentsSection = 'attachments';
const _memoryItemsSection = 'memory_items';
const _memoryCandidatesSection = 'memory_candidates';
const _cardsSection = 'cards';
const _insightsSection = 'insights';
const _chatSessionsSection = 'chat_sessions';
const _chatMessagesSection = 'chat_messages';
const _modelProviderConfigsSection = 'model_provider_configs';
const _todosSection = 'todos';
const _traceEventsSection = 'trace_events';

const _backupSections = <String>[
  _eventLogSection,
  _capturesSection,
  _attachmentsSection,
  _memoryItemsSection,
  _memoryCandidatesSection,
  _cardsSection,
  _insightsSection,
  _chatSessionsSection,
  _chatMessagesSection,
  _modelProviderConfigsSection,
  _todosSection,
  _traceEventsSection,
];

abstract final class LocalBackupCodec {
  static const formatId = 'widenote.local_data_backup';
  static const currentFormatVersion = 2;
  static const oldestSupportedFormatVersion = 1;

  static String encode(LocalDataBackup backup) {
    return const JsonEncoder.withIndent('  ').convert(backup.toJson());
  }

  static LocalDataBackup decode(String source) {
    return LocalDataBackup.fromJson(decodeJsonMap(source));
  }
}

final class LocalBackupManifest {
  LocalBackupManifest({
    required this.localDbSchemaVersion,
    required this.createdAt,
    required Map<String, int> recordCounts,
    this.format = LocalBackupCodec.formatId,
    this.formatVersion = LocalBackupCodec.currentFormatVersion,
  }) : recordCounts = Map<String, int>.unmodifiable(recordCounts);

  factory LocalBackupManifest.fromJson(JsonMap json) {
    final format = _requiredString(json, 'format');
    if (format != LocalBackupCodec.formatId) {
      throw FormatException('Unsupported backup format: $format.');
    }

    final sourceFormatVersion = _requiredInt(json, 'format_version');
    if (sourceFormatVersion < LocalBackupCodec.oldestSupportedFormatVersion ||
        sourceFormatVersion > LocalBackupCodec.currentFormatVersion) {
      throw UnsupportedError(
        'Backup format $sourceFormatVersion is not supported by '
        'format ${LocalBackupCodec.currentFormatVersion}.',
      );
    }

    return LocalBackupManifest(
      format: format,
      formatVersion: sourceFormatVersion,
      localDbSchemaVersion: _requiredInt(json, 'local_db_schema_version'),
      createdAt: _requiredDateTime(json, 'created_at'),
      recordCounts: _recordCountsFromJson(
        _requiredMap(json, 'record_counts'),
        sourceFormatVersion: sourceFormatVersion,
      ),
    );
  }

  final String format;
  final int formatVersion;
  final int localDbSchemaVersion;
  final DateTime createdAt;
  final Map<String, int> recordCounts;

  JsonMap toJson() {
    return <String, Object?>{
      'format': format,
      'format_version': formatVersion,
      'local_db_schema_version': localDbSchemaVersion,
      'created_at': _dateTimeToJson(createdAt),
      'record_counts': recordCounts,
    };
  }
}

final class LocalDataBackup {
  LocalDataBackup({
    required this.manifest,
    required this.eventLog,
    required this.captures,
    required this.attachments,
    required this.memoryItems,
    required this.memoryCandidates,
    required this.cards,
    required this.insights,
    required this.chatSessions,
    required this.chatMessages,
    required this.modelProviderConfigs,
    required this.todos,
    required this.traceEvents,
  }) {
    _validateCounts();
  }

  factory LocalDataBackup.fromJson(JsonMap json) {
    final manifest = LocalBackupManifest.fromJson(
      _requiredMap(json, 'manifest'),
    );
    return LocalDataBackup(
      manifest: manifest,
      eventLog: _requiredRecordList(
        json,
        _eventLogSection,
      ).map(_eventFromJson).toList(growable: false),
      captures: _requiredRecordList(
        json,
        _capturesSection,
      ).map(_captureFromJson).toList(growable: false),
      attachments: _recordList(
        json,
        _attachmentsSection,
        requiredSection: manifest.formatVersion >= 2,
      ).map(_attachmentFromJson).toList(growable: false),
      memoryItems: _requiredRecordList(
        json,
        _memoryItemsSection,
      ).map(_memoryItemFromJson).toList(growable: false),
      memoryCandidates: _requiredRecordList(
        json,
        _memoryCandidatesSection,
      ).map(_memoryCandidateFromJson).toList(growable: false),
      cards: _requiredRecordList(
        json,
        _cardsSection,
      ).map(_cardFromJson).toList(growable: false),
      insights: _requiredRecordList(
        json,
        _insightsSection,
      ).map(_insightFromJson).toList(growable: false),
      chatSessions: _requiredRecordList(
        json,
        _chatSessionsSection,
      ).map(_chatSessionFromJson).toList(growable: false),
      chatMessages: _requiredRecordList(
        json,
        _chatMessagesSection,
      ).map(_chatMessageFromJson).toList(growable: false),
      modelProviderConfigs: _requiredRecordList(
        json,
        _modelProviderConfigsSection,
      ).map(_modelProviderConfigFromJson).toList(growable: false),
      todos: _requiredRecordList(
        json,
        _todosSection,
      ).map(_todoFromJson).toList(growable: false),
      traceEvents: _requiredRecordList(
        json,
        _traceEventsSection,
      ).map(_traceEventFromJson).toList(growable: false),
    );
  }

  final LocalBackupManifest manifest;
  final List<EventLogEntry> eventLog;
  final List<CaptureRecord> captures;
  final List<AttachmentRecord> attachments;
  final List<MemoryItemRecord> memoryItems;
  final List<MemoryCandidateRecord> memoryCandidates;
  final List<CardRecord> cards;
  final List<InsightRecord> insights;
  final List<ChatSessionRecord> chatSessions;
  final List<ChatMessageRecord> chatMessages;
  final List<ModelProviderConfigRecord> modelProviderConfigs;
  final List<TodoRecord> todos;
  final List<TraceEventRecord> traceEvents;

  JsonMap toJson() {
    return <String, Object?>{
      'manifest': manifest.toJson(),
      _eventLogSection: eventLog.map(_eventToJson).toList(growable: false),
      _capturesSection: captures.map(_captureToJson).toList(growable: false),
      _attachmentsSection: attachments
          .map(_attachmentToJson)
          .toList(growable: false),
      _memoryItemsSection: memoryItems
          .map(_memoryItemToJson)
          .toList(growable: false),
      _memoryCandidatesSection: memoryCandidates
          .map(_memoryCandidateToJson)
          .toList(growable: false),
      _cardsSection: cards.map(_cardToJson).toList(growable: false),
      _insightsSection: insights.map(_insightToJson).toList(growable: false),
      _chatSessionsSection: chatSessions
          .map(_chatSessionToJson)
          .toList(growable: false),
      _chatMessagesSection: chatMessages
          .map(_chatMessageToJson)
          .toList(growable: false),
      _modelProviderConfigsSection: modelProviderConfigs
          .map(_modelProviderConfigToJson)
          .toList(growable: false),
      _todosSection: todos.map(_todoToJson).toList(growable: false),
      _traceEventsSection: traceEvents
          .map(_traceEventToJson)
          .toList(growable: false),
    };
  }

  void _validateCounts() {
    final actualCounts = <String, int>{
      _eventLogSection: eventLog.length,
      _capturesSection: captures.length,
      _attachmentsSection: attachments.length,
      _memoryItemsSection: memoryItems.length,
      _memoryCandidatesSection: memoryCandidates.length,
      _cardsSection: cards.length,
      _insightsSection: insights.length,
      _chatSessionsSection: chatSessions.length,
      _chatMessagesSection: chatMessages.length,
      _modelProviderConfigsSection: modelProviderConfigs.length,
      _todosSection: todos.length,
      _traceEventsSection: traceEvents.length,
    };
    for (final entry in actualCounts.entries) {
      final expected = manifest.recordCounts[entry.key];
      if (expected == null) {
        throw FormatException('Missing manifest count for ${entry.key}.');
      }
      if (expected != entry.value) {
        throw FormatException(
          'Manifest count mismatch for ${entry.key}: '
          'expected $expected, found ${entry.value}.',
        );
      }
    }
  }
}

final class LocalBackupService {
  LocalBackupService(this.database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WideNoteLocalDatabase database;
  final DateTime Function() _clock;

  LocalDataBackup exportBackup() {
    final eventLog = database.eventLog.readAll();
    final captures = database.captures.readAll();
    final attachments = database.attachments.readAll();
    final memoryItems = database.memoryItems.readAll();
    final memoryCandidates = database.memoryCandidates.readAll();
    final cards = database.cards.readAll();
    final insights = database.insights.readAll();
    final chatSessions = database.chatSessions.readAll();
    final chatMessages = database.chatMessages.readAll();
    final modelProviderConfigs = database.modelProviderConfigs.readAll();
    final todos = database.todos.readAll();
    final traceEvents = database.traceEvents.readAll();

    return LocalDataBackup(
      manifest: LocalBackupManifest(
        localDbSchemaVersion: database.schemaVersion,
        createdAt: _clock().toUtc(),
        recordCounts: <String, int>{
          _eventLogSection: eventLog.length,
          _capturesSection: captures.length,
          _attachmentsSection: attachments.length,
          _memoryItemsSection: memoryItems.length,
          _memoryCandidatesSection: memoryCandidates.length,
          _cardsSection: cards.length,
          _insightsSection: insights.length,
          _chatSessionsSection: chatSessions.length,
          _chatMessagesSection: chatMessages.length,
          _modelProviderConfigsSection: modelProviderConfigs.length,
          _todosSection: todos.length,
          _traceEventsSection: traceEvents.length,
        },
      ),
      eventLog: eventLog,
      captures: captures,
      attachments: attachments,
      memoryItems: memoryItems,
      memoryCandidates: memoryCandidates,
      cards: cards,
      insights: insights,
      chatSessions: chatSessions,
      chatMessages: chatMessages,
      modelProviderConfigs: modelProviderConfigs,
      todos: todos,
      traceEvents: traceEvents,
    );
  }

  String exportJson() {
    return LocalBackupCodec.encode(exportBackup());
  }

  void importJson(String source) {
    importBackup(LocalBackupCodec.decode(source));
  }

  void importBackup(LocalDataBackup backup) {
    if (backup.manifest.localDbSchemaVersion > LocalDbSchema.currentVersion) {
      throw UnsupportedError(
        'Backup DB schema ${backup.manifest.localDbSchemaVersion} is newer '
        'than supported schema ${LocalDbSchema.currentVersion}.',
      );
    }
    _rejectImportConflicts(backup);

    final rawDatabase = database.rawDatabase;
    rawDatabase.execute('BEGIN IMMEDIATE;');
    try {
      for (final capture in backup.captures) {
        database.captures.insert(capture);
      }
      for (final attachment in backup.attachments) {
        database.attachments.insert(attachment);
      }
      for (final event in backup.eventLog) {
        database.eventLog.append(event);
      }
      for (final memoryItem in backup.memoryItems) {
        database.memoryItems.insert(memoryItem);
      }
      for (final candidate in backup.memoryCandidates) {
        database.memoryCandidates.insert(candidate);
      }
      for (final card in backup.cards) {
        database.cards.insert(card);
      }
      for (final insight in backup.insights) {
        database.insights.insert(insight);
      }
      for (final session in backup.chatSessions) {
        database.chatSessions.insert(session);
      }
      for (final message in backup.chatMessages) {
        database.chatMessages.insert(message);
      }
      for (final config in backup.modelProviderConfigs) {
        database.modelProviderConfigs.insert(config);
      }
      for (final todo in backup.todos) {
        database.todos.insert(todo);
      }
      for (final traceEvent in backup.traceEvents) {
        database.traceEvents.insert(traceEvent);
      }
      final foreignKeyErrors = rawDatabase.select('PRAGMA foreign_key_check;');
      if (foreignKeyErrors.isNotEmpty) {
        throw StateError(
          'Backup import failed foreign key validation '
          'for ${foreignKeyErrors.length} row(s).',
        );
      }
      rawDatabase.execute('COMMIT;');
    } catch (_) {
      rawDatabase.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _rejectImportConflicts(LocalDataBackup backup) {
    _rejectExistingOrDuplicateIds(
      _capturesSection,
      backup.captures.map((record) => record.id),
      (id) => database.captures.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _attachmentsSection,
      backup.attachments.map((record) => record.id),
      (id) => database.attachments.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _eventLogSection,
      backup.eventLog.map((record) => record.id),
      (id) => database.eventLog.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _memoryItemsSection,
      backup.memoryItems.map((record) => record.id),
      (id) => database.memoryItems.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _memoryCandidatesSection,
      backup.memoryCandidates.map((record) => record.id),
      (id) => database.memoryCandidates.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _cardsSection,
      backup.cards.map((record) => record.id),
      (id) => database.cards.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _insightsSection,
      backup.insights.map((record) => record.id),
      (id) => database.insights.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _chatSessionsSection,
      backup.chatSessions.map((record) => record.id),
      (id) => database.chatSessions.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _chatMessagesSection,
      backup.chatMessages.map((record) => record.id),
      (id) => database.chatMessages.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _modelProviderConfigsSection,
      backup.modelProviderConfigs.map((record) => record.id),
      (id) => database.modelProviderConfigs.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _todosSection,
      backup.todos.map((record) => record.id),
      (id) => database.todos.readById(id) != null,
    );
    _rejectExistingOrDuplicateIds(
      _traceEventsSection,
      backup.traceEvents.map((record) => record.id),
      (id) => database.traceEvents.readById(id) != null,
    );
  }
}

void _rejectExistingOrDuplicateIds(
  String section,
  Iterable<String> ids,
  bool Function(String id) exists,
) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw FormatException(
        'Backup section $section contains duplicate id $id.',
      );
    }
    if (exists(id)) {
      throw StateError(
        'Backup import would overwrite existing $section row $id.',
      );
    }
  }
}

JsonMap _eventToJson(EventLogEntry event) {
  return <String, Object?>{
    'id': event.id,
    'type': event.type,
    'schema_version': event.schemaVersion,
    'actor': event.actor,
    'status': event.status,
    'privacy': event.privacy,
    'source_capture_id': event.sourceCaptureId,
    'source_event_id': event.sourceEventId,
    'subject_kind': event.subjectKind,
    'subject_id': event.subjectId,
    'subject_ref': event.subjectRef,
    'pack_id': event.packId,
    'agent_id': event.agentId,
    'device_id': event.deviceId,
    'causation_id': event.causationId,
    'correlation_id': event.correlationId,
    'payload': event.payload,
    'created_at': _dateTimeToJson(event.createdAt),
  };
}

EventLogEntry _eventFromJson(JsonMap json) {
  return EventLogEntry(
    id: _requiredString(json, 'id'),
    type: _requiredString(json, 'type'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    actor: _requiredString(json, 'actor'),
    status: _requiredString(json, 'status'),
    privacy: _requiredString(json, 'privacy'),
    sourceCaptureId: _optionalString(json, 'source_capture_id'),
    sourceEventId: _optionalString(json, 'source_event_id'),
    subjectKind: _optionalString(json, 'subject_kind'),
    subjectId: _optionalString(json, 'subject_id'),
    subjectRef: _requiredMap(json, 'subject_ref'),
    packId: _optionalString(json, 'pack_id'),
    agentId: _optionalString(json, 'agent_id'),
    deviceId: _optionalString(json, 'device_id'),
    causationId: _optionalString(json, 'causation_id'),
    correlationId: _optionalString(json, 'correlation_id'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
  );
}

JsonMap _captureToJson(CaptureRecord capture) {
  return <String, Object?>{
    'id': capture.id,
    'schema_version': capture.schemaVersion,
    'source_type': capture.sourceType,
    'source_id': capture.sourceId,
    'status': capture.status,
    'payload': capture.payload,
    'created_at': _dateTimeToJson(capture.createdAt),
    'updated_at': _dateTimeToJson(capture.updatedAt),
  };
}

CaptureRecord _captureFromJson(JsonMap json) {
  return CaptureRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    sourceType: _requiredString(json, 'source_type'),
    sourceId: _optionalString(json, 'source_id'),
    status: _requiredString(json, 'status'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _attachmentToJson(AttachmentRecord attachment) {
  return <String, Object?>{
    'id': attachment.id,
    'schema_version': attachment.schemaVersion,
    'capture_id': attachment.captureId,
    'source_event_id': attachment.sourceEventId,
    'asset_kind': attachment.assetKind,
    'mime_type': attachment.mimeType,
    'storage_path': attachment.storagePath,
    'original_file_name': attachment.originalFileName,
    'sha256': attachment.sha256,
    'byte_length': attachment.byteLength,
    'status': attachment.status,
    'payload': attachment.payload,
    'created_at': _dateTimeToJson(attachment.createdAt),
    'updated_at': _dateTimeToJson(attachment.updatedAt),
  };
}

AttachmentRecord _attachmentFromJson(JsonMap json) {
  return AttachmentRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    captureId: _requiredString(json, 'capture_id'),
    sourceEventId: _optionalString(json, 'source_event_id'),
    assetKind: _requiredString(json, 'asset_kind'),
    mimeType: _optionalString(json, 'mime_type'),
    storagePath: _requiredString(json, 'storage_path'),
    originalFileName: _optionalString(json, 'original_file_name'),
    sha256: _optionalString(json, 'sha256'),
    byteLength: _optionalInt(json, 'byte_length'),
    status: _requiredString(json, 'status'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _memoryItemToJson(MemoryItemRecord item) {
  return <String, Object?>{
    'id': item.id,
    'key': item.key,
    'schema_version': item.schemaVersion,
    'source_capture_id': item.sourceCaptureId,
    'source_event_id': item.sourceEventId,
    'status': item.status,
    'body': item.body,
    'source_refs': item.sourceRefs,
    'memory_type': item.memoryType,
    'confidence': item.confidence,
    'sensitivity': item.sensitivity,
    'revision': item.revision,
    'tombstone': item.tombstone,
    'payload': item.payload,
    'created_at': _dateTimeToJson(item.createdAt),
    'updated_at': _dateTimeToJson(item.updatedAt),
  };
}

MemoryItemRecord _memoryItemFromJson(JsonMap json) {
  return MemoryItemRecord(
    id: _requiredString(json, 'id'),
    key: _requiredString(json, 'key'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    sourceCaptureId: _optionalString(json, 'source_capture_id'),
    sourceEventId: _optionalString(json, 'source_event_id'),
    status: _requiredString(json, 'status'),
    body: _requiredString(json, 'body'),
    sourceRefs: _requiredList(json, 'source_refs'),
    memoryType: _requiredString(json, 'memory_type'),
    confidence: _requiredString(json, 'confidence'),
    sensitivity: _requiredString(json, 'sensitivity'),
    revision: _requiredInt(json, 'revision'),
    tombstone: _requiredBool(json, 'tombstone'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _memoryCandidateToJson(MemoryCandidateRecord candidate) {
  return <String, Object?>{
    'id': candidate.id,
    'key': candidate.key,
    'schema_version': candidate.schemaVersion,
    'source_capture_id': candidate.sourceCaptureId,
    'source_event_id': candidate.sourceEventId,
    'status': candidate.status,
    'body': candidate.body,
    'source_refs': candidate.sourceRefs,
    'memory_type': candidate.memoryType,
    'confidence': candidate.confidence,
    'sensitivity': candidate.sensitivity,
    'payload': candidate.payload,
    'created_at': _dateTimeToJson(candidate.createdAt),
    'updated_at': _dateTimeToJson(candidate.updatedAt),
  };
}

MemoryCandidateRecord _memoryCandidateFromJson(JsonMap json) {
  return MemoryCandidateRecord(
    id: _requiredString(json, 'id'),
    key: _requiredString(json, 'key'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    sourceCaptureId: _optionalString(json, 'source_capture_id'),
    sourceEventId: _optionalString(json, 'source_event_id'),
    status: _requiredString(json, 'status'),
    body: _requiredString(json, 'body'),
    sourceRefs: _requiredList(json, 'source_refs'),
    memoryType: _requiredString(json, 'memory_type'),
    confidence: _requiredString(json, 'confidence'),
    sensitivity: _requiredString(json, 'sensitivity'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _cardToJson(CardRecord card) {
  return <String, Object?>{
    'id': card.id,
    'schema_version': card.schemaVersion,
    'card_kind': card.cardKind,
    'status': card.status,
    'title': card.title,
    'body': card.body,
    'source_refs': card.sourceRefs,
    'payload': card.payload,
    'created_at': _dateTimeToJson(card.createdAt),
    'updated_at': _dateTimeToJson(card.updatedAt),
  };
}

CardRecord _cardFromJson(JsonMap json) {
  return CardRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    cardKind: _requiredString(json, 'card_kind'),
    status: _requiredString(json, 'status'),
    title: _requiredString(json, 'title'),
    body: _requiredString(json, 'body'),
    sourceRefs: _requiredList(json, 'source_refs'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _insightToJson(InsightRecord insight) {
  return <String, Object?>{
    'id': insight.id,
    'schema_version': insight.schemaVersion,
    'insight_kind': insight.insightKind,
    'status': insight.status,
    'title': insight.title,
    'summary': insight.summary,
    'source_refs': insight.sourceRefs,
    'metric_label': insight.metricLabel,
    'metric_value': insight.metricValue,
    'payload': insight.payload,
    'created_at': _dateTimeToJson(insight.createdAt),
    'updated_at': _dateTimeToJson(insight.updatedAt),
  };
}

InsightRecord _insightFromJson(JsonMap json) {
  return InsightRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    insightKind: _requiredString(json, 'insight_kind'),
    status: _requiredString(json, 'status'),
    title: _requiredString(json, 'title'),
    summary: _requiredString(json, 'summary'),
    sourceRefs: _requiredList(json, 'source_refs'),
    metricLabel: _optionalString(json, 'metric_label'),
    metricValue: _optionalNum(json, 'metric_value'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _chatSessionToJson(ChatSessionRecord session) {
  return <String, Object?>{
    'id': session.id,
    'schema_version': session.schemaVersion,
    'title': session.title,
    'status': session.status,
    'payload': session.payload,
    'created_at': _dateTimeToJson(session.createdAt),
    'updated_at': _dateTimeToJson(session.updatedAt),
  };
}

ChatSessionRecord _chatSessionFromJson(JsonMap json) {
  return ChatSessionRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    title: _requiredString(json, 'title'),
    status: _requiredString(json, 'status'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _chatMessageToJson(ChatMessageRecord message) {
  return <String, Object?>{
    'id': message.id,
    'schema_version': message.schemaVersion,
    'session_id': message.sessionId,
    'role': message.role,
    'status': message.status,
    'body': message.body,
    'source_refs': message.sourceRefs,
    'payload': message.payload,
    'created_at': _dateTimeToJson(message.createdAt),
  };
}

ChatMessageRecord _chatMessageFromJson(JsonMap json) {
  return ChatMessageRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    sessionId: _requiredString(json, 'session_id'),
    role: _requiredString(json, 'role'),
    status: _requiredString(json, 'status'),
    body: _requiredString(json, 'body'),
    sourceRefs: _requiredList(json, 'source_refs'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
  );
}

JsonMap _modelProviderConfigToJson(ModelProviderConfigRecord config) {
  return <String, Object?>{
    'id': config.id,
    'schema_version': config.schemaVersion,
    'provider_kind': config.providerKind,
    'display_name': config.displayName,
    'endpoint': config.endpoint,
    'model': config.model,
    'status': config.status,
    'is_default': config.isDefault,
    'has_api_key': config.hasApiKey,
    'api_key': config.apiKey,
    'capabilities': config.capabilities,
    'payload': config.payload,
    'created_at': _dateTimeToJson(config.createdAt),
    'updated_at': _dateTimeToJson(config.updatedAt),
  };
}

ModelProviderConfigRecord _modelProviderConfigFromJson(JsonMap json) {
  final apiKey = _optionalString(json, 'api_key') ?? '';
  return ModelProviderConfigRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    providerKind: _requiredString(json, 'provider_kind'),
    displayName: _requiredString(json, 'display_name'),
    endpoint: _requiredString(json, 'endpoint'),
    model: _requiredString(json, 'model'),
    status: _requiredString(json, 'status'),
    isDefault: _requiredBool(json, 'is_default'),
    hasApiKey: _requiredBool(json, 'has_api_key'),
    apiKey: apiKey,
    capabilities: _requiredList(json, 'capabilities'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _todoToJson(TodoRecord todo) {
  return <String, Object?>{
    'id': todo.id,
    'schema_version': todo.schemaVersion,
    'source_capture_id': todo.sourceCaptureId,
    'source_event_id': todo.sourceEventId,
    'status': todo.status,
    'payload': todo.payload,
    'created_at': _dateTimeToJson(todo.createdAt),
    'updated_at': _dateTimeToJson(todo.updatedAt),
  };
}

TodoRecord _todoFromJson(JsonMap json) {
  return TodoRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    sourceCaptureId: _optionalString(json, 'source_capture_id'),
    sourceEventId: _optionalString(json, 'source_event_id'),
    status: _requiredString(json, 'status'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _traceEventToJson(TraceEventRecord trace) {
  return <String, Object?>{
    'id': trace.id,
    'name': trace.name,
    'level': trace.level,
    'trace_type': trace.traceType,
    'run_id': trace.runId,
    'severity': trace.severity,
    'schema_version': trace.schemaVersion,
    'message': trace.message,
    'source_event_id': trace.sourceEventId,
    'source_run_id': trace.sourceRunId,
    'source_task_id': trace.sourceTaskId,
    'pack_id': trace.packId,
    'agent_id': trace.agentId,
    'parent_trace_id': trace.parentTraceId,
    'duration_ms': trace.durationMs,
    'status': trace.status,
    'payload': trace.payload,
    'created_at': _dateTimeToJson(trace.createdAt),
  };
}

TraceEventRecord _traceEventFromJson(JsonMap json) {
  return TraceEventRecord(
    id: _requiredString(json, 'id'),
    name: _requiredString(json, 'name'),
    level: _requiredString(json, 'level'),
    traceTypeOverride: _requiredString(json, 'trace_type'),
    runIdOverride: _optionalString(json, 'run_id'),
    severityOverride: _requiredString(json, 'severity'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    message: _requiredString(json, 'message'),
    sourceEventId: _optionalString(json, 'source_event_id'),
    sourceRunId: _optionalString(json, 'source_run_id'),
    sourceTaskId: _optionalString(json, 'source_task_id'),
    packId: _optionalString(json, 'pack_id'),
    agentId: _optionalString(json, 'agent_id'),
    parentTraceId: _optionalString(json, 'parent_trace_id'),
    durationMs: _optionalNum(json, 'duration_ms'),
    status: _requiredString(json, 'status'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
  );
}

Map<String, int> _recordCountsFromJson(
  JsonMap json, {
  required int sourceFormatVersion,
}) {
  final counts = <String, int>{};
  for (final section in _backupSections) {
    if (section == _attachmentsSection &&
        sourceFormatVersion < LocalBackupCodec.currentFormatVersion &&
        !json.containsKey(section)) {
      counts[section] = 0;
    } else {
      counts[section] = _requiredInt(json, section);
    }
  }
  return counts;
}

List<JsonMap> _requiredRecordList(JsonMap json, String key) {
  return _recordList(json, key, requiredSection: true);
}

List<JsonMap> _recordList(
  JsonMap json,
  String key, {
  required bool requiredSection,
}) {
  final value = json[key];
  if (value == null) {
    if (!requiredSection) {
      return const <JsonMap>[];
    }
    throw FormatException('Missing backup section: $key.');
  }
  if (value is! List) {
    throw FormatException('Backup section $key must be a list.');
  }
  return value
      .map((item) {
        if (item is! Map<String, Object?>) {
          throw FormatException(
            'Backup section $key contains a non-object row.',
          );
        }
        return item;
      })
      .toList(growable: false);
}

JsonMap _requiredMap(JsonMap json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('Backup field $key must be an object.');
}

JsonList _requiredList(JsonMap json, String key) {
  final value = json[key];
  if (value is JsonList) {
    return value;
  }
  throw FormatException('Backup field $key must be a list.');
}

String _requiredString(JsonMap json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Backup field $key must be a string.');
}

String? _optionalString(JsonMap json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Backup field $key must be a string or null.');
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Backup field $key must be an integer.');
}

int? _optionalInt(JsonMap json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('Backup field $key must be an integer or null.');
}

num? _optionalNum(JsonMap json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value;
  }
  throw FormatException('Backup field $key must be a number or null.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Backup field $key must be a boolean.');
}

DateTime _requiredDateTime(JsonMap json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('Backup field $key must be an ISO-8601 timestamp.');
  }
}

String _dateTimeToJson(DateTime value) {
  return value.toUtc().toIso8601String();
}
