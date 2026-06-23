enum RuntimeTaskStatus { queued, running, succeeded, failed, denied }

enum RuntimeRunStatus { running, succeeded, failed, denied }

final class RuntimeTask {
  const RuntimeTask({
    required this.id,
    required this.packId,
    required this.agentId,
    required this.subscriptionId,
    required this.triggerEventId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packId;
  final String agentId;
  final String subscriptionId;
  final String triggerEventId;
  final RuntimeTaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  RuntimeTask copyWith({RuntimeTaskStatus? status, DateTime? updatedAt}) {
    return RuntimeTask(
      id: id,
      packId: packId,
      agentId: agentId,
      subscriptionId: subscriptionId,
      triggerEventId: triggerEventId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class RuntimeRun {
  const RuntimeRun({
    required this.id,
    required this.taskId,
    required this.packId,
    required this.agentId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.outputEventIds = const <String>[],
    this.error,
  });

  final String id;
  final String taskId;
  final String packId;
  final String agentId;
  final RuntimeRunStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
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
      agentId: agentId,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      outputEventIds: outputEventIds ?? this.outputEventIds,
      error: error ?? this.error,
    );
  }
}
