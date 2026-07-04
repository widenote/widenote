import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';

final agentExecutionStatusControllerProvider =
    NotifierProvider<
      AgentExecutionStatusController,
      AgentExecutionStatusSnapshot
    >(AgentExecutionStatusController.new);

@visibleForTesting
final agentExecutionStatusNowProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now().toUtc();
});

enum AgentExecutionStatusKind {
  running,
  queued,
  retrying,
  recovering,
  succeeded,
  failed,
  denied,
  canceled,
  blocked,
}

extension AgentExecutionStatusKindWire on AgentExecutionStatusKind {
  String get wireName {
    return switch (this) {
      AgentExecutionStatusKind.running => 'running',
      AgentExecutionStatusKind.queued => 'queued',
      AgentExecutionStatusKind.retrying => 'retrying',
      AgentExecutionStatusKind.recovering => 'recovering',
      AgentExecutionStatusKind.succeeded => 'succeeded',
      AgentExecutionStatusKind.failed => 'failed',
      AgentExecutionStatusKind.denied => 'denied',
      AgentExecutionStatusKind.canceled => 'canceled',
      AgentExecutionStatusKind.blocked => 'blocked',
    };
  }

  bool get isActiveLike {
    return switch (this) {
      AgentExecutionStatusKind.running ||
      AgentExecutionStatusKind.queued ||
      AgentExecutionStatusKind.retrying ||
      AgentExecutionStatusKind.recovering => true,
      AgentExecutionStatusKind.succeeded ||
      AgentExecutionStatusKind.failed ||
      AgentExecutionStatusKind.denied ||
      AgentExecutionStatusKind.canceled ||
      AgentExecutionStatusKind.blocked => false,
    };
  }

  bool get isAttentionLike {
    return switch (this) {
      AgentExecutionStatusKind.failed ||
      AgentExecutionStatusKind.denied ||
      AgentExecutionStatusKind.canceled ||
      AgentExecutionStatusKind.blocked => true,
      AgentExecutionStatusKind.running ||
      AgentExecutionStatusKind.queued ||
      AgentExecutionStatusKind.retrying ||
      AgentExecutionStatusKind.recovering ||
      AgentExecutionStatusKind.succeeded => false,
    };
  }
}

enum AgentExecutionOverallStatus { idle, active, attention, completed }

extension AgentExecutionOverallStatusWire on AgentExecutionOverallStatus {
  String get wireName {
    return switch (this) {
      AgentExecutionOverallStatus.idle => 'idle',
      AgentExecutionOverallStatus.active => 'active',
      AgentExecutionOverallStatus.attention => 'attention',
      AgentExecutionOverallStatus.completed => 'completed',
    };
  }
}

final class AgentExecutionStatusController
    extends Notifier<AgentExecutionStatusSnapshot> {
  static const visibleRefreshInterval = Duration(seconds: 1);
  static const idleRefreshInterval = Duration(seconds: 5);
  static const terminalVisibleWindow = Duration(seconds: 5);

  Timer? _refreshTimer;

  @override
  AgentExecutionStatusSnapshot build() {
    final snapshot = _load();
    _scheduleRefresh(snapshot);
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    });
    return snapshot;
  }

  void refresh() {
    try {
      final snapshot = _load();
      state = snapshot;
      _scheduleRefresh(snapshot);
    } catch (_) {
      _scheduleRefresh(state);
      rethrow;
    }
  }

  void _scheduleRefresh(AgentExecutionStatusSnapshot snapshot) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_nextRefreshDelay(snapshot), refresh);
  }

  Duration _nextRefreshDelay(AgentExecutionStatusSnapshot snapshot) {
    if (snapshot.hasVisibleStatus) {
      return visibleRefreshInterval;
    }
    return idleRefreshInterval;
  }

  AgentExecutionStatusSnapshot _load() {
    final database = ref.read(localDatabaseProvider);
    final now = ref.read(agentExecutionStatusNowProvider)();
    final tasks = database.runtimeTasks.readAll().reversed.toList(
      growable: false,
    );
    final latestRunsByTask = _latestRunsByTask(database.runtimeRuns.readAll());
    final items = <AgentExecutionStatusItem>[];

    for (final task in tasks) {
      final run = latestRunsByTask[task.id];
      final kind = _kindForTask(task, now);
      if (!_shouldShowTask(task, kind, now)) {
        continue;
      }
      items.add(_itemFromTask(task, run: run, kind: kind));
    }

    items.sort(_compareItems);
    return AgentExecutionStatusSnapshot(
      generatedAt: now,
      items: List<AgentExecutionStatusItem>.unmodifiable(items),
    );
  }
}

@immutable
final class AgentExecutionStatusSnapshot {
  const AgentExecutionStatusSnapshot({
    required this.generatedAt,
    required this.items,
  });

  final DateTime generatedAt;
  final List<AgentExecutionStatusItem> items;

  int get runningCount => countKind(AgentExecutionStatusKind.running);
  int get queuedCount => countKind(AgentExecutionStatusKind.queued);
  int get retryingCount => countKind(AgentExecutionStatusKind.retrying);
  int get recoveringCount => countKind(AgentExecutionStatusKind.recovering);
  int get succeededCount => countKind(AgentExecutionStatusKind.succeeded);
  int get failedCount => countKind(AgentExecutionStatusKind.failed);
  int get deniedCount => countKind(AgentExecutionStatusKind.denied);
  int get canceledCount => countKind(AgentExecutionStatusKind.canceled);
  int get blockedCount => countKind(AgentExecutionStatusKind.blocked);

  int get activeCount {
    return runningCount + queuedCount + retryingCount + recoveringCount;
  }

  int get attentionCount {
    return failedCount + deniedCount + canceledCount + blockedCount;
  }

  bool get hasVisibleStatus =>
      overallStatus != AgentExecutionOverallStatus.idle;

  AgentExecutionOverallStatus get overallStatus {
    if (attentionCount > 0) {
      return AgentExecutionOverallStatus.attention;
    }
    if (activeCount > 0) {
      return AgentExecutionOverallStatus.active;
    }
    if (succeededCount > 0) {
      return AgentExecutionOverallStatus.completed;
    }
    return AgentExecutionOverallStatus.idle;
  }

  AgentExecutionStatusItem? get primaryItem {
    return items.isEmpty ? null : items.first;
  }

  DateTime? get lastUpdatedAt {
    DateTime? latest;
    for (final item in items) {
      if (latest == null || item.updatedAt.isAfter(latest)) {
        latest = item.updatedAt;
      }
    }
    return latest;
  }

  DateTime? get terminalStatusExpiresAt {
    DateTime? latest;
    for (final item in items) {
      if (item.kind.isActiveLike) {
        continue;
      }
      final expiresAt = item.updatedAt.add(
        AgentExecutionStatusController.terminalVisibleWindow,
      );
      if (latest == null || expiresAt.isAfter(latest)) {
        latest = expiresAt;
      }
    }
    return latest;
  }

  int countKind(AgentExecutionStatusKind kind) {
    return items.where((item) => item.kind == kind).length;
  }

  String get syncIdentity {
    final buffer = StringBuffer()
      ..write(overallStatus.wireName)
      ..write('|')
      ..write(runningCount)
      ..write('|')
      ..write(queuedCount)
      ..write('|')
      ..write(retryingCount)
      ..write('|')
      ..write(recoveringCount)
      ..write('|')
      ..write(failedCount)
      ..write('|')
      ..write(deniedCount)
      ..write('|')
      ..write(canceledCount)
      ..write('|')
      ..write(blockedCount)
      ..write('|')
      ..write(succeededCount);
    for (final item in items.take(6)) {
      buffer
        ..write('|')
        ..write(item.taskId)
        ..write(':')
        ..write(item.kind.wireName)
        ..write(':')
        ..write(item.attempts)
        ..write(':')
        ..write(item.updatedAt.toUtc().toIso8601String());
    }
    return buffer.toString();
  }
}

@immutable
final class AgentExecutionStatusItem {
  const AgentExecutionStatusItem({
    required this.id,
    required this.taskId,
    required this.packId,
    required this.agentId,
    required this.status,
    required this.kind,
    required this.attempts,
    required this.maxAttempts,
    required this.createdAt,
    required this.updatedAt,
    required this.missingDependencyCount,
    required this.hasError,
    this.runId,
    this.runStatus,
    this.scheduledAt,
    this.leasedUntil,
    this.outputCount = 0,
  });

  final String id;
  final String taskId;
  final String? runId;
  final String packId;
  final String agentId;
  final String status;
  final String? runStatus;
  final AgentExecutionStatusKind kind;
  final int attempts;
  final int maxAttempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? scheduledAt;
  final DateTime? leasedUntil;
  final int missingDependencyCount;
  final int outputCount;
  final bool hasError;

  bool get hasRetryBudget => attempts < maxAttempts;
}

Map<String, RuntimeRunRecord> _latestRunsByTask(List<RuntimeRunRecord> runs) {
  final latest = <String, RuntimeRunRecord>{};
  for (final run in runs) {
    final existing = latest[run.taskId];
    if (existing == null || run.startedAt.isAfter(existing.startedAt)) {
      latest[run.taskId] = run;
    }
  }
  return latest;
}

AgentExecutionStatusKind _kindForTask(RuntimeTaskRecord task, DateTime now) {
  return switch (task.status) {
    'running' =>
      _isStaleRunning(task, now)
          ? task.attempts < task.maxAttempts
                ? AgentExecutionStatusKind.recovering
                : AgentExecutionStatusKind.failed
          : AgentExecutionStatusKind.running,
    'queued' || 'waiting' =>
      _isScheduledRetry(task, now)
          ? AgentExecutionStatusKind.retrying
          : AgentExecutionStatusKind.queued,
    'succeeded' => AgentExecutionStatusKind.succeeded,
    'failed' => AgentExecutionStatusKind.failed,
    'denied' => AgentExecutionStatusKind.denied,
    'canceled' => AgentExecutionStatusKind.canceled,
    'blocked' => AgentExecutionStatusKind.blocked,
    _ => AgentExecutionStatusKind.queued,
  };
}

bool _shouldShowTask(
  RuntimeTaskRecord task,
  AgentExecutionStatusKind kind,
  DateTime now,
) {
  if (kind.isActiveLike) {
    return true;
  }
  return _withinWindow(
    task.updatedAt,
    now,
    AgentExecutionStatusController.terminalVisibleWindow,
  );
}

bool _isScheduledRetry(RuntimeTaskRecord task, DateTime now) {
  final scheduledAt = task.scheduledAt;
  return task.attempts > 0 && scheduledAt != null && scheduledAt.isAfter(now);
}

bool _isStaleRunning(RuntimeTaskRecord task, DateTime now) {
  final leasedUntil = task.leasedUntil;
  return leasedUntil != null && !leasedUntil.isAfter(now);
}

bool _withinWindow(DateTime updatedAt, DateTime now, Duration window) {
  return !updatedAt.isBefore(now.subtract(window));
}

AgentExecutionStatusItem _itemFromTask(
  RuntimeTaskRecord task, {
  required RuntimeRunRecord? run,
  required AgentExecutionStatusKind kind,
}) {
  return AgentExecutionStatusItem(
    id: task.id,
    taskId: task.id,
    runId: run?.id,
    packId: task.packId,
    agentId: task.agentId,
    status: task.status,
    runStatus: run?.status,
    kind: kind,
    attempts: task.attempts,
    maxAttempts: task.maxAttempts,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    scheduledAt: task.scheduledAt,
    leasedUntil: task.leasedUntil,
    missingDependencyCount: task.missingDependencyIds.length,
    outputCount: run?.outputEventIds.length ?? 0,
    hasError: task.error != null || run?.error != null,
  );
}

int _compareItems(
  AgentExecutionStatusItem left,
  AgentExecutionStatusItem right,
) {
  final priority = _itemPriority(left).compareTo(_itemPriority(right));
  if (priority != 0) {
    return priority;
  }
  return right.updatedAt.compareTo(left.updatedAt);
}

int _itemPriority(AgentExecutionStatusItem item) {
  if (item.kind.isAttentionLike) {
    return 0;
  }
  return switch (item.kind) {
    AgentExecutionStatusKind.running => 1,
    AgentExecutionStatusKind.recovering => 2,
    AgentExecutionStatusKind.retrying => 3,
    AgentExecutionStatusKind.queued => 4,
    AgentExecutionStatusKind.succeeded => 5,
    AgentExecutionStatusKind.failed ||
    AgentExecutionStatusKind.denied ||
    AgentExecutionStatusKind.canceled ||
    AgentExecutionStatusKind.blocked => 0,
  };
}
