import 'run_mode.dart';

enum RuntimeTaskStatus {
  queued,
  waiting,
  running,
  succeeded,
  failed,
  denied,
  canceled,
  blocked,
}

enum RuntimeRunStatus { running, succeeded, failed, denied, canceled }

extension RuntimeTaskStatusState on RuntimeTaskStatus {
  bool get isTerminal {
    return switch (this) {
      RuntimeTaskStatus.succeeded ||
      RuntimeTaskStatus.failed ||
      RuntimeTaskStatus.denied ||
      RuntimeTaskStatus.canceled ||
      RuntimeTaskStatus.blocked => true,
      RuntimeTaskStatus.queued ||
      RuntimeTaskStatus.waiting ||
      RuntimeTaskStatus.running => false,
    };
  }
}

extension RuntimeRunStatusState on RuntimeRunStatus {
  bool get isTerminal {
    return switch (this) {
      RuntimeRunStatus.succeeded ||
      RuntimeRunStatus.failed ||
      RuntimeRunStatus.denied ||
      RuntimeRunStatus.canceled => true,
      RuntimeRunStatus.running => false,
    };
  }
}

final class RetryPolicy {
  const RetryPolicy({this.maxAttempts = 1});

  final int maxAttempts;

  int get normalizedMaxAttempts => maxAttempts < 1 ? 1 : maxAttempts;
}

final class RuntimeTask {
  const RuntimeTask({
    required this.id,
    required this.identityKey,
    required this.packId,
    required this.packVersion,
    required this.agentId,
    required this.handlerRole,
    required this.subscriptionId,
    required this.triggerEventId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.dependencyTaskIds = const <String>[],
    this.missingDependencyIds = const <String>[],
    this.attempts = 0,
    this.maxAttempts = 1,
    this.error,
  });

  final String id;
  final String identityKey;
  final String packId;
  final String packVersion;
  final String agentId;
  final String handlerRole;
  final String subscriptionId;
  final String triggerEventId;
  final RuntimeTaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> dependencyTaskIds;
  final List<String> missingDependencyIds;
  final int attempts;
  final int maxAttempts;
  final String? error;

  bool get canRetry => attempts < maxAttempts;

  RuntimeTask copyWith({
    RuntimeTaskStatus? status,
    DateTime? updatedAt,
    List<String>? dependencyTaskIds,
    List<String>? missingDependencyIds,
    int? attempts,
    int? maxAttempts,
    String? error,
    bool clearError = false,
  }) {
    return RuntimeTask(
      id: id,
      identityKey: identityKey,
      packId: packId,
      packVersion: packVersion,
      agentId: agentId,
      handlerRole: handlerRole,
      subscriptionId: subscriptionId,
      triggerEventId: triggerEventId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dependencyTaskIds: dependencyTaskIds ?? this.dependencyTaskIds,
      missingDependencyIds: missingDependencyIds ?? this.missingDependencyIds,
      attempts: attempts ?? this.attempts,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final class RuntimeRun {
  const RuntimeRun({
    required this.id,
    required this.taskId,
    required this.packId,
    required this.packVersion,
    required this.agentId,
    required this.status,
    required this.startedAt,
    required this.attempt,
    this.runMode = RunMode.auto,
    this.completedAt,
    this.leaseExpiresAt,
    this.outputEventIds = const <String>[],
    this.error,
  });

  final String id;
  final String taskId;
  final String packId;
  final String packVersion;
  final String agentId;
  final RuntimeRunStatus status;
  final DateTime startedAt;
  final int attempt;
  final RunMode runMode;
  final DateTime? completedAt;
  final DateTime? leaseExpiresAt;
  final List<String> outputEventIds;
  final String? error;

  RuntimeRun copyWith({
    RuntimeRunStatus? status,
    DateTime? completedAt,
    List<String>? outputEventIds,
    String? error,
  }) {
    return RuntimeRun(
      id: id,
      taskId: taskId,
      packId: packId,
      packVersion: packVersion,
      agentId: agentId,
      status: status ?? this.status,
      startedAt: startedAt,
      attempt: attempt,
      runMode: runMode,
      completedAt: completedAt ?? this.completedAt,
      leaseExpiresAt: leaseExpiresAt,
      outputEventIds: outputEventIds ?? this.outputEventIds,
      error: error ?? this.error,
    );
  }
}

enum RuntimePackStatusKind {
  idle,
  queued,
  running,
  succeeded,
  failed,
  denied,
  canceled,
  blocked,
}

final class RuntimePackStatus {
  const RuntimePackStatus({
    required this.packId,
    required this.version,
    required this.name,
    required this.status,
    required this.taskCount,
    required this.queuedCount,
    required this.runningCount,
    required this.succeededCount,
    required this.failedCount,
    required this.deniedCount,
    required this.canceledCount,
    required this.blockedCount,
  });

  final String packId;
  final String version;
  final String name;
  final RuntimePackStatusKind status;
  final int taskCount;
  final int queuedCount;
  final int runningCount;
  final int succeededCount;
  final int failedCount;
  final int deniedCount;
  final int canceledCount;
  final int blockedCount;
}
