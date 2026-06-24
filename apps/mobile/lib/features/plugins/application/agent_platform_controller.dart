import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

final class AgentPlatformController {
  AgentPlatformController.preview()
    : _runs = <AgentRunView>[
        const AgentRunView(
          taskId: 'task-queued-capture',
          packId: 'pack.default',
          packName: 'Default Capture Loop',
          agentId: 'agent.capture_loop',
          title: 'Capture projection',
          status: runtime.RuntimeTaskStatus.queued,
          detail: 'Waiting for local executor',
          attempts: 0,
          maxAttempts: 2,
        ),
        const AgentRunView(
          taskId: 'task-denied-permission',
          packId: 'pack.custom',
          packName: 'Custom Agent',
          agentId: 'agent.custom_summary',
          title: 'Custom summary',
          status: runtime.RuntimeTaskStatus.denied,
          detail: 'Missing permission: model.complete',
          attempts: 1,
          maxAttempts: 1,
        ),
        const AgentRunView(
          taskId: 'task-failed-retry',
          packId: 'pack.todo',
          packName: 'Todo Extraction Loop',
          agentId: 'agent.todo_loop',
          title: 'Todo suggestion',
          status: runtime.RuntimeTaskStatus.failed,
          detail: 'Transient fake executor failure',
          attempts: 1,
          maxAttempts: 2,
        ),
        const AgentRunView(
          taskId: 'task-script-denied',
          packId: 'pack.local_script',
          packName: 'Local Script Draft',
          agentId: 'agent.script',
          title: 'Script draft',
          status: runtime.RuntimeTaskStatus.denied,
          detail: 'Script runtime blocked until sandbox exists',
          attempts: 1,
          maxAttempts: 1,
        ),
      ];

  List<AgentRunView> _runs;

  AgentPlatformSnapshot get snapshot {
    return AgentPlatformSnapshot(
      packs: _packStatuses(),
      runs: List<AgentRunView>.unmodifiable(_runs),
    );
  }

  void cancel(String taskId) {
    _replace(taskId, (run) {
      if (run.status != runtime.RuntimeTaskStatus.queued &&
          run.status != runtime.RuntimeTaskStatus.waiting) {
        return run;
      }
      return run.copyWith(
        status: runtime.RuntimeTaskStatus.canceled,
        detail: 'Canceled before local executor start',
      );
    });
  }

  void retry(String taskId) {
    _replace(taskId, (run) {
      if (run.status != runtime.RuntimeTaskStatus.failed) {
        return run;
      }
      return run.copyWith(
        status: runtime.RuntimeTaskStatus.queued,
        detail: 'Retry queued for fake executor',
      );
    });
  }

  void _replace(String taskId, AgentRunView Function(AgentRunView run) update) {
    _runs = _runs
        .map((run) {
          if (run.taskId != taskId) {
            return run;
          }
          return update(run);
        })
        .toList(growable: false);
  }

  List<AgentPackStatusView> _packStatuses() {
    final byPack = <String, List<AgentRunView>>{};
    for (final run in _runs) {
      byPack.putIfAbsent(run.packId, () => <AgentRunView>[]).add(run);
    }

    return byPack.entries
        .map((entry) {
          final runs = entry.value;
          return AgentPackStatusView(
            packId: entry.key,
            name: runs.first.packName,
            status: _packStatusFor(runs),
            queuedCount:
                _count(runs, runtime.RuntimeTaskStatus.queued) +
                _count(runs, runtime.RuntimeTaskStatus.waiting),
            runningCount: _count(runs, runtime.RuntimeTaskStatus.running),
            succeededCount: _count(runs, runtime.RuntimeTaskStatus.succeeded),
            failedCount: _count(runs, runtime.RuntimeTaskStatus.failed),
            deniedCount: _count(runs, runtime.RuntimeTaskStatus.denied),
            canceledCount: _count(runs, runtime.RuntimeTaskStatus.canceled),
          );
        })
        .toList(growable: false);
  }

  runtime.RuntimePackStatusKind _packStatusFor(List<AgentRunView> runs) {
    if (runs.any((run) => run.status == runtime.RuntimeTaskStatus.running)) {
      return runtime.RuntimePackStatusKind.running;
    }
    if (runs.any(
      (run) =>
          run.status == runtime.RuntimeTaskStatus.queued ||
          run.status == runtime.RuntimeTaskStatus.waiting,
    )) {
      return runtime.RuntimePackStatusKind.queued;
    }
    if (runs.any((run) => run.status == runtime.RuntimeTaskStatus.failed)) {
      return runtime.RuntimePackStatusKind.failed;
    }
    if (runs.any((run) => run.status == runtime.RuntimeTaskStatus.denied)) {
      return runtime.RuntimePackStatusKind.denied;
    }
    if (runs.any((run) => run.status == runtime.RuntimeTaskStatus.canceled)) {
      return runtime.RuntimePackStatusKind.canceled;
    }
    return runtime.RuntimePackStatusKind.succeeded;
  }

  int _count(List<AgentRunView> runs, runtime.RuntimeTaskStatus status) {
    return runs.where((run) => run.status == status).length;
  }
}

final class AgentPlatformSnapshot {
  const AgentPlatformSnapshot({required this.packs, required this.runs});

  final List<AgentPackStatusView> packs;
  final List<AgentRunView> runs;
}

final class AgentPackStatusView {
  const AgentPackStatusView({
    required this.packId,
    required this.name,
    required this.status,
    required this.queuedCount,
    required this.runningCount,
    required this.succeededCount,
    required this.failedCount,
    required this.deniedCount,
    required this.canceledCount,
  });

  final String packId;
  final String name;
  final runtime.RuntimePackStatusKind status;
  final int queuedCount;
  final int runningCount;
  final int succeededCount;
  final int failedCount;
  final int deniedCount;
  final int canceledCount;
}

final class AgentRunView {
  const AgentRunView({
    required this.taskId,
    required this.packId,
    required this.packName,
    required this.agentId,
    required this.title,
    required this.status,
    required this.detail,
    required this.attempts,
    required this.maxAttempts,
  });

  final String taskId;
  final String packId;
  final String packName;
  final String agentId;
  final String title;
  final runtime.RuntimeTaskStatus status;
  final String detail;
  final int attempts;
  final int maxAttempts;

  bool get canCancel {
    return status == runtime.RuntimeTaskStatus.queued ||
        status == runtime.RuntimeTaskStatus.waiting;
  }

  bool get canRetry => status == runtime.RuntimeTaskStatus.failed;

  AgentRunView copyWith({
    runtime.RuntimeTaskStatus? status,
    String? detail,
    int? attempts,
  }) {
    return AgentRunView(
      taskId: taskId,
      packId: packId,
      packName: packName,
      agentId: agentId,
      title: title,
      status: status ?? this.status,
      detail: detail ?? this.detail,
      attempts: attempts ?? this.attempts,
      maxAttempts: maxAttempts,
    );
  }
}
