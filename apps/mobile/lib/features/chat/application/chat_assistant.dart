import '../../../shared/text_preview.dart';
import '../domain/chat_models.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

abstract interface class ChatAssistant {
  Future<ChatAssistantReply> answer(ChatAssistantPrompt prompt);
}

final class ChatModelRequiredAssistant implements ChatAssistant {
  const ChatModelRequiredAssistant();

  @override
  Future<ChatAssistantReply> answer(ChatAssistantPrompt prompt) async {
    throw const ChatAssistantException(
      'Chat needs a configured model provider before it can generate an answer.',
    );
  }
}

final class ModelBackedChatAssistant implements ChatAssistant {
  const ModelBackedChatAssistant({required this.model, this.maxSources = 6});

  final runtime.ModelClient model;
  final int maxSources;

  @override
  Future<ChatAssistantReply> answer(ChatAssistantPrompt prompt) async {
    try {
      final response = await model.complete(
        runtime.ModelRequest(
          prompt: _prompt(prompt),
          context: <String, Object?>{
            'source_count': prompt.sources.length,
            'chat_mode': 'source_cited_local_context',
          },
        ),
      );
      final body = response.text.trim();
      if (body.isEmpty) {
        throw const ChatAssistantException(
          'The model returned an empty answer. Retry or choose another provider.',
        );
      }
      return ChatAssistantReply(body: body);
    } on ChatAssistantException {
      rethrow;
    } catch (error) {
      throw ChatAssistantException(
        'Chat model request failed. Check provider settings and retry. '
        'Cause: ${error.runtimeType}',
      );
    }
  }

  String _prompt(ChatAssistantPrompt prompt) {
    final sourceLines = prompt.sources
        .take(maxSources)
        .map(
          (source) =>
              '- ${source.kind}/${source.id}: ${previewText(source.excerpt)}',
        )
        .join('\n');
    final localSources = sourceLines.isEmpty ? '(none)' : sourceLines;
    return '''
Answer the user's WideNote question using only the local sources below.
Be concise, cite the source kind/id in prose, and do not invent facts.

Question:
${prompt.question}

Local sources:
$localSources
''';
  }
}

final class ChatAssistantException implements Exception {
  const ChatAssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}
