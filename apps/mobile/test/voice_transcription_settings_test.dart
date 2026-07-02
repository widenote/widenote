import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/transcription/presentation/voice_transcription_settings_page.dart';
import 'package:widenote_mobile/features/transcription/transcription_service.dart';
import 'package:widenote_mobile/features/transcription/transcription_settings.dart';
import 'package:widenote_mobile/features/transcription/transcription_types.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  test('legacy remote fallback setting migrates to local engine', () {
    final settings = VoiceTranscriptionSettings.fromJson(
      const <String, Object?>{
        'provider_mode': 'local_first_remote_auto',
        'remote_consent_granted': true,
      },
    );

    expect(settings.engine, VoiceTranscriptionEngine.localSenseVoice);
    expect(settings.remoteAsrEnabled, isFalse);
    expect(settings.remoteConsentGranted, isFalse);
  });

  testWidgets('engine selector persists explicit alternatives', (tester) async {
    final database = localdb.WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final repository = MemoryVoiceTranscriptionSettingsRepository(
      const VoiceTranscriptionSettings(
        engine: VoiceTranscriptionEngine.localSenseVoice,
        remoteConsentGranted: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          voiceTranscriptionSettingsRepositoryProvider.overrideWithValue(
            repository,
          ),
          transcriptionCredentialStoreProvider.overrideWithValue(
            MemoryTranscriptionCredentialStore(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VoiceTranscriptionSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final engineControl = find.byKey(
      const Key('voice-transcription-engine-control'),
    );
    await tester.scrollUntilVisible(
      engineControl,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: engineControl, matching: find.text('MiMo ASR')),
    );
    await tester.pumpAndSettle();
    var saved = await repository.load();
    expect(saved.engine, VoiceTranscriptionEngine.xiaomiMimo);
    expect(saved.remoteConsentGranted, isTrue);

    await tester.tap(
      find.descendant(of: engineControl, matching: find.text('Off')),
    );
    await tester.pumpAndSettle();
    saved = await repository.load();
    expect(saved.engine, VoiceTranscriptionEngine.disabled);
    expect(saved.remoteConsentGranted, isFalse);

    await tester.tap(
      find.descendant(
        of: engineControl,
        matching: find.text('Local SenseVoice'),
      ),
    );
    await tester.pumpAndSettle();
    saved = await repository.load();
    expect(saved.engine, VoiceTranscriptionEngine.localSenseVoice);
    expect(saved.remoteConsentGranted, isFalse);
  });

  testWidgets(
    'voice settings persists controls and retries failed transcripts',
    (tester) async {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _seedFailedVoiceTranscript(database);
      final repository = MemoryVoiceTranscriptionSettingsRepository(
        const VoiceTranscriptionSettings(
          localModelState: LocalTranscriptionModelState.ready,
        ),
      );
      final credentials = MemoryTranscriptionCredentialStore();
      final service = TranscriptionService(
        database: database,
        supportDirectory: Directory.systemTemp,
        settingsRepository: repository,
        credentialStore: credentials,
        httpClient: null,
        modelClient: const _StaticModelClient(),
        localProvider: const _FailingTranscriptionProvider(),
        remoteProvider: const _RemoteTranscriptionProvider(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(database),
            voiceTranscriptionSettingsRepositoryProvider.overrideWithValue(
              repository,
            ),
            transcriptionCredentialStoreProvider.overrideWithValue(credentials),
            transcriptionServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VoiceTranscriptionSettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('voice-transcription-settings-page')),
        findsOneWidget,
      );
      expect(find.text('Voice Transcription'), findsWidgets);
      expect(find.text('ready'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('voice-preview-switch')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-preview-switch')));
      await tester.pumpAndSettle();
      expect((await repository.load()).realtimePreviewEnabled, isFalse);

      await tester.scrollUntilVisible(
        find.byKey(const Key('voice-remote-consent-switch')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-remote-consent-switch')));
      await tester.pumpAndSettle();
      expect((await repository.load()).remoteAsrEnabled, isTrue);

      await tester.enterText(
        find.byKey(const Key('voice-asr-endpoint-field')),
        'https://example.invalid/v1/chat/completions',
      );
      await tester.enterText(
        find.byKey(const Key('voice-asr-model-field')),
        'mimo-test-asr',
      );
      await tester.enterText(
        find.byKey(const Key('voice-asr-api-key-field')),
        'test-key',
      );
      await tester.ensureVisible(
        find.byKey(const Key('voice-asr-save-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-asr-save-button')));
      await tester.pumpAndSettle();

      final saved = await repository.load();
      expect(
        saved.mimoAsrEndpoint,
        'https://example.invalid/v1/chat/completions',
      );
      expect(saved.mimoAsrModel, 'mimo-test-asr');
      expect(await credentials.readMimoAsrApiKey(), 'test-key');
      expect(find.text('Voice transcription settings saved.'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('voice-correction-mode-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-correction-mode-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suggest only').last);
      await tester.pumpAndSettle();
      expect(
        (await repository.load()).correctionMode,
        TranscriptCorrectionMode.suggestOnly,
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('voice-retry-failed-transcripts-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('voice-retry-failed-transcripts-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 attempted / 1 succeeded / 0 failed'), findsOneWidget);
      expect(
        database.derivedArtifacts
            .readById('artifact.capture-1.voice-1.audio_transcript')!
            .body,
        'Recovered transcript.',
      );
    },
  );
}

void _seedFailedVoiceTranscript(localdb.WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 7, 1, 10);
  database.captures.save(
    localdb.CaptureRecord(
      id: 'capture-1',
      sourceType: 'manual_with_attachments',
      payload: const <String, Object?>{'text': 'voice'},
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.attachments.save(
    localdb.AttachmentRecord(
      id: 'voice-1',
      captureId: 'capture-1',
      assetKind: 'voice',
      mimeType: 'audio/wav',
      storagePath: '/tmp/voice-1.wav',
      originalFileName: 'voice-1.wav',
      sha256: 'voice-sha',
      byteLength: 128,
      payload: const <String, Object?>{
        'raw_metadata': <String, Object?>{
          'adapter_metadata': <String, Object?>{
            'local_path': '/tmp/voice-1.wav',
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
      id: 'artifact.capture-1.voice-1.audio_transcript',
      sourceCaptureId: 'capture-1',
      sourceAttachmentId: 'voice-1',
      artifactKind: 'audio_transcript',
      status: 'failed',
      title: 'Audio transcript failed',
      body: 'Transcript failed.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
        <String, Object?>{'kind': 'file', 'id': 'voice-1'},
      ],
      generatorId: 'local_sensevoice',
      generatorVersion: 'local_sensevoice',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

final class _StaticModelClient implements runtime.ModelClient {
  const _StaticModelClient();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    return const runtime.ModelResponse(text: '{"patches":[]}');
  }
}

final class _FailingTranscriptionProvider
    implements AudioTranscriptionProvider {
  const _FailingTranscriptionProvider();

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
    throw const TranscriptionException(
      code: TranscriptionFailureCode.modelMissing,
      message: 'missing',
    );
  }

  @override
  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async* {}

  @override
  Future<void> dispose() async {}
}

final class _RemoteTranscriptionProvider implements AudioTranscriptionProvider {
  const _RemoteTranscriptionProvider();

  @override
  String get id => 'fake_remote';

  @override
  String get displayName => id;

  @override
  TranscriptionProviderKind get kind => TranscriptionProviderKind.mimoAsr;

  @override
  bool get supportsFileTranscription => true;

  @override
  bool get supportsRemoteUpload => true;

  @override
  bool get supportsStreamingPreview => false;

  @override
  Future<void> prepare() async {}

  @override
  Future<TranscriptionResult> transcribeAttachment(
    AudioAttachmentRef attachment, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    return TranscriptionResult(
      text: 'Recovered transcript.',
      status: TranscriptStatus.active,
      providerId: id,
      providerKind: kind,
      model: 'fake-remote',
      durationMs: attachment.durationMs,
    );
  }

  @override
  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async* {}

  @override
  Future<void> dispose() async {}
}
