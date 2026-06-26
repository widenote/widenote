import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../../capture/application/capture_controller.dart';
import '../../timeline/application/timeline_repository.dart';

final memoryControllerProvider =
    NotifierProvider<MemoryController, MemoryState>(MemoryController.new);

@immutable
final class MemoryState {
  const MemoryState({
    required this.activeItems,
    required this.deletedItems,
    this.errorMessage,
  });

  final List<MemoryListItem> activeItems;
  final List<MemoryListItem> deletedItems;
  final String? errorMessage;

  MemoryState copyWith({
    List<MemoryListItem>? activeItems,
    List<MemoryListItem>? deletedItems,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MemoryState(
      activeItems: activeItems ?? this.activeItems,
      deletedItems: deletedItems ?? this.deletedItems,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

@immutable
final class MemoryListItem {
  const MemoryListItem({
    required this.id,
    required this.key,
    required this.body,
    required this.status,
    required this.sourceLabel,
    required this.memoryType,
    required this.confidence,
    required this.sensitivity,
    required this.revision,
    required this.tombstone,
    required this.updatedAt,
    this.sourceCaptureId,
  });

  final String id;
  final String key;
  final String body;
  final String status;
  final String sourceLabel;
  final String memoryType;
  final String confidence;
  final String sensitivity;
  final int revision;
  final bool tombstone;
  final DateTime updatedAt;
  final String? sourceCaptureId;
}

final class MemoryController extends Notifier<MemoryState> {
  @override
  MemoryState build() {
    return _readState();
  }

  void editMemory(String id, String body) {
    final nextBody = body.trim();
    if (nextBody.isEmpty) {
      state = state.copyWith(errorMessage: 'Memory body cannot be empty.');
      return;
    }
    _updateItem(id, 'edited', (item, now) {
      return item.copyWith(
        body: nextBody,
        status: 'active',
        tombstone: false,
        revision: item.revision + 1,
        updatedAt: now,
      );
    });
  }

  void deleteMemory(String id) {
    _updateItem(id, 'deleted', (item, now) {
      return item.copyWith(
        status: 'deleted',
        tombstone: true,
        revision: item.revision + 1,
        updatedAt: now,
      );
    });
  }

  void restoreMemory(String id) {
    _updateItem(id, 'restored', (item, now) {
      return item.copyWith(
        status: 'active',
        tombstone: false,
        revision: item.revision + 1,
        updatedAt: now,
      );
    });
  }

  void _updateItem(
    String id,
    String action,
    localdb.MemoryItemRecord Function(localdb.MemoryItemRecord, DateTime)
    update,
  ) {
    try {
      final existing = _database.memoryItems.readById(id);
      if (existing == null) {
        throw StateError('Memory not found: $id');
      }
      final now = DateTime.now().toUtc();
      final updated = update(existing, now);
      _database.memoryItems.save(updated);
      _appendLifecycleEvidence(existing, updated, action, now);
      ref
        ..invalidate(timelineSnapshotProvider)
        ..invalidate(captureControllerProvider);
      state = _readState().copyWith(clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Memory update failed.');
    }
  }

  MemoryState _readState() {
    final items = _database.memoryItems.readAll().reversed.map(_memoryView);
    final active = <MemoryListItem>[];
    final deleted = <MemoryListItem>[];
    for (final item in items) {
      if (item.tombstone || item.status == 'deleted') {
        deleted.add(item);
      } else {
        active.add(item);
      }
    }
    return MemoryState(activeItems: active, deletedItems: deleted);
  }

  localdb.WideNoteLocalDatabase get _database {
    return ref.read(localDatabaseProvider);
  }

  void _appendLifecycleEvidence(
    localdb.MemoryItemRecord previous,
    localdb.MemoryItemRecord updated,
    String action,
    DateTime occurredAt,
  ) {
    final eventId =
        'event-memory-$action-${updated.id}-${occurredAt.microsecondsSinceEpoch}';
    final eventType = switch (action) {
      'edited' => runtime.WnEventTypes.memoryEdited,
      'deleted' => runtime.WnEventTypes.memoryDeleted,
      'restored' => runtime.WnEventTypes.memoryRestored,
      _ => 'wn.memory.$action',
    };
    _database.eventLog.append(
      localdb.EventLogEntry(
        id: eventId,
        type: eventType,
        actor: runtime.WnActor.user.name,
        subjectRef: <String, Object?>{'kind': 'memory', 'id': updated.id},
        sourceCaptureId: updated.sourceCaptureId,
        sourceEventId: updated.sourceEventId,
        payload: <String, Object?>{
          'action': action,
          'memory_id': updated.id,
          'previous_revision': previous.revision,
          'revision': updated.revision,
          'previous_status': previous.status,
          'status': updated.status,
          'previous_tombstone': previous.tombstone,
          'tombstone': updated.tombstone,
          if (action == 'edited') 'body': updated.body,
        },
        createdAt: occurredAt,
      ),
    );
    _database.traceEvents.insert(
      localdb.TraceEventRecord(
        id: 'trace-$eventId',
        name: 'memory.lifecycle.$action',
        level: 'info',
        traceTypeOverride: 'memory.lifecycle',
        message: 'Memory $action by user.',
        sourceEventId: eventId,
        status: 'ok',
        payload: <String, Object?>{
          'memory_id': updated.id,
          'revision': updated.revision,
          'action': action,
        },
        createdAt: occurredAt,
      ),
    );
  }
}

MemoryListItem _memoryView(localdb.MemoryItemRecord record) {
  return MemoryListItem(
    id: record.id,
    key: record.key,
    body: record.body,
    status: record.status,
    sourceLabel: _sourceLabel(record),
    memoryType: record.memoryType,
    confidence: record.confidence,
    sensitivity: record.sensitivity,
    revision: record.revision,
    tombstone: record.tombstone,
    updatedAt: record.updatedAt,
    sourceCaptureId: _sourceCaptureId(record),
  );
}

String? _sourceCaptureId(localdb.MemoryItemRecord record) {
  for (final sourceRef in record.sourceRefs.whereType<Map>()) {
    final kind =
        _string(sourceRef['kind']) ?? _string(sourceRef['source_type']);
    final id = _string(sourceRef['id']) ?? _string(sourceRef['source_id']);
    if ((kind == 'capture' || kind == 'event') && id != null) {
      return id;
    }
  }
  return record.sourceCaptureId ?? record.sourceEventId;
}

String _sourceLabel(localdb.MemoryItemRecord record) {
  final first = record.sourceRefs.whereType<Map>().firstOrNull;
  if (first != null) {
    final kind = _string(first['kind']) ?? _string(first['source_type']);
    final id = _string(first['id']) ?? _string(first['source_id']);
    if (kind != null && id != null) {
      return '$kind: $id';
    }
  }
  if (record.sourceEventId != null) {
    return 'event: ${record.sourceEventId}';
  }
  if (record.sourceCaptureId != null) {
    return 'capture: ${record.sourceCaptureId}';
  }
  return 'memory: ${record.id}';
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
