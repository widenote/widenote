import 'package:flutter/foundation.dart';

@immutable
final class DailyRecapSnapshot {
  const DailyRecapSnapshot({
    required this.localDate,
    required this.captureCount,
    required this.eventCount,
    required this.memoryCount,
    required this.todoOpenCount,
    required this.todoCompletedCount,
    required this.cardCount,
    required this.insightCount,
    required this.traceCount,
    required this.records,
    required this.memories,
    required this.cards,
    required this.insights,
    required this.todos,
  });

  final DateTime localDate;
  final int captureCount;
  final int eventCount;
  final int memoryCount;
  final int todoOpenCount;
  final int todoCompletedCount;
  final int cardCount;
  final int insightCount;
  final int traceCount;
  final List<DailyRecapEntry> records;
  final List<DailyRecapEntry> memories;
  final List<DailyRecapEntry> cards;
  final List<DailyRecapEntry> insights;
  final List<DailyRecapEntry> todos;

  bool get isEmpty {
    return captureCount == 0 &&
        memoryCount == 0 &&
        todoOpenCount == 0 &&
        todoCompletedCount == 0 &&
        cardCount == 0 &&
        insightCount == 0;
  }
}

@immutable
final class DailyRecapEntry {
  const DailyRecapEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.sourceLabel,
    required this.timeLabel,
  });

  final String id;
  final String title;
  final String body;
  final String sourceLabel;
  final String timeLabel;
}
