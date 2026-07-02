import 'package:test/test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  test(
    'RuntimeModelClientAdapter bridges runtime requests to provider',
    () async {
      final provider = FakeModelProvider(
        responses: <String>['bridged response'],
      );
      final client = RuntimeModelClientAdapter(
        provider: provider,
        model: 'local-test-model',
      );

      final response = await client.complete(
        const runtime.ModelRequest(
          prompt: 'Summarize capture',
          context: <String, Object?>{'source_event_id': 'evt-1'},
        ),
      );

      expect(response.text, 'bridged response');
      expect(response.raw['provider_id'], 'fake');
      expect(response.raw['model'], 'local-test-model');
      expect(provider.requests.single.promptText, 'Summarize capture');
      expect(provider.requests.single.metadata['source_event_id'], 'evt-1');
      expect(
        provider.requests.single.requiredCapabilities,
        contains(ModelCapability.completion),
      );
    },
  );

  test(
    'RuntimeModelClientAdapter bridges inline images to vision requests',
    () async {
      final provider = FakeModelProvider(
        capabilities: const <ModelCapability>{
          ModelCapability.chat,
          ModelCapability.completion,
          ModelCapability.vision,
        },
        responses: <String>['vision response'],
      );
      final client = RuntimeModelClientAdapter(provider: provider);

      final response = await client.complete(
        const runtime.ModelRequest(
          prompt: 'Describe image',
          context: <String, Object?>{'capture_id': 'capture-1'},
          attachments: <runtime.ModelRequestAttachment>[
            runtime.ModelRequestAttachment.inlineImage(
              mimeType: 'image/png',
              dataBase64: 'abc123',
              sourceRef: <String, Object?>{
                'kind': 'capture_attachment',
                'id': 'attachment-1',
                'local_path': '/Users/guangmo/private/image.png',
                'storage_ref': 'file:///Users/guangmo/private/image.png',
              },
            ),
          ],
        ),
      );

      expect(response.text, 'vision response');
      final request = provider.requests.single;
      expect(request.promptText, 'Describe image');
      expect(
        request.requiredCapabilities,
        contains(ModelCapability.completion),
      );
      expect(request.requiredCapabilities, contains(ModelCapability.vision));
      expect(request.metadata['capture_id'], 'capture-1');
      expect(request.messages.single.parts, hasLength(2));
      expect(
        request.messages.single.parts.last.kind,
        ModelContentPartKind.inlineImage,
      );
      expect(request.messages.single.parts.last.sourceRef, <String, Object?>{
        'kind': 'capture_attachment',
        'id': 'attachment-1',
      });
      expect(
        request.messages.single.parts.last.sourceRef.values.join(' '),
        isNot(contains('/Users/guangmo')),
      );
    },
  );

  test(
    'RuntimeModelClientAdapter maps usage and metadata to raw output',
    () async {
      final provider = FakeModelProvider(
        responder: (request) async {
          return ModelResponse(
            providerId: 'fake',
            model: request.model ?? 'fallback-model',
            text: 'raw mapped',
            usage: const ModelUsage(inputTokens: 12, outputTokens: 7),
            metadata: const <String, Object?>{
              'finish_reason': 'stop',
              'request_id': 'req-1',
            },
          );
        },
      );
      final client = RuntimeModelClientAdapter(
        provider: provider,
        model: 'local-test-model',
      );

      final response = await client.complete(
        const runtime.ModelRequest(prompt: 'Map raw fields'),
      );

      expect(response.text, 'raw mapped');
      expect(response.raw['usage'], <String, Object?>{
        'input_tokens': 12,
        'output_tokens': 7,
        'total_tokens': 19,
      });
      expect(response.raw['metadata'], <String, Object?>{
        'finish_reason': 'stop',
        'request_id': 'req-1',
      });
    },
  );

  test('RuntimeModelClientAdapter wraps provider failures', () async {
    final provider = FakeModelProvider(
      responder: (request) => throw StateError('provider failed'),
    );
    final client = RuntimeModelClientAdapter(provider: provider);

    await expectLater(
      client.complete(const runtime.ModelRequest(prompt: 'fail')),
      throwsA(
        isA<RuntimeModelProviderException>()
            .having((error) => error.providerId, 'providerId', 'fake')
            .having((error) => error.cause, 'cause', isA<StateError>()),
      ),
    );
  });
}
