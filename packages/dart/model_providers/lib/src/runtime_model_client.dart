import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

import 'model_provider.dart';

final class RuntimeModelClientAdapter implements runtime.ModelClient {
  const RuntimeModelClientAdapter({required this.provider, this.model});

  final ModelProvider provider;
  final String? model;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    final ModelResponse response;
    try {
      response = await provider.complete(_providerRequest(request));
    } catch (error) {
      throw RuntimeModelProviderException(
        providerId: provider.id,
        message: 'Model provider failed to complete a runtime request.',
        cause: error,
      );
    }

    return runtime.ModelResponse(
      text: response.text,
      raw: <String, Object?>{
        'provider_id': response.providerId,
        'model': response.model,
        'usage': <String, Object?>{
          'input_tokens': response.usage.inputTokens,
          'output_tokens': response.usage.outputTokens,
          'total_tokens': response.usage.totalTokens,
        },
        'metadata': response.metadata,
      },
    );
  }

  ModelRequest _providerRequest(runtime.ModelRequest request) {
    if (!request.hasAttachments) {
      return ModelRequest.text(
        request.prompt,
        model: model,
        requiredCapabilities: const <ModelCapability>{
          ModelCapability.completion,
        },
        metadata: request.context,
      );
    }
    return ModelRequest.multimodal(
      request.prompt,
      model: model,
      metadata: request.context,
      parts: request.attachments
          .map(
            (attachment) => ModelContentPart.inlineImage(
              mimeType: attachment.mimeType,
              dataBase64: attachment.dataBase64,
              sourceRef: _safeSourceRef(attachment.sourceRef),
            ),
          )
          .toList(growable: false),
    );
  }
}

Map<String, Object?> _safeSourceRef(Map<String, Object?> value) {
  final kind = value['kind'];
  final id = value['id'];
  return <String, Object?>{
    if (kind is String && kind.trim().isNotEmpty) 'kind': kind.trim(),
    if (id is String && id.trim().isNotEmpty) 'id': id.trim(),
  };
}

final class RuntimeModelProviderException implements Exception {
  const RuntimeModelProviderException({
    required this.providerId,
    required this.message,
    required this.cause,
  });

  final String providerId;
  final String message;
  final Object cause;

  @override
  String toString() {
    return 'RuntimeModelProviderException(providerId: $providerId, '
        'message: $message, cause: $cause)';
  }
}
