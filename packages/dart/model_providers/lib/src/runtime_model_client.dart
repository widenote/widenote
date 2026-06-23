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
      response = await provider.complete(
        ModelRequest.text(
          request.prompt,
          model: model,
          requiredCapabilities: const <ModelCapability>{
            ModelCapability.completion,
          },
          metadata: request.context,
        ),
      );
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
