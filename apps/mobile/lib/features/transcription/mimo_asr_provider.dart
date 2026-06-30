import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:widenote_model_providers/model_providers.dart';

import 'transcription_settings.dart';
import 'transcription_types.dart';

final class MimoAsrProvider implements AudioTranscriptionProvider {
  const MimoAsrProvider({
    required VoiceTranscriptionSettings settings,
    required TranscriptionCredentialStore credentialStore,
    required ModelProviderHttpClient httpClient,
    this.timeout = const Duration(seconds: 45),
  }) : _settings = settings,
       _credentialStore = credentialStore,
       _httpClient = httpClient;

  static const int base64SizeLimitBytes = 10 * 1024 * 1024;

  final VoiceTranscriptionSettings _settings;
  final TranscriptionCredentialStore _credentialStore;
  final ModelProviderHttpClient _httpClient;
  final Duration timeout;

  @override
  String get id => _settings.mimoAsrProviderId;

  @override
  String get displayName => 'Xiaomi MiMo ASR';

  @override
  TranscriptionProviderKind get kind => TranscriptionProviderKind.mimoAsr;

  @override
  bool get supportsFileTranscription => true;

  @override
  bool get supportsStreamingPreview => false;

  @override
  bool get supportsRemoteUpload => true;

  @override
  Future<void> prepare() async {
    if (!_settings.remoteConsentGranted) {
      throw const TranscriptionException(
        code: TranscriptionFailureCode.remoteDisabled,
        message: 'Remote ASR is disabled until consent is granted.',
      );
    }
    final apiKey = await _credentialStore.readMimoAsrApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const TranscriptionException(
        code: TranscriptionFailureCode.remoteCredentialMissing,
        message: 'MiMo ASR credential is not configured.',
      );
    }
  }

  @override
  Future<TranscriptionResult> transcribeAttachment(
    AudioAttachmentRef attachment, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    await prepare();
    final apiKey = (await _credentialStore.readMimoAsrApiKey())!.trim();
    final audioBytes = await File(attachment.localPath).readAsBytes();
    final format = _formatForAttachment(attachment);
    final dataUrl = _audioDataUrl(base64Encode(audioBytes), format);
    if (dataUrl.length > base64SizeLimitBytes) {
      throw const TranscriptionException(
        code: TranscriptionFailureCode.remoteSizeLimit,
        message: 'Audio is too large for MiMo ASR Base64 upload.',
      );
    }

    final response = await _sendRequest(
      apiKey: apiKey,
      audioData: dataUrl,
      format: format,
      language: options.language,
    );
    final transcript = _extractTranscript(response).trim();
    if (transcript.isEmpty) {
      throw const TranscriptionException(
        code: TranscriptionFailureCode.malformedResponse,
        message: 'MiMo ASR response did not include transcript text.',
      );
    }

    return TranscriptionResult(
      text: transcript,
      status: TranscriptStatus.active,
      providerId: id,
      providerKind: kind,
      model: _settings.mimoAsrModel,
      durationMs: attachment.durationMs,
      language: options.language,
      rawAsrText: transcript,
      chunkCount: 1,
      metadata: <String, Object?>{
        'remote': true,
        'usage': _safeUsage(response['usage']),
        'request_id': _stringValue(response['id']),
      },
    );
  }

  @override
  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async* {
    throw const TranscriptionException(
      code: TranscriptionFailureCode.streamUnavailable,
      message: 'MiMo ASR does not provide local streaming preview.',
    );
  }

  @override
  Future<void> dispose() async {}

  Future<Map<String, Object?>> _sendRequest({
    required String apiKey,
    required String audioData,
    required String format,
    required String language,
  }) async {
    try {
      final httpResponse = await _httpClient.postJson(
        Uri.parse(_settings.mimoAsrEndpoint),
        headers: <String, String>{
          'content-type': 'application/json',
          'authorization': 'Bearer $apiKey',
          'api-key': apiKey,
        },
        body: <String, Object?>{
          'model': _settings.mimoAsrModel,
          'messages': <Object?>[
            <String, Object?>{
              'role': 'user',
              'content': <Object?>[
                <String, Object?>{
                  'type': 'input_audio',
                  'input_audio': <String, Object?>{
                    'data': audioData,
                    'format': format,
                  },
                },
              ],
            },
          ],
          'asr_options': <String, Object?>{'language': language},
          'stream': false,
        },
        timeout: timeout,
      );
      _assertSuccess(httpResponse.statusCode);
      final body = httpResponse.body;
      if (body is Map<String, Object?>) {
        return body;
      }
      if (body is Map) {
        return body.cast<String, Object?>();
      }
      throw const TranscriptionException(
        code: TranscriptionFailureCode.malformedResponse,
        message: 'MiMo ASR response was not an object.',
      );
    } on TranscriptionException {
      rethrow;
    } on TimeoutException catch (error) {
      throw TranscriptionException(
        code: TranscriptionFailureCode.timeout,
        message: 'MiMo ASR timed out.',
        cause: error,
      );
    } on Object catch (error) {
      throw TranscriptionException(
        code: TranscriptionFailureCode.network,
        message: 'MiMo ASR network request failed.',
        cause: error,
      );
    }
  }

  void _assertSuccess(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }
    final code = switch (statusCode) {
      401 || 403 => TranscriptionFailureCode.authentication,
      408 => TranscriptionFailureCode.timeout,
      429 => TranscriptionFailureCode.rateLimited,
      >= 500 => TranscriptionFailureCode.server,
      _ => TranscriptionFailureCode.unknown,
    };
    throw TranscriptionException(
      code: code,
      message: 'MiMo ASR failed with HTTP $statusCode.',
    );
  }
}

String _audioDataUrl(String base64Audio, String format) {
  final mimeType = switch (format) {
    'wav' => 'audio/wav',
    'mp3' => 'audio/mpeg',
    _ => 'application/octet-stream',
  };
  return 'data:$mimeType;base64,$base64Audio';
}

String _formatForAttachment(AudioAttachmentRef attachment) {
  if (attachment.mimeType == 'audio/wav' ||
      attachment.localPath.endsWith('.wav')) {
    return 'wav';
  }
  if (attachment.mimeType == 'audio/mpeg' ||
      attachment.localPath.endsWith('.mp3')) {
    return 'mp3';
  }
  throw const TranscriptionException(
    code: TranscriptionFailureCode.unsupportedAudio,
    message: 'MiMo ASR supports wav and mp3 audio only.',
  );
}

String _extractTranscript(Map<String, Object?> response) {
  final choices = response['choices'];
  if (choices is List<Object?> && choices.isNotEmpty) {
    final first = choices.first;
    if (first is Map<String, Object?>) {
      final message = first['message'];
      if (message is Map<String, Object?>) {
        final content = message['content'];
        if (content is String) {
          return content;
        }
      }
    }
  }
  final text = response['text'];
  if (text is String) {
    return text;
  }
  return '';
}

Map<String, Object?> _safeUsage(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
