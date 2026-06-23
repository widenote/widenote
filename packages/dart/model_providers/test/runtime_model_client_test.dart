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
