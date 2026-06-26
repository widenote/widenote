import 'backup_export.dart';
import 'json.dart';

final class LocalMarkdownExportService {
  const LocalMarkdownExportService();

  String exportBackup(LocalDataBackup backup) {
    final buffer = StringBuffer()
      ..writeln('# WideNote Owner Export')
      ..writeln()
      ..writeln('- format: ${backup.manifest.format}')
      ..writeln('- format_version: ${backup.manifest.formatVersion}')
      ..writeln('- backup_mode: ${backup.manifest.backupMode.wireName}')
      ..writeln('- includes_secrets: ${backup.manifest.includesSecrets}')
      ..writeln('- local_db_schema: ${backup.manifest.localDbSchemaVersion}')
      ..writeln('- exported_at: ${backup.manifest.createdAt.toIso8601String()}')
      ..writeln();
    _writeRestoreBoundary(buffer, backup);
    _writeCounts(buffer, backup);
    _writeCaptures(buffer, backup);
    _writeMemory(buffer, backup);
    _writeCards(buffer, backup);
    _writeInsights(buffer, backup);
    _writeTodos(buffer, backup);
    _writeConversations(buffer, backup);
    _writeProviders(buffer, backup);
    _writeRuntimeState(buffer, backup);
    _writeTraces(buffer, backup);
    return buffer.toString();
  }

  void _writeRestoreBoundary(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Export Boundary')
      ..writeln()
      ..writeln('- owner_export: readable, secret-free projection')
      ..writeln(
        '- restore_source: use the paired JSON backup, not this Markdown',
      )
      ..writeln('- provider_keys_in_markdown: never')
      ..writeln('- context_packet_cache_in_markdown: excluded, rebuildable')
      ..writeln(
        '- provider_keys_needed_after_safe_restore: '
        '${backup.providerConfigsNeedingCredentialReentry.length}',
      )
      ..writeln();
  }

  void _writeCounts(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Manifest Counts')
      ..writeln();
    for (final entry in backup.manifest.recordCounts.entries) {
      if (entry.key == 'context_packet_cache') {
        continue;
      }
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
    buffer.writeln();
  }

  void _writeCaptures(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Records')
      ..writeln();
    if (backup.captures.isEmpty) {
      buffer
        ..writeln('_No local records exported._')
        ..writeln();
      return;
    }
    for (final capture in backup.captures) {
      _writeItem(
        buffer,
        title: capture.id,
        metadata: <String>[
          'created: ${capture.createdAt.toIso8601String()}',
          'status: ${capture.status}',
          'source_type: ${capture.sourceType}',
        ],
        body: _firstText(capture.payload, const <String>['text', 'raw_text']),
      );
    }
  }

  void _writeMemory(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Memory')
      ..writeln();
    if (backup.memoryItems.isEmpty && backup.memoryCandidates.isEmpty) {
      buffer
        ..writeln('_No Memory exported._')
        ..writeln();
      return;
    }
    for (final item in backup.memoryItems) {
      _writeItem(
        buffer,
        title: item.key,
        metadata: <String>[
          'id: ${item.id}',
          'status: ${item.status}',
          'type: ${item.memoryType}',
          'confidence: ${item.confidence}',
          'sensitivity: ${item.sensitivity}',
          'revision: ${item.revision}',
          if (item.sourceRefs.isNotEmpty)
            'sources: ${_sourceRefs(item.sourceRefs)}',
        ],
        body: item.body,
      );
    }
    for (final candidate in backup.memoryCandidates) {
      _writeItem(
        buffer,
        title: 'candidate/${candidate.key}',
        metadata: <String>[
          'id: ${candidate.id}',
          'status: ${candidate.status}',
          'type: ${candidate.memoryType}',
          'confidence: ${candidate.confidence}',
          'sensitivity: ${candidate.sensitivity}',
          if (candidate.sourceRefs.isNotEmpty)
            'sources: ${_sourceRefs(candidate.sourceRefs)}',
        ],
        body: candidate.body,
      );
    }
  }

  void _writeCards(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Cards')
      ..writeln();
    if (backup.cards.isEmpty) {
      buffer
        ..writeln('_No cards exported._')
        ..writeln();
      return;
    }
    for (final card in backup.cards) {
      _writeItem(
        buffer,
        title: card.title,
        metadata: <String>[
          'id: ${card.id}',
          'kind: ${card.cardKind}',
          'status: ${card.status}',
          if (card.sourceRefs.isNotEmpty)
            'sources: ${_sourceRefs(card.sourceRefs)}',
        ],
        body: card.body,
      );
    }
  }

  void _writeInsights(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Insights')
      ..writeln();
    if (backup.insights.isEmpty) {
      buffer
        ..writeln('_No insights exported._')
        ..writeln();
      return;
    }
    for (final insight in backup.insights) {
      _writeItem(
        buffer,
        title: insight.title,
        metadata: <String>[
          'id: ${insight.id}',
          'kind: ${insight.insightKind}',
          'status: ${insight.status}',
          if (insight.metricLabel != null)
            'metric: ${insight.metricValue ?? ''} ${insight.metricLabel}',
          if (insight.sourceRefs.isNotEmpty)
            'sources: ${_sourceRefs(insight.sourceRefs)}',
        ],
        body: insight.summary,
      );
    }
  }

  void _writeTodos(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Todos')
      ..writeln();
    if (backup.todos.isEmpty) {
      buffer
        ..writeln('_No todos exported._')
        ..writeln();
      return;
    }
    for (final todo in backup.todos) {
      _writeItem(
        buffer,
        title: _firstText(todo.payload, const <String>['title', 'text']),
        metadata: <String>[
          'id: ${todo.id}',
          'status: ${todo.status}',
          if (todo.sourceCaptureId != null)
            'source_capture: ${todo.sourceCaptureId}',
          if (todo.sourceEventId != null) 'source_event: ${todo.sourceEventId}',
        ],
        body: _firstText(todo.payload, const <String>['body', 'summary']),
      );
    }
  }

  void _writeConversations(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Conversations')
      ..writeln();
    if (backup.chatSessions.isEmpty) {
      buffer
        ..writeln('_No conversations exported._')
        ..writeln();
      return;
    }
    for (final session in backup.chatSessions) {
      buffer
        ..writeln('### ${_line(session.title)}')
        ..writeln()
        ..writeln('- id: ${session.id}')
        ..writeln('- status: ${session.status}')
        ..writeln('- updated: ${session.updatedAt.toIso8601String()}')
        ..writeln();
      final messages = backup.chatMessages
          .where((message) => message.sessionId == session.id)
          .toList(growable: false);
      for (final message in messages) {
        buffer
          ..writeln('**${message.role}**')
          ..writeln()
          ..writeln(_block(message.body))
          ..writeln();
      }
    }
  }

  void _writeProviders(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Model Providers')
      ..writeln();
    if (backup.modelProviderConfigs.isEmpty) {
      buffer
        ..writeln('_No model providers exported._')
        ..writeln();
      return;
    }
    for (final provider in backup.modelProviderConfigs) {
      _writeItem(
        buffer,
        title: provider.displayName,
        metadata: <String>[
          'id: ${provider.id}',
          'kind: ${provider.providerKind}',
          'model: ${provider.model}',
          'endpoint: ${provider.endpoint}',
          'default: ${provider.isDefault}',
          'api_key_present: ${provider.hasApiKey}',
        ],
        body: '',
      );
    }
  }

  void _writeRuntimeState(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Runtime State')
      ..writeln();
    if (backup.packInstallations.isEmpty &&
        backup.permissionGrants.isEmpty &&
        backup.runtimeTasks.isEmpty &&
        backup.runtimeRuns.isEmpty) {
      buffer
        ..writeln('_No runtime state exported._')
        ..writeln();
      return;
    }
    if (backup.packInstallations.isNotEmpty) {
      buffer
        ..writeln('### Pack Installations')
        ..writeln();
      for (final pack in backup.packInstallations) {
        buffer
          ..writeln('- ${_line(pack.packId)}: ${_line(pack.status)}')
          ..writeln(
            '  - version: ${_line(pack.version)}, runtime: ${_line(pack.runtimeStatus)}',
          );
      }
      buffer.writeln();
    }
    if (backup.permissionGrants.isNotEmpty) {
      buffer
        ..writeln('### Permissions')
        ..writeln();
      for (final grant in backup.permissionGrants) {
        buffer.writeln(
          '- ${_line(grant.packId)} ${_line(grant.permissionId)}: ${_line(grant.status)}',
        );
      }
      buffer.writeln();
    }
    if (backup.runtimeTasks.isNotEmpty) {
      buffer
        ..writeln('### Tasks')
        ..writeln();
      for (final task in backup.runtimeTasks) {
        buffer.writeln(
          '- ${_line(task.id)}: ${_line(task.status)} ${_line(task.packId)} ${_line(task.subscriptionId)}',
        );
      }
      buffer.writeln();
    }
    if (backup.runtimeRuns.isNotEmpty) {
      buffer
        ..writeln('### Runs')
        ..writeln();
      for (final run in backup.runtimeRuns) {
        buffer.writeln(
          '- ${_line(run.id)}: ${_line(run.status)} task=${_line(run.taskId)}',
        );
      }
      buffer.writeln();
    }
  }

  void _writeTraces(StringBuffer buffer, LocalDataBackup backup) {
    buffer
      ..writeln('## Trace Events')
      ..writeln();
    if (backup.traceEvents.isEmpty) {
      buffer
        ..writeln('_No trace events exported._')
        ..writeln();
      return;
    }
    for (final trace in backup.traceEvents) {
      _writeItem(
        buffer,
        title: trace.traceType,
        metadata: <String>[
          'id: ${trace.id}',
          'severity: ${trace.severity}',
          'status: ${trace.status}',
          if (trace.runId != null) 'run: ${trace.runId}',
          if (trace.packId != null) 'pack: ${trace.packId}',
          if (trace.agentId != null) 'agent: ${trace.agentId}',
        ],
        body: trace.message,
      );
    }
  }
}

void _writeItem(
  StringBuffer buffer, {
  required String title,
  required List<String> metadata,
  required String body,
}) {
  buffer
    ..writeln('### ${_line(title.isEmpty ? 'Untitled' : title)}')
    ..writeln();
  for (final line in metadata.where((line) => line.trim().isNotEmpty)) {
    buffer.writeln('- ${_line(line)}');
  }
  if (body.trim().isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(_block(body));
  }
  buffer.writeln();
}

String _firstText(JsonMap payload, List<String> keys) {
  for (final key in keys) {
    final value = payload[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}

String _sourceRefs(List<Object?> refs) {
  return refs.map(_sourceRef).where((value) => value.isNotEmpty).join(', ');
}

String _sourceRef(Object? value) {
  if (value is Map) {
    final kind = value['kind'] ?? value['source_type'] ?? 'source';
    final id = value['id'] ?? value['source_id'] ?? '';
    return '$kind:$id';
  }
  return '';
}

String _line(String value) {
  return value.replaceAll('\n', ' ').trim();
}

String _block(String value) {
  return value.trim().split('\n').map((line) => '> ${line.trim()}').join('\n');
}
