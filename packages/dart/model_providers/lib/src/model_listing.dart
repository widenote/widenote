import 'dart:async';

import 'compatible_model_provider.dart';
import 'provider_config.dart';
import 'provider_http.dart';

abstract interface class ModelProviderModelListService {
  Future<ModelProviderModelListResult> listModels(ModelProviderConfig config);
}

final class ModelProviderModelListResult {
  const ModelProviderModelListResult({
    required this.succeeded,
    this.models = const <String>[],
    this.errorKind,
    this.statusCode,
  });

  factory ModelProviderModelListResult.success(List<String> models) {
    return ModelProviderModelListResult(
      succeeded: true,
      models: List.unmodifiable(models),
    );
  }

  factory ModelProviderModelListResult.failure({
    required ModelProviderErrorKind errorKind,
    int? statusCode,
  }) {
    return ModelProviderModelListResult(
      succeeded: false,
      errorKind: errorKind,
      statusCode: statusCode,
    );
  }

  final bool succeeded;
  final List<String> models;
  final ModelProviderErrorKind? errorKind;
  final int? statusCode;
}

final class OfflineModelProviderModelListService
    implements ModelProviderModelListService {
  const OfflineModelProviderModelListService();

  @override
  Future<ModelProviderModelListResult> listModels(
    ModelProviderConfig config,
  ) async {
    return ModelProviderModelListResult.success(
      <String>{
        config.model,
        config.kind.defaultModel,
      }.where((model) => model.trim().isNotEmpty).toList(growable: false),
    );
  }
}

final class AdapterModelProviderModelListService
    implements ModelProviderModelListService {
  const AdapterModelProviderModelListService({
    required this.httpClient,
    this.timeout = const Duration(seconds: 10),
  });

  final ModelProviderHttpClient httpClient;
  final Duration timeout;

  @override
  Future<ModelProviderModelListResult> listModels(
    ModelProviderConfig config,
  ) async {
    if (config.endpoint.toString().trim().isEmpty) {
      return ModelProviderModelListResult.failure(
        errorKind: ModelProviderErrorKind.invalidConfiguration,
      );
    }
    if (config.kind.requiresApiKey && config.apiKey.trim().isEmpty) {
      return ModelProviderModelListResult.failure(
        errorKind: ModelProviderErrorKind.authentication,
      );
    }

    try {
      final response = await httpClient.getJson(
        _modelsEndpoint(config),
        headers: _modelListHeaders(config),
        timeout: timeout,
      );
      if (!_isSuccess(response.statusCode)) {
        return ModelProviderModelListResult.failure(
          errorKind: _errorKindForStatus(response.statusCode),
          statusCode: response.statusCode,
        );
      }
      return ModelProviderModelListResult.success(
        _parseModels(config.kind, response.body),
      );
    } on TimeoutException {
      return ModelProviderModelListResult.failure(
        errorKind: ModelProviderErrorKind.timeout,
      );
    } catch (_) {
      return ModelProviderModelListResult.failure(
        errorKind: ModelProviderErrorKind.network,
      );
    }
  }
}

Uri _modelsEndpoint(ModelProviderConfig config) {
  if (config.kind == ModelProviderKind.gemini) {
    return _geminiModelsEndpoint(config.endpoint, apiKey: config.apiKey);
  }
  if (config.kind.usesAnthropicMessages) {
    return _anthropicModelsEndpoint(config.endpoint);
  }
  return _openAiModelsEndpoint(config.endpoint);
}

Uri _openAiModelsEndpoint(Uri endpoint) {
  var segments = endpoint.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: true);
  if (segments.isNotEmpty && segments.last == 'models') {
    return endpoint;
  }
  if (segments.length >= 2 &&
      segments[segments.length - 2] == 'chat' &&
      segments.last == 'completions') {
    segments = segments.take(segments.length - 2).toList(growable: true);
  } else if (segments.isNotEmpty && segments.last == 'chat') {
    segments = segments.take(segments.length - 1).toList(growable: true);
  }
  return endpoint.replace(pathSegments: <String>[...segments, 'models']);
}

Uri _anthropicModelsEndpoint(Uri endpoint) {
  var segments = endpoint.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: true);
  if (segments.isNotEmpty && segments.last == 'models') {
    return endpoint;
  }
  if (segments.isNotEmpty && segments.last == 'messages') {
    segments = segments.take(segments.length - 1).toList(growable: true);
  }
  if (segments.isNotEmpty && segments.last == 'v1') {
    return endpoint.replace(pathSegments: <String>[...segments, 'models']);
  }
  return endpoint.replace(pathSegments: <String>[...segments, 'v1', 'models']);
}

Uri _geminiModelsEndpoint(Uri endpoint, {required String apiKey}) {
  var segments = endpoint.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: true);
  if (segments.isNotEmpty && segments.last == 'models') {
    return _withGeminiKey(endpoint, apiKey);
  }
  if (segments.isNotEmpty && segments.last == 'openai') {
    segments = segments.take(segments.length - 1).toList(growable: true);
  }
  return _withGeminiKey(
    endpoint.replace(pathSegments: <String>[...segments, 'models']),
    apiKey,
  );
}

Uri _withGeminiKey(Uri endpoint, String apiKey) {
  if (apiKey.trim().isEmpty) {
    return endpoint;
  }
  // Gemini's native Models API authenticates API keys in the query string.
  return endpoint.replace(
    queryParameters: <String, String>{
      ...endpoint.queryParameters,
      'key': apiKey,
    },
  );
}

Map<String, String> _modelListHeaders(ModelProviderConfig config) {
  final headers = <String, String>{'accept': 'application/json'};
  if (config.kind == ModelProviderKind.gemini || config.apiKey.trim().isEmpty) {
    return headers;
  }
  if (config.kind.usesAnthropicMessages) {
    if (config.kind == ModelProviderKind.miniMax) {
      // MiniMax's Messages endpoint documents Bearer auth, while its
      // Anthropic-compatible Models endpoint documents X-Api-Key.
      headers['X-Api-Key'] = config.apiKey;
    } else {
      headers['x-api-key'] = config.apiKey;
      headers['anthropic-version'] = '2023-06-01';
    }
    return headers;
  }
  headers['authorization'] = 'Bearer ${config.apiKey}';
  return headers;
}

List<String> _parseModels(ModelProviderKind kind, Object? body) {
  final models = kind == ModelProviderKind.gemini
      ? _parseGeminiModels(body)
      : _parseOpenAiStyleModels(body);
  final seen = <String>{};
  final unique = <String>[];
  for (final model in models) {
    final trimmed = model.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) {
      continue;
    }
    unique.add(trimmed);
  }
  unique.sort();
  return unique;
}

List<String> _parseOpenAiStyleModels(Object? body) {
  if (body is! Map<String, Object?>) {
    return const <String>[];
  }
  final data = body['data'];
  if (data is! List<Object?>) {
    return const <String>[];
  }
  final models = <String>[];
  for (final item in data) {
    if (item is Map<String, Object?> && item['id'] is String) {
      models.add(item['id']! as String);
    }
  }
  return models;
}

List<String> _parseGeminiModels(Object? body) {
  if (body is! Map<String, Object?>) {
    return const <String>[];
  }
  final data = body['models'];
  if (data is! List<Object?>) {
    return const <String>[];
  }
  final models = <String>[];
  for (final item in data) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    final methods = item['supportedGenerationMethods'];
    if (methods is List<Object?> && !methods.contains('generateContent')) {
      continue;
    }
    final id = item['baseModelId'];
    if (id is String && id.trim().isNotEmpty) {
      models.add(id);
      continue;
    }
    final name = item['name'];
    if (name is String && name.trim().isNotEmpty) {
      models.add(name.replaceFirst('models/', ''));
    }
  }
  return models;
}

bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

ModelProviderErrorKind _errorKindForStatus(int statusCode) {
  if (statusCode == 401 || statusCode == 403) {
    return ModelProviderErrorKind.authentication;
  }
  if (statusCode == 408) {
    return ModelProviderErrorKind.timeout;
  }
  if (statusCode == 429) {
    return ModelProviderErrorKind.rateLimited;
  }
  if (statusCode >= 500) {
    return ModelProviderErrorKind.server;
  }
  return ModelProviderErrorKind.unknown;
}
