import 'models.dart';

final class MemoryFirstCardService {
  const MemoryFirstCardService();

  MemoryFirstCardBundle generate(MemoryFirstCardInput input) {
    final cards = <MemoryFirstCard>[
      for (final capture in input.captures) _captureCard(capture),
      for (final memory in input.memories) _memoryCard(memory),
    ];

    return MemoryFirstCardBundle(
      cards: cards,
      insights: _insights(input, cards),
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
      if (_actionCandidateCards(cards).isNotEmpty)
        _actionPatternInsight(input, cards),
      if (_attachmentEvidenceCards(cards).isNotEmpty)
        _attachmentEvidenceInsight(input, cards),
    ];
  }

  MemoryFirstInsight _summaryInsight(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    final latest = _latestCard(cards);
    return MemoryFirstInsight(
      id: _id('insight.summary', _dateStamp(input.now)),
      kind: MemoryFirstInsightKind.summary,
      title: 'Latest source summary',
      summary: latest.body,
      sourceLinks: latest.sourceLinks,
      createdAt: input.now,
      metadata: <String, Object?>{'card_id': latest.id},
    );
  }

  MemoryFirstInsight _countInsight(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    final captureCount = input.captures.length;
    final memoryCount = input.memories.length;
    return MemoryFirstInsight(
      id: _id('insight.count', _dateStamp(input.now)),
      kind: MemoryFirstInsightKind.count,
      title: 'Knowledge layer coverage',
      summary:
          '$captureCount captures and $memoryCount Memory items '
          'generated ${cards.length} source-linked cards.',
      sourceLinks: _dedupeLinks([
        for (final card in cards) ...card.sourceLinks,
      ]),
      createdAt: input.now,
      metricLabel: 'source-linked cards',
      metricValue: cards.length,
      metadata: <String, Object?>{
        'capture_count': captureCount,
        'memory_count': memoryCount,
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

    return MemoryFirstInsight(
      id: _id('insight.trend', day),
      kind: MemoryFirstInsightKind.trend,
      title: 'Most active day',
      summary: '$day has ${dayCards.length} source item(s).',
      sourceLinks: _dedupeLinks([
        for (final card in dayCards) ...card.sourceLinks,
      ]),
      createdAt: input.now,
      metricLabel: 'source items',
      metricValue: dayCards.length,
      metadata: <String, Object?>{'day': day},
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
    return MemoryFirstInsight(
      id: _id('insight.source_mix', _dateStamp(input.now)),
      kind: MemoryFirstInsightKind.sourceMix,
      title: 'Knowledge source mix',
      summary:
          'Current knowledge combines ${input.captures.length} capture(s), '
          '${input.memories.length} Memory item(s), and ${cards.length} '
          'card(s) across ${sourceLinks.length} source ref(s).',
      sourceLinks: sourceLinks,
      createdAt: input.now,
      metricLabel: 'source refs',
      metricValue: sourceLinks.length,
      metadata: <String, Object?>{
        'capture_count': input.captures.length,
        'memory_count': input.memories.length,
        'card_count': cards.length,
        'source_kinds': sourceKinds,
      },
    );
  }

  MemoryFirstInsight _actionPatternInsight(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    final candidates = _actionCandidateCards(cards);
    final terms = _actionTerms(candidates);
    return MemoryFirstInsight(
      id: _id('insight.action_pattern', _dateStamp(input.now)),
      kind: MemoryFirstInsightKind.actionPattern,
      title: 'Action pattern',
      summary:
          '${candidates.length} source-linked item(s) mention follow-up, '
          'review, or preparation signals.',
      sourceLinks: _dedupeLinks([
        for (final card in candidates) ...card.sourceLinks,
      ]),
      createdAt: input.now,
      metricLabel: 'action-linked sources',
      metricValue: candidates.length,
      metadata: <String, Object?>{
        'card_ids': candidates.map((card) => card.id).toList(growable: false),
        'terms': terms,
      },
    );
  }

  MemoryFirstInsight _attachmentEvidenceInsight(
    MemoryFirstCardInput input,
    List<MemoryFirstCard> cards,
  ) {
    final candidates = _attachmentEvidenceCards(cards);
    final modalities = _modalities(candidates);
    return MemoryFirstInsight(
      id: _id('insight.attachment_evidence', _dateStamp(input.now)),
      kind: MemoryFirstInsightKind.attachmentEvidence,
      title: 'Attachment evidence',
      summary:
          '${candidates.length} source-linked item(s) include media, OCR, '
          'transcript, or attachment evidence.',
      sourceLinks: _dedupeLinks([
        for (final card in candidates) ...card.sourceLinks,
      ]),
      createdAt: input.now,
      metricLabel: 'media-backed sources',
      metricValue: candidates.length,
      metadata: <String, Object?>{
        'card_ids': candidates.map((card) => card.id).toList(growable: false),
        'modalities': modalities,
      },
    );
  }
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

List<MemoryFirstCard> _actionCandidateCards(List<MemoryFirstCard> cards) {
  return cards
      .where((card) {
        final text = '${card.title}\n${card.body}'.toLowerCase();
        return text.contains('follow up') ||
            text.contains('follow-up') ||
            text.contains('todo') ||
            text.contains('review') ||
            text.contains('prepare') ||
            text.contains('next step') ||
            text.contains('action');
      })
      .toList(growable: false);
}

List<String> _actionTerms(List<MemoryFirstCard> cards) {
  final terms = <String>{};
  for (final card in cards) {
    final text = '${card.title}\n${card.body}'.toLowerCase();
    for (final term in const <String>[
      'follow up',
      'follow-up',
      'todo',
      'review',
      'prepare',
      'next step',
      'action',
    ]) {
      if (text.contains(term)) {
        terms.add(term);
      }
    }
  }
  return terms.toList(growable: false)..sort();
}

List<MemoryFirstCard> _attachmentEvidenceCards(List<MemoryFirstCard> cards) {
  return cards
      .where((card) {
        final text = '${card.title}\n${card.body}'.toLowerCase();
        return text.contains('attachment') ||
            text.contains('photo') ||
            text.contains('image') ||
            text.contains('ocr') ||
            text.contains('transcript') ||
            text.contains('voice') ||
            text.contains('audio');
      })
      .toList(growable: false);
}

List<String> _modalities(List<MemoryFirstCard> cards) {
  final modalities = <String>{};
  for (final card in cards) {
    final text = '${card.title}\n${card.body}'.toLowerCase();
    if (text.contains('photo') || text.contains('image')) {
      modalities.add('image');
    }
    if (text.contains('ocr')) {
      modalities.add('ocr');
    }
    if (text.contains('transcript')) {
      modalities.add('transcript');
    }
    if (text.contains('voice') || text.contains('audio')) {
      modalities.add('audio');
    }
    if (text.contains('attachment')) {
      modalities.add('attachment');
    }
  }
  return modalities.toList(growable: false)..sort();
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
