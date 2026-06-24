typedef CardJsonMap = Map<String, Object?>;

enum MemoryFirstCardKind { captureSummary, memorySummary }

enum MemoryFirstInsightKind { summary, count, trend }

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
  final CardJsonMap metadata;

  bool get isSourceLinked => sourceLinks.isNotEmpty;
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

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
