import '../../../shared/text_preview.dart';
import '../../../l10n/l10n.dart';
import '../domain/chat_models.dart';

abstract interface class ChatAssistant {
  Future<ChatAssistantReply> answer(ChatAssistantPrompt prompt);
}

final class DeterministicLocalChatAssistant implements ChatAssistant {
  const DeterministicLocalChatAssistant({
    this.copy = const ChatAssistantCopy.english(),
  });

  final ChatAssistantCopy copy;

  @override
  Future<ChatAssistantReply> answer(ChatAssistantPrompt prompt) async {
    if (prompt.sources.isEmpty) {
      return ChatAssistantReply(body: copy.emptyReply);
    }

    final lead = _leadSource(prompt.sources.first);
    final sourceSummary = prompt.sources
        .take(3)
        .map((source) => '${source.title}: ${previewText(source.excerpt)}')
        .join('\n');

    return ChatAssistantReply(
      body: copy.contextReply(
        count: prompt.sources.length,
        lead: lead,
        sources: sourceSummary,
      ),
    );
  }

  String _leadSource(ChatSource source) {
    final excerpt = previewText(source.excerpt);
    return switch (source.kind) {
      'todo' => copy.todoLead(excerpt),
      'memory' => copy.memoryLead(excerpt),
      'capture' => copy.captureLead(excerpt),
      _ => copy.genericLead(excerpt),
    };
  }
}

final class ChatAssistantCopy {
  const ChatAssistantCopy({
    required this.emptyReply,
    required this.contextReply,
    required this.todoLead,
    required this.memoryLead,
    required this.captureLead,
    required this.genericLead,
  });

  const ChatAssistantCopy.english()
    : emptyReply =
          "I don't have local records to cite yet. Add captures first, "
          'then I can answer from Memory, records, and todos.',
      contextReply = _englishContextReply,
      todoLead = _englishTodoLead,
      memoryLead = _englishMemoryLead,
      captureLead = _englishCaptureLead,
      genericLead = _englishGenericLead;

  factory ChatAssistantCopy.fromL10n(AppLocalizations l10n) {
    return ChatAssistantCopy(
      emptyReply: l10n.chatAssistantEmptyReply,
      contextReply:
          ({
            required int count,
            required String lead,
            required String sources,
          }) => l10n.chatAssistantContextReply(count, lead, sources),
      todoLead: l10n.chatAssistantLeadTodo,
      memoryLead: l10n.chatAssistantLeadMemory,
      captureLead: l10n.chatAssistantLeadCapture,
      genericLead: l10n.chatAssistantLeadGeneric,
    );
  }

  final String emptyReply;
  final String Function({
    required int count,
    required String lead,
    required String sources,
  })
  contextReply;
  final String Function(String excerpt) todoLead;
  final String Function(String excerpt) memoryLead;
  final String Function(String excerpt) captureLead;
  final String Function(String excerpt) genericLead;
}

String _englishContextReply({
  required int count,
  required String lead,
  required String sources,
}) {
  return 'I found $count local context item(s). $lead\n\n$sources';
}

String _englishTodoLead(String excerpt) {
  return 'The closest match is a todo: $excerpt';
}

String _englishMemoryLead(String excerpt) {
  return 'The closest match is a Memory item: $excerpt';
}

String _englishCaptureLead(String excerpt) {
  return 'The closest match is a raw record: $excerpt';
}

String _englishGenericLead(String excerpt) {
  return 'The closest match is: $excerpt';
}
