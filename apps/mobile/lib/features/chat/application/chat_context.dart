import '../domain/chat_models.dart';

abstract interface class ChatContextSource {
  Future<List<ChatSource>> loadSources();
}

final class ChatContextSelector {
  const ChatContextSelector();

  List<ChatSource> select({
    required String question,
    required List<ChatSource> sources,
    int limit = 12,
  }) {
    // Intentionally do not inspect `question`: local code only applies context
    // packet boundaries and prompt-budget limits. Semantic ranking belongs to
    // a model-backed retriever or the model call itself.
    if (sources.isEmpty || limit <= 0) {
      return const <ChatSource>[];
    }
    return sources.take(limit).toList(growable: false);
  }
}
