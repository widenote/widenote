import 'dart:math' as math;

import '../domain/chat_models.dart';

abstract interface class ChatContextSource {
  Future<List<ChatSource>> loadSources();
}

final class ChatContextSelector {
  const ChatContextSelector();

  List<ChatSource> select({
    required String question,
    required List<ChatSource> sources,
    int limit = 5,
  }) {
    if (sources.isEmpty || limit <= 0) {
      return const <ChatSource>[];
    }

    final recent = [...sources]..sort(_newestFirst);
    final query = question.trim().toLowerCase();
    final terms = _terms(query);
    if (query.isEmpty || terms.isEmpty) {
      return recent.take(math.min(limit, 3)).toList(growable: false);
    }

    final scored = [
      for (final source in recent)
        _ScoredSource(source: source, score: _score(source, query, terms)),
    ]..sort(_bestFirst);

    final matches = scored.where((item) => item.score > 0).toList();
    if (matches.isEmpty) {
      return recent.take(math.min(limit, 3)).toList(growable: false);
    }

    return matches
        .take(limit)
        .map((item) => item.source)
        .toList(growable: false);
  }

  int _score(ChatSource source, String query, List<String> terms) {
    final haystack = '${source.title}\n${source.excerpt}\n${source.kind}'
        .toLowerCase();
    var score = haystack.contains(query) ? 8 : 0;
    for (final term in terms) {
      if (haystack.contains(term)) {
        score += term.length > 3 ? 3 : 2;
      }
    }
    if (score == 0) {
      return 0;
    }
    return score + _kindBoost(source.kind);
  }
}

final class _ScoredSource {
  const _ScoredSource({required this.source, required this.score});

  final ChatSource source;
  final int score;
}

int _bestFirst(_ScoredSource a, _ScoredSource b) {
  final score = b.score.compareTo(a.score);
  if (score != 0) {
    return score;
  }
  return _newestFirst(a.source, b.source);
}

int _newestFirst(ChatSource a, ChatSource b) {
  return b.createdAt.compareTo(a.createdAt);
}

int _kindBoost(String kind) {
  return switch (kind) {
    'memory' => 3,
    'capture' => 2,
    'todo' => 1,
    _ => 0,
  };
}

List<String> _terms(String query) {
  return query
      .split(RegExp(r'[\s,，。.!！?？:：;；、/\\()（）\[\]{}]+'))
      .map((term) => term.trim())
      .where((term) => term.length >= 2)
      .toSet()
      .toList(growable: false);
}
