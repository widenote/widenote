import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _updateItem(id, (item, now) {
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
    _updateItem(id, (item, now) {
      return item.copyWith(
        status: 'deleted',
        tombstone: true,
        revision: item.revision + 1,
        updatedAt: now,
      );
    });
  }

  void restoreMemory(String id) {
    _updateItem(id, (item, now) {
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
    localdb.MemoryItemRecord Function(localdb.MemoryItemRecord, DateTime)
    update,
  ) {
    try {
      final existing = _database.memoryItems.readById(id);
      if (existing == null) {
        throw StateError('Memory not found: $id');
      }
      _database.memoryItems.save(update(existing, DateTime.now().toUtc()));
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
  );
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
