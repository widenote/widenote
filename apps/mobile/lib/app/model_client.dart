import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_model_providers/model_providers.dart';

import 'local_database.dart';
import '../shared/text_preview.dart';

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
  return const LocalSummaryModelClient();
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

final class LocalSummaryModelClient implements runtime.ModelClient {
  const LocalSummaryModelClient();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    final text = request.prompt.replaceFirst(
      'Summarize capture for Memory: ',
      '',
    );
    return runtime.ModelResponse(text: previewText(text));
  }
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
  return _FallbackModelClient(
    primary: RuntimeModelClientAdapter(provider: provider, model: config.model),
    fallback: const LocalSummaryModelClient(),
    providerId: config.id,
  );
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

final class _FallbackModelClient implements runtime.ModelClient {
  const _FallbackModelClient({
    required this.primary,
    required this.fallback,
    required this.providerId,
  });

  final runtime.ModelClient primary;
  final runtime.ModelClient fallback;
  final String providerId;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    try {
      return await primary.complete(request);
    } catch (error) {
      final response = await fallback.complete(request);
      return runtime.ModelResponse(
        text: response.text,
        raw: <String, Object?>{
          ...response.raw,
          'model_fallback': true,
          'model_fallback_provider_id': providerId,
          'model_fallback_error_type': error.runtimeType.toString(),
        },
      );
    }
  }
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
      'max_tokens': 128,
      'messages': <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': _qaPrompt(request.prompt)},
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
    return runtime.ModelResponse(text: previewText(text));
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

String _qaPrompt(String prompt) {
  return '''
You are the WideNote Android QA model adapter.
Return one concise, safe Memory sentence in the same language as the input.
Do not include JSON, markdown, bullet points, secrets, or commentary.

$prompt
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
