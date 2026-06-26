import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_model_providers/model_providers.dart';

import 'local_database.dart';

final modelClientProvider = Provider<runtime.ModelClient>((ref) {
  final qaClient = qaMimoModelClientFromEnvironment();
  if (qaClient is XiaomiMimoModelClient) {
    ref.onDispose(qaClient.close);
    return qaClient;
  }

  final providerClient = _defaultProviderClient(ref);
  if (providerClient != null) {
    return providerClient;
  }
  return const ModelUnavailableModelClient();
});

final chatModelClientProvider = Provider<runtime.ModelClient?>((ref) {
  final qaClient = qaMimoModelClientFromEnvironment();
  if (qaClient is XiaomiMimoModelClient) {
    ref.onDispose(qaClient.close);
    return qaClient;
  }

  return _defaultProviderClient(ref);
});

runtime.ModelClient? qaMimoModelClientFromEnvironment() {
  const apiKey = String.fromEnvironment('WIDENOTE_QA_MIMO_API_KEY');
  return qaMimoModelClientFromKey(apiKey);
}

runtime.ModelClient? qaMimoModelClientFromKey(String apiKey) {
  final trimmed = apiKey.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return XiaomiMimoModelClient(apiKey: trimmed);
}

final class ModelUnavailableModelClient implements runtime.ModelClient {
  const ModelUnavailableModelClient();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    throw const ModelUnavailableException(
      'Configure a model provider before running model-backed work.',
    );
  }
}

final class ModelUnavailableException implements Exception {
  const ModelUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

runtime.ModelClient? _defaultProviderClient(Ref ref) {
  final WideNoteLocalDatabase database;
  try {
    database = ref.watch(localDatabaseProvider);
  } on Object {
    return null;
  }
  final record = database.modelProviderConfigs.readDefault();
  if (record == null || record.apiKey.trim().isEmpty) {
    return null;
  }
  final config = _modelProviderConfigFromRecord(record);
  if (config == null || !config.validate().isValid) {
    return null;
  }

  final httpClient = _DartIoModelProviderHttpClient();
  ref.onDispose(httpClient.close);
  final provider = modelProviderFromConfig(
    config: config,
    httpClient: httpClient,
  );
  final primary = RuntimeModelClientAdapter(
    provider: provider,
    model: config.model,
  );
  return primary;
}

ModelProviderConfig? _modelProviderConfigFromRecord(
  ModelProviderConfigRecord record,
) {
  final kind = _modelProviderKindFromName(record.providerKind);
  if (kind == null) {
    return null;
  }
  final endpoint = _safeUri(record.endpoint);
  if (endpoint == null) {
    return null;
  }
  return ModelProviderConfig(
    id: record.id,
    kind: kind,
    displayName: record.displayName,
    endpoint: endpoint,
    model: record.model,
    apiKey: record.apiKey,
    capabilities: _modelCapabilitiesFromNames(record.capabilities),
  );
}

Uri? _safeUri(String value) {
  try {
    return Uri.parse(value);
  } on FormatException {
    return null;
  }
}

ModelProviderKind? _modelProviderKindFromName(String name) {
  for (final kind in ModelProviderKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  return null;
}

Set<ModelCapability> _modelCapabilitiesFromNames(List<Object?> names) {
  final capabilities = <ModelCapability>{};
  for (final name in names.whereType<String>()) {
    for (final capability in ModelCapability.values) {
      if (capability.name == name) {
        capabilities.add(capability);
        break;
      }
    }
  }
  if (capabilities.isEmpty) {
    return const <ModelCapability>{
      ModelCapability.chat,
      ModelCapability.completion,
    };
  }
  return capabilities;
}

final class _DartIoModelProviderHttpClient implements ModelProviderHttpClient {
  _DartIoModelProviderHttpClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  void close() {
    _httpClient.close(force: true);
  }

  @override
  Future<ModelProviderHttpResponse> postJson(
    Uri endpoint, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final request = await _httpClient.postUrl(endpoint).timeout(timeout);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    request.add(utf8.encode(jsonEncode(body)));

    final response = await request.close().timeout(timeout);
    final responseBody = await utf8.decodeStream(response);
    return ModelProviderHttpResponse(
      statusCode: response.statusCode,
      headers: _responseHeaders(response),
      body: _decodeResponseBody(responseBody),
    );
  }
}

final class XiaomiMimoModelClient implements runtime.ModelClient {
  XiaomiMimoModelClient({
    required this.apiKey,
    this.model = 'mimo-v2.5-pro',
    Uri? endpoint,
    HttpClient? httpClient,
    this.retryDelays = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 3),
    ],
  }) : endpoint =
           endpoint ??
           Uri.parse(
             'https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages',
           ),
       _httpClient = httpClient ?? HttpClient();

  final String apiKey;
  final String model;
  final Uri endpoint;
  final HttpClient _httpClient;
  final List<Duration> retryDelays;

  void close({bool force = false}) {
    _httpClient.close(force: force);
  }

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    for (var attempt = 0; ; attempt += 1) {
      try {
        return await _completeOnce(request);
      } on XiaomiMimoModelException catch (error) {
        if (attempt >= retryDelays.length || !_shouldRetry(error)) {
          rethrow;
        }
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  Future<runtime.ModelResponse> _completeOnce(
    runtime.ModelRequest request,
  ) async {
    final httpRequest = await _httpClient
        .postUrl(endpoint)
        .timeout(const Duration(seconds: 15));
    httpRequest.headers
      ..set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType)
      ..set('anthropic-version', '2023-06-01')
      ..set('x-api-key', apiKey);

    final body = jsonEncode(<String, Object?>{
      'model': model,
      'max_tokens': _maxTokens(request),
      'messages': <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': _qaPrompt(request)},
      ],
    });
    httpRequest.add(utf8.encode(body));

    final response = await httpRequest.close().timeout(
      const Duration(seconds: 30),
    );
    final responseBody = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw XiaomiMimoModelException(
        'MIMO request failed with HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException {
      throw const XiaomiMimoModelException('Invalid MIMO response.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const XiaomiMimoModelException('MIMO response was not an object.');
    }
    final text = _extractText(decoded).trim();
    if (text.isEmpty) {
      throw const XiaomiMimoModelException(
        'MIMO response did not contain text.',
      );
    }
    return runtime.ModelResponse(
      text: text,
      raw: <String, Object?>{
        'provider_id': 'xiaomi_mimo',
        'model': model,
        'usage': _mimoUsage(decoded),
      },
    );
  }
}

final class XiaomiMimoModelException implements Exception {
  const XiaomiMimoModelException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'XiaomiMimoModelException: $message';
}

bool _shouldRetry(XiaomiMimoModelException error) {
  final statusCode = error.statusCode;
  return statusCode == HttpStatus.tooManyRequests ||
      (statusCode != null && statusCode >= 500);
}

int _maxTokens(runtime.ModelRequest request) {
  if (request.context['chat_mode'] == 'source_cited_local_context') {
    return 512;
  }
  return 128;
}

String _qaPrompt(runtime.ModelRequest request) {
  if (request.context['chat_mode'] == 'source_cited_local_context') {
    return '''
You are the WideNote QA chat model adapter.
Follow the user task exactly. Use only the local sources included in the prompt.
Cite source kind/id when answering. If the sources are insufficient, say what is unknown.

${request.prompt}
''';
  }
  return '''
You are the WideNote QA capture model adapter.
Return one concise, safe Memory sentence in the same language as the input.
Do not include JSON, markdown, bullet points, secrets, or commentary.

${request.prompt}
''';
}

String _extractText(Map<String, Object?> response) {
  final content = response['content'];
  if (content is! List<Object?>) {
    return '';
  }
  final parts = <String>[];
  for (final item in content) {
    if (item is Map<String, Object?> && item['type'] == 'text') {
      final text = item['text'];
      if (text is String) {
        parts.add(text);
      }
    }
  }
  return parts.join('\n');
}

Map<String, Object?> _mimoUsage(Map<String, Object?> response) {
  final usage = response['usage'];
  if (usage is! Map) {
    return const <String, Object?>{};
  }
  final inputTokens = _intValue(usage['input_tokens']);
  final outputTokens = _intValue(usage['output_tokens']);
  final totalTokens =
      _intValue(usage['total_tokens']) ??
      (inputTokens == null || outputTokens == null
          ? null
          : inputTokens + outputTokens);
  final result = <String, Object?>{};
  if (inputTokens != null) {
    result['input_tokens'] = inputTokens;
  }
  if (outputTokens != null) {
    result['output_tokens'] = outputTokens;
  }
  if (totalTokens != null) {
    result['total_tokens'] = totalTokens;
  }
  return result;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

Map<String, String> _responseHeaders(HttpClientResponse response) {
  final headers = <String, String>{};
  response.headers.forEach((name, values) {
    headers[name] = values.join(',');
  });
  return headers;
}

Object? _decodeResponseBody(String body) {
  if (body.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(body) as Object?;
  } on FormatException {
    return body;
  }
}
