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
  const TodoState({
    required this.actionItems,
    required this.scheduleItems,
    required this.quietItems,
    this.errorMessage,
  });

  final List<TodoListItem> actionItems;
  final List<TodoListItem> scheduleItems;
  final List<TodoListItem> quietItems;
  final String? errorMessage;

  List<TodoListItem> get items => <TodoListItem>[
    ...actionItems,
    ...scheduleItems,
  ];

  int get quietCount => quietItems.length;

  TodoState copyWith({
    List<TodoListItem>? actionItems,
    List<TodoListItem>? scheduleItems,
    List<TodoListItem>? quietItems,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TodoState(
      actionItems: actionItems ?? this.actionItems,
      scheduleItems: scheduleItems ?? this.scheduleItems,
      quietItems: quietItems ?? this.quietItems,
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
    required this.suggestionKind,
    required this.confidenceLabel,
    this.reasonLabel,
    this.scheduledAtLabel,
    this.sourceCaptureId,
    this.sourceEventId,
  });

  final String id;
  final String title;
  final String status;
  final String statusLabel;
  final String sourceLabel;
  final String suggestionKind;
  final String confidenceLabel;
  final String? reasonLabel;
  final String? scheduledAtLabel;
  final String? sourceCaptureId;
  final String? sourceEventId;

  bool get isCompleted => status == 'completed';
  bool get isAction => suggestionKind == 'action';
  bool get isSchedule => suggestionKind == 'schedule';
  bool get isQuiet => suggestionKind == 'quiet';
}

final class TodoController extends Notifier<TodoState> {
  @override
  TodoState build() {
    return _readState();
  }

  Future<void> refresh() async {
    state = _readState().copyWith(clearError: true);
  }

  void complete(String id) {
    _setStatus(id, 'completed');
  }

  void reopen(String id) {
    _setStatus(id, 'open');
  }

  void _setStatus(String id, String status) {
    try {
      final item = _itemById(id);
      if (item != null && !item.isAction) {
        return;
      }
      _database.todos.updateStatus(id, status);
      ref.invalidate(timelineSnapshotProvider);
      state = _readState().copyWith(clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Todo update failed.');
    }
  }

  TodoListItem? _itemById(String id) {
    for (final item in state.items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  TodoState _readState() {
    final items = _database.todos
        .readAll()
        .where((record) => record.status != 'completed')
        .toList()
        .reversed
        .map(_todoView)
        .toList();
    return TodoState(
      actionItems: items.where((item) => item.isAction).toList(growable: false),
      scheduleItems: items
          .where((item) => item.isSchedule)
          .toList(growable: false),
      quietItems: items.where((item) => item.isQuiet).toList(growable: false),
    );
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
  final suggestionKind = _string(record.payload['suggestion_kind']) ?? 'quiet';
  final statusLabel =
      _string(record.payload['status_label']) ??
      switch (suggestionKind) {
        'schedule' => 'schedule candidate',
        'action' => record.status,
        _ => 'not suggested',
      };
  return TodoListItem(
    id: record.id,
    title: title,
    status: record.status,
    statusLabel: record.status == 'completed' ? 'completed' : statusLabel,
    sourceLabel:
        _string(record.payload['source_label']) ??
        _sourceLabel(
          id: record.id,
          sourceCaptureId: record.sourceCaptureId,
          sourceEventId: record.sourceEventId,
        ),
    suggestionKind: suggestionKind,
    confidenceLabel: _string(record.payload['suggestion_confidence']) ?? 'low',
    reasonLabel:
        _string(record.payload['suggestion_reason']) ??
        'legacy_missing_suggestion_kind',
    scheduledAtLabel: _string(record.payload['scheduled_at_label']),
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
