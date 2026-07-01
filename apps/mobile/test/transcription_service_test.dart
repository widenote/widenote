import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;
import 'package:widenote_mobile/features/transcription/mimo_asr_provider.dart';
import 'package:widenote_mobile/features/transcription/transcription_service.dart';
import 'package:widenote_mobile/features/transcription/transcription_settings.dart';
import 'package:widenote_mobile/features/transcription/transcription_types.dart';
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  group('TranscriptionService', () {
    test('local success saves source-linked transcript artifact', () async {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _seedVoiceAttachment(database);
      final service = _service(
        database,
        settings: const VoiceTranscriptionSettings(
          correctionMode: TranscriptCorrectionMode.disabled,
        ),
        localProvider: _FakeTranscriptionProvider(
          resultText: 'Discuss WideNote voice capture.',
        ),
      );

      final result = await service.transcribeAttachment('voice-1');

      expect(result.status, TranscriptStatus.active);
      expect(result.text, 'Discuss WideNote voice capture.');
      final artifact = database.derivedArtifacts.readById(
        'artifact.capture-1.voice-1.audio_transcript',
      );
      expect(artifact, isNotNull);
      expect(artifact!.status, 'active');
      expect(artifact.body, result.text);
      expect(artifact.payload['provider_id'], 'fake_local');
      expect(
        artifact.sourceRefs.whereType<Map>().any(
          (ref) =>
              ref['kind'] == 'file' &&
              ref['id'] == 'voice-1' &&
              ref['sha256'] == 'voice-sha',
        ),
        isTrue,
      );
      expect(
        database.attachments.readById('voice-1')!.payload['transcript_status'],
        'active',
      );
    });

    test(
      'local failure falls back to remote when consent is granted',
      () async {
        final database = localdb.WideNoteLocalDatabase.inMemory();
        addTearDown(database.close);
        _seedVoiceAttachment(database);
        final service = _service(
          database,
          settings: const VoiceTranscriptionSettings(
            remoteConsentGranted: true,
          ),
          localProvider: const _FailingTranscriptionProvider(
            TranscriptionFailureCode.modelMissing,
          ),
          remoteProvider: _FakeTranscriptionProvider(
            id: 'fake_remote',
            kind: TranscriptionProviderKind.mimoAsr,
            resultText: 'Remote transcript text.',
          ),
        );

        final result = await service.transcribeAttachment('voice-1');

        expect(result.status, TranscriptStatus.active);
        expect(result.providerId, 'fake_remote');
        expect(result.metadata['fallback_from'], 'model_missing');
        final artifact = database.derivedArtifacts.readById(
          'artifact.capture-1.voice-1.audio_transcript',
        )!;
        expect(artifact.payload['provider_kind'], 'mimo_asr');
        expect(artifact.payload['fallback_from'], 'model_missing');
      },
    );

    test('remote fallback without credential records safe failure', () async {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _seedVoiceAttachment(database);
      final service = _service(
        database,
        settings: const VoiceTranscriptionSettings(remoteConsentGranted: true),
        localProvider: const _FailingTranscriptionProvider(
          TranscriptionFailureCode.modelMissing,
        ),
        httpClient: _RecordingHttpClient(),
      );

      final result = await service.transcribeAttachment('voice-1');

      expect(result.status, TranscriptStatus.failed);
      expect(
        result.errorCode,
        TranscriptionFailureCode.remoteCredentialMissing,
      );
      final artifact = database.derivedArtifacts.readById(
        'artifact.capture-1.voice-1.audio_transcript',
      )!;
      expect(artifact.payload['error_code'], 'remote_credential_missing');
      expect(artifact.payload.toString(), isNot(contains('sk-')));
    });

    test('correction auto-applies safe high-confidence patches', () async {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _seedVoiceAttachment(database);
      _seedMemory(database, 'Memex is a project glossary term.');
      final model = runtime.FakeModel(
        responses: const <String>[
          '{"patches":[{"from":"Mimex","to":"Memex","span":{"start":4,"end":9},"confidence":"high","reason":"term_memory","requires_review":false}]}',
        ],
      );
      final service = _service(
        database,
        settings: const VoiceTranscriptionSettings(
          correctionMode: TranscriptCorrectionMode.autoApplyHighConfidence,
        ),
        localProvider: _FakeTranscriptionProvider(
          resultText: 'Use Mimex today',
        ),
        modelClient: model,
      );

      final result = await service.transcribeAttachment('voice-1');

      expect(result.text, 'Use Memex today');
      expect(database.memoryItems.readAll(status: 'active'), hasLength(1));
      expect(
        model.requests.single.context['pack_id'],
        'pack.transcript_correction',
      );
      final artifact = database.derivedArtifacts.readById(
        'artifact.capture-1.voice-1.audio_transcript',
      )!;
      expect(artifact.payload['correction_status'], 'auto_applied');
      expect(artifact.payload['correction_auto_applied'], isTrue);
      expect(
        artifact.sourceRefs.whereType<Map>().any(
          (ref) =>
              ref['kind'] == 'correction_event' &&
              ref['id'] == 'correction.voice-1' &&
              ref['pack_id'] == 'pack.transcript_correction',
        ),
        isTrue,
      );
    });

    test('manual retry scans failed transcript artifacts', () async {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _seedVoiceAttachment(database, attachmentId: 'voice-1');
      _seedVoiceAttachment(database, attachmentId: 'voice-2');
      database.derivedArtifacts.save(
        database.derivedArtifacts
            .readById('artifact.capture-1.voice-1.audio_transcript')!
            .copyWith(status: 'failed'),
      );
      database.derivedArtifacts.save(
        database.derivedArtifacts
            .readById('artifact.capture-1.voice-2.audio_transcript')!
            .copyWith(status: 'needs_review'),
      );
      final service = _service(
        database,
        settings: const VoiceTranscriptionSettings(
          remoteConsentGranted: true,
          correctionMode: TranscriptCorrectionMode.disabled,
        ),
        localProvider: const _FailingTranscriptionProvider(
          TranscriptionFailureCode.modelMissing,
        ),
        remoteProvider: _FakeTranscriptionProvider(
          id: 'fake_remote',
          kind: TranscriptionProviderKind.mimoAsr,
          resultText: 'Recovered transcript.',
        ),
      );

      final summary = await service.retryFailedTranscripts();

      expect(summary.attempted, 2);
      expect(summary.succeeded, 2);
      expect(summary.failed, 0);
      expect(
        database.derivedArtifacts
            .readById('artifact.capture-1.voice-1.audio_transcript')!
            .status,
        'active',
      );
      expect(
        database.derivedArtifacts
            .readById('artifact.capture-1.voice-2.audio_transcript')!
            .body,
        'Recovered transcript.',
      );
    });
  });

  group('MimoAsrProvider', () {
    test(
      'sends official data-url audio payload without exposing key',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'widenote-mimo-',
        );
        addTearDown(() async {
          if (tempDirectory.existsSync()) {
            await tempDirectory.delete(recursive: true);
          }
        });
        final temp = File('${tempDirectory.path}/audio.wav');
        await temp.writeAsBytes(_minimalWavBytes());
        final credentialStore = MemoryTranscriptionCredentialStore();
        await credentialStore.writeMimoAsrApiKey('test-secret-key');
        final httpClient = _RecordingHttpClient(
          responseBody: <String, Object?>{
            'id': 'response-1',
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{'content': 'MiMo transcript'},
              },
            ],
          },
        );
        final provider = MimoAsrProvider(
          settings: const VoiceTranscriptionSettings(
            remoteConsentGranted: true,
          ),
          credentialStore: credentialStore,
          httpClient: httpClient,
        );

        final result = await provider.transcribeAttachment(
          AudioAttachmentRef(
            id: 'voice-1',
            captureId: 'capture-1',
            storagePath: temp.path,
            mimeType: 'audio/wav',
            sha256: 'sha',
            byteLength: temp.lengthSync(),
            durationMs: 1000,
            localPath: temp.path,
          ),
        );

        expect(result.text, 'MiMo transcript');
        final inputAudio =
            ((((httpClient.lastBody['messages'] as List).single
                                as Map)['content']
                            as List)
                        .single
                    as Map)['input_audio']
                as Map;
        expect(inputAudio['data'], startsWith('data:audio/wav;base64,'));
        expect(inputAudio['format'], 'wav');
        expect(
          httpClient.lastHeaders['authorization'],
          'Bearer test-secret-key',
        );
        expect(
          httpClient.lastBody.toString(),
          isNot(contains('test-secret-key')),
        );
      },
    );
  });
}

TranscriptionService _service(
  localdb.WideNoteLocalDatabase database, {
  required VoiceTranscriptionSettings settings,
  AudioTranscriptionProvider? localProvider,
  AudioTranscriptionProvider? remoteProvider,
  TranscriptionCredentialStore? credentialStore,
  ModelProviderHttpClient? httpClient,
  runtime.ModelClient? modelClient,
}) {
  return TranscriptionService(
    database: database,
    supportDirectory: Directory.systemTemp,
    settingsRepository: MemoryVoiceTranscriptionSettingsRepository(settings),
    credentialStore: credentialStore ?? MemoryTranscriptionCredentialStore(),
    httpClient: httpClient,
    modelClient:
        modelClient ?? const runtime.ModelResponse(text: '').asClient(),
    localProvider: localProvider,
    remoteProvider: remoteProvider,
  );
}

void _seedVoiceAttachment(
  localdb.WideNoteLocalDatabase database, {
  String attachmentId = 'voice-1',
}) {
  final now = DateTime.utc(2026, 7, 1, 9);
  if (database.captures.readById('capture-1') == null) {
    database.captures.save(
      localdb.CaptureRecord(
        id: 'capture-1',
        sourceType: 'manual_with_attachments',
        payload: const <String, Object?>{'text': 'voice capture'},
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
  database.attachments.save(
    localdb.AttachmentRecord(
      id: attachmentId,
      captureId: 'capture-1',
      assetKind: 'voice',
      mimeType: 'audio/wav',
      storagePath: '/tmp/$attachmentId.wav',
      originalFileName: '$attachmentId.wav',
      sha256: 'voice-sha',
      byteLength: 128,
      payload: <String, Object?>{
        'raw_metadata': <String, Object?>{
          'adapter_metadata': <String, Object?>{
            'local_path': '/tmp/$attachmentId.wav',
            'duration_ms': 1000,
            'sha256': 'voice-sha',
          },
        },
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.derivedArtifacts.save(
    localdb.DerivedArtifactRecord(
      id: 'artifact.capture-1.$attachmentId.audio_transcript',
      sourceCaptureId: 'capture-1',
      sourceAttachmentId: attachmentId,
      artifactKind: 'audio_transcript',
      status: 'pending',
      title: 'Audio transcript',
      body: 'Transcript pending.',
      sourceRefs: <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
        <String, Object?>{'kind': 'file', 'id': attachmentId},
      ],
      generatorId: 'pending',
      generatorVersion: 'pending',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _seedMemory(localdb.WideNoteLocalDatabase database, String body) {
  final now = DateTime.utc(2026, 7, 1, 9, 10);
  database.memoryItems.insert(
    localdb.MemoryItemRecord(
      id: 'memory-1',
      key: 'glossary',
      body: body,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Uint8List _minimalWavBytes() {
  return Uint8List.fromList(<int>[
    0x52,
    0x49,
    0x46,
    0x46,
    0x24,
    0,
    0,
    0,
    0x57,
    0x41,
    0x56,
    0x45,
    0x66,
    0x6d,
    0x74,
    0x20,
    16,
    0,
    0,
    0,
    1,
    0,
    1,
    0,
    0x80,
    0x3e,
    0,
    0,
    0,
    0x7d,
    0,
    0,
    2,
    0,
    16,
    0,
    0x64,
    0x61,
    0x74,
    0x61,
    0,
    0,
    0,
    0,
  ]);
}

final class _FakeTranscriptionProvider implements AudioTranscriptionProvider {
  const _FakeTranscriptionProvider({
    this.id = 'fake_local',
    this.kind = TranscriptionProviderKind.localSenseVoice,
    required this.resultText,
  });

  @override
  final String id;

  @override
  final TranscriptionProviderKind kind;

  final String resultText;

  @override
  String get displayName => id;

  @override
  bool get supportsFileTranscription => true;

  @override
  bool get supportsRemoteUpload => kind == TranscriptionProviderKind.mimoAsr;

  @override
  bool get supportsStreamingPreview => true;

  @override
  Future<void> prepare() async {}

  @override
  Future<TranscriptionResult> transcribeAttachment(
    AudioAttachmentRef attachment, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    return TranscriptionResult(
      text: resultText,
      status: TranscriptStatus.active,
      providerId: id,
      providerKind: kind,
      model: 'fake-model',
      durationMs: attachment.durationMs,
      rawAsrText: resultText,
    );
  }

  @override
  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async* {
    yield TranscriptionPreview(
      pendingText: resultText,
      status: TranscriptStatus.transcribing,
    );
  }

  @override
  Future<void> dispose() async {}
}

final class _FailingTranscriptionProvider
    implements AudioTranscriptionProvider {
  const _FailingTranscriptionProvider(this.code);

  final TranscriptionFailureCode code;

  @override
  String get id => 'failing_local';

  @override
  String get displayName => id;

  @override
  TranscriptionProviderKind get kind =>
      TranscriptionProviderKind.localSenseVoice;

  @override
  bool get supportsFileTranscription => true;

  @override
  bool get supportsRemoteUpload => false;

  @override
  bool get supportsStreamingPreview => false;

  @override
  Future<void> prepare() async {}

  @override
  Future<TranscriptionResult> transcribeAttachment(
    AudioAttachmentRef attachment, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    throw TranscriptionException(code: code, message: code.wireName);
  }

  @override
  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async* {}

  @override
  Future<void> dispose() async {}
}

final class _RecordingHttpClient implements ModelProviderHttpClient {
  _RecordingHttpClient({
    this.responseBody = const <String, Object?>{},
  });

  final Map<String, Object?> responseBody;
  Map<String, String> lastHeaders = const <String, String>{};
  Map<String, Object?> lastBody = const <String, Object?>{};

  @override
  Future<ModelProviderHttpResponse> postJson(
    Uri endpoint, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    lastHeaders = headers;
    lastBody = body;
    return ModelProviderHttpResponse(
      statusCode: 200,
      headers: const <String, String>{},
      body: responseBody,
    );
  }
}

extension on runtime.ModelResponse {
  runtime.ModelClient asClient() => _StaticModelClient(this);
}

final class _StaticModelClient implements runtime.ModelClient {
  const _StaticModelClient(this.response);

  final runtime.ModelResponse response;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    return response;
  }
}
