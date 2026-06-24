import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

import '../shared/text_preview.dart';

final modelClientProvider = Provider<runtime.ModelClient>((ref) {
  final qaClient = qaMimoModelClientFromEnvironment();
  if (qaClient is XiaomiMimoModelClient) {
    ref.onDispose(qaClient.close);
  }
  return qaClient ?? const LocalSummaryModelClient();
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

final class XiaomiMimoModelClient implements runtime.ModelClient {
  XiaomiMimoModelClient({
    required this.apiKey,
    this.model = 'mimo-v2.5-pro',
    Uri? endpoint,
    HttpClient? httpClient,
    this.retryDelays = const <Duration>[
      Duration(seconds: 4),
      Duration(seconds: 12),
      Duration(seconds: 24),
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
    httpRequest.write(body);

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
