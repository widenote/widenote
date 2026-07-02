import 'dart:convert';

import 'package:sqlite3/sqlite3.dart' show Database;

import 'database.dart';
import 'json.dart';
import 'json_codec.dart';
import 'migration.dart';
import 'models.dart';

const _eventLogSection = 'event_log';
const _capturesSection = 'captures';
const _attachmentsSection = 'attachments';
const _derivedArtifactsSection = 'derived_artifacts';
const _memoryItemsSection = 'memory_items';
const _memoryCandidatesSection = 'memory_candidates';
const _cardsSection = 'cards';
const _insightsSection = 'insights';
const _chatSessionsSection = 'chat_sessions';
const _chatMessagesSection = 'chat_messages';
const _modelProviderConfigsSection = 'model_provider_configs';
const _todosSection = 'todos';
const _runtimeTasksSection = 'runtime_tasks';
const _runtimeRunsSection = 'runtime_runs';
const _packInstallationsSection = 'pack_installations';
const _permissionGrantsSection = 'permission_grants';
const _contextPacketCacheSection = 'context_packet_cache';
const _traceEventsSection = 'trace_events';

const _backupSections = <String>[
  _eventLogSection,
  _capturesSection,
  _attachmentsSection,
  _derivedArtifactsSection,
  _memoryItemsSection,
  _memoryCandidatesSection,
  _cardsSection,
  _insightsSection,
  _chatSessionsSection,
  _chatMessagesSection,
  _modelProviderConfigsSection,
  _todosSection,
  _runtimeTasksSection,
  _runtimeRunsSection,
  _packInstallationsSection,
  _permissionGrantsSection,
  _contextPacketCacheSection,
  _traceEventsSection,
];

enum LocalBackupMode {
  safe('safe'),
  full('full'),
  encryptedFull('encrypted_full');

  const LocalBackupMode(this.wireName);

  final String wireName;

  static LocalBackupMode fromWireName(String value) {
    return LocalBackupMode.values.firstWhere(
      (mode) => mode.wireName == value,
      orElse: () {
        throw FormatException('Unsupported backup mode: $value.');
      },
    );
  }
}

enum LocalBackupImportStrategy { append, replaceAll }

abstract final class LocalBackupCodec {
  static const formatId = 'widenote.local_data_backup';
  static const currentFormatVersion = 4;
  static const oldestSupportedFormatVersion = 1;

  static String encode(LocalDataBackup backup) {
    if (backup.manifest.includesSecrets) {
      throw UnsupportedError(
        'Secret-bearing backup JSON export requires encryption and is not '
        'available in this build.',
      );
    }
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
    this.backupMode = LocalBackupMode.safe,
    this.format = LocalBackupCodec.formatId,
    this.formatVersion = LocalBackupCodec.currentFormatVersion,
    this.kind = 'backup_manifest',
    this.schemaVersion = 1,
    bool? includesSecrets,
    JsonMap? encryption,
  }) : includesSecrets =
           includesSecrets ?? _backupModeIncludesSecrets(backupMode),
       encryption = encryption == null
           ? null
           : Map<String, Object?>.unmodifiable(encryption),
       recordCounts = Map<String, int>.unmodifiable(recordCounts) {
    if (kind != 'backup_manifest') {
      throw FormatException('Unsupported backup manifest kind: $kind.');
    }
    if (schemaVersion < 1) {
      throw const FormatException(
        'Backup manifest schema version must be positive.',
      );
    }
    if (backupMode == LocalBackupMode.safe && this.includesSecrets) {
      throw const FormatException('Safe backups cannot include secrets.');
    }
    if (_backupModeIncludesSecrets(backupMode) && !this.includesSecrets) {
      throw const FormatException(
        'Full backups must declare included secrets.',
      );
    }
    if (formatVersion >= 3 &&
        backupMode == LocalBackupMode.encryptedFull &&
        this.includesSecrets &&
        this.encryption == null) {
      throw const FormatException(
        'Encrypted full backups must declare encryption metadata.',
      );
    }
  }

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

    final backupMode = _backupModeFromJson(json, sourceFormatVersion);
    return LocalBackupManifest(
      kind: _optionalManifestKind(json),
      schemaVersion: _optionalManifestSchemaVersion(json),
      format: format,
      formatVersion: sourceFormatVersion,
      backupMode: backupMode,
      includesSecrets: _optionalIncludesSecrets(json, backupMode),
      encryption: _optionalMap(json, 'encryption'),
      localDbSchemaVersion: _requiredInt(json, 'local_db_schema_version'),
      createdAt: _requiredDateTime(json, 'created_at'),
      recordCounts: _recordCountsFromJson(
        _requiredMap(json, 'record_counts'),
        sourceFormatVersion: sourceFormatVersion,
      ),
    );
  }

  final String kind;
  final int schemaVersion;
  final String format;
  final int formatVersion;
  final LocalBackupMode backupMode;
  final bool includesSecrets;
  final JsonMap? encryption;
  final int localDbSchemaVersion;
  final DateTime createdAt;
  final Map<String, int> recordCounts;

  JsonMap toJson() {
    return <String, Object?>{
      'kind': kind,
      'schema_version': schemaVersion,
      'format': format,
      'format_version': formatVersion,
      'backup_mode': backupMode.wireName,
      'includes_secrets': includesSecrets,
      'encryption': encryption,
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
    required this.derivedArtifacts,
    required this.memoryItems,
    required this.memoryCandidates,
    required this.cards,
    required this.insights,
    required this.chatSessions,
    required this.chatMessages,
    required this.modelProviderConfigs,
    required this.todos,
    required this.runtimeTasks,
    required this.runtimeRuns,
    required this.packInstallations,
    required this.permissionGrants,
    required this.contextPacketCaches,
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
      derivedArtifacts: _recordList(
        json,
        _derivedArtifactsSection,
        requiredSection: manifest.formatVersion >= 4,
      ).map(_derivedArtifactFromJson).toList(growable: false),
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
      runtimeTasks: _recordList(
        json,
        _runtimeTasksSection,
        requiredSection: manifest.formatVersion >= 3,
      ).map(_runtimeTaskFromJson).toList(growable: false),
      runtimeRuns: _recordList(
        json,
        _runtimeRunsSection,
        requiredSection: manifest.formatVersion >= 3,
      ).map(_runtimeRunFromJson).toList(growable: false),
      packInstallations: _recordList(
        json,
        _packInstallationsSection,
        requiredSection: manifest.formatVersion >= 3,
      ).map(_packInstallationFromJson).toList(growable: false),
      permissionGrants: _recordList(
        json,
        _permissionGrantsSection,
        requiredSection: manifest.formatVersion >= 3,
      ).map(_permissionGrantFromJson).toList(growable: false),
      contextPacketCaches: _recordList(
        json,
        _contextPacketCacheSection,
        requiredSection: false,
      ).map(_contextPacketCacheFromJson).toList(growable: false),
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
  final List<DerivedArtifactRecord> derivedArtifacts;
  final List<MemoryItemRecord> memoryItems;
  final List<MemoryCandidateRecord> memoryCandidates;
  final List<CardRecord> cards;
  final List<InsightRecord> insights;
  final List<ChatSessionRecord> chatSessions;
  final List<ChatMessageRecord> chatMessages;
  final List<ModelProviderConfigRecord> modelProviderConfigs;
  final List<TodoRecord> todos;
  final List<RuntimeTaskRecord> runtimeTasks;
  final List<RuntimeRunRecord> runtimeRuns;
  final List<PackInstallationRecord> packInstallations;
  final List<PermissionGrantRecord> permissionGrants;
  final List<ContextPacketCacheRecord> contextPacketCaches;
  final List<TraceEventRecord> traceEvents;

  List<ModelProviderConfigRecord> get providerConfigsNeedingCredentialReentry {
    return modelProviderConfigs
        .where((config) => config.hasApiKey && config.apiKey.isEmpty)
        .toList(growable: false);
  }

  JsonMap toJson() {
    return <String, Object?>{
      'manifest': manifest.toJson(),
      _eventLogSection: eventLog.map(_eventToJson).toList(growable: false),
      _capturesSection: captures.map(_captureToJson).toList(growable: false),
      _attachmentsSection: attachments
          .map(_attachmentToJson)
          .toList(growable: false),
      _derivedArtifactsSection: derivedArtifacts
          .map(_derivedArtifactToJson)
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
      _runtimeTasksSection: runtimeTasks
          .map(_runtimeTaskToJson)
          .toList(growable: false),
      _runtimeRunsSection: runtimeRuns
          .map(_runtimeRunToJson)
          .toList(growable: false),
      _packInstallationsSection: packInstallations
          .map(_packInstallationToJson)
          .toList(growable: false),
      _permissionGrantsSection: permissionGrants
          .map(_permissionGrantToJson)
          .toList(growable: false),
      _contextPacketCacheSection: contextPacketCaches
          .map(_contextPacketCacheToJson)
          .toList(growable: false),
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
      _derivedArtifactsSection: derivedArtifacts.length,
      _memoryItemsSection: memoryItems.length,
      _memoryCandidatesSection: memoryCandidates.length,
      _cardsSection: cards.length,
      _insightsSection: insights.length,
      _chatSessionsSection: chatSessions.length,
      _chatMessagesSection: chatMessages.length,
      _modelProviderConfigsSection: modelProviderConfigs.length,
      _todosSection: todos.length,
      _runtimeTasksSection: runtimeTasks.length,
      _runtimeRunsSection: runtimeRuns.length,
      _packInstallationsSection: packInstallations.length,
      _permissionGrantsSection: permissionGrants.length,
      _contextPacketCacheSection: contextPacketCaches.length,
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

final class LocalBackupImportReport {
  const LocalBackupImportReport({
    required this.backupMode,
    required this.includesSecrets,
    required this.providerConfigsRestored,
    required this.providerConfigsNeedingCredentialReentry,
    required this.packInstallationsRestored,
    required this.permissionGrantsRestored,
    required this.runtimeTasksRestored,
    required this.runtimeRunsRestored,
    required this.contextPacketCachesRestored,
  });

  factory LocalBackupImportReport.fromBackup(LocalDataBackup backup) {
    return LocalBackupImportReport(
      backupMode: backup.manifest.backupMode,
      includesSecrets: backup.manifest.includesSecrets,
      providerConfigsRestored: backup.modelProviderConfigs.length,
      providerConfigsNeedingCredentialReentry:
          backup.providerConfigsNeedingCredentialReentry.length,
      packInstallationsRestored: backup.packInstallations.length,
      permissionGrantsRestored: backup.permissionGrants.length,
      runtimeTasksRestored: backup.runtimeTasks.length,
      runtimeRunsRestored: backup.runtimeRuns.length,
      contextPacketCachesRestored: backup.contextPacketCaches.length,
    );
  }

  final LocalBackupMode backupMode;
  final bool includesSecrets;
  final int providerConfigsRestored;
  final int providerConfigsNeedingCredentialReentry;
  final int packInstallationsRestored;
  final int permissionGrantsRestored;
  final int runtimeTasksRestored;
  final int runtimeRunsRestored;
  final int contextPacketCachesRestored;

  bool get requiresCredentialReentry =>
      providerConfigsNeedingCredentialReentry > 0;
}

final class LocalBackupService {
  LocalBackupService(this.database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WideNoteLocalDatabase database;
  final DateTime Function() _clock;

  LocalDataBackup exportBackup({LocalBackupMode mode = LocalBackupMode.safe}) {
    if (mode == LocalBackupMode.encryptedFull) {
      throw UnsupportedError(
        'Encrypted full backup export requires encryption and is not '
        'available in this build.',
      );
    }

    final eventLog = database.eventLog.readAll();
    final captures = database.captures.readAll();
    final attachments = database.attachments.readAll();
    final derivedArtifacts = database.derivedArtifacts.readAll();
    final memoryItems = database.memoryItems.readAll();
    final memoryCandidates = database.memoryCandidates.readAll();
    final cards = database.cards.readAll();
    final insights = database.insights.readAll();
    final chatSessions = database.chatSessions.readAll();
    final chatMessages = database.chatMessages.readAll();
    final modelProviderConfigs = database.modelProviderConfigs
        .readAll()
        .map((config) => _modelProviderConfigForBackup(config, mode))
        .toList(growable: false);
    final todos = database.todos.readAll();
    final runtimeTasks = database.runtimeTasks.readAll();
    final runtimeRuns = database.runtimeRuns.readAll();
    final packInstallations = database.packInstallations.readAll();
    final permissionGrants = database.permissionGrants.readAll();
    final contextPacketCaches = database.contextPacketCaches.readAll();
    final traceEvents = database.traceEvents.readAll();

    return LocalDataBackup(
      manifest: LocalBackupManifest(
        localDbSchemaVersion: database.schemaVersion,
        createdAt: _clock().toUtc(),
        backupMode: mode,
        recordCounts: <String, int>{
          _eventLogSection: eventLog.length,
          _capturesSection: captures.length,
          _attachmentsSection: attachments.length,
          _derivedArtifactsSection: derivedArtifacts.length,
          _memoryItemsSection: memoryItems.length,
          _memoryCandidatesSection: memoryCandidates.length,
          _cardsSection: cards.length,
          _insightsSection: insights.length,
          _chatSessionsSection: chatSessions.length,
          _chatMessagesSection: chatMessages.length,
          _modelProviderConfigsSection: modelProviderConfigs.length,
          _todosSection: todos.length,
          _runtimeTasksSection: runtimeTasks.length,
          _runtimeRunsSection: runtimeRuns.length,
          _packInstallationsSection: packInstallations.length,
          _permissionGrantsSection: permissionGrants.length,
          _contextPacketCacheSection: contextPacketCaches.length,
          _traceEventsSection: traceEvents.length,
        },
      ),
      eventLog: eventLog,
      captures: captures,
      attachments: attachments,
      derivedArtifacts: derivedArtifacts,
      memoryItems: memoryItems,
      memoryCandidates: memoryCandidates,
      cards: cards,
      insights: insights,
      chatSessions: chatSessions,
      chatMessages: chatMessages,
      modelProviderConfigs: modelProviderConfigs,
      todos: todos,
      runtimeTasks: runtimeTasks,
      runtimeRuns: runtimeRuns,
      packInstallations: packInstallations,
      permissionGrants: permissionGrants,
      contextPacketCaches: contextPacketCaches,
      traceEvents: traceEvents,
    );
  }

  String exportJson({LocalBackupMode mode = LocalBackupMode.safe}) {
    return LocalBackupCodec.encode(exportBackup(mode: mode));
  }

  LocalBackupImportReport importJson(
    String source, {
    LocalBackupImportStrategy strategy = LocalBackupImportStrategy.append,
  }) {
    final backup = LocalBackupCodec.decode(source);
    if (backup.manifest.includesSecrets) {
      throw UnsupportedError(
        'Secret-bearing backup JSON import requires a directory restore path.',
      );
    }
    return importBackup(backup, strategy: strategy);
  }

  LocalBackupImportReport importBackup(
    LocalDataBackup backup, {
    LocalBackupImportStrategy strategy = LocalBackupImportStrategy.append,
  }) {
    if (backup.manifest.backupMode == LocalBackupMode.encryptedFull) {
      throw UnsupportedError(
        'Secret-bearing backup import requires encrypted full restore and is '
        'not available in this build.',
      );
    }
    if (backup.manifest.localDbSchemaVersion > LocalDbSchema.currentVersion) {
      throw UnsupportedError(
        'Backup DB schema ${backup.manifest.localDbSchemaVersion} is newer '
        'than supported schema ${LocalDbSchema.currentVersion}.',
      );
    }
    _validateImportIds(
      backup,
      rejectExisting: strategy == LocalBackupImportStrategy.append,
    );

    final rawDatabase = database.rawDatabase;
    rawDatabase.execute('BEGIN IMMEDIATE;');
    try {
      if (strategy == LocalBackupImportStrategy.replaceAll) {
        _clearRestorableTables(rawDatabase);
      }
      for (final capture in backup.captures) {
        database.captures.insert(capture);
      }
      for (final attachment in backup.attachments) {
        database.attachments.insert(attachment);
      }
      for (final artifact in backup.derivedArtifacts) {
        database.derivedArtifacts.insert(artifact);
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
      for (final installation in backup.packInstallations) {
        database.packInstallations.insert(installation);
      }
      for (final grant in backup.permissionGrants) {
        database.permissionGrants.insert(grant);
      }
      for (final task in backup.runtimeTasks) {
        database.runtimeTasks.insert(task);
      }
      for (final run in backup.runtimeRuns) {
        database.runtimeRuns.insert(run);
      }
      for (final cache in backup.contextPacketCaches) {
        database.contextPacketCaches.insert(cache);
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
      return LocalBackupImportReport.fromBackup(backup);
    } catch (_) {
      rawDatabase.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _validateImportIds(
    LocalDataBackup backup, {
    required bool rejectExisting,
  }) {
    _rejectExistingOrDuplicateIds(
      _capturesSection,
      backup.captures.map((record) => record.id),
      rejectExisting ? (id) => database.captures.readById(id) != null : null,
    );
    _rejectExistingOrDuplicateIds(
      _attachmentsSection,
      backup.attachments.map((record) => record.id),
      rejectExisting ? (id) => database.attachments.readById(id) != null : null,
    );
    _rejectExistingOrDuplicateIds(
      _derivedArtifactsSection,
      backup.derivedArtifacts.map((record) => record.id),
      rejectExisting
          ? (id) => database.derivedArtifacts.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _eventLogSection,
      backup.eventLog.map((record) => record.id),
      rejectExisting ? (id) => database.eventLog.readById(id) != null : null,
    );
    _rejectExistingOrDuplicateIds(
      _memoryItemsSection,
      backup.memoryItems.map((record) => record.id),
      rejectExisting ? (id) => database.memoryItems.readById(id) != null : null,
    );
    _rejectExistingOrDuplicateIds(
      _memoryCandidatesSection,
      backup.memoryCandidates.map((record) => record.id),
      rejectExisting
          ? (id) => database.memoryCandidates.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _cardsSection,
      backup.cards.map((record) => record.id),
      rejectExisting ? (id) => database.cards.readById(id) != null : null,
    );
    _rejectExistingOrDuplicateIds(
      _insightsSection,
      backup.insights.map((record) => record.id),
      rejectExisting ? (id) => database.insights.readById(id) != null : null,
    );
    _rejectExistingOrDuplicateIds(
      _chatSessionsSection,
      backup.chatSessions.map((record) => record.id),
      rejectExisting
          ? (id) => database.chatSessions.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _chatMessagesSection,
      backup.chatMessages.map((record) => record.id),
      rejectExisting
          ? (id) => database.chatMessages.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _modelProviderConfigsSection,
      backup.modelProviderConfigs.map((record) => record.id),
      rejectExisting
          ? (id) => database.modelProviderConfigs.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _todosSection,
      backup.todos.map((record) => record.id),
      rejectExisting ? (id) => database.todos.readById(id) != null : null,
    );
    _rejectExistingOrDuplicateIds(
      _runtimeTasksSection,
      backup.runtimeTasks.map((record) => record.id),
      rejectExisting
          ? (id) => database.runtimeTasks.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _runtimeRunsSection,
      backup.runtimeRuns.map((record) => record.id),
      rejectExisting ? (id) => database.runtimeRuns.readById(id) != null : null,
    );
    _rejectExistingOrDuplicateIds(
      _packInstallationsSection,
      backup.packInstallations.map((record) => record.packId),
      rejectExisting
          ? (id) => database.packInstallations.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _permissionGrantsSection,
      backup.permissionGrants.map((record) => record.id),
      rejectExisting
          ? (id) => database.permissionGrants.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _contextPacketCacheSection,
      backup.contextPacketCaches.map((record) => record.id),
      rejectExisting
          ? (id) => database.contextPacketCaches.readById(id) != null
          : null,
    );
    _rejectExistingOrDuplicateIds(
      _traceEventsSection,
      backup.traceEvents.map((record) => record.id),
      rejectExisting ? (id) => database.traceEvents.readById(id) != null : null,
    );
  }
}

void _rejectExistingOrDuplicateIds(
  String section,
  Iterable<String> ids,
  bool Function(String id)? exists,
) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw FormatException(
        'Backup section $section contains duplicate id $id.',
      );
    }
    if (exists != null && exists(id)) {
      throw StateError(
        'Backup import would overwrite existing $section row $id.',
      );
    }
  }
}

void _clearRestorableTables(Database rawDatabase) {
  for (final table in const <String>[
    'trace_events',
    'context_packet_cache',
    'runtime_approval_requests',
    'permission_grants',
    'runtime_runs',
    'runtime_tasks',
    'pack_installations',
    'todos',
    'model_provider_configs',
    'chat_messages',
    'chat_sessions',
    'insights',
    'cards',
    'memory_candidates',
    'memory_items',
    'derived_artifacts',
    'attachments',
    'event_log',
    'captures',
  ]) {
    rawDatabase.execute('DELETE FROM $table;');
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

JsonMap _derivedArtifactToJson(DerivedArtifactRecord artifact) {
  return <String, Object?>{
    'id': artifact.id,
    'schema_version': artifact.schemaVersion,
    'source_capture_id': artifact.sourceCaptureId,
    'source_attachment_id': artifact.sourceAttachmentId,
    'source_event_id': artifact.sourceEventId,
    'artifact_kind': artifact.artifactKind,
    'status': artifact.status,
    'title': artifact.title,
    'body': artifact.body,
    'mime_type': artifact.mimeType,
    'storage_path': artifact.storagePath,
    'content_hash': artifact.contentHash,
    'source_refs': artifact.sourceRefs,
    'sensitivity': artifact.sensitivity,
    'confidence': artifact.confidence,
    'generator_id': artifact.generatorId,
    'generator_version': artifact.generatorVersion,
    'payload': artifact.payload,
    'created_at': _dateTimeToJson(artifact.createdAt),
    'updated_at': _dateTimeToJson(artifact.updatedAt),
    'invalidated_at': _optionalDateTimeToJson(artifact.invalidatedAt),
  };
}

DerivedArtifactRecord _derivedArtifactFromJson(JsonMap json) {
  return DerivedArtifactRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    sourceCaptureId: _requiredString(json, 'source_capture_id'),
    sourceAttachmentId: _optionalString(json, 'source_attachment_id'),
    sourceEventId: _optionalString(json, 'source_event_id'),
    artifactKind: _requiredString(json, 'artifact_kind'),
    status: _requiredString(json, 'status'),
    title: _requiredString(json, 'title'),
    body: _requiredString(json, 'body'),
    mimeType: _optionalString(json, 'mime_type'),
    storagePath: _optionalString(json, 'storage_path'),
    contentHash: _optionalString(json, 'content_hash'),
    sourceRefs: _requiredList(json, 'source_refs'),
    sensitivity: _requiredString(json, 'sensitivity'),
    confidence: _requiredString(json, 'confidence'),
    generatorId: _requiredString(json, 'generator_id'),
    generatorVersion: _requiredString(json, 'generator_version'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
    invalidatedAt: _optionalDateTime(json, 'invalidated_at'),
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

JsonMap _runtimeTaskToJson(RuntimeTaskRecord task) {
  return <String, Object?>{
    'id': task.id,
    'schema_version': task.schemaVersion,
    'pack_id': task.packId,
    'pack_version': task.packVersion,
    'agent_id': task.agentId,
    'handler_id': task.handlerId,
    'subscription_id': task.subscriptionId,
    'trigger_event_id': task.triggerEventId,
    'identity_key': task.effectiveIdentityKey,
    'status': task.status,
    'dependency_task_ids': task.dependencyTaskIds,
    'missing_dependency_ids': task.missingDependencyIds,
    'attempts': task.attempts,
    'max_attempts': task.maxAttempts,
    'lease_owner': task.leaseOwner,
    'leased_until': _optionalDateTimeToJson(task.leasedUntil),
    'scheduled_at': _optionalDateTimeToJson(task.scheduledAt),
    'concurrency_key': task.concurrencyKey,
    'error': task.error,
    'payload': task.payload,
    'created_at': _dateTimeToJson(task.createdAt),
    'updated_at': _dateTimeToJson(task.updatedAt),
  };
}

RuntimeTaskRecord _runtimeTaskFromJson(JsonMap json) {
  return RuntimeTaskRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    packId: _requiredString(json, 'pack_id'),
    packVersion: _requiredString(json, 'pack_version'),
    agentId: _requiredString(json, 'agent_id'),
    handlerId: _requiredString(json, 'handler_id'),
    subscriptionId: _requiredString(json, 'subscription_id'),
    triggerEventId: _requiredString(json, 'trigger_event_id'),
    identityKey: _requiredString(json, 'identity_key'),
    status: _requiredString(json, 'status'),
    dependencyTaskIds: _requiredList(json, 'dependency_task_ids'),
    missingDependencyIds: _requiredList(json, 'missing_dependency_ids'),
    attempts: _requiredInt(json, 'attempts'),
    maxAttempts: _requiredInt(json, 'max_attempts'),
    leaseOwner: _optionalString(json, 'lease_owner'),
    leasedUntil: _optionalDateTime(json, 'leased_until'),
    scheduledAt: _optionalDateTime(json, 'scheduled_at'),
    concurrencyKey: _optionalString(json, 'concurrency_key'),
    error: _optionalString(json, 'error'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _runtimeRunToJson(RuntimeRunRecord run) {
  return <String, Object?>{
    'id': run.id,
    'schema_version': run.schemaVersion,
    'task_id': run.taskId,
    'pack_id': run.packId,
    'pack_version': run.packVersion,
    'agent_id': run.agentId,
    'handler_id': run.handlerId,
    'status': run.status,
    'attempt': run.attempt,
    'output_event_ids': run.outputEventIds,
    'error': run.error,
    'payload': run.payload,
    'started_at': _dateTimeToJson(run.startedAt),
    'completed_at': _optionalDateTimeToJson(run.completedAt),
  };
}

RuntimeRunRecord _runtimeRunFromJson(JsonMap json) {
  return RuntimeRunRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    taskId: _requiredString(json, 'task_id'),
    packId: _requiredString(json, 'pack_id'),
    packVersion: _requiredString(json, 'pack_version'),
    agentId: _requiredString(json, 'agent_id'),
    handlerId: _requiredString(json, 'handler_id'),
    status: _requiredString(json, 'status'),
    attempt: _requiredInt(json, 'attempt'),
    outputEventIds: _requiredList(json, 'output_event_ids'),
    error: _optionalString(json, 'error'),
    payload: _requiredMap(json, 'payload'),
    startedAt: _requiredDateTime(json, 'started_at'),
    completedAt: _optionalDateTime(json, 'completed_at'),
  );
}

JsonMap _packInstallationToJson(PackInstallationRecord installation) {
  return <String, Object?>{
    'pack_id': installation.packId,
    'schema_version': installation.schemaVersion,
    'name': installation.name,
    'version': installation.version,
    'publisher': installation.publisher,
    'edition': installation.edition,
    'status': installation.status,
    'runtime_status': installation.runtimeStatus,
    'entrypoint_kind': installation.entrypointKind,
    'requested_permissions': installation.requestedPermissions,
    'enabled_subscription_ids': installation.enabledSubscriptionIds,
    'manifest': installation.manifest,
    'payload': installation.payload,
    'installed_at': _dateTimeToJson(installation.installedAt),
    'updated_at': _dateTimeToJson(installation.updatedAt),
  };
}

PackInstallationRecord _packInstallationFromJson(JsonMap json) {
  return PackInstallationRecord(
    packId: _requiredString(json, 'pack_id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    name: _requiredString(json, 'name'),
    version: _requiredString(json, 'version'),
    publisher: _requiredString(json, 'publisher'),
    edition: _requiredString(json, 'edition'),
    status: _requiredString(json, 'status'),
    runtimeStatus: _requiredString(json, 'runtime_status'),
    entrypointKind: _requiredString(json, 'entrypoint_kind'),
    requestedPermissions: _requiredList(json, 'requested_permissions'),
    enabledSubscriptionIds: _requiredList(json, 'enabled_subscription_ids'),
    manifest: _requiredMap(json, 'manifest'),
    payload: _requiredMap(json, 'payload'),
    installedAt: _requiredDateTime(json, 'installed_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _permissionGrantToJson(PermissionGrantRecord grant) {
  return <String, Object?>{
    'id': grant.id,
    'schema_version': grant.schemaVersion,
    'pack_id': grant.packId,
    'permission_id': grant.permissionId,
    'status': grant.status,
    'grant_kind': grant.grantKind,
    'source_event_id': grant.sourceEventId,
    'granted_at': _optionalDateTimeToJson(grant.grantedAt),
    'revoked_at': _optionalDateTimeToJson(grant.revokedAt),
    'reason': grant.reason,
    'payload': grant.payload,
    'created_at': _dateTimeToJson(grant.createdAt),
    'updated_at': _dateTimeToJson(grant.updatedAt),
  };
}

PermissionGrantRecord _permissionGrantFromJson(JsonMap json) {
  return PermissionGrantRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    packId: _requiredString(json, 'pack_id'),
    permissionId: _requiredString(json, 'permission_id'),
    status: _requiredString(json, 'status'),
    grantKind: _requiredString(json, 'grant_kind'),
    sourceEventId: _optionalString(json, 'source_event_id'),
    grantedAt: _optionalDateTime(json, 'granted_at'),
    revokedAt: _optionalDateTime(json, 'revoked_at'),
    reason: _optionalString(json, 'reason'),
    payload: _requiredMap(json, 'payload'),
    createdAt: _requiredDateTime(json, 'created_at'),
    updatedAt: _requiredDateTime(json, 'updated_at'),
  );
}

JsonMap _contextPacketCacheToJson(ContextPacketCacheRecord cache) {
  return <String, Object?>{
    'id': cache.id,
    'schema_version': cache.schemaVersion,
    'surface': cache.surface,
    'request_ref': cache.requestRef,
    'subject_ref': cache.subjectRef,
    'source_refs': cache.sourceRefs,
    'source_versions': cache.sourceVersions,
    'permission_scope': cache.permissionScope,
    'disclosure_level': cache.disclosureLevel,
    'generator_id': cache.generatorId,
    'generator_version': cache.generatorVersion,
    'prompt_version': cache.promptVersion,
    'pack_id': cache.packId,
    'pack_version': cache.packVersion,
    'agent_id': cache.agentId,
    'local_date': cache.localDate,
    'privacy_profile': cache.privacyProfile,
    'invalidation_keys': cache.invalidationKeys,
    'cache_key': cache.cacheKey,
    'status': cache.status,
    'packet': cache.packet,
    'expires_at': _optionalDateTimeToJson(cache.expiresAt),
    'invalidated_at': _optionalDateTimeToJson(cache.invalidatedAt),
    'created_at': _dateTimeToJson(cache.createdAt),
    'updated_at': _dateTimeToJson(cache.updatedAt),
  };
}

ContextPacketCacheRecord _contextPacketCacheFromJson(JsonMap json) {
  return ContextPacketCacheRecord(
    id: _requiredString(json, 'id'),
    schemaVersion: _requiredInt(json, 'schema_version'),
    surface: _requiredString(json, 'surface'),
    requestRef: _requiredMap(json, 'request_ref'),
    subjectRef: _requiredMap(json, 'subject_ref'),
    sourceRefs: _requiredList(json, 'source_refs'),
    sourceVersions: _requiredList(json, 'source_versions'),
    permissionScope: _requiredString(json, 'permission_scope'),
    disclosureLevel: _requiredString(json, 'disclosure_level'),
    generatorId: _requiredString(json, 'generator_id'),
    generatorVersion: _requiredString(json, 'generator_version'),
    promptVersion: _requiredString(json, 'prompt_version'),
    packId: _optionalString(json, 'pack_id'),
    packVersion: _optionalString(json, 'pack_version'),
    agentId: _optionalString(json, 'agent_id'),
    localDate: _optionalString(json, 'local_date'),
    privacyProfile: _requiredString(json, 'privacy_profile'),
    invalidationKeys: _requiredList(json, 'invalidation_keys'),
    cacheKey: _requiredString(json, 'cache_key'),
    status: _requiredString(json, 'status'),
    packet: _requiredMap(json, 'packet'),
    expiresAt: _optionalDateTime(json, 'expires_at'),
    invalidatedAt: _optionalDateTime(json, 'invalidated_at'),
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
    if (_missingSectionAllowed(section, sourceFormatVersion) &&
        !json.containsKey(section)) {
      counts[section] = 0;
    } else {
      counts[section] = _requiredInt(json, section);
    }
  }
  return counts;
}

bool _missingSectionAllowed(String section, int sourceFormatVersion) {
  if (section == _contextPacketCacheSection) {
    return true;
  }
  if (section == _attachmentsSection && sourceFormatVersion < 2) {
    return true;
  }
  if (section == _derivedArtifactsSection && sourceFormatVersion < 4) {
    return true;
  }
  if (_v3BackupSections.contains(section) && sourceFormatVersion < 3) {
    return true;
  }
  return false;
}

const _v3BackupSections = <String>{
  _runtimeTasksSection,
  _runtimeRunsSection,
  _packInstallationsSection,
  _permissionGrantsSection,
  _contextPacketCacheSection,
};

LocalBackupMode _backupModeFromJson(JsonMap json, int sourceFormatVersion) {
  final value = json['backup_mode'];
  if (value == null) {
    return sourceFormatVersion < 3
        ? LocalBackupMode.encryptedFull
        : LocalBackupMode.safe;
  }
  if (value is String) {
    return LocalBackupMode.fromWireName(value);
  }
  throw const FormatException('Backup field backup_mode must be a string.');
}

String _optionalManifestKind(JsonMap json) {
  final value = json['kind'];
  if (value == null) {
    return 'backup_manifest';
  }
  if (value is String) {
    return value;
  }
  throw const FormatException('Backup field kind must be a string.');
}

int _optionalManifestSchemaVersion(JsonMap json) {
  final value = json['schema_version'];
  if (value == null) {
    return 1;
  }
  if (value is int) {
    return value;
  }
  throw const FormatException(
    'Backup field schema_version must be an integer.',
  );
}

bool _optionalIncludesSecrets(JsonMap json, LocalBackupMode mode) {
  final value = json['includes_secrets'];
  if (value == null) {
    return _backupModeIncludesSecrets(mode);
  }
  if (value is bool) {
    return value;
  }
  throw const FormatException(
    'Backup field includes_secrets must be a boolean.',
  );
}

ModelProviderConfigRecord _modelProviderConfigForBackup(
  ModelProviderConfigRecord config,
  LocalBackupMode mode,
) {
  if (mode != LocalBackupMode.safe) {
    return config;
  }
  return ModelProviderConfigRecord(
    id: config.id,
    schemaVersion: config.schemaVersion,
    providerKind: config.providerKind,
    displayName: config.displayName,
    endpoint: config.endpoint,
    model: config.model,
    status: config.status,
    isDefault: config.isDefault,
    hasApiKey: config.hasApiKey,
    apiKey: '',
    capabilities: config.capabilities,
    payload: _providerPayloadForBackup(config.payload, mode),
    createdAt: config.createdAt,
    updatedAt: config.updatedAt,
  );
}

JsonMap _providerPayloadForBackup(JsonMap payload, LocalBackupMode mode) {
  if (mode != LocalBackupMode.safe) {
    return payload;
  }
  final safe = <String, Object?>{};
  for (final key in const <String>[
    'secret_storage',
    'has_api_key',
    'api_key_present',
  ]) {
    final value = payload[key];
    if (value is String || value is bool || value is num) {
      safe[key] = value;
    }
  }
  if (payload.isNotEmpty && safe.length != payload.length) {
    safe['payload_omitted'] = true;
  }
  return safe;
}

bool _backupModeIncludesSecrets(LocalBackupMode mode) {
  return switch (mode) {
    LocalBackupMode.safe => false,
    LocalBackupMode.full || LocalBackupMode.encryptedFull => true,
  };
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

JsonMap? _optionalMap(JsonMap json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('Backup field $key must be an object or null.');
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

DateTime? _optionalDateTime(JsonMap json, String key) {
  final value = _optionalString(json, key);
  if (value == null) {
    return null;
  }
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('Backup field $key must be an ISO-8601 timestamp.');
  }
}

String _dateTimeToJson(DateTime value) {
  return value.toUtc().toIso8601String();
}

String? _optionalDateTimeToJson(DateTime? value) {
  return value == null ? null : _dateTimeToJson(value);
}
