import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';

final traceConsoleControllerProvider =
    NotifierProvider<TraceConsoleController, TraceConsoleSnapshot>(
      TraceConsoleController.new,
    );

enum AgentConsoleFilter { all, active, failed, denied, blocked }

final class TraceConsoleController extends Notifier<TraceConsoleSnapshot> {
  AgentConsoleFilter _filter = AgentConsoleFilter.all;

  @override
  TraceConsoleSnapshot build() {
    return _load(ref.watch(localDatabaseProvider), filter: _filter);
  }

  void setFilter(AgentConsoleFilter filter) {
    _filter = filter;
    state = _load(ref.read(localDatabaseProvider), filter: _filter);
  }

  void refresh() {
    state = _load(ref.read(localDatabaseProvider), filter: _filter);
  }

  TraceConsoleSnapshot _load(
    WideNoteLocalDatabase database, {
    required AgentConsoleFilter filter,
  }) {
    final traces = database.traceEvents
        .readAll(limit: 200)
        .reversed
        .map(_traceItemFromRecord)
        .toList(growable: false);
    final tracesByRun = <String, List<TraceConsoleItem>>{};
    for (final trace in traces) {
      final runId = trace.runId;
      if (runId == null) {
        continue;
      }
      tracesByRun.putIfAbsent(runId, () => <TraceConsoleItem>[]).add(trace);
    }

    final tasksById = <String, AgentConsoleTask>{
      for (final task in database.runtimeTasks.readAll().reversed.map(
        _taskFromRecord,
      ))
        task.id: task,
    };

    final runs = database.runtimeRuns
        .readAll()
        .reversed
        .map(
          (run) => _runFromRecord(
            run,
            task: tasksById[run.taskId],
            traces: tracesByRun[run.id] ?? const <TraceConsoleItem>[],
          ),
        )
        .toList(growable: false);

    return TraceConsoleSnapshot(
      items: traces,
      runs: runs,
      tasks: tasksById.values.toList(growable: false),
      filter: filter,
      pendingApprovals: const <AgentApprovalItem>[],
    );
  }
}

@immutable
final class TraceConsoleSnapshot {
  const TraceConsoleSnapshot({
    required this.items,
    required this.runs,
    required this.tasks,
    required this.filter,
    required this.pendingApprovals,
  });

  final List<TraceConsoleItem> items;
  final List<AgentConsoleRun> runs;
  final List<AgentConsoleTask> tasks;
  final AgentConsoleFilter filter;
  final List<AgentApprovalItem> pendingApprovals;

  int get runCount {
    if (runs.isNotEmpty) {
      return runs.length;
    }
    return items.map((item) => item.runId).whereType<String>().toSet().length;
  }

  int get warningCount {
    return items.where((item) => item.isWarningLike).length;
  }

  int get taskCount => tasks.length;

  int get pendingApprovalCount => pendingApprovals.length;

  AgentConsoleSummary get summary {
    final statuses = <String>[
      for (final run in runs) run.status,
      for (final task in tasks) task.status,
    ];
    return AgentConsoleSummary(
      total: statuses.length,
      active: statuses.where(_isActiveStatus).length,
      failed: statuses.where((status) => status == 'failed').length,
      denied: statuses.where((status) => status == 'denied').length,
      blocked: statuses.where((status) => status == 'blocked').length,
    );
  }

  List<AgentConsoleRun> get filteredRuns {
    return runs
        .where((run) => _matchesFilter(run.status, filter))
        .toList(growable: false);
  }

  List<AgentConsoleTask> get filteredTasks {
    return tasks
        .where((task) => _matchesFilter(task.status, filter))
        .toList(growable: false);
  }
}

@immutable
final class AgentConsoleSummary {
  const AgentConsoleSummary({
    required this.total,
    required this.active,
    required this.failed,
    required this.denied,
    required this.blocked,
  });

  final int total;
  final int active;
  final int failed;
  final int denied;
  final int blocked;
}

@immutable
final class AgentConsoleRun {
  const AgentConsoleRun({
    required this.id,
    required this.taskId,
    required this.packId,
    required this.agentId,
    required this.handlerId,
    required this.status,
    required this.attempt,
    required this.runMode,
    required this.startedAt,
    required this.outputCount,
    required this.traces,
    this.completedAt,
    this.error,
    this.task,
  });

  final String id;
  final String taskId;
  final String packId;
  final String agentId;
  final String handlerId;
  final String status;
  final int attempt;
  final AgentRunMode runMode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int outputCount;
  final RedactedText? error;
  final AgentConsoleTask? task;
  final List<TraceConsoleItem> traces;

  bool get canRetry => false;
  bool get canCancel => false;
}

enum AgentRunMode { readOnly, confirm, auto, unknown }

@immutable
final class AgentConsoleTask {
  const AgentConsoleTask({
    required this.id,
    required this.packId,
    required this.agentId,
    required this.handlerId,
    required this.subscriptionId,
    required this.triggerEventId,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
    required this.createdAt,
    required this.updatedAt,
    required this.missingDependencyIds,
    this.error,
  });

  final String id;
  final String packId;
  final String agentId;
  final String handlerId;
  final String subscriptionId;
  final String triggerEventId;
  final String status;
  final int attempts;
  final int maxAttempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> missingDependencyIds;
  final RedactedText? error;
}

@immutable
final class AgentApprovalItem {
  const AgentApprovalItem();
}

@immutable
final class TraceConsoleItem {
  const TraceConsoleItem({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.payloadEntries,
    required this.redactedPayloadFieldCount,
    this.runId,
    this.packId,
    this.agentId,
    this.eventId,
    this.taskId,
    this.parentTraceId,
    this.durationMs,
    this.delegation,
  });

  final String id;
  final String title;
  final String severity;
  final String status;
  final RedactedText message;
  final DateTime createdAt;
  final String? runId;
  final String? packId;
  final String? agentId;
  final String? eventId;
  final String? taskId;
  final String? parentTraceId;
  final num? durationMs;
  final AgentDelegationLink? delegation;
  final List<TracePayloadEntry> payloadEntries;
  final int redactedPayloadFieldCount;

  bool get isWarningLike {
    final normalized = severity.toLowerCase();
    return normalized == 'warning' ||
        normalized == 'warn' ||
        normalized == 'error' ||
        status.toLowerCase() != 'ok';
  }
}

@immutable
final class AgentDelegationLink {
  const AgentDelegationLink({
    required this.delegationId,
    required this.status,
    required this.violationCodes,
    this.childRunId,
  });

  final String delegationId;
  final String status;
  final String? childRunId;
  final List<String> violationCodes;
}

@immutable
final class RedactedText {
  const RedactedText({required this.value, required this.isRedacted});

  final String value;
  final bool isRedacted;
}

@immutable
final class TracePayloadEntry {
  const TracePayloadEntry({
    required this.key,
    required this.value,
    required this.isValueRedacted,
  });

  final String key;
  final String value;
  final bool isValueRedacted;
}

AgentConsoleRun _runFromRecord(
  RuntimeRunRecord run, {
  required AgentConsoleTask? task,
  required List<TraceConsoleItem> traces,
}) {
  return AgentConsoleRun(
    id: run.id,
    taskId: run.taskId,
    packId: run.packId,
    agentId: run.agentId,
    handlerId: run.handlerId,
    status: run.status,
    attempt: run.attempt,
    runMode: _runModeFromPayload(run.payload),
    startedAt: run.startedAt,
    completedAt: run.completedAt,
    outputCount: run.outputEventIds.length,
    error: run.error == null ? null : _redactText(run.error!),
    task: task,
    traces: traces,
  );
}

AgentConsoleTask _taskFromRecord(RuntimeTaskRecord task) {
  return AgentConsoleTask(
    id: task.id,
    packId: task.packId,
    agentId: task.agentId,
    handlerId: task.handlerId,
    subscriptionId: task.subscriptionId,
    triggerEventId: task.triggerEventId,
    status: task.status,
    attempts: task.attempts,
    maxAttempts: task.maxAttempts,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    missingDependencyIds: task.missingDependencyIds.whereType<String>().toList(
      growable: false,
    ),
    error: task.error == null ? null : _redactText(task.error!),
  );
}

TraceConsoleItem _traceItemFromRecord(TraceEventRecord trace) {
  final payload = _payloadEntries(trace.payload);
  return TraceConsoleItem(
    id: trace.id,
    title: _traceTitle(trace),
    severity: trace.severity,
    status: trace.status,
    message: _redactText(trace.message),
    createdAt: trace.createdAt,
    runId: trace.runId,
    packId: trace.packId,
    agentId: trace.agentId,
    eventId: trace.eventId,
    taskId: trace.taskId,
    parentTraceId: trace.parentTraceId,
    durationMs: trace.durationMs,
    delegation: _delegationFromPayload(trace.payload),
    payloadEntries: payload.entries,
    redactedPayloadFieldCount: payload.redactedCount,
  );
}

String _traceTitle(TraceEventRecord trace) {
  final traceType = _payloadString(trace.payload['trace_type']);
  if (traceType != null && traceType.isNotEmpty) {
    return traceType;
  }
  return trace.traceType;
}

AgentDelegationLink? _delegationFromPayload(JsonMap payload) {
  final delegationId = _payloadString(payload['child_delegation_id']);
  final childRunId = _payloadString(payload['child_run_id']);
  final status = _payloadString(payload['child_status']);
  if ((delegationId == null || delegationId.isEmpty) &&
      (childRunId == null || childRunId.isEmpty) &&
      (status == null || status.isEmpty)) {
    return null;
  }
  return AgentDelegationLink(
    delegationId: delegationId ?? '',
    childRunId: childRunId,
    status: status ?? '',
    violationCodes: _delegationViolationCodes(payload),
  );
}

List<String> _delegationViolationCodes(JsonMap payload) {
  final direct = _payloadStringList(payload['violation_codes']);
  if (direct.isNotEmpty) {
    return direct;
  }
  final violations = payload['violations'];
  if (violations is! Iterable) {
    return const <String>[];
  }
  final codes = <String>[];
  for (final violation in violations) {
    if (violation is Map) {
      final code = _payloadString(violation['code']);
      if (code != null && code.isNotEmpty) {
        codes.add(code);
      }
    }
  }
  return List<String>.unmodifiable(codes);
}

AgentRunMode _runModeFromPayload(JsonMap payload) {
  final value = payload['runtime_run_mode'];
  if (value is! String || value.isEmpty) {
    return AgentRunMode.auto;
  }
  return switch (value) {
    'read_only' || 'readOnly' => AgentRunMode.readOnly,
    'confirm' => AgentRunMode.confirm,
    'auto' => AgentRunMode.auto,
    _ => AgentRunMode.unknown,
  };
}

bool _matchesFilter(String status, AgentConsoleFilter filter) {
  return switch (filter) {
    AgentConsoleFilter.all => true,
    AgentConsoleFilter.active => _isActiveStatus(status),
    AgentConsoleFilter.failed => status == 'failed',
    AgentConsoleFilter.denied => status == 'denied',
    AgentConsoleFilter.blocked => status == 'blocked',
  };
}

bool _isActiveStatus(String status) {
  return status == 'queued' || status == 'waiting' || status == 'running';
}

_PayloadEntries _payloadEntries(JsonMap payload) {
  final entries = <TracePayloadEntry>[];
  var redactedCount = 0;
  final keys = payload.keys.toList()..sort();
  for (final key in keys) {
    if (_isSensitiveText(key)) {
      redactedCount += 1;
      continue;
    }
    final value = _redactPayloadValue(payload[key]);
    redactedCount += value.redactedCount;
    entries.add(
      TracePayloadEntry(
        key: key,
        value: value.text,
        isValueRedacted: value.isRedacted,
      ),
    );
  }
  return _PayloadEntries(entries: entries, redactedCount: redactedCount);
}

RedactedText _redactText(String value) {
  if (value.isEmpty) {
    return const RedactedText(value: '', isRedacted: false);
  }
  if (_isSensitiveText(value)) {
    return const RedactedText(value: '', isRedacted: true);
  }
  return RedactedText(value: value, isRedacted: false);
}

_RedactedPayloadValue _redactPayloadValue(Object? value) {
  if (value is String) {
    if (_isSensitiveText(value)) {
      return const _RedactedPayloadValue(
        text: '',
        isRedacted: true,
        redactedCount: 1,
      );
    }
    return _RedactedPayloadValue(
      text: value,
      isRedacted: false,
      redactedCount: 0,
    );
  }
  if (value is Map) {
    var redactedCount = 0;
    final safe = <String, Object?>{};
    for (final entry in value.entries) {
      final key = '${entry.key}';
      if (_isSensitiveText(key)) {
        redactedCount += 1;
        continue;
      }
      final child = _redactPayloadValue(entry.value);
      redactedCount += child.redactedCount;
      if (child.isRedacted) {
        continue;
      }
      safe[key] = child.text;
    }
    if (redactedCount > 0) {
      return _RedactedPayloadValue(
        text: safe.isEmpty ? '' : jsonEncode(safe),
        isRedacted: true,
        redactedCount: redactedCount,
      );
    }
    return _RedactedPayloadValue(
      text: jsonEncode(safe),
      isRedacted: false,
      redactedCount: 0,
    );
  }
  if (value is Iterable) {
    var redactedCount = 0;
    final safe = <Object?>[];
    for (final childValue in value) {
      final child = _redactPayloadValue(childValue);
      redactedCount += child.redactedCount;
      if (child.isRedacted) {
        continue;
      }
      safe.add(child.text);
    }
    if (redactedCount > 0) {
      return _RedactedPayloadValue(
        text: safe.isEmpty ? '' : jsonEncode(safe),
        isRedacted: true,
        redactedCount: redactedCount,
      );
    }
    return _RedactedPayloadValue(
      text: jsonEncode(safe),
      isRedacted: false,
      redactedCount: 0,
    );
  }
  return _RedactedPayloadValue(
    text: value == null ? 'null' : '$value',
    isRedacted: false,
    redactedCount: 0,
  );
}

bool _isSensitiveText(String value) {
  final normalized = value.trim().toLowerCase();
  if (_sensitiveExactValues.contains(normalized)) {
    return true;
  }
  return _sensitivePattern.hasMatch(value);
}

const _sensitiveExactValues = <String>{
  'input',
  'instructions',
  'prompt',
  'raw_input',
  'raw_prompt',
  'capture_body',
  'raw_capture_body',
  'attachment_path',
  'file_path',
  'raw_media',
  'media_bytes',
  'oauth_token',
};

final _sensitivePattern = RegExp(
  r'(api[_-]?key|authorization|bearer|token|secret|credential|oauth|raw[_-]?prompt|raw[_-]?capture|attachment[_-]?path|file[_-]?path|raw[_-]?media|media[_-]?bytes)',
  caseSensitive: false,
);

String? _payloadString(Object? value) {
  if (value is String) {
    return value;
  }
  return null;
}

List<String> _payloadStringList(Object? value) {
  if (value is! Iterable) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

final class _PayloadEntries {
  const _PayloadEntries({required this.entries, required this.redactedCount});

  final List<TracePayloadEntry> entries;
  final int redactedCount;
}

final class _RedactedPayloadValue {
  const _RedactedPayloadValue({
    required this.text,
    required this.isRedacted,
    required this.redactedCount,
  });

  final String text;
  final bool isRedacted;
  final int redactedCount;
}
