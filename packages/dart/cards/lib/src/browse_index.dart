import 'browse_models.dart';
import 'models.dart';

final class MemoryFirstBrowseIndex {
  MemoryFirstBrowseIndex._(this.items, this._byId);

  factory MemoryFirstBrowseIndex.build(
    Iterable<MemoryFirstTimelineItem> items,
  ) {
    final sorted = items.toList(growable: false)
      ..sort((a, b) {
        final time = b.createdAt.compareTo(a.createdAt);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
    return MemoryFirstBrowseIndex._(
      List<MemoryFirstTimelineItem>.unmodifiable(sorted),
      <String, MemoryFirstTimelineItem>{
        for (final item in sorted) item.id: item,
      },
    );
  }

  final List<MemoryFirstTimelineItem> items;
  final Map<String, MemoryFirstTimelineItem> _byId;

  bool get isEmpty => items.isEmpty;

  MemoryFirstTimelineItem? itemById(String id) => _byId[id];

  List<MemoryFirstTimelineItem> search([
    MemoryFirstTimelineFilter filter = const MemoryFirstTimelineFilter(),
  ]) {
    return items.where((item) => _matchesFilter(item, filter)).toList();
  }

  List<MemoryFirstTimelineDay> timeline([
    MemoryFirstTimelineFilter filter = const MemoryFirstTimelineFilter(),
  ]) {
    final grouped = <String, List<MemoryFirstTimelineItem>>{};
    final days = <String, DateTime>{};

    for (final item in search(filter)) {
      final localDay = _day(item.createdAt);
      final label = _dayLabel(localDay);
      grouped.putIfAbsent(label, () => <MemoryFirstTimelineItem>[]).add(item);
      days[label] = localDay;
    }

    return [
      for (final entry in grouped.entries)
        MemoryFirstTimelineDay(
          day: days[entry.key]!,
          label: entry.key,
          items: List<MemoryFirstTimelineItem>.unmodifiable(entry.value),
        ),
    ];
  }

  MemoryFirstCardDetail? cardDetail(String cardId) {
    final card = itemById(cardId);
    if (card == null || card.kind != MemoryFirstTimelineItemKind.card) {
      return null;
    }
    return MemoryFirstCardDetail(
      card: card,
      relatedItems: items
          .where((item) => item.id != card.id && _isRelated(card, item))
          .toList(growable: false),
    );
  }
}

List<SourceLink> sourceLinksFromJsonList(List<Object?> values) {
  final links = <SourceLink>[];
  for (final value in values) {
    if (value is Map) {
      try {
        links.add(SourceLink.fromJson(Map<Object?, Object?>.from(value)));
      } on ArgumentError {
        continue;
      }
    }
  }
  return dedupeSourceLinks(links);
}

List<SourceLink> sourceLinksOrSelf({
  required String kind,
  required String id,
  String? label,
  String? excerpt,
  List<SourceLink> links = const <SourceLink>[],
}) {
  final deduped = dedupeSourceLinks(links);
  if (deduped.isNotEmpty) {
    return deduped;
  }
  return <SourceLink>[
    SourceLink(kind: kind, id: id, label: label, excerpt: excerpt),
  ];
}

List<SourceLink> dedupeSourceLinks(List<SourceLink> links) {
  final seen = <String>{};
  final deduped = <SourceLink>[];
  for (final link in links) {
    if (seen.add(sourceLinkKey(link))) {
      deduped.add(link);
    }
  }
  return List<SourceLink>.unmodifiable(deduped);
}

String sourceLinkKey(SourceLink link) => '${link.kind}:${link.id}';

bool _matchesFilter(
  MemoryFirstTimelineItem item,
  MemoryFirstTimelineFilter filter,
) {
  if (filter.kinds.isNotEmpty && !filter.kinds.contains(item.kind)) {
    return false;
  }

  final tokens = _tokens(filter.query);
  if (tokens.isEmpty) {
    return true;
  }

  final haystack = _normalize(
    <String>[
      item.id,
      item.kind.name,
      item.title,
      item.body,
      item.status,
      for (final link in item.sourceLinks) ...[
        link.kind,
        link.id,
        if (link.label != null) link.label!,
        if (link.excerpt != null) link.excerpt!,
      ],
      for (final value in item.metadata.values)
        if (value != null) '$value',
    ].join(' '),
  );
  return tokens.every(haystack.contains);
}

bool _isRelated(
  MemoryFirstTimelineItem card,
  MemoryFirstTimelineItem candidate,
) {
  final cardKeys = card.sourceLinks.map(sourceLinkKey).toSet();
  final candidateKeys = candidate.sourceLinks.map(sourceLinkKey).toSet();
  if (candidateKeys.any(cardKeys.contains)) {
    return true;
  }
  if (cardKeys.contains('${_sourceKind(candidate.kind)}:${candidate.id}')) {
    return true;
  }
  return card.sourceLinks.any((link) => link.id == candidate.id);
}

String _sourceKind(MemoryFirstTimelineItemKind kind) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.capture => 'capture',
    MemoryFirstTimelineItemKind.card => 'card',
    MemoryFirstTimelineItemKind.insight => 'insight',
    MemoryFirstTimelineItemKind.memory => 'memory',
    MemoryFirstTimelineItemKind.todo => 'todo',
  };
}

List<String> _tokens(String value) {
  return _normalize(value)
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

String _normalize(String value) => value.trim().toLowerCase();

DateTime _day(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _dayLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
