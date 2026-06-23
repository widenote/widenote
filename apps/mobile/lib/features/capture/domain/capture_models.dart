import 'package:flutter/foundation.dart';

@immutable
class CaptureRecord {
  const CaptureRecord({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String status;

  CaptureRecord copyWith({
    String? id,
    String? body,
    DateTime? createdAt,
    String? status,
  }) {
    return CaptureRecord(
      id: id ?? this.id,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

@immutable
class CaptureMemoryItem {
  const CaptureMemoryItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.sourceRecordId,
    required this.confidenceLabel,
    required this.statusLabel,
    required this.needsReview,
  });

  final String id;
  final String title;
  final String summary;
  final String sourceRecordId;
  final String confidenceLabel;
  final String statusLabel;
  final bool needsReview;
}

@immutable
class MemoryReviewCandidate {
  const MemoryReviewCandidate({
    required this.id,
    required this.summary,
    required this.sourceLabel,
    required this.reasonLabel,
    required this.typeLabel,
  });

  final String id;
  final String summary;
  final String sourceLabel;
  final String reasonLabel;
  final String typeLabel;
}

@immutable
class SourceTodo {
  const SourceTodo({
    required this.id,
    required this.title,
    required this.sourceLabel,
    required this.statusLabel,
  });

  final String id;
  final String title;
  final String sourceLabel;
  final String statusLabel;
}

@immutable
class TraceEvent {
  const TraceEvent({
    required this.id,
    required this.label,
    required this.detail,
    required this.sourceRecordId,
    required this.timeLabel,
    this.packId,
    this.agentId,
    this.runId,
  });

  final String id;
  final String label;
  final String detail;
  final String sourceRecordId;
  final String timeLabel;
  final String? packId;
  final String? agentId;
  final String? runId;
}

@immutable
class CaptureState {
  const CaptureState({
    required this.records,
    required this.memories,
    required this.reviewCandidates,
    required this.todos,
    required this.traces,
    required this.isProcessing,
    required this.errorMessage,
  });

  factory CaptureState.initial() {
    return const CaptureState(
      records: [],
      memories: [],
      reviewCandidates: [],
      todos: [
        SourceTodo(
          id: 'seed-todo-1',
          title: 'Review generated Memory before export',
          sourceLabel: 'source: local capture placeholder',
          statusLabel: 'source-linked placeholder',
        ),
        SourceTodo(
          id: 'seed-todo-2',
          title: 'Confirm backup permission boundary',
          sourceLabel: 'source: permission pack placeholder',
          statusLabel: 'needs explicit permission',
        ),
      ],
      traces: [],
      isProcessing: false,
      errorMessage: null,
    );
  }

  final List<CaptureRecord> records;
  final List<CaptureMemoryItem> memories;
  final List<MemoryReviewCandidate> reviewCandidates;
  final List<SourceTodo> todos;
  final List<TraceEvent> traces;
  final bool isProcessing;
  final String? errorMessage;

  CaptureState copyWith({
    List<CaptureRecord>? records,
    List<CaptureMemoryItem>? memories,
    List<MemoryReviewCandidate>? reviewCandidates,
    List<SourceTodo>? todos,
    List<TraceEvent>? traces,
    bool? isProcessing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CaptureState(
      records: records ?? this.records,
      memories: memories ?? this.memories,
      reviewCandidates: reviewCandidates ?? this.reviewCandidates,
      todos: todos ?? this.todos,
      traces: traces ?? this.traces,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
