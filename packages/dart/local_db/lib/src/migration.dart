import 'package:sqlite3/sqlite3.dart';

abstract final class LocalDbSchema {
  static const currentVersion = 8;
}

final class LocalDbMigrator {
  const LocalDbMigrator._();

  static void bootstrap(
    Database database, {
    int targetVersion = LocalDbSchema.currentVersion,
  }) {
    if (targetVersion > LocalDbSchema.currentVersion) {
      throw UnsupportedError(
        'Requested schema $targetVersion is newer than supported '
        'schema ${LocalDbSchema.currentVersion}.',
      );
    }

    database.execute('PRAGMA foreign_keys = ON;');

    final currentVersion = readSchemaVersion(database);
    if (currentVersion > targetVersion) {
      throw UnsupportedError(
        'Database schema $currentVersion is newer than supported '
        'schema $targetVersion.',
      );
    }
    if (currentVersion == targetVersion) {
      return;
    }

    database.execute('BEGIN IMMEDIATE;');
    try {
      if (currentVersion < 1 && targetVersion >= 1) {
        _createV1(database);
        database.execute('PRAGMA user_version = 1;');
      }
      if (currentVersion < 2 && targetVersion >= 2) {
        _migrateToV2(database);
        database.execute('PRAGMA user_version = 2;');
      }
      if (currentVersion < 3 && targetVersion >= 3) {
        _migrateToV3(database);
        database.execute('PRAGMA user_version = 3;');
      }
      if (currentVersion < 4 && targetVersion >= 4) {
        _migrateToV4(database);
        database.execute('PRAGMA user_version = 4;');
      }
      if (currentVersion < 5 && targetVersion >= 5) {
        _migrateToV5(database);
        database.execute('PRAGMA user_version = 5;');
      }
      if (currentVersion < 6 && targetVersion >= 6) {
        _migrateToV6(database);
        database.execute('PRAGMA user_version = 6;');
      }
      if (currentVersion < 7 && targetVersion >= 7) {
        _migrateToV7(database);
        database.execute('PRAGMA user_version = 7;');
      }
      if (currentVersion < 8 && targetVersion >= 8) {
        _migrateToV8(database);
        database.execute('PRAGMA user_version = 8;');
      }
      database.execute('COMMIT;');
    } catch (_) {
      database.execute('ROLLBACK;');
      rethrow;
    }
  }

  static int readSchemaVersion(Database database) {
    final result = database.select('PRAGMA user_version;');
    return result.first['user_version'] as int;
  }

  static void _createV1(Database database) {
    database
      ..execute('''
CREATE TABLE IF NOT EXISTS event_log (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  actor TEXT NOT NULL,
  status TEXT NOT NULL,
  source_capture_id TEXT,
  source_event_id TEXT,
  subject_kind TEXT,
  subject_id TEXT,
  pack_id TEXT,
  agent_id TEXT,
  device_id TEXT,
  causation_id TEXT,
  correlation_id TEXT,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS event_log_type_created_at_idx
ON event_log(type, created_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS event_log_source_event_idx
ON event_log(source_event_id);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS captures (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  source_type TEXT NOT NULL,
  source_id TEXT,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS captures_created_at_idx
ON captures(created_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS captures_status_idx
ON captures(status);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS memory_items (
  id TEXT PRIMARY KEY,
  memory_key TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  source_capture_id TEXT,
  source_event_id TEXT,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS memory_items_key_idx
ON memory_items(memory_key);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS memory_items_status_idx
ON memory_items(status);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS memory_candidates (
  id TEXT PRIMARY KEY,
  candidate_key TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  source_capture_id TEXT,
  source_event_id TEXT,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS memory_candidates_status_idx
ON memory_candidates(status);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS todos (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  source_capture_id TEXT,
  source_event_id TEXT,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS todos_status_idx
ON todos(status);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS trace_events (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  level TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  source_event_id TEXT,
  source_run_id TEXT,
  source_task_id TEXT,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS trace_events_run_idx
ON trace_events(source_run_id, created_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS trace_events_name_idx
ON trace_events(name);
''');
  }

  static void _migrateToV2(Database database) {
    database
      ..execute('''
ALTER TABLE event_log
ADD COLUMN privacy TEXT NOT NULL DEFAULT 'local_only';
''')
      ..execute('''
ALTER TABLE event_log
ADD COLUMN subject_ref_json TEXT NOT NULL DEFAULT '{}';
''')
      ..execute('''
UPDATE event_log
SET subject_ref_json = json_object('kind', subject_kind, 'id', subject_id)
WHERE subject_kind IS NOT NULL AND subject_id IS NOT NULL;
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS event_log_subject_idx
ON event_log(subject_kind, subject_id);
''')
      ..execute('''
ALTER TABLE memory_items
ADD COLUMN body TEXT NOT NULL DEFAULT '';
''')
      ..execute('''
ALTER TABLE memory_items
ADD COLUMN source_refs_json TEXT NOT NULL DEFAULT '[]';
''')
      ..execute('''
ALTER TABLE memory_items
ADD COLUMN memory_type TEXT NOT NULL DEFAULT 'project';
''')
      ..execute('''
ALTER TABLE memory_items
ADD COLUMN confidence TEXT NOT NULL DEFAULT 'medium';
''')
      ..execute('''
ALTER TABLE memory_items
ADD COLUMN sensitivity TEXT NOT NULL DEFAULT 'low';
''')
      ..execute('''
ALTER TABLE memory_items
ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;
''')
      ..execute('''
ALTER TABLE memory_items
ADD COLUMN tombstone INTEGER NOT NULL DEFAULT 0;
''')
      ..execute('''
ALTER TABLE memory_candidates
ADD COLUMN body TEXT NOT NULL DEFAULT '';
''')
      ..execute('''
ALTER TABLE memory_candidates
ADD COLUMN source_refs_json TEXT NOT NULL DEFAULT '[]';
''')
      ..execute('''
ALTER TABLE memory_candidates
ADD COLUMN memory_type TEXT NOT NULL DEFAULT 'project';
''')
      ..execute('''
ALTER TABLE memory_candidates
ADD COLUMN confidence TEXT NOT NULL DEFAULT 'medium';
''')
      ..execute('''
ALTER TABLE memory_candidates
ADD COLUMN sensitivity TEXT NOT NULL DEFAULT 'low';
''')
      ..execute('''
ALTER TABLE trace_events
ADD COLUMN trace_type TEXT NOT NULL DEFAULT '';
''')
      ..execute('''
ALTER TABLE trace_events
ADD COLUMN run_id TEXT;
''')
      ..execute('''
ALTER TABLE trace_events
ADD COLUMN severity TEXT NOT NULL DEFAULT 'info';
''')
      ..execute('''
UPDATE trace_events
SET trace_type = name,
    run_id = source_run_id,
    severity = level;
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS trace_events_run_id_idx
ON trace_events(run_id, created_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS trace_events_trace_type_idx
ON trace_events(trace_type);
''');
  }

  static void _migrateToV3(Database database) {
    database
      ..execute('''
ALTER TABLE trace_events
ADD COLUMN message TEXT NOT NULL DEFAULT '';
''')
      ..execute('''
ALTER TABLE trace_events
ADD COLUMN pack_id TEXT;
''')
      ..execute('''
ALTER TABLE trace_events
ADD COLUMN agent_id TEXT;
''')
      ..execute('''
ALTER TABLE trace_events
ADD COLUMN parent_trace_id TEXT;
''')
      ..execute('''
ALTER TABLE trace_events
ADD COLUMN duration_ms REAL;
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS trace_events_pack_agent_idx
ON trace_events(pack_id, agent_id, created_at);
''');
  }

  static void _migrateToV4(Database database) {
    database
      ..execute('''
CREATE TABLE IF NOT EXISTS cards (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  card_kind TEXT NOT NULL,
  status TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  source_refs_json TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS cards_kind_created_at_idx
ON cards(card_kind, created_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS cards_status_idx
ON cards(status);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS insights (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  insight_kind TEXT NOT NULL,
  status TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  source_refs_json TEXT NOT NULL,
  metric_label TEXT,
  metric_value REAL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS insights_kind_created_at_idx
ON insights(insight_kind, created_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS insights_status_idx
ON insights(status);
''');
  }

  static void _migrateToV5(Database database) {
    database
      ..execute('''
CREATE TABLE IF NOT EXISTS chat_sessions (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS chat_sessions_updated_at_idx
ON chat_sessions(updated_at);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS chat_messages (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL,
  status TEXT NOT NULL,
  body TEXT NOT NULL,
  source_refs_json TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS chat_messages_session_created_at_idx
ON chat_messages(session_id, created_at);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS model_provider_configs (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  provider_kind TEXT NOT NULL,
  display_name TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  model TEXT NOT NULL,
  status TEXT NOT NULL,
  is_default INTEGER NOT NULL,
  has_api_key INTEGER NOT NULL,
  capabilities_json TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS model_provider_configs_default_idx
ON model_provider_configs(is_default);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS model_provider_configs_kind_idx
ON model_provider_configs(provider_kind);
''');
  }

  static void _migrateToV6(Database database) {
    database.execute('''
ALTER TABLE model_provider_configs
ADD COLUMN api_key TEXT NOT NULL DEFAULT '';
''');
  }

  static void _migrateToV7(Database database) {
    database
      ..execute('''
CREATE TABLE IF NOT EXISTS attachments (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  capture_id TEXT NOT NULL,
  source_event_id TEXT,
  asset_kind TEXT NOT NULL,
  mime_type TEXT,
  storage_path TEXT NOT NULL,
  original_file_name TEXT,
  sha256 TEXT,
  byte_length INTEGER,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(capture_id) REFERENCES captures(id) ON DELETE CASCADE
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS attachments_capture_idx
ON attachments(capture_id, created_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS attachments_status_idx
ON attachments(status);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS attachments_sha256_idx
ON attachments(sha256);
''');
  }

  static void _migrateToV8(Database database) {
    database
      ..execute('''
CREATE TABLE IF NOT EXISTS runtime_tasks (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  pack_id TEXT NOT NULL,
  pack_version TEXT NOT NULL,
  agent_id TEXT NOT NULL,
  handler_id TEXT NOT NULL,
  subscription_id TEXT NOT NULL,
  trigger_event_id TEXT NOT NULL,
  identity_key TEXT NOT NULL,
  status TEXT NOT NULL,
  dependency_task_ids_json TEXT NOT NULL,
  missing_dependency_ids_json TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  max_attempts INTEGER NOT NULL,
  lease_owner TEXT,
  leased_until TEXT,
  error TEXT,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(trigger_event_id) REFERENCES event_log(id) ON DELETE CASCADE
);
''')
      ..execute('''
CREATE UNIQUE INDEX IF NOT EXISTS runtime_tasks_identity_key_idx
ON runtime_tasks(identity_key);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS runtime_tasks_pack_status_idx
ON runtime_tasks(pack_id, status, updated_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS runtime_tasks_trigger_event_idx
ON runtime_tasks(trigger_event_id);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS runtime_tasks_subscription_idx
ON runtime_tasks(pack_id, subscription_id, trigger_event_id);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS runtime_runs (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  task_id TEXT NOT NULL,
  pack_id TEXT NOT NULL,
  pack_version TEXT NOT NULL,
  agent_id TEXT NOT NULL,
  handler_id TEXT NOT NULL,
  status TEXT NOT NULL,
  attempt INTEGER NOT NULL,
  output_event_ids_json TEXT NOT NULL,
  error TEXT,
  payload_json TEXT NOT NULL,
  started_at TEXT NOT NULL,
  completed_at TEXT,
  FOREIGN KEY(task_id) REFERENCES runtime_tasks(id) ON DELETE CASCADE
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS runtime_runs_task_idx
ON runtime_runs(task_id, started_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS runtime_runs_pack_status_idx
ON runtime_runs(pack_id, status, started_at);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS pack_installations (
  pack_id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  name TEXT NOT NULL,
  version TEXT NOT NULL,
  publisher TEXT NOT NULL,
  edition TEXT NOT NULL,
  status TEXT NOT NULL,
  runtime_status TEXT NOT NULL,
  entrypoint_kind TEXT NOT NULL,
  requested_permissions_json TEXT NOT NULL,
  enabled_subscription_ids_json TEXT NOT NULL,
  manifest_json TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  installed_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS pack_installations_status_idx
ON pack_installations(status, runtime_status);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS pack_installations_edition_idx
ON pack_installations(edition);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS permission_grants (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  pack_id TEXT NOT NULL,
  permission_id TEXT NOT NULL,
  status TEXT NOT NULL,
  grant_kind TEXT NOT NULL,
  source_event_id TEXT,
  granted_at TEXT,
  revoked_at TEXT,
  reason TEXT,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(pack_id) REFERENCES pack_installations(pack_id) ON DELETE CASCADE,
  UNIQUE(pack_id, permission_id)
);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS permission_grants_pack_status_idx
ON permission_grants(pack_id, status);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS permission_grants_permission_idx
ON permission_grants(permission_id);
''')
      ..execute('''
CREATE TABLE IF NOT EXISTS context_packet_cache (
  id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  surface TEXT NOT NULL,
  request_ref_json TEXT NOT NULL,
  subject_ref_json TEXT NOT NULL,
  source_refs_json TEXT NOT NULL,
  source_versions_json TEXT NOT NULL,
  permission_scope TEXT NOT NULL,
  disclosure_level TEXT NOT NULL,
  generator_id TEXT NOT NULL,
  generator_version TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  pack_id TEXT,
  pack_version TEXT,
  agent_id TEXT,
  local_date TEXT,
  privacy_profile TEXT NOT NULL,
  invalidation_keys_json TEXT NOT NULL,
  cache_key TEXT NOT NULL,
  status TEXT NOT NULL,
  packet_json TEXT NOT NULL,
  expires_at TEXT,
  invalidated_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(pack_id) REFERENCES pack_installations(pack_id) ON DELETE SET NULL
);
''')
      ..execute('''
CREATE UNIQUE INDEX IF NOT EXISTS context_packet_cache_key_idx
ON context_packet_cache(cache_key);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS context_packet_cache_subject_idx
ON context_packet_cache(surface, status, updated_at);
''')
      ..execute('''
CREATE INDEX IF NOT EXISTS context_packet_cache_pack_idx
ON context_packet_cache(pack_id, agent_id, status);
''');
  }
}
