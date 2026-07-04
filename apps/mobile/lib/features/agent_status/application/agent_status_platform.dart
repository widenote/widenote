import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agent_execution_status_controller.dart';

final agentStatusPlatformClientProvider = Provider<AgentStatusPlatformClient>((
  ref,
) {
  return const MethodChannelAgentStatusPlatformClient();
});

final agentStatusPlatformSyncControllerProvider =
    NotifierProvider<
      AgentStatusPlatformSyncController,
      AgentStatusPlatformSyncState
    >(AgentStatusPlatformSyncController.new);

abstract interface class AgentStatusPlatformClient {
  Future<AgentStatusPlatformResult> sync(AgentStatusPlatformPayload payload);
}

final class MethodChannelAgentStatusPlatformClient
    implements AgentStatusPlatformClient {
  const MethodChannelAgentStatusPlatformClient({
    MethodChannel channel = const MethodChannel('app.widenote/agent_status'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<AgentStatusPlatformResult> sync(
    AgentStatusPlatformPayload payload,
  ) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'syncStatus',
      payload.toJson(),
    );
    return AgentStatusPlatformResult(
      notificationStatus: result?['notification_status']?.toString(),
      liveActivityStatus: result?['live_activity_status']?.toString(),
    );
  }
}

final class AgentStatusPlatformSyncController
    extends Notifier<AgentStatusPlatformSyncState> {
  String? _lastSyncKey;

  @override
  AgentStatusPlatformSyncState build() {
    return const AgentStatusPlatformSyncState();
  }

  Future<void> sync(
    AgentExecutionStatusSnapshot snapshot,
    AgentStatusPlatformLabels labels,
  ) async {
    final payload = AgentStatusPlatformPayload.fromSnapshot(
      snapshot,
      labels: labels,
    );
    if (_lastSyncKey == payload.syncKey) {
      return;
    }
    state = state.copyWith(
      status: AgentStatusPlatformSyncStatus.syncing,
      lastSyncKey: payload.syncKey,
      clearError: true,
    );
    try {
      final result = await ref
          .read(agentStatusPlatformClientProvider)
          .sync(payload);
      if (result.hasNativeFailure) {
        state = state.copyWith(
          status: AgentStatusPlatformSyncStatus.failed,
          lastResult: result,
          errorCode: 'native_failed',
        );
        return;
      }
      _lastSyncKey = payload.syncKey;
      state = state.copyWith(
        status: AgentStatusPlatformSyncStatus.synced,
        lastResult: result,
        clearError: true,
      );
    } on MissingPluginException {
      state = state.copyWith(
        status: AgentStatusPlatformSyncStatus.unsupported,
        clearError: true,
      );
      _lastSyncKey = payload.syncKey;
    } on PlatformException catch (error) {
      state = state.copyWith(
        status: AgentStatusPlatformSyncStatus.failed,
        errorCode: error.code,
      );
    } catch (error) {
      state = state.copyWith(
        status: AgentStatusPlatformSyncStatus.failed,
        errorCode: error.runtimeType.toString(),
      );
    }
  }
}

@immutable
final class AgentStatusPlatformPayload {
  const AgentStatusPlatformPayload({
    required this.schemaVersion,
    required this.status,
    required this.title,
    required this.body,
    required this.runningCount,
    required this.queuedCount,
    required this.retryingCount,
    required this.recoveringCount,
    required this.failedCount,
    required this.blockedCount,
    required this.deniedCount,
    required this.canceledCount,
    required this.succeededCount,
    required this.updatedAt,
    required this.staleAt,
    required this.hasActiveWork,
    required this.items,
  });

  factory AgentStatusPlatformPayload.fromSnapshot(
    AgentExecutionStatusSnapshot snapshot, {
    required AgentStatusPlatformLabels labels,
  }) {
    final updatedAt = snapshot.lastUpdatedAt ?? snapshot.generatedAt;
    return AgentStatusPlatformPayload(
      schemaVersion: 1,
      status: snapshot.overallStatus.wireName,
      title: labels.title,
      body: labels.body,
      runningCount: snapshot.runningCount,
      queuedCount: snapshot.queuedCount,
      retryingCount: snapshot.retryingCount,
      recoveringCount: snapshot.recoveringCount,
      failedCount: snapshot.failedCount,
      blockedCount: snapshot.blockedCount,
      deniedCount: snapshot.deniedCount,
      canceledCount: snapshot.canceledCount,
      succeededCount: snapshot.succeededCount,
      updatedAt: updatedAt,
      staleAt: _staleAtForSnapshot(snapshot),
      hasActiveWork: snapshot.activeCount > 0,
      items: snapshot.items
          .take(4)
          .map(AgentStatusPlatformItem.fromStatusItem)
          .toList(growable: false),
    );
  }

  final int schemaVersion;
  final String status;
  final String title;
  final String body;
  final int runningCount;
  final int queuedCount;
  final int retryingCount;
  final int recoveringCount;
  final int failedCount;
  final int blockedCount;
  final int deniedCount;
  final int canceledCount;
  final int succeededCount;
  final DateTime updatedAt;
  final DateTime staleAt;
  final bool hasActiveWork;
  final List<AgentStatusPlatformItem> items;

  String get syncKey {
    return [
      status,
      title,
      body,
      runningCount,
      queuedCount,
      retryingCount,
      recoveringCount,
      failedCount,
      blockedCount,
      deniedCount,
      canceledCount,
      succeededCount,
      hasActiveWork,
      for (final item in items) item.syncKey,
    ].join('|');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': schemaVersion,
      'status': status,
      'title': title,
      'body': body,
      'running_count': runningCount,
      'queued_count': queuedCount,
      'retrying_count': retryingCount,
      'recovering_count': recoveringCount,
      'failed_count': failedCount,
      'blocked_count': blockedCount,
      'denied_count': deniedCount,
      'canceled_count': canceledCount,
      'succeeded_count': succeededCount,
      'has_active_work': hasActiveWork,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'stale_at': staleAt.toUtc().toIso8601String(),
    };
  }
}

DateTime _staleAtForSnapshot(AgentExecutionStatusSnapshot snapshot) {
  if (snapshot.overallStatus == AgentExecutionOverallStatus.idle) {
    return snapshot.generatedAt.add(const Duration(seconds: 5));
  }
  if (snapshot.activeCount > 0) {
    return snapshot.generatedAt.add(const Duration(minutes: 15));
  }
  return snapshot.terminalStatusExpiresAt ??
      snapshot.generatedAt.add(
        AgentExecutionStatusController.terminalVisibleWindow,
      );
}

@immutable
final class AgentStatusPlatformItem {
  const AgentStatusPlatformItem({
    required this.taskId,
    required this.packId,
    required this.agentId,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
  });

  factory AgentStatusPlatformItem.fromStatusItem(
    AgentExecutionStatusItem item,
  ) {
    return AgentStatusPlatformItem(
      taskId: item.taskId,
      packId: item.packId,
      agentId: item.agentId,
      status: item.kind.wireName,
      attempts: item.attempts,
      maxAttempts: item.maxAttempts,
    );
  }

  final String taskId;
  final String packId;
  final String agentId;
  final String status;
  final int attempts;
  final int maxAttempts;

  String get syncKey {
    return '$taskId:$status:$attempts/$maxAttempts';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'task_id': taskId,
      'pack_id': packId,
      'agent_id': agentId,
      'status': status,
      'attempts': attempts,
      'max_attempts': maxAttempts,
    };
  }
}

@immutable
final class AgentStatusPlatformLabels {
  const AgentStatusPlatformLabels({required this.title, required this.body});

  final String title;
  final String body;
}

@immutable
final class AgentStatusPlatformResult {
  const AgentStatusPlatformResult({
    this.notificationStatus,
    this.liveActivityStatus,
  });

  final String? notificationStatus;
  final String? liveActivityStatus;

  bool get hasNativeFailure {
    return notificationStatus == 'failed' || liveActivityStatus == 'failed';
  }
}

enum AgentStatusPlatformSyncStatus {
  idle,
  syncing,
  synced,
  unsupported,
  failed,
}

@immutable
final class AgentStatusPlatformSyncState {
  const AgentStatusPlatformSyncState({
    this.status = AgentStatusPlatformSyncStatus.idle,
    this.lastSyncKey,
    this.lastResult,
    this.errorCode,
  });

  final AgentStatusPlatformSyncStatus status;
  final String? lastSyncKey;
  final AgentStatusPlatformResult? lastResult;
  final String? errorCode;

  AgentStatusPlatformSyncState copyWith({
    AgentStatusPlatformSyncStatus? status,
    String? lastSyncKey,
    AgentStatusPlatformResult? lastResult,
    String? errorCode,
    bool clearError = false,
  }) {
    return AgentStatusPlatformSyncState(
      status: status ?? this.status,
      lastSyncKey: lastSyncKey ?? this.lastSyncKey,
      lastResult: lastResult ?? this.lastResult,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }
}
