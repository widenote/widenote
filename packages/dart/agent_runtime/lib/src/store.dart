import 'event.dart';
import 'task.dart';

abstract interface class EventStore {
  Future<void> append(WnEvent event);
  Future<void> appendAll(Iterable<WnEvent> events);
  Future<List<WnEvent>> readAll();
  Future<WnEvent?> readById(String id);
  Future<List<WnEvent>> readByType(String type);
}

final class InMemoryEventStore implements EventStore {
  final List<WnEvent> _events = <WnEvent>[];
  final Map<String, WnEvent> _byId = <String, WnEvent>{};

  @override
  Future<void> append(WnEvent event) async {
    if (_byId.containsKey(event.id)) {
      throw StateError('Event already exists: ${event.id}');
    }
    _events.add(event);
    _byId[event.id] = event;
  }

  @override
  Future<void> appendAll(Iterable<WnEvent> events) async {
    final batch = events.toList(growable: false);
    final batchIds = <String>{};
    for (final event in batch) {
      if (_byId.containsKey(event.id)) {
        throw StateError('Event already exists: ${event.id}');
      }
      if (!batchIds.add(event.id)) {
        throw StateError('Duplicate event in batch: ${event.id}');
      }
    }
    for (final event in batch) {
      _events.add(event);
      _byId[event.id] = event;
    }
  }

  @override
  Future<List<WnEvent>> readAll() async => List<WnEvent>.unmodifiable(_events);

  @override
  Future<WnEvent?> readById(String id) async => _byId[id];

  @override
  Future<List<WnEvent>> readByType(String type) async {
    return List<WnEvent>.unmodifiable(
      _events.where((event) => event.type == type),
    );
  }
}

abstract interface class RuntimeStore {
  Future<void> upsertTask(RuntimeTask task);
  Future<RuntimeTask?> readTaskById(String id);
  Future<List<RuntimeTask>> readTasks({String? packId});
  Future<RuntimeTask?> claimTaskForExecution(
    String id, {
    required String leaseOwner,
    required DateTime leasedUntil,
    required DateTime now,
    required int maxRunningTasks,
  });
  Future<RuntimeTask?> upsertTaskIfLeaseOwner(
    RuntimeTask task, {
    required String leaseOwner,
  });

  Future<void> upsertRun(RuntimeRun run);
  Future<RuntimeRun?> readRunById(String id);
  Future<List<RuntimeRun>> readRuns({String? taskId, String? packId});

  Future<void> upsertPackStatus(RuntimePackStatus status);
  Future<RuntimePackStatus?> readPackStatus(String packId);
  Future<List<RuntimePackStatus>> readPackStatuses();
}

abstract interface class RuntimePackInstallationStore {
  Future<void> upsertPackInstallation(RuntimePackInstallation installation);
  Future<RuntimePackInstallation?> readPackInstallation(String packId);
}

final class InMemoryRuntimeStore
    implements RuntimeStore, RuntimePackInstallationStore {
  final Map<String, RuntimeTask> _tasksById = <String, RuntimeTask>{};
  final List<String> _taskOrder = <String>[];
  final Map<String, RuntimeRun> _runsById = <String, RuntimeRun>{};
  final List<String> _runOrder = <String>[];
  final Map<String, RuntimePackStatus> _packStatusesById =
      <String, RuntimePackStatus>{};
  final List<String> _packStatusOrder = <String>[];
  final Map<String, RuntimePackInstallation> _packInstallationsById =
      <String, RuntimePackInstallation>{};

  @override
  Future<void> upsertTask(RuntimeTask task) async {
    if (!_tasksById.containsKey(task.id)) {
      _taskOrder.add(task.id);
    }
    _tasksById[task.id] = task;
  }

  @override
  Future<RuntimeTask?> readTaskById(String id) async => _tasksById[id];

  @override
  Future<List<RuntimeTask>> readTasks({String? packId}) async {
    return List<RuntimeTask>.unmodifiable(
      _taskOrder
          .map((id) => _tasksById[id])
          .whereType<RuntimeTask>()
          .where((task) => packId == null || task.packId == packId),
    );
  }

  @override
  Future<RuntimeTask?> claimTaskForExecution(
    String id, {
    required String leaseOwner,
    required DateTime leasedUntil,
    required DateTime now,
    required int maxRunningTasks,
  }) async {
    final task = _tasksById[id];
    if (task == null ||
        (task.status != RuntimeTaskStatus.queued &&
            task.status != RuntimeTaskStatus.waiting)) {
      return null;
    }
    final scheduledAt = task.scheduledAt;
    if (scheduledAt != null && scheduledAt.isAfter(now)) {
      return null;
    }
    if (!_dependenciesSucceeded(task)) {
      return null;
    }
    final running = _tasksById.values
        .where((candidate) => _isActiveRunning(candidate, now))
        .length;
    if (running >= maxRunningTasks) {
      return null;
    }
    final concurrencyKey = task.concurrencyKey;
    if (concurrencyKey != null &&
        _tasksById.values.any(
          (candidate) =>
              candidate.id != task.id &&
              candidate.concurrencyKey == concurrencyKey &&
              _isActiveRunning(candidate, now),
        )) {
      return null;
    }
    final claimed = task.copyWith(
      status: RuntimeTaskStatus.running,
      updatedAt: now,
      attempts: task.attempts + 1,
      leaseOwner: leaseOwner,
      leasedUntil: leasedUntil,
      clearError: true,
      clearScheduledAt: true,
    );
    _tasksById[id] = claimed;
    return claimed;
  }

  @override
  Future<RuntimeTask?> upsertTaskIfLeaseOwner(
    RuntimeTask task, {
    required String leaseOwner,
  }) async {
    final existing = _tasksById[task.id];
    if (existing == null || existing.leaseOwner != leaseOwner) {
      return null;
    }
    await upsertTask(task);
    return task;
  }

  @override
  Future<void> upsertRun(RuntimeRun run) async {
    if (!_runsById.containsKey(run.id)) {
      _runOrder.add(run.id);
    }
    _runsById[run.id] = run;
  }

  @override
  Future<RuntimeRun?> readRunById(String id) async => _runsById[id];

  @override
  Future<List<RuntimeRun>> readRuns({String? taskId, String? packId}) async {
    return List<RuntimeRun>.unmodifiable(
      _runOrder
          .map((id) => _runsById[id])
          .whereType<RuntimeRun>()
          .where((run) => taskId == null || run.taskId == taskId)
          .where((run) => packId == null || run.packId == packId),
    );
  }

  @override
  Future<void> upsertPackStatus(RuntimePackStatus status) async {
    if (!_packStatusesById.containsKey(status.packId)) {
      _packStatusOrder.add(status.packId);
    }
    _packStatusesById[status.packId] = status;
  }

  @override
  Future<RuntimePackStatus?> readPackStatus(String packId) async {
    return _packStatusesById[packId];
  }

  @override
  Future<List<RuntimePackStatus>> readPackStatuses() async {
    return List<RuntimePackStatus>.unmodifiable(
      _packStatusOrder
          .map((id) => _packStatusesById[id])
          .whereType<RuntimePackStatus>(),
    );
  }

  @override
  Future<void> upsertPackInstallation(
    RuntimePackInstallation installation,
  ) async {
    _packInstallationsById[installation.packId] = installation;
  }

  @override
  Future<RuntimePackInstallation?> readPackInstallation(String packId) async {
    return _packInstallationsById[packId];
  }

  bool _dependenciesSucceeded(RuntimeTask task) {
    return task.dependencyTaskIds.every(
      (id) => _tasksById[id]?.status == RuntimeTaskStatus.succeeded,
    );
  }

  bool _isActiveRunning(RuntimeTask task, DateTime now) {
    if (task.status != RuntimeTaskStatus.running) {
      return false;
    }
    final leasedUntil = task.leasedUntil;
    return leasedUntil == null || leasedUntil.isAfter(now);
  }
}
