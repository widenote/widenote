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
      insights: const <MemoryFirstInsight>[],
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
