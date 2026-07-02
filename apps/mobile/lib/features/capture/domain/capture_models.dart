import 'package:flutter/foundation.dart';

import '../../location/domain/location_context.dart';

const captureStatusSavedProcessing = 'Saved locally, processing';
const captureStatusTranscriptReady = 'Saved locally, transcript ready';
const captureStatusProcessed = 'Processed locally';
const captureStatusAgentFailed = 'Saved locally, agent failed';

@immutable
class CaptureRecord {
  const CaptureRecord({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.status,
    this.sourceEventId,
    this.locationContext,
    this.memoryGenerated,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String status;
  final String? sourceEventId;
  final CapturedLocationContext? locationContext;
  final bool? memoryGenerated;

  bool get isProcessing {
    return status == captureStatusSavedProcessing ||
        status == captureStatusTranscriptReady;
  }

  bool get canRetry => status == captureStatusAgentFailed;

  CaptureRecord copyWith({
    String? id,
    String? body,
    DateTime? createdAt,
    String? status,
    String? sourceEventId,
    CapturedLocationContext? locationContext,
    bool? memoryGenerated,
    bool clearLocationContext = false,
    bool clearMemoryGenerated = false,
  }) {
    return CaptureRecord(
      id: id ?? this.id,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      locationContext: clearLocationContext
          ? null
          : locationContext ?? this.locationContext,
      memoryGenerated: clearMemoryGenerated
          ? null
          : memoryGenerated ?? this.memoryGenerated,
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
    this.suggestionKind = 'quiet',
    this.confidenceLabel = 'low',
    this.reasonLabel,
    this.scheduledAtLabel,
    this.sourceCaptureId,
    this.sourceEventId,
    this.isSuggested = true,
  });

  final String id;
  final String title;
  final String sourceLabel;
  final String statusLabel;
  final String suggestionKind;
  final String confidenceLabel;
  final String? reasonLabel;
  final String? scheduledAtLabel;
  final String? sourceCaptureId;
  final String? sourceEventId;
  final bool isSuggested;

  bool get isAction => suggestionKind == 'action';
  bool get isSchedule => suggestionKind == 'schedule';
}

@immutable
class SourceCard {
  const SourceCard({
    required this.id,
    required this.title,
    required this.summary,
    required this.sourceLabel,
    required this.kindLabel,
    required this.statusLabel,
  });

  final String id;
  final String title;
  final String summary;
  final String sourceLabel;
  final String kindLabel;
  final String statusLabel;
}

@immutable
class SourceInsight {
  const SourceInsight({
    required this.id,
    required this.title,
    required this.summary,
    required this.sourceLabel,
    required this.kindLabel,
    required this.metricLabel,
  });

  final String id;
  final String title;
  final String summary;
  final String sourceLabel;
  final String kindLabel;
  final String metricLabel;
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
    required this.cards,
    required this.insights,
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
      cards: [],
      insights: [],
      todos: [],
      traces: [],
      isProcessing: false,
      errorMessage: null,
    );
  }

  final List<CaptureRecord> records;
  final List<CaptureMemoryItem> memories;
  final List<MemoryReviewCandidate> reviewCandidates;
  final List<SourceCard> cards;
  final List<SourceInsight> insights;
  final List<SourceTodo> todos;
  final List<TraceEvent> traces;
  final bool isProcessing;
  final String? errorMessage;

  CaptureState copyWith({
    List<CaptureRecord>? records,
    List<CaptureMemoryItem>? memories,
    List<MemoryReviewCandidate>? reviewCandidates,
    List<SourceCard>? cards,
    List<SourceInsight>? insights,
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
      cards: cards ?? this.cards,
      insights: insights ?? this.insights,
      todos: todos ?? this.todos,
      traces: traces ?? this.traces,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
