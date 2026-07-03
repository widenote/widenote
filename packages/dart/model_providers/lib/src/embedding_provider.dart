import 'dart:async';

import 'compatible_model_provider.dart';
import 'provider_http.dart';

enum EmbeddingProviderKind { openRouter, openAiCompatible }

extension EmbeddingProviderKindDetails on EmbeddingProviderKind {
  String get wireName {
    return switch (this) {
      EmbeddingProviderKind.openRouter => 'openrouter',
      EmbeddingProviderKind.openAiCompatible => 'openai_compatible',
    };
  }

  String get label {
    return switch (this) {
      EmbeddingProviderKind.openRouter => 'OpenRouter',
      EmbeddingProviderKind.openAiCompatible => 'OpenAI-compatible',
    };
  }

  Uri get defaultEndpoint {
    return switch (this) {
      EmbeddingProviderKind.openRouter => Uri.parse(
        'https://openrouter.ai/api/v1',
      ),
      EmbeddingProviderKind.openAiCompatible => Uri.parse(
        'https://api.openai.com/v1',
      ),
    };
  }

  String get defaultModel {
    return switch (this) {
      EmbeddingProviderKind.openRouter => 'qwen/qwen3-embedding-0.6b',
      EmbeddingProviderKind.openAiCompatible => 'text-embedding-3-small',
    };
  }
}

EmbeddingProviderKind embeddingProviderKindFromWireName(String value) {
  final normalized = value.trim().replaceAll('-', '_');
  return switch (normalized) {
    'openrouter' ||
    'open_router' ||
    'openRouter' => EmbeddingProviderKind.openRouter,
    'openai_compatible' ||
    'open_ai_compatible' ||
    'openAiCompatible' => EmbeddingProviderKind.openAiCompatible,
    _ => throw StateError('Unknown embedding provider kind: $value'),
  };
}

final class EmbeddingProviderConfig {
  const EmbeddingProviderConfig({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.endpoint,
    required this.model,
    this.apiKey = '',
    this.dimensions,
    this.batchSize = 16,
  });

  factory EmbeddingProviderConfig.preset({
    required String id,
    EmbeddingProviderKind kind = EmbeddingProviderKind.openRouter,
    String? displayName,
    Uri? endpoint,
    String? model,
    String apiKey = '',
    int? dimensions,
    int batchSize = 16,
  }) {
    return EmbeddingProviderConfig(
      id: id,
      kind: kind,
      displayName: displayName ?? kind.label,
      endpoint: endpoint ?? kind.defaultEndpoint,
      model: model ?? kind.defaultModel,
      apiKey: apiKey,
      dimensions: dimensions,
      batchSize: batchSize,
    );
  }

  final String id;
  final EmbeddingProviderKind kind;
  final String displayName;
  final Uri endpoint;
  final String model;
  final String apiKey;
  final int? dimensions;
  final int batchSize;

  EmbeddingProviderConfigValidation validate({bool requireApiKey = true}) {
    final issues = <EmbeddingProviderConfigIssue>[];
    if (id.trim().isEmpty) {
      issues.add(EmbeddingProviderConfigIssue.missingProviderId);
    }
    if (displayName.trim().isEmpty) {
      issues.add(EmbeddingProviderConfigIssue.missingDisplayName);
    }
    if (endpoint.toString().trim().isEmpty) {
      issues.add(EmbeddingProviderConfigIssue.missingEndpoint);
    } else if (endpoint.scheme != 'https' && endpoint.scheme != 'http') {
      issues.add(EmbeddingProviderConfigIssue.unsupportedEndpointScheme);
    }
    if (model.trim().isEmpty) {
      issues.add(EmbeddingProviderConfigIssue.missingModel);
    }
    if (requireApiKey && apiKey.trim().isEmpty) {
      issues.add(EmbeddingProviderConfigIssue.missingApiKey);
    }
    if (batchSize <= 0) {
      issues.add(EmbeddingProviderConfigIssue.invalidBatchSize);
    }
    return EmbeddingProviderConfigValidation(issues: Set.unmodifiable(issues));
  }
}

enum EmbeddingProviderConfigIssue {
  missingProviderId,
  missingDisplayName,
  missingEndpoint,
  unsupportedEndpointScheme,
  missingModel,
  missingApiKey,
  invalidBatchSize,
}

final class EmbeddingProviderConfigValidation {
  const EmbeddingProviderConfigValidation({required this.issues});

  final Set<EmbeddingProviderConfigIssue> issues;

  bool get isValid => issues.isEmpty;

  String get summary {
    if (issues.isEmpty) {
      return 'valid';
    }
    return issues.map((issue) => issue.name).join(', ');
  }
}

final class EmbeddingRequest {
  const EmbeddingRequest({required this.input, this.model});

  final List<String> input;
  final String? model;
}

final class EmbeddingResponse {
  const EmbeddingResponse({
    required this.providerId,
    required this.model,
    required this.embeddings,
    this.usage = const EmbeddingUsage(),
  });

  final String providerId;
  final String model;
  final List<List<double>> embeddings;
  final EmbeddingUsage usage;
}

final class EmbeddingUsage {
  const EmbeddingUsage({this.inputTokens = 0});

  final int inputTokens;
}

abstract interface class EmbeddingProvider {
  String get id;

  Future<EmbeddingResponse> embed(EmbeddingRequest request);
}

final class OpenAiCompatibleEmbeddingProvider implements EmbeddingProvider {
  const OpenAiCompatibleEmbeddingProvider({
    required this.config,
    required this.httpClient,
    this.timeout = const Duration(seconds: 30),
  });

  final EmbeddingProviderConfig config;
  final ModelProviderHttpClient httpClient;
  final Duration timeout;

  @override
  String get id => config.id;

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    final validation = config.validate();
    if (!validation.isValid) {
      throw ModelProviderException(
        providerId: id,
        kind: ModelProviderErrorKind.invalidConfiguration,
        message: 'Embedding provider config is invalid: ${validation.summary}.',
      );
    }
    if (request.input.isEmpty ||
        request.input.any((value) => value.trim().isEmpty)) {
      throw const ModelProviderException(
        providerId: 'embedding',
        kind: ModelProviderErrorKind.invalidConfiguration,
        message: 'Embedding input must not be empty.',
      );
    }

    final response = await _sendRequest(
      id,
      () => httpClient.postJson(
        _embeddingsEndpoint(config.endpoint),
        headers: _embeddingHeaders(config),
        body: <String, Object?>{
          'model': request.model ?? config.model,
          'input': request.input,
          if (config.dimensions != null) 'dimensions': config.dimensions,
        },
        timeout: timeout,
      ),
    );
    _assertSuccessStatus(id, response.statusCode);
    return _parseResponse(response.body, request.model);
  }

  EmbeddingResponse _parseResponse(Object? body, String? requestedModel) {
    if (body is! Map<String, Object?>) {
      throw _malformed(id, 'Embedding response was not an object.');
    }
    final data = body['data'];
    if (data is! List<Object?> || data.isEmpty) {
      throw _malformed(id, 'Embedding response had no data.');
    }
    final embeddingsByIndex = <int, List<double>>{};
    for (var fallbackIndex = 0; fallbackIndex < data.length; fallbackIndex++) {
      final item = data[fallbackIndex];
      if (item is! Map<String, Object?>) {
        throw _malformed(id, 'Embedding data item was not an object.');
      }
      final embedding = item['embedding'];
      if (embedding is! List<Object?> || embedding.isEmpty) {
        throw _malformed(id, 'Embedding data item had no vector.');
      }
      final index = item['index'] is int
          ? item['index']! as int
          : fallbackIndex;
      embeddingsByIndex[index] = [
        for (final value in embedding)
          if (value is num)
            value.toDouble()
          else
            throw _malformed(id, 'Embedding vector contained a non-number.'),
      ];
    }
    final ordered = [
      for (var index = 0; index < embeddingsByIndex.length; index += 1)
        embeddingsByIndex[index] ??
            (throw _malformed(id, 'Embedding indexes were incomplete.')),
    ];
    return EmbeddingResponse(
      providerId: id,
      model: _stringValue(body['model']) ?? requestedModel ?? config.model,
      embeddings: List.unmodifiable(ordered),
      usage: _embeddingUsage(body['usage']),
    );
  }
}

EmbeddingProvider embeddingProviderFromConfig({
  required EmbeddingProviderConfig config,
  required ModelProviderHttpClient httpClient,
}) {
  return OpenAiCompatibleEmbeddingProvider(
    config: config,
    httpClient: httpClient,
  );
}

Uri _embeddingsEndpoint(Uri endpoint) {
  var segments = endpoint.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: true);
  if (segments.isNotEmpty && segments.last == 'embeddings') {
    return endpoint;
  }
  if (segments.length >= 2 &&
      segments[segments.length - 2] == 'chat' &&
      segments.last == 'completions') {
    segments = segments.take(segments.length - 2).toList(growable: true);
  } else if (segments.isNotEmpty &&
      (segments.last == 'chat' || segments.last == 'responses')) {
    segments = segments.take(segments.length - 1).toList(growable: true);
  }
  return endpoint.replace(pathSegments: <String>[...segments, 'embeddings']);
}

Map<String, String> _embeddingHeaders(EmbeddingProviderConfig config) {
  return <String, String>{
    'accept': 'application/json',
    'content-type': 'application/json',
    if (config.apiKey.trim().isNotEmpty)
      'authorization': 'Bearer ${config.apiKey}',
  };
}

EmbeddingUsage _embeddingUsage(Object? usage) {
  if (usage is! Map<String, Object?>) {
    return const EmbeddingUsage();
  }
  return EmbeddingUsage(inputTokens: _intValue(usage['prompt_tokens']));
}

Future<ModelProviderHttpResponse> _sendRequest(
  String providerId,
  Future<ModelProviderHttpResponse> Function() request,
) async {
  try {
    return await request();
  } on TimeoutException catch (error) {
    throw ModelProviderException(
      providerId: providerId,
      kind: ModelProviderErrorKind.timeout,
      message: 'Embedding provider request timed out.',
      cause: error,
    );
  } on ModelProviderException {
    rethrow;
  } catch (error) {
    throw ModelProviderException(
      providerId: providerId,
      kind: ModelProviderErrorKind.network,
      message: 'Embedding provider request failed.',
      cause: error,
    );
  }
}

void _assertSuccessStatus(String providerId, int statusCode) {
  if (statusCode >= 200 && statusCode < 300) {
    return;
  }
  throw ModelProviderException(
    providerId: providerId,
    kind: _errorKindForStatus(statusCode),
    message: 'Embedding provider returned HTTP $statusCode.',
    statusCode: statusCode,
  );
}

ModelProviderException _malformed(String providerId, String message) {
  return ModelProviderException(
    providerId: providerId,
    kind: ModelProviderErrorKind.malformedResponse,
    message: message,
  );
}

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

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

String? _stringValue(Object? value) {
  return value is String && value.trim().isNotEmpty ? value : null;
}
