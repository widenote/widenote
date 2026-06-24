import 'package:test/test.dart';
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  group('ModelProviderConfig', () {
    test('validates required provider setup fields', () {
      final config = ModelProviderConfig(
        id: ' ',
        kind: ModelProviderKind.openAiCompatible,
        displayName: '',
        endpoint: Uri.parse('file:///tmp/provider'),
        model: ' ',
      );

      final validation = config.validate();

      expect(validation.isValid, isFalse);
      expect(
        validation.issues,
        containsAll(<ModelProviderConfigIssue>{
          ModelProviderConfigIssue.missingProviderId,
          ModelProviderConfigIssue.missingDisplayName,
          ModelProviderConfigIssue.unsupportedEndpointScheme,
          ModelProviderConfigIssue.missingModel,
          ModelProviderConfigIssue.missingApiKey,
        }),
      );
    });

    test('safe JSON and toString do not expose credentials', () {
      final credential = _runtimeCredential();
      final config = ModelProviderConfig.preset(
        id: 'kimi-main',
        kind: ModelProviderKind.kimi,
        apiKey: credential,
      );

      final safeJson = config.toSafeJson();

      expect(safeJson['has_api_key'], isTrue);
      expect(safeJson.containsKey('api_key'), isFalse);
      expect(safeJson.containsValue(credential), isFalse);
      expect(config.toString(), isNot(contains(credential)));
    });

    test('presets choose compatibility endpoints and models', () {
      final mimo = ModelProviderConfig.preset(
        id: 'mimo',
        kind: ModelProviderKind.mimo,
      );
      final kimi = ModelProviderConfig.preset(
        id: 'kimi',
        kind: ModelProviderKind.kimi,
      );

      expect(mimo.kind.usesAnthropicMessages, isTrue);
      expect(mimo.endpoint.path, contains('/anthropic/'));
      expect(mimo.model, isNotEmpty);
      expect(kimi.kind.usesAnthropicMessages, isFalse);
      expect(kimi.endpoint.path, contains('/chat/completions'));
      expect(kimi.model, isNotEmpty);
    });
  });
}

String _runtimeCredential() {
  return String.fromCharCodes(<int>[
    99,
    114,
    101,
    100,
    101,
    110,
    116,
    105,
    97,
    108,
  ]);
}
