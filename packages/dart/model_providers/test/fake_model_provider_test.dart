import 'package:test/test.dart';
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  group('FakeModelProvider', () {
    test('returns queued responses and records requests', () async {
      final provider = FakeModelProvider(responses: ['first', 'second']);

      final first = await provider.complete(ModelRequest.text('hello'));
      final second = await provider.complete(ModelRequest.text('again'));

      expect(first.text, 'first');
      expect(second.text, 'second');
      expect(first.providerId, 'fake');
      expect(provider.requests, hasLength(2));
      expect(provider.requests.first.promptText, 'hello');
    });

    test('throws when required capabilities are missing', () async {
      final provider = FakeModelProvider(
        capabilities: const {ModelCapability.completion},
      );

      expect(
        () => provider.complete(
          ModelRequest.text(
            'look at this',
            requiredCapabilities: const {ModelCapability.vision},
          ),
        ),
        throwsA(isA<UnsupportedModelCapabilityException>()),
      );
    });

    test(
      'multimodal promptText includes text parts but not image data',
      () async {
        final provider = FakeModelProvider(
          capabilities: const <ModelCapability>{
            ModelCapability.completion,
            ModelCapability.vision,
          },
        );

        await provider.complete(
          ModelRequest.multimodal(
            'look at this',
            parts: const <ModelContentPart>[
              ModelContentPart.inlineImage(
                mimeType: 'image/png',
                dataBase64: 'abc123',
              ),
            ],
          ),
        );

        expect(provider.requests.single.promptText, 'look at this');
        expect(provider.requests.single.promptText, isNot(contains('abc123')));
      },
    );
  });
}
