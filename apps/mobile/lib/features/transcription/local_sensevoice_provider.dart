import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'transcription_settings.dart';
import 'transcription_types.dart';

final class LocalSenseVoiceModelFiles {
  const LocalSenseVoiceModelFiles({
    required this.modelPath,
    required this.tokensPath,
  });

  final String modelPath;
  final String tokensPath;
}

typedef LocalSenseVoiceModelResolver =
    Future<LocalSenseVoiceModelFiles?> Function();

final class LocalSenseVoiceProvider implements AudioTranscriptionProvider {
  LocalSenseVoiceProvider({
    required LocalSenseVoiceModelResolver modelResolver,
    VoiceTranscriptionSettings settings = const VoiceTranscriptionSettings(),
    this.bindingsInitializer = sherpa.initBindings,
  }) : _modelResolver = modelResolver,
       _settings = settings;

  final LocalSenseVoiceModelResolver _modelResolver;
  final VoiceTranscriptionSettings _settings;
  final void Function([String? path]) bindingsInitializer;
  bool _bindingsInitialized = false;

  @override
  String get id => 'local_sensevoice';

  @override
  String get displayName => 'Local SenseVoice';

  @override
  TranscriptionProviderKind get kind =>
      TranscriptionProviderKind.localSenseVoice;

  @override
  bool get supportsFileTranscription => true;

  @override
  bool get supportsStreamingPreview => true;

  @override
  bool get supportsRemoteUpload => false;

  @override
  Future<void> prepare() async {
    final files = await _modelResolver();
    if (files == null) {
      throw const TranscriptionException(
        code: TranscriptionFailureCode.modelMissing,
        message: 'Local SenseVoice model is not downloaded.',
      );
    }
    if (!File(files.modelPath).existsSync() ||
        !File(files.tokensPath).existsSync()) {
      throw const TranscriptionException(
        code: TranscriptionFailureCode.modelMissing,
        message: 'Local SenseVoice model files are missing.',
      );
    }
    _ensureBindings();
  }

  @override
  Future<TranscriptionResult> transcribeAttachment(
    AudioAttachmentRef attachment, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    if (!attachment.isWav) {
      throw const TranscriptionException(
        code: TranscriptionFailureCode.unsupportedAudio,
        message:
            'Local SenseVoice first slice accepts new WAV recordings only.',
      );
    }
    final files = await _requireModelFiles();
    _ensureBindings();

    sherpa.OfflineRecognizer? recognizer;
    sherpa.OfflineStream? stream;
    try {
      final model = sherpa.OfflineModelConfig(
        senseVoice: sherpa.OfflineSenseVoiceModelConfig(
          model: files.modelPath,
          language: _senseVoiceLanguage(options.language),
          useInverseTextNormalization: true,
        ),
        tokens: files.tokensPath,
        modelType: 'sense-voice',
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );
      recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(model: model),
      );
      final wave = sherpa.readWave(attachment.localPath);
      if (wave.samples.isEmpty || wave.sampleRate <= 0) {
        throw const TranscriptionException(
          code: TranscriptionFailureCode.noSpeech,
          message: 'No readable speech samples were found.',
        );
      }
      stream = recognizer.createStream();
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = result.text.trim();
      if (text.isEmpty) {
        throw const TranscriptionException(
          code: TranscriptionFailureCode.noSpeech,
          message: 'Local ASR detected no speech.',
        );
      }
      return TranscriptionResult(
        text: text,
        status: TranscriptStatus.active,
        providerId: id,
        providerKind: kind,
        model: p.basename(p.dirname(files.modelPath)),
        durationMs: attachment.durationMs,
        language: result.lang.trim().isEmpty ? options.language : result.lang,
        rawAsrText: text,
        metadata: <String, Object?>{
          if (result.emotion.trim().isNotEmpty) 'emotion': result.emotion,
          if (result.event.trim().isNotEmpty) 'event': result.event,
        },
      );
    } on TranscriptionException {
      rethrow;
    } on Object catch (error) {
      throw TranscriptionException(
        code: TranscriptionFailureCode.modelInitFailed,
        message: 'Local SenseVoice transcription failed.',
        cause: error,
      );
    } finally {
      stream?.free();
      recognizer?.free();
    }
  }

  @override
  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async* {
    if (!_settings.realtimePreviewEnabled) {
      yield const TranscriptionPreview(status: TranscriptStatus.pending);
      return;
    }
    try {
      await prepare();
    } on TranscriptionException catch (error) {
      yield TranscriptionPreview(
        status: TranscriptStatus.pending,
        errorCode: error.code,
      );
      return;
    }

    var bytesSeen = 0;
    await for (final chunk in samples) {
      bytesSeen += chunk.bytes.length;
      if (bytesSeen == 0) {
        continue;
      }
      yield TranscriptionPreview(
        pendingText: '',
        status: TranscriptStatus.transcribing,
      );
    }
  }

  @override
  Future<void> dispose() async {}

  Future<LocalSenseVoiceModelFiles> _requireModelFiles() async {
    final files = await _modelResolver();
    if (files == null) {
      throw const TranscriptionException(
        code: TranscriptionFailureCode.modelMissing,
        message: 'Local SenseVoice model is not downloaded.',
      );
    }
    return files;
  }

  void _ensureBindings() {
    if (_bindingsInitialized) {
      return;
    }
    bindingsInitializer();
    _bindingsInitialized = true;
  }
}

String _senseVoiceLanguage(String language) {
  return switch (language) {
    'zh' => 'zh',
    'en' => 'en',
    _ => 'auto',
  };
}
