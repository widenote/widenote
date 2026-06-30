typedef CardJsonMap = Map<String, Object?>;

abstract final class InsightUiBlockKinds {
  static const String claimList = 'claim_list';
  static const String metricRow = 'metric_row';
  static const String sourceRefs = 'source_refs';
  static const String note = 'note';
}

const Set<String> allowedInsightUiBlockKinds = <String>{
  InsightUiBlockKinds.claimList,
  InsightUiBlockKinds.metricRow,
  InsightUiBlockKinds.sourceRefs,
  InsightUiBlockKinds.note,
};

enum MemoryFirstCardKind { captureSummary, memorySummary }

enum MemoryFirstInsightKind {
  summary,
  count,
  trend,
  sourceMix,
  actionPattern,
  attachmentEvidence,
}

final class SourceLink {
  const SourceLink({
    required this.kind,
    required this.id,
    this.label,
    this.excerpt,
    this.uri,
  });

  final String kind;
  final String id;
  final String? label;
  final String? excerpt;
  final Uri? uri;

  factory SourceLink.fromJson(Map<Object?, Object?> json) {
    final kind = _string(json['kind']) ?? _string(json['source_type']);
    final id =
        _string(json['id']) ??
        _string(json['source_id']) ??
        _string(json['event_id']);
    if (kind == null || id == null) {
      throw ArgumentError.value(json, 'json', 'source link needs kind and id');
    }
    final uriValue = _string(json['uri']);
    return SourceLink(
      kind: kind,
      id: id,
      label: _string(json['label']),
      excerpt: _string(json['excerpt']) ?? _string(json['evidence_text']),
      uri: uriValue == null ? null : Uri.tryParse(uriValue),
    );
  }

  CardJsonMap toJson() {
    return <String, Object?>{
      'kind': kind,
      'id': id,
      if (label != null) 'label': label,
      if (excerpt != null) 'excerpt': excerpt,
      if (uri != null) 'uri': uri.toString(),
    };
  }
}

final class MemoryFirstInsightClaim {
  MemoryFirstInsightClaim({
    required this.text,
    required this.sourceLinks,
    this.id,
    this.confidence,
    this.metadata = const <String, Object?>{},
  }) {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be empty');
    }
    _requireSourceLinks(sourceLinks, 'sourceLinks');
  }

  final String? id;
  final String text;
  final List<SourceLink> sourceLinks;
  final num? confidence;
  final CardJsonMap metadata;

  factory MemoryFirstInsightClaim.fromJson(Map<Object?, Object?> json) {
    return MemoryFirstInsightClaim(
      id: _string(json['id']),
      text: _requiredString(json['text'], 'text'),
      sourceLinks: _sourceLinksFromValue(
        json['source_refs'] ?? json['sourceLinks'],
        'source_refs',
      ),
      confidence: _num(json['confidence']),
      metadata: _jsonMap(json['metadata']),
    );
  }

  CardJsonMap toJson() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'text': text.trim(),
      'source_refs': sourceLinks
          .map((link) => link.toJson())
          .toList(growable: false),
      if (confidence != null) 'confidence': confidence,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

final class MemoryFirstInsightMetric {
  MemoryFirstInsightMetric({
    required this.label,
    required this.value,
    this.unit,
    this.sourceLinks = const <SourceLink>[],
  }) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
  }

  final String label;
  final num value;
  final String? unit;
  final List<SourceLink> sourceLinks;

  factory MemoryFirstInsightMetric.fromJson(Map<Object?, Object?> json) {
    return MemoryFirstInsightMetric(
      label: _requiredString(json['label'], 'label'),
      value: _requiredNum(json['value'], 'value'),
      unit: _string(json['unit']),
      sourceLinks: _sourceLinksFromValue(
        json['source_refs'] ?? json['sourceLinks'],
        'source_refs',
        required: false,
      ),
    );
  }

  CardJsonMap toJson() {
    return <String, Object?>{
      'label': label.trim(),
      'value': value,
      if (unit != null) 'unit': unit,
      if (sourceLinks.isNotEmpty)
        'source_refs': sourceLinks
            .map((link) => link.toJson())
            .toList(growable: false),
    };
  }
}

final class MemoryFirstInsightUiBlock {
  MemoryFirstInsightUiBlock({
    required this.kind,
    this.ref,
    this.payload = const <String, Object?>{},
  }) {
    _requireAllowedInsightUiBlockKind(kind, 'kind');
  }

  final String kind;
  final String? ref;
  final CardJsonMap payload;

  factory MemoryFirstInsightUiBlock.fromJson(Map<Object?, Object?> json) {
    return MemoryFirstInsightUiBlock(
      kind: _requiredString(json['kind'] ?? json['type'], 'kind'),
      ref: _string(json['ref']),
      payload: _jsonMap(json['payload']),
    );
  }

  CardJsonMap toJson() {
    return <String, Object?>{
      'kind': kind,
      if (ref != null) 'ref': ref,
      if (payload.isNotEmpty) 'payload': payload,
    };
  }
}

final class MemoryFirstInsightPayload {
  MemoryFirstInsightPayload({
    this.claims = const <MemoryFirstInsightClaim>[],
    this.metrics = const <MemoryFirstInsightMetric>[],
    this.sourceLinks = const <SourceLink>[],
    this.uiBlocks = const <MemoryFirstInsightUiBlock>[],
    this.note,
  });

  final List<MemoryFirstInsightClaim> claims;
  final List<MemoryFirstInsightMetric> metrics;
  final List<SourceLink> sourceLinks;
  final List<MemoryFirstInsightUiBlock> uiBlocks;
  final String? note;

  bool get isEmpty {
    return claims.isEmpty &&
        metrics.isEmpty &&
        sourceLinks.isEmpty &&
        uiBlocks.isEmpty &&
        note == null;
  }

  factory MemoryFirstInsightPayload.fromJson(Map<Object?, Object?> json) {
    return MemoryFirstInsightPayload(
      claims: _objectList(
        json['claims'],
        'claims',
        MemoryFirstInsightClaim.fromJson,
      ),
      metrics: _objectList(
        json['metrics'] ?? json['stats'],
        'metrics',
        MemoryFirstInsightMetric.fromJson,
      ),
      sourceLinks: _sourceLinksFromValue(
        json['source_refs'] ?? json['sourceLinks'],
        'source_refs',
        required: false,
      ),
      uiBlocks: _objectList(
        json['ui_blocks'] ?? json['uiBlocks'],
        'ui_blocks',
        MemoryFirstInsightUiBlock.fromJson,
      ),
      note: _string(json['note']),
    );
  }

  CardJsonMap toJson() {
    return <String, Object?>{
      'claims': claims.map((claim) => claim.toJson()).toList(growable: false),
      if (metrics.isNotEmpty)
        'metrics': metrics
            .map((metric) => metric.toJson())
            .toList(growable: false),
      if (sourceLinks.isNotEmpty)
        'source_refs': sourceLinks
            .map((link) => link.toJson())
            .toList(growable: false),
      if (uiBlocks.isNotEmpty)
        'ui_blocks': uiBlocks
            .map((block) => block.toJson())
            .toList(growable: false),
      if (note != null) 'note': note,
    };
  }
}

final class CaptureCardSource {
  const CaptureCardSource({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;
}

final class MemoryCardSource {
  const MemoryCardSource({
    required this.id,
    required this.key,
    required this.body,
    required this.createdAt,
    this.memoryType = 'project',
    this.sourceLinks = const <SourceLink>[],
  });

  final String id;
  final String key;
  final String body;
  final String memoryType;
  final DateTime createdAt;
  final List<SourceLink> sourceLinks;
}

final class MemoryFirstCardInput {
  const MemoryFirstCardInput({
    required this.now,
    this.captures = const <CaptureCardSource>[],
    this.memories = const <MemoryCardSource>[],
  });

  final DateTime now;
  final List<CaptureCardSource> captures;
  final List<MemoryCardSource> memories;
}

final class MemoryFirstCard {
  MemoryFirstCard({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.sourceLinks,
    required this.createdAt,
    this.status = 'active',
    this.metadata = const <String, Object?>{},
  }) {
    _requireSourceLinks(sourceLinks, 'sourceLinks');
  }

  final String id;
  final MemoryFirstCardKind kind;
  final String title;
  final String body;
  final List<SourceLink> sourceLinks;
  final DateTime createdAt;
  final String status;
  final CardJsonMap metadata;

  bool get isSourceLinked => sourceLinks.isNotEmpty;
}

final class MemoryFirstInsight {
  MemoryFirstInsight({
    required this.id,
    required this.kind,
    required this.title,
    required this.summary,
    required this.sourceLinks,
    required this.createdAt,
    this.metricLabel,
    this.metricValue,
    this.claims = const <MemoryFirstInsightClaim>[],
    this.metrics = const <MemoryFirstInsightMetric>[],
    this.uiBlocks = const <MemoryFirstInsightUiBlock>[],
    this.metadata = const <String, Object?>{},
  }) {
    _requireSourceLinks(sourceLinks, 'sourceLinks');
  }

  final String id;
  final MemoryFirstInsightKind kind;
  final String title;
  final String summary;
  final List<SourceLink> sourceLinks;
  final DateTime createdAt;
  final String? metricLabel;
  final num? metricValue;
  final List<MemoryFirstInsightClaim> claims;
  final List<MemoryFirstInsightMetric> metrics;
  final List<MemoryFirstInsightUiBlock> uiBlocks;
  final CardJsonMap metadata;

  bool get isSourceLinked => sourceLinks.isNotEmpty;

  MemoryFirstInsightPayload get structuredPayload {
    return MemoryFirstInsightPayload(
      claims: claims,
      metrics: metrics,
      sourceLinks: sourceLinks,
      uiBlocks: uiBlocks,
      note: summary,
    );
  }
}

final class MemoryFirstCardBundle {
  const MemoryFirstCardBundle({required this.cards, required this.insights});

  final List<MemoryFirstCard> cards;
  final List<MemoryFirstInsight> insights;
}

void _requireSourceLinks(List<SourceLink> links, String name) {
  if (links.isEmpty) {
    throw ArgumentError.value(links, name, 'must not be empty');
  }
}

void _requireAllowedInsightUiBlockKind(String kind, String name) {
  if (!allowedInsightUiBlockKinds.contains(kind)) {
    throw ArgumentError.value(kind, name, 'unknown insight UI block kind');
  }
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String _requiredString(Object? value, String name) {
  final text = _string(value);
  if (text == null) {
    throw ArgumentError.value(value, name, 'must be a non-empty string');
  }
  return text;
}

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.trim());
  }
  return null;
}

num _requiredNum(Object? value, String name) {
  final parsed = _num(value);
  if (parsed == null) {
    throw ArgumentError.value(value, name, 'must be a number');
  }
  return parsed;
}

CardJsonMap _jsonMap(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, value) => MapEntry('$key', value)),
    );
  }
  return const <String, Object?>{};
}

List<SourceLink> _sourceLinksFromValue(
  Object? value,
  String name, {
  bool required = true,
}) {
  if (value == null) {
    if (required) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
    return const <SourceLink>[];
  }
  if (value is! List) {
    throw ArgumentError.value(value, name, 'must be an array');
  }
  final links = <SourceLink>[];
  for (final item in value) {
    if (item is! Map) {
      throw ArgumentError.value(item, name, 'must contain source link objects');
    }
    links.add(SourceLink.fromJson(Map<Object?, Object?>.from(item)));
  }
  final deduped = _dedupeSourceLinks(links);
  if (required) {
    _requireSourceLinks(deduped, name);
  }
  return deduped;
}

List<T> _objectList<T>(
  Object? value,
  String name,
  T Function(Map<Object?, Object?> json) parse,
) {
  if (value == null) {
    return List<T>.unmodifiable(<T>[]);
  }
  if (value is! List) {
    throw ArgumentError.value(value, name, 'must be an array');
  }
  final objects = <T>[];
  for (final item in value) {
    if (item is! Map) {
      throw ArgumentError.value(item, name, 'must contain objects');
    }
    objects.add(parse(Map<Object?, Object?>.from(item)));
  }
  return List<T>.unmodifiable(objects);
}

List<SourceLink> _dedupeSourceLinks(List<SourceLink> links) {
  final seen = <String>{};
  final deduped = <SourceLink>[];
  for (final link in links) {
    if (seen.add('${link.kind}:${link.id}')) {
      deduped.add(link);
    }
  }
  return List<SourceLink>.unmodifiable(deduped);
}
