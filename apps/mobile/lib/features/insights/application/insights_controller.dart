import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_cards/widenote_cards.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';

final insightsControllerProvider =
    NotifierProvider<InsightsController, InsightsState>(InsightsController.new);

@immutable
final class InsightsState {
  const InsightsState({required this.items});

  final List<InsightListItem> items;

  bool get isEmpty => items.isEmpty;

  InsightListItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}

@immutable
final class InsightListItem {
  const InsightListItem({
    required this.id,
    required this.insightKind,
    required this.status,
    required this.title,
    required this.summary,
    required this.sourceLinks,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.metricLabel,
    this.metricValue,
    this.confidence,
    this.sensitivity,
    this.evidenceDensity,
    this.requiresReview = false,
    this.evidence = const <InsightEvidenceItem>[],
    this.counterEvidence = const <InsightEvidenceItem>[],
  });

  final String id;
  final String insightKind;
  final String status;
  final String title;
  final String summary;
  final List<SourceLink> sourceLinks;
  final MemoryFirstInsightPayload payload;
  final String? metricLabel;
  final num? metricValue;
  final num? confidence;
  final String? sensitivity;
  final String? evidenceDensity;
  final bool requiresReview;
  final List<InsightEvidenceItem> evidence;
  final List<InsightEvidenceItem> counterEvidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get sourceRefCount => sourceLinks.length;
}

@immutable
final class InsightEvidenceItem {
  const InsightEvidenceItem({
    required this.text,
    required this.sourceLinks,
    this.id,
    this.label,
    this.confidence,
  });

  final String? id;
  final String? label;
  final String text;
  final num? confidence;
  final List<SourceLink> sourceLinks;
}

final class InsightsController extends Notifier<InsightsState> {
  @override
  InsightsState build() {
    return _readState();
  }

  void refresh() {
    state = _readState();
  }

  InsightListItem? readInsightById(String id) {
    final record = _database.insights.readById(id);
    if (record == null || _isLegacyArchived(record)) {
      return null;
    }
    return _insightView(record);
  }

  InsightsState _readState() {
    final records = _database.insights
        .readAll()
        .reversed
        .where((record) => !_isLegacyArchived(record))
        .map(_insightView)
        .toList(growable: false);
    return InsightsState(items: records);
  }

  localdb.WideNoteLocalDatabase get _database {
    return ref.read(localDatabaseProvider);
  }
}

bool _isLegacyArchived(localdb.InsightRecord record) {
  return record.status.trim().toLowerCase() == 'archived';
}

InsightListItem _insightView(localdb.InsightRecord record) {
  final payload = _payloadFromRecord(record);
  final sourceLinks = dedupeSourceLinks(<SourceLink>[
    ..._safeSourceLinks(record.sourceRefs),
    ...payload.sourceLinks,
    for (final claim in payload.claims) ...claim.sourceLinks,
    for (final metric in payload.metrics) ...metric.sourceLinks,
  ]);
  return InsightListItem(
    id: record.id,
    insightKind: record.insightKind,
    status: record.status,
    title: record.title,
    summary: record.summary,
    sourceLinks: sourceLinks,
    payload: payload,
    metricLabel: record.metricLabel,
    metricValue: record.metricValue,
    confidence: _num(record.payload['confidence']),
    sensitivity: _string(record.payload['sensitivity']),
    evidenceDensity: _string(record.payload['evidence_density']),
    requiresReview:
        _bool(record.payload['requires_review']) ||
        record.status == 'review' ||
        record.status == 'needs_review',
    evidence: _evidenceItems(record.payload['evidence']),
    counterEvidence: _evidenceItems(record.payload['counter_evidence']),
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
  );
}

MemoryFirstInsightPayload _payloadFromRecord(localdb.InsightRecord record) {
  try {
    return MemoryFirstInsightPayload.fromJson(
      Map<Object?, Object?>.from(record.payload),
    );
  } on ArgumentError {
    return MemoryFirstInsightPayload(
      sourceLinks: _safeSourceLinks(record.sourceRefs),
    );
  }
}

List<SourceLink> _safeSourceLinks(List<Object?> sourceRefs) {
  try {
    return sourceLinksFromJsonList(sourceRefs);
  } on ArgumentError {
    return const <SourceLink>[];
  }
}

List<InsightEvidenceItem> _evidenceItems(Object? value) {
  if (value is! List) {
    return const <InsightEvidenceItem>[];
  }
  final items = <InsightEvidenceItem>[];
  for (final entry in value) {
    if (entry is! Map) {
      continue;
    }
    final text =
        _string(entry['text']) ??
        _string(entry['summary']) ??
        _string(entry['claim']);
    if (text == null) {
      continue;
    }
    items.add(
      InsightEvidenceItem(
        id: _string(entry['id']),
        label: _string(entry['label']) ?? _string(entry['kind']),
        text: text,
        confidence: _num(entry['confidence']),
        sourceLinks: _safeSourceLinks(
          entry['source_refs'] is List
              ? List<Object?>.from(entry['source_refs']! as List)
              : const <Object?>[],
        ),
      ),
    );
  }
  return List<InsightEvidenceItem>.unmodifiable(items);
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}
