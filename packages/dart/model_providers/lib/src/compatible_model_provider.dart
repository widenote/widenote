import 'dart:async';

import 'model_provider.dart';
import 'provider_config.dart';
import 'provider_http.dart';

enum ModelProviderErrorKind {
  invalidConfiguration,
  unsupportedCapability,
  authentication,
  rateLimited,
  timeout,
  server,
  network,
  malformedResponse,
  missingText,
  unknown,
}

final class ModelProviderException implements Exception {
  const ModelProviderException({
    required this.providerId,
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final String providerId;
  final ModelProviderErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ', statusCode: $statusCode';
    return 'ModelProviderException(providerId: $providerId, kind: $kind, '
        'message: $message$status)';
  }
}

ModelProvider modelProviderFromConfig({
  required ModelProviderConfig config,
  required ModelProviderHttpClient httpClient,
}) {
  if (config.kind.usesAnthropicMessages) {
    return AnthropicCompatibleModelProvider(
      config: config,
      httpClient: httpClient,
    );
  }
  return OpenAiCompatibleModelProvider(config: config, httpClient: httpClient);
}

final class OpenAiCompatibleModelProvider implements ModelProvider {
  const OpenAiCompatibleModelProvider({
    required this.config,
    required this.httpClient,
    this.timeout = const Duration(seconds: 30),
  });

  final ModelProviderConfig config;
  final ModelProviderHttpClient httpClient;
  final Duration timeout;

  @override
  String get id => config.id;

  @override
  String get displayName => config.displayName;

  @override
  Set<ModelCapability> get capabilities => config.capabilities;

  @override
  bool supports(ModelCapability capability) {
    return capabilities.contains(capability);
  }

  @override
  Future<ModelResponse> complete(ModelRequest request) async {
    _assertUsableConfig();
    _assertCapabilities(id, capabilities, request.requiredCapabilities);

    final httpResponse = await _sendRequest(
      id,
      () => httpClient.postJson(
        _openAiChatCompletionsEndpoint(config.endpoint),
        headers: _openAiHeaders(config.apiKey),
        body: _buildBody(request),
        timeout: timeout,
      ),
    );

    _assertSuccessStatus(id, httpResponse.statusCode);
    return _parseOpenAiResponse(httpResponse.body, request.model);
  }

  Map<String, Object?> _buildBody(ModelRequest request) {
    return <String, Object?>{
      'model': request.model ?? config.model,
      'messages': request.messages
          .map(
            (message) => <String, Object?>{
              'role': _openAiRole(message.role),
              'content': message.content,
            },
          )
          .toList(),
      'max_tokens': config.maxOutputTokens,
      if (request.metadata.isNotEmpty) 'metadata': request.metadata,
    };
  }

  ModelResponse _parseOpenAiResponse(Object? body, String? requestedModel) {
    if (body is! Map<String, Object?>) {
      throw _malformed(id, 'OpenAI-compatible response was not an object.');
    }

    final choices = body['choices'];
    if (choices is! List<Object?> || choices.isEmpty) {
      throw _missingText(id, 'OpenAI-compatible response had no choices.');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, Object?>) {
      throw _malformed(id, 'OpenAI-compatible choice was not an object.');
    }
    final message = firstChoice['message'];
    if (message is! Map<String, Object?>) {
      throw _malformed(id, 'OpenAI-compatible message was not an object.');
    }
    final text = message['content'];
    if (text is! String || text.trim().isEmpty) {
      throw _missingText(
        id,
        'OpenAI-compatible response did not include text.',
      );
    }

    final usage = _openAiUsage(body['usage']);
    return ModelResponse(
      providerId: id,
      model: _stringValue(body['model']) ?? requestedModel ?? config.model,
      text: text,
      usage: usage,
      metadata: <String, Object?>{
        if (body['id'] is String) 'request_id': body['id'],
        if (firstChoice['finish_reason'] is String)
          'finish_reason': firstChoice['finish_reason'],
      },
    );
  }

  void _assertUsableConfig() {
    final validation = config.validate();
    if (validation.isValid) {
      return;
    }
    throw ModelProviderException(
      providerId: id,
      kind: ModelProviderErrorKind.invalidConfiguration,
      message: 'Provider config is invalid: ${validation.summary}.',
    );
  }
}

final class AnthropicCompatibleModelProvider implements ModelProvider {
  const AnthropicCompatibleModelProvider({
    required this.config,
    required this.httpClient,
    this.timeout = const Duration(seconds: 30),
  });

  final ModelProviderConfig config;
  final ModelProviderHttpClient httpClient;
  final Duration timeout;

  @override
  String get id => config.id;

  @override
  String get displayName => config.displayName;

  @override
  Set<ModelCapability> get capabilities => config.capabilities;

  @override
  bool supports(ModelCapability capability) {
    return capabilities.contains(capability);
  }

  @override
  Future<ModelResponse> complete(ModelRequest request) async {
    _assertUsableConfig();
    _assertCapabilities(id, capabilities, request.requiredCapabilities);

    final httpResponse = await _sendRequest(
      id,
      () => httpClient.postJson(
        _anthropicMessagesEndpoint(config.endpoint),
        headers: _anthropicHeaders(config),
        body: _buildBody(request),
        timeout: timeout,
      ),
    );

    _assertSuccessStatus(id, httpResponse.statusCode);
    return _parseAnthropicResponse(httpResponse.body, request.model);
  }

  Map<String, Object?> _buildBody(ModelRequest request) {
    final systemMessages = request.messages
        .where((message) => message.role == ModelMessageRole.system)
        .map((message) => message.content)
        .where((content) => content.trim().isNotEmpty)
        .toList();
    final conversationMessages = request.messages
        .where((message) => message.role != ModelMessageRole.system)
        .map(
          (message) => <String, Object?>{
            'role': _anthropicRole(message.role),
            'content': message.content,
          },
        )
        .toList();

    return <String, Object?>{
      'model': request.model ?? config.model,
      'max_tokens': config.maxOutputTokens,
      if (_shouldDisableAnthropicThinking(config))
        'thinking': const <String, Object?>{'type': 'disabled'},
      if (systemMessages.isNotEmpty) 'system': systemMessages.join('\n'),
      'messages': conversationMessages,
    };
  }

  ModelResponse _parseAnthropicResponse(Object? body, String? requestedModel) {
    if (body is! Map<String, Object?>) {
      throw _malformed(id, 'Anthropic-compatible response was not an object.');
    }

    final content = body['content'];
    if (content is! List<Object?> || content.isEmpty) {
      throw _missingText(id, 'Anthropic-compatible response had no content.');
    }
    final parts = <String>[];
    for (final item in content) {
      if (item is Map<String, Object?> && item['type'] == 'text') {
        final text = item['text'];
        if (text is String && text.trim().isNotEmpty) {
          parts.add(text);
        }
      }
    }
    if (parts.isEmpty) {
      throw _missingText(
        id,
        'Anthropic-compatible response did not include text.',
      );
    }

    final usage = _anthropicUsage(body['usage']);
    return ModelResponse(
      providerId: id,
      model: _stringValue(body['model']) ?? requestedModel ?? config.model,
      text: parts.join('\n'),
      usage: usage,
      metadata: <String, Object?>{
        if (body['id'] is String) 'request_id': body['id'],
        if (body['stop_reason'] is String) 'finish_reason': body['stop_reason'],
      },
    );
  }

  void _assertUsableConfig() {
    final validation = config.validate();
    if (validation.isValid) {
      return;
    }
    throw ModelProviderException(
      providerId: id,
      kind: ModelProviderErrorKind.invalidConfiguration,
      message: 'Provider config is invalid: ${validation.summary}.',
    );
  }
}

Uri _openAiChatCompletionsEndpoint(Uri endpoint) {
  final segments = endpoint.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (_endsWithOpenAiChatCompletionsPath(segments)) {
    return endpoint;
  }
  if (segments.isNotEmpty && segments.last == 'chat') {
    return endpoint.replace(pathSegments: <String>[...segments, 'completions']);
  }
  return endpoint.replace(
    pathSegments: <String>[...segments, 'chat', 'completions'],
  );
}

bool _endsWithOpenAiChatCompletionsPath(List<String> segments) {
  return segments.length >= 2 &&
      segments[segments.length - 2] == 'chat' &&
      segments.last == 'completions';
}

Uri _anthropicMessagesEndpoint(Uri endpoint) {
  final segments = endpoint.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (_endsWithMessagesPath(segments)) {
    return endpoint;
  }
  if (segments.isNotEmpty && segments.last == 'v1') {
    return endpoint.replace(pathSegments: <String>[...segments, 'messages']);
  }
  return endpoint.replace(
    pathSegments: <String>[...segments, 'v1', 'messages'],
  );
}

bool _endsWithMessagesPath(List<String> segments) {
  return segments.isNotEmpty && segments.last == 'messages';
}

Map<String, String> _openAiHeaders(String apiKey) {
  return <String, String>{
    'content-type': 'application/json',
    if (apiKey.trim().isNotEmpty) 'authorization': 'Bearer $apiKey',
  };
}

Map<String, String> _anthropicHeaders(ModelProviderConfig config) {
  return <String, String>{
    'content-type': 'application/json',
    'anthropic-version': '2023-06-01',
    if (config.apiKey.trim().isNotEmpty)
      if (config.kind.usesAnthropicBearerAuthorization)
        'authorization': 'Bearer ${config.apiKey}'
      else
        'x-api-key': config.apiKey,
  };
}

bool _shouldDisableAnthropicThinking(ModelProviderConfig config) {
  if (config.kind == ModelProviderKind.mimo) {
    return true;
  }
  final model = config.model.toLowerCase();
  final host = config.endpoint.host.toLowerCase();
  final path = config.endpoint.path.toLowerCase();
  return model.contains('deepseek') ||
      host.contains('deepseek') ||
      path.contains('deepseek');
}

String _openAiRole(ModelMessageRole role) {
  return switch (role) {
    ModelMessageRole.system => 'system',
    ModelMessageRole.user => 'user',
    ModelMessageRole.assistant => 'assistant',
    ModelMessageRole.tool => 'tool',
  };
}

String _anthropicRole(ModelMessageRole role) {
  return switch (role) {
    ModelMessageRole.assistant => 'assistant',
    ModelMessageRole.system ||
    ModelMessageRole.user ||
    ModelMessageRole.tool => 'user',
  };
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
      message: 'Model provider request timed out.',
      cause: error,
    );
  } on ModelProviderException {
    rethrow;
  } catch (error) {
    throw ModelProviderException(
      providerId: providerId,
      kind: ModelProviderErrorKind.network,
      message: 'Model provider request failed before a response was received.',
      cause: error,
    );
  }
}

void _assertCapabilities(
  String providerId,
  Set<ModelCapability> capabilities,
  Set<ModelCapability> requiredCapabilities,
) {
  final missing = requiredCapabilities.difference(capabilities);
  if (missing.isEmpty) {
    return;
  }
  throw ModelProviderException(
    providerId: providerId,
    kind: ModelProviderErrorKind.unsupportedCapability,
    message:
        'Provider does not support: ${missing.map((item) => item.name).join(', ')}.',
  );
}

void _assertSuccessStatus(String providerId, int statusCode) {
  if (statusCode >= 200 && statusCode < 300) {
    return;
  }

  throw ModelProviderException(
    providerId: providerId,
    kind: _errorKindForStatus(statusCode),
    message: 'Model provider returned HTTP $statusCode.',
    statusCode: statusCode,
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

ModelProviderException _malformed(String providerId, String message) {
  return ModelProviderException(
    providerId: providerId,
    kind: ModelProviderErrorKind.malformedResponse,
    message: message,
  );
}

ModelProviderException _missingText(String providerId, String message) {
  return ModelProviderException(
    providerId: providerId,
    kind: ModelProviderErrorKind.missingText,
    message: message,
  );
}

ModelUsage _openAiUsage(Object? usage) {
  if (usage is! Map<String, Object?>) {
    return const ModelUsage();
  }
  return ModelUsage(
    inputTokens: _intValue(usage['prompt_tokens']),
    outputTokens: _intValue(usage['completion_tokens']),
  );
}

ModelUsage _anthropicUsage(Object? usage) {
  if (usage is! Map<String, Object?>) {
    return const ModelUsage();
  }
  return ModelUsage(
    inputTokens: _intValue(usage['input_tokens']),
    outputTokens: _intValue(usage['output_tokens']),
  );
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
