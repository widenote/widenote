import 'model_provider.dart';
import 'provider_config.dart';
import 'provider_http.dart';
import 'compatible_model_provider.dart';

abstract interface class ModelProviderConnectionTestService {
  Future<ModelProviderConnectionTestResult> test(ModelProviderConfig config);
}

final class ModelProviderConnectionTestResult {
  const ModelProviderConnectionTestResult({
    required this.succeeded,
    required this.message,
    required this.usedLiveAdapter,
    this.errorKind,
  });

  factory ModelProviderConnectionTestResult.success({
    required String message,
    required bool usedLiveAdapter,
  }) {
    return ModelProviderConnectionTestResult(
      succeeded: true,
      message: message,
      usedLiveAdapter: usedLiveAdapter,
    );
  }

  factory ModelProviderConnectionTestResult.failure({
    required String message,
    required bool usedLiveAdapter,
    required ModelProviderErrorKind errorKind,
  }) {
    return ModelProviderConnectionTestResult(
      succeeded: false,
      message: message,
      usedLiveAdapter: usedLiveAdapter,
      errorKind: errorKind,
    );
  }

  final bool succeeded;
  final String message;
  final bool usedLiveAdapter;
  final ModelProviderErrorKind? errorKind;
}

typedef ModelProviderConnectionProviderFactory =
    ModelProvider Function(ModelProviderConfig config);

final class OfflineModelProviderConnectionTestService
    implements ModelProviderConnectionTestService {
  const OfflineModelProviderConnectionTestService();

  @override
  Future<ModelProviderConnectionTestResult> test(
    ModelProviderConfig config,
  ) async {
    final validation = config.validate();
    if (!validation.isValid) {
      return ModelProviderConnectionTestResult.failure(
        usedLiveAdapter: false,
        errorKind: ModelProviderErrorKind.invalidConfiguration,
        message:
            '${config.kind.label} configuration is incomplete: ${validation.summary}.',
      );
    }
    return ModelProviderConnectionTestResult.success(
      usedLiveAdapter: false,
      message: '${config.kind.label} validated offline. No live request sent.',
    );
  }
}

final class AdapterModelProviderConnectionTestService
    implements ModelProviderConnectionTestService {
  const AdapterModelProviderConnectionTestService({
    required this.httpClient,
    this.providerFactory,
    this.probePrompt =
        'WideNote provider connection test. Reply with one short OK.',
  });

  final ModelProviderHttpClient httpClient;
  final ModelProviderConnectionProviderFactory? providerFactory;
  final String probePrompt;

  @override
  Future<ModelProviderConnectionTestResult> test(
    ModelProviderConfig config,
  ) async {
    final validation = config.validate();
    if (!validation.isValid) {
      return ModelProviderConnectionTestResult.failure(
        usedLiveAdapter: true,
        errorKind: ModelProviderErrorKind.invalidConfiguration,
        message:
            '${config.kind.label} configuration is incomplete: ${validation.summary}.',
      );
    }

    final provider = (providerFactory ?? _providerFromConfig)(config);
    try {
      await provider.complete(
        ModelRequest.text(
          probePrompt,
          model: config.model,
          requiredCapabilities: const <ModelCapability>{ModelCapability.chat},
          metadata: const <String, Object?>{'widenote_connection_test': true},
        ),
      );
      return ModelProviderConnectionTestResult.success(
        usedLiveAdapter: true,
        message: '${config.kind.label} connection test succeeded.',
      );
    } on ModelProviderException catch (error) {
      return ModelProviderConnectionTestResult.failure(
        usedLiveAdapter: true,
        errorKind: error.kind,
        message: _classifiedMessage(config.kind, error),
      );
    } on UnsupportedModelCapabilityException {
      return ModelProviderConnectionTestResult.failure(
        usedLiveAdapter: true,
        errorKind: ModelProviderErrorKind.unsupportedCapability,
        message:
            '${config.kind.label} cannot run the chat connection probe with this capability set.',
      );
    } catch (_) {
      return ModelProviderConnectionTestResult.failure(
        usedLiveAdapter: true,
        errorKind: ModelProviderErrorKind.unknown,
        message: '${config.kind.label} connection test failed unexpectedly.',
      );
    }
  }

  ModelProvider _providerFromConfig(ModelProviderConfig config) {
    return modelProviderFromConfig(config: config, httpClient: httpClient);
  }
}

String _classifiedMessage(
  ModelProviderKind kind,
  ModelProviderException error,
) {
  final label = kind.label;
  final status = error.statusCode == null ? '' : ' HTTP ${error.statusCode}.';
  return switch (error.kind) {
    ModelProviderErrorKind.invalidConfiguration =>
      '$label configuration is incomplete: ${error.message}',
    ModelProviderErrorKind.unsupportedCapability =>
      '$label cannot run the requested model capability.',
    ModelProviderErrorKind.authentication =>
      '$label authentication failed.$status Check the saved API key and account access.',
    ModelProviderErrorKind.rateLimited =>
      '$label is rate limited.$status Try again later or choose another provider.',
    ModelProviderErrorKind.timeout =>
      '$label connection timed out.$status Check the endpoint and network.',
    ModelProviderErrorKind.server =>
      '$label provider returned a server error.$status Try again later.',
    ModelProviderErrorKind.network =>
      '$label network request failed before a response was received.',
    ModelProviderErrorKind.malformedResponse =>
      '$label returned a response WideNote could not parse.',
    ModelProviderErrorKind.missingText =>
      '$label responded without usable text.',
    ModelProviderErrorKind.unknown =>
      '$label connection failed.$status ${error.message}',
  };
}
