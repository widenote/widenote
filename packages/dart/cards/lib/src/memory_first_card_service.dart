import 'models.dart';

final class MemoryFirstCardService {
  const MemoryFirstCardService();

  MemoryFirstCardBundle generate(MemoryFirstCardInput input) {
    final cards = _dedupeCards(<MemoryFirstCard>[
      for (final capture in input.captures) _captureCard(capture),
      for (final memory in input.memories) _memoryCard(memory),
    ]);

    return MemoryFirstCardBundle(
      cards: cards,
      insights: _insights(input, _rankCards(cards)),
    );
  }

  MemoryFirstCard _captureCard(CaptureCardSource capture) {
    final preview = _preview(capture.text);
    final source = SourceLink(
      kind: 'capture',
      id: capture.id,
      label: 'capture:${capture.id}',
      excerpt: preview,
    );
    return MemoryFirstCard(
      id: _id('card.capture', capture.id),
      kind: MemoryFirstCardKind.captureSummary,
      title: _title('Capture', capture.text),
      body: preview,
      sourceLinks: <SourceLink>[source],
      createdAt: capture.createdAt,
      metadata: <String, Object?>{'source_count': 1},
    );
  }

  MemoryFirstCard _memoryCard(MemoryCardSource memory) {
    final ownSource = SourceLink(
      kind: 'memory',
      id: memory.id,
      label: 'memory:${memory.id}',
      excerpt: _preview(memory.body),
    );
    final sources = _dedupeLinks(<SourceLink>[
      ownSource,
      ...memory.sourceLinks,
    ]);

    return MemoryFirstCard(
      id: _id('card.memory', memory.id),
      kind: MemoryFirstCardKind.memorySummary,
      title: _title('Memory', memory.body),
      body: memory.body.trim(),
      sourceLinks: sources,
      createdAt: memory.createdAt,
      metadata: <String, Object?>{
        'memory_key': memory.key,
        'memory_type': memory.memoryType,
        'source_count': sources.length,
      },
    );
  }

  List<MemoryFirstInsight> _insights(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    if (cards.isEmpty) {
      return const <MemoryFirstInsight>[];
    }

    return <MemoryFirstInsight>[
      _summaryInsight(input, cards),
      _countInsight(input, cards),
      _trendInsight(input, cards),
      _sourceMixInsight(input, cards),
    ];
  }

  MemoryFirstInsight _summaryInsight(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    final latest = _latestCard(cards);
    final sourceLinks = latest.sourceLinks;
    final claims = <MemoryFirstInsightClaim>[
      _claim(
        id: 'claim.latest_source',
        text: latest.body,
        sourceLinks: sourceLinks,
      ),
    ];
    return MemoryFirstInsight(
      id: _id('insight.summary', _dateStamp(input.now)),
      kind: MemoryFirstInsightKind.summary,
      title: 'Latest source summary',
      summary: latest.body,
      sourceLinks: sourceLinks,
      createdAt: input.now,
      claims: claims,
      uiBlocks: _uiBlocks(includeMetric: false),
      metadata: _insightMetadata(
        base: <String, Object?>{'card_id': latest.id},
        claims: claims,
        sourceLinks: sourceLinks,
        includeMetric: false,
        note: latest.body,
      ),
    );
  }

  MemoryFirstInsight _countInsight(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    final captureCount = input.captures.length;
    final memoryCount = input.memories.length;
    final sourceLinks = _dedupeLinks([
      for (final card in cards) ...card.sourceLinks,
    ]);
    final claims = <MemoryFirstInsightClaim>[
      _claim(
        id: 'claim.knowledge_coverage',
        text:
            '$captureCount captures and $memoryCount Memory items '
            'generated ${cards.length} source-linked cards.',
        sourceLinks: sourceLinks,
      ),
    ];
    final metrics = <MemoryFirstInsightMetric>[
      _metric(
        label: 'source-linked cards',
        value: cards.length,
        sourceLinks: sourceLinks,
      ),
    ];
    return MemoryFirstInsight(
      id: _id('insight.count', _dateStamp(input.now)),
      kind: MemoryFirstInsightKind.count,
      title: 'Knowledge layer coverage',
      summary: claims.single.text,
      sourceLinks: sourceLinks,
      createdAt: input.now,
      metricLabel: 'source-linked cards',
      metricValue: cards.length,
      claims: claims,
      metrics: metrics,
      uiBlocks: _uiBlocks(),
      metadata: <String, Object?>{
        'capture_count': captureCount,
        'memory_count': memoryCount,
        ..._insightMetadata(
          claims: claims,
          metrics: metrics,
          sourceLinks: sourceLinks,
          note: claims.single.text,
        ),
      },
    );
  }

  MemoryFirstInsight _trendInsight(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    final day = _mostActiveDay(cards);
    final dayCards = cards
        .where((card) => _dateStamp(card.createdAt) == day)
        .toList(growable: false);
    final sourceLinks = _dedupeLinks([
      for (final card in dayCards) ...card.sourceLinks,
    ]);
    final claims = <MemoryFirstInsightClaim>[
      _claim(
        id: 'claim.most_active_day',
        text: '$day has ${dayCards.length} source item(s).',
        sourceLinks: sourceLinks,
      ),
    ];
    final metrics = <MemoryFirstInsightMetric>[
      _metric(
        label: 'source items',
        value: dayCards.length,
        sourceLinks: sourceLinks,
      ),
    ];

    return MemoryFirstInsight(
      id: _id('insight.trend', day),
      kind: MemoryFirstInsightKind.trend,
      title: 'Most active day',
      summary: claims.single.text,
      sourceLinks: sourceLinks,
      createdAt: input.now,
      metricLabel: 'source items',
      metricValue: dayCards.length,
      claims: claims,
      metrics: metrics,
      uiBlocks: _uiBlocks(),
      metadata: _insightMetadata(
        base: <String, Object?>{'day': day},
        claims: claims,
        metrics: metrics,
        sourceLinks: sourceLinks,
        note: claims.single.text,
      ),
    );
  }

  MemoryFirstInsight _sourceMixInsight(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    final sourceLinks = _dedupeLinks([
      for (final card in cards) ...card.sourceLinks,
    ]);
    final sourceKinds = <String, int>{};
    for (final link in sourceLinks) {
      sourceKinds[link.kind] = (sourceKinds[link.kind] ?? 0) + 1;
    }
    final claims = <MemoryFirstInsightClaim>[
      _claim(
        id: 'claim.source_mix',
        text:
            'Current knowledge combines ${input.captures.length} capture(s), '
            '${input.memories.length} Memory item(s), and ${cards.length} '
            'card(s) across ${sourceLinks.length} source ref(s).',
        sourceLinks: sourceLinks,
      ),
    ];
    final metrics = <MemoryFirstInsightMetric>[
      _metric(
        label: 'source refs',
        value: sourceLinks.length,
        sourceLinks: sourceLinks,
      ),
    ];
    return MemoryFirstInsight(
      id: _id('insight.source_mix', _dateStamp(input.now)),
      kind: MemoryFirstInsightKind.sourceMix,
      title: 'Knowledge source mix',
      summary: claims.single.text,
      sourceLinks: sourceLinks,
      createdAt: input.now,
      metricLabel: 'source refs',
      metricValue: sourceLinks.length,
      claims: claims,
      metrics: metrics,
      uiBlocks: _uiBlocks(),
      metadata: <String, Object?>{
        'capture_count': input.captures.length,
        'memory_count': input.memories.length,
        'card_count': cards.length,
        'source_kinds': sourceKinds,
        ..._insightMetadata(
          claims: claims,
          metrics: metrics,
          sourceLinks: sourceLinks,
          note: claims.single.text,
        ),
      },
    );
  }
}

List<MemoryFirstCard> _dedupeCards(List<MemoryFirstCard> cards) {
  final seen = <String>{};
  final deduped = <MemoryFirstCard>[];
  for (final card in cards) {
    if (seen.add(card.id)) {
      deduped.add(card);
    }
  }
  return List<MemoryFirstCard>.unmodifiable(deduped);
}

List<MemoryFirstCard> _rankCards(List<MemoryFirstCard> cards) {
  final ranked = cards.toList()
    ..sort((a, b) {
      final sourceScore = b.sourceLinks.length.compareTo(a.sourceLinks.length);
      if (sourceScore != 0) {
        return sourceScore;
      }
      final timeScore = b.createdAt.compareTo(a.createdAt);
      return timeScore == 0 ? a.id.compareTo(b.id) : timeScore;
    });
  return List<MemoryFirstCard>.unmodifiable(ranked);
}

MemoryFirstCard _latestCard(List<MemoryFirstCard> cards) {
  return cards.reduce((current, next) {
    if (next.createdAt.isAfter(current.createdAt)) {
      return next;
    }
    return current;
  });
}

String _mostActiveDay(List<MemoryFirstCard> cards) {
  final counts = <String, int>{};
  for (final card in cards) {
    final day = _dateStamp(card.createdAt);
    counts[day] = (counts[day] ?? 0) + 1;
  }

  var bestDay = counts.keys.first;
  var bestCount = counts[bestDay]!;
  for (final entry in counts.entries) {
    if (entry.value > bestCount || _isLaterDay(entry.key, bestDay)) {
      bestDay = entry.key;
      bestCount = entry.value;
    }
  }
  return bestDay;
}

bool _isLaterDay(String candidate, String current) {
  return candidate.compareTo(current) > 0;
}

List<SourceLink> _dedupeLinks(List<SourceLink> links) {
  final seen = <String>{};
  final deduped = <SourceLink>[];
  for (final link in links) {
    if (seen.add('${link.kind}:${link.id}')) {
      deduped.add(link);
    }
  }
  return List<SourceLink>.unmodifiable(deduped);
}

MemoryFirstInsightClaim _claim({
  required String id,
  required String text,
  required List<SourceLink> sourceLinks,
}) {
  return MemoryFirstInsightClaim(
    id: id,
    text: text,
    sourceLinks: _dedupeLinks(sourceLinks),
  );
}

MemoryFirstInsightMetric _metric({
  required String label,
  required num value,
  required List<SourceLink> sourceLinks,
}) {
  return MemoryFirstInsightMetric(
    label: label,
    value: value,
    sourceLinks: _dedupeLinks(sourceLinks),
  );
}

List<MemoryFirstInsightUiBlock> _uiBlocks({bool includeMetric = true}) {
  return <MemoryFirstInsightUiBlock>[
    MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.claimList),
    if (includeMetric)
      MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.metricRow),
    MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.sourceRefs),
    MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.note),
  ];
}

CardJsonMap _insightMetadata({
  CardJsonMap base = const <String, Object?>{},
  required List<MemoryFirstInsightClaim> claims,
  List<MemoryFirstInsightMetric> metrics = const <MemoryFirstInsightMetric>[],
  required List<SourceLink> sourceLinks,
  bool includeMetric = true,
  String? note,
}) {
  return <String, Object?>{
    ...base,
    ...MemoryFirstInsightPayload(
      claims: claims,
      metrics: metrics,
      sourceLinks: sourceLinks,
      uiBlocks: _uiBlocks(includeMetric: includeMetric),
      note: note,
    ).toJson(),
  };
}

String _title(String prefix, String text) {
  final preview = _preview(text, maxLength: 48);
  if (preview.isEmpty) {
    return prefix;
  }
  return '$prefix: $preview';
}

String _preview(String value, {int maxLength = 160}) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength - 1)}...';
}

String _id(String prefix, String sourceId) {
  return '$prefix.${_sanitizeId(sourceId)}';
}

String _sanitizeId(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}

String _dateStamp(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}
