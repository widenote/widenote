import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../../timeline/application/timeline_repository.dart';

final todoControllerProvider = NotifierProvider<TodoController, TodoState>(
  TodoController.new,
);

@immutable
final class TodoState {
  const TodoState({required this.items, this.errorMessage});

  final List<TodoListItem> items;
  final String? errorMessage;

  TodoState copyWith({
    List<TodoListItem>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TodoState(
      items: items ?? this.items,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

@immutable
final class TodoListItem {
  const TodoListItem({
    required this.id,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.sourceLabel,
    this.sourceCaptureId,
    this.sourceEventId,
  });

  final String id;
  final String title;
  final String status;
  final String statusLabel;
  final String sourceLabel;
  final String? sourceCaptureId;
  final String? sourceEventId;

  bool get isCompleted => status == 'completed';
}

final class TodoController extends Notifier<TodoState> {
  @override
  TodoState build() {
    return TodoState(items: _readItems());
  }

  void complete(String id) {
    _setStatus(id, 'completed');
  }

  void reopen(String id) {
    _setStatus(id, 'open');
  }

  void _setStatus(String id, String status) {
    try {
      _database.todos.updateStatus(id, status);
      ref.invalidate(timelineSnapshotProvider);
      state = state.copyWith(items: _readItems(), clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Todo update failed.');
    }
  }

  List<TodoListItem> _readItems() {
    return _database.todos
        .readAll()
        .where((record) => record.status != 'completed')
        .toList()
        .reversed
        .map(_todoView)
        .toList();
  }

  localdb.WideNoteLocalDatabase get _database {
    return ref.read(localDatabaseProvider);
  }
}

TodoListItem _todoView(localdb.TodoRecord record) {
  final title =
      _string(record.payload['title']) ??
      _string(record.payload['text']) ??
      'Review capture';
  return TodoListItem(
    id: record.id,
    title: title,
    status: record.status,
    statusLabel: record.status == 'completed'
        ? 'completed'
        : _string(record.payload['status_label']) ?? record.status,
    sourceLabel:
        _string(record.payload['source_label']) ??
        _sourceLabel(
          id: record.id,
          sourceCaptureId: record.sourceCaptureId,
          sourceEventId: record.sourceEventId,
        ),
    sourceCaptureId: record.sourceCaptureId,
    sourceEventId: record.sourceEventId,
  );
}

String _sourceLabel({
  required String id,
  String? sourceCaptureId,
  String? sourceEventId,
}) {
  if (sourceCaptureId != null) {
    return 'source: $sourceCaptureId';
  }
  if (sourceEventId != null) {
    return 'event: $sourceEventId';
  }
  return 'todo: $id';
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
