import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_mobile/features/transcription/transcription_download_manager.dart';
import 'package:widenote_mobile/features/transcription/transcription_settings.dart';

void main() {
  test('default SenseVoice URLs use the reachable MemeX mirror', () {
    expect(
      defaultSenseVoiceHfMirrorBaseUrl,
      'https://hf-mirror.com/csukuangfj/'
      'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main',
    );
    expect(defaultSenseVoiceDownloadFiles.map((file) => file.url), <String>[
      '$defaultSenseVoiceHfMirrorBaseUrl/model.int8.onnx',
      '$defaultSenseVoiceHfMirrorBaseUrl/tokens.txt',
    ]);
    expect(
      defaultSenseVoiceDownloadFiles
          .map((file) => file.expectedMinBytes)
          .toList(),
      <int?>[200 * 1024 * 1024, 250 * 1024],
    );
  });

  test('download manager reports interrupted partial downloads', () async {
    final temp = await Directory.systemTemp.createTemp(
      'widenote-transcription-download-',
    );
    addTearDown(() async {
      if (temp.existsSync()) {
        await temp.delete(recursive: true);
      }
    });
    final repository = MemoryVoiceTranscriptionSettingsRepository();
    final manager = TranscriptionDownloadManager(
      supportDirectory: temp,
      settingsRepository: repository,
    );

    await manager.markDownloadStarted();
    var settings = await repository.load();
    expect(settings.localModelState, LocalTranscriptionModelState.downloading);
    expect(Directory('${manager.modelRoot.path}.part').existsSync(), isTrue);

    final snapshot = await manager.check();

    expect(snapshot.state, LocalTranscriptionModelState.pausedOrInterrupted);
    settings = await repository.load();
    expect(
      settings.localModelState,
      LocalTranscriptionModelState.pausedOrInterrupted,
    );
  });

  test(
    'download manager promotes ready marker and deletes all model state',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'widenote-transcription-ready-',
      );
      addTearDown(() async {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      });
      final repository = MemoryVoiceTranscriptionSettingsRepository();
      final manager = TranscriptionDownloadManager(
        supportDirectory: temp,
        settingsRepository: repository,
      );

      await manager.markReadyForTests();
      final ready = await manager.check();

      expect(ready.state, LocalTranscriptionModelState.ready);
      expect(ready.progress, 100);

      await manager.markDownloadStarted();
      await manager.deleteModel();

      final settings = await repository.load();
      expect(
        settings.localModelState,
        LocalTranscriptionModelState.notDownloaded,
      );
      expect(settings.downloadProgress, 0);
      expect(manager.modelRoot.existsSync(), isFalse);
      expect(Directory('${manager.modelRoot.path}.part').existsSync(), isFalse);
    },
  );

  test('download manager downloads files through a .part directory', () async {
    final temp = await Directory.systemTemp.createTemp(
      'widenote-transcription-download-success-',
    );
    addTearDown(() async {
      if (temp.existsSync()) {
        await temp.delete(recursive: true);
      }
    });
    final repository = MemoryVoiceTranscriptionSettingsRepository();
    final manager = TranscriptionDownloadManager(
      supportDirectory: temp,
      settingsRepository: repository,
      downloader: const _FakeModelDownloader(),
      files: const <TranscriptionModelDownloadFile>[
        TranscriptionModelDownloadFile(
          url: 'https://example.invalid/model.int8.onnx',
          relativePath: '$defaultSenseVoiceModelDirectory/model.int8.onnx',
        ),
        TranscriptionModelDownloadFile(
          url: 'https://example.invalid/tokens.txt',
          relativePath: '$defaultSenseVoiceModelDirectory/tokens.txt',
        ),
      ],
    );

    final snapshot = await manager.downloadDefaultModel();

    expect(snapshot.state, LocalTranscriptionModelState.ready);
    expect(snapshot.progress, 100);
    final settings = await repository.load();
    expect(settings.localModelState, LocalTranscriptionModelState.ready);
    expect(settings.downloadProgress, 100);
    expect(File('${manager.modelRoot.path}/READY').existsSync(), isTrue);
    expect(
      File(
        '${manager.modelRoot.path}/$defaultSenseVoiceModelDirectory/model.int8.onnx',
      ).existsSync(),
      isTrue,
    );
    expect(Directory('${manager.modelRoot.path}.part').existsSync(), isFalse);
  });

  test('download failure preserves partial state for safe retry', () async {
    final temp = await Directory.systemTemp.createTemp(
      'widenote-transcription-download-failure-',
    );
    addTearDown(() async {
      if (temp.existsSync()) {
        await temp.delete(recursive: true);
      }
    });
    final repository = MemoryVoiceTranscriptionSettingsRepository();
    final manager = TranscriptionDownloadManager(
      supportDirectory: temp,
      settingsRepository: repository,
      downloader: const _FailingModelDownloader(),
    );

    final failed = await manager.downloadDefaultModel();

    expect(failed.state, LocalTranscriptionModelState.failed);
    expect(failed.errorCode, 'model_download_failed');
    expect(Directory('${manager.modelRoot.path}.part').existsSync(), isTrue);
    var settings = await repository.load();
    expect(settings.localModelState, LocalTranscriptionModelState.failed);
    expect(settings.lastErrorCode, 'model_download_failed');

    final interrupted = await manager.check();

    expect(interrupted.state, LocalTranscriptionModelState.pausedOrInterrupted);
    settings = await repository.load();
    expect(
      settings.localModelState,
      LocalTranscriptionModelState.pausedOrInterrupted,
    );
  });

  test('download manager persists safe failure details', () async {
    final temp = await Directory.systemTemp.createTemp(
      'widenote-transcription-failed-',
    );
    addTearDown(() async {
      if (temp.existsSync()) {
        await temp.delete(recursive: true);
      }
    });
    final repository = MemoryVoiceTranscriptionSettingsRepository();
    final manager = TranscriptionDownloadManager(
      supportDirectory: temp,
      settingsRepository: repository,
    );

    await manager.markFailed('network_timeout', 'Download timed out.');
    final snapshot = await manager.check();

    expect(snapshot.state, LocalTranscriptionModelState.failed);
    expect(snapshot.errorCode, 'network_timeout');
    expect(snapshot.errorMessage, 'Download timed out.');
  });
}

final class _FakeModelDownloader implements TranscriptionModelFileDownloader {
  const _FakeModelDownloader();

  @override
  Future<void> download({
    required Uri url,
    required File destination,
    required FutureOr<void> Function(int receivedBytes, int? totalBytes)
    onProgress,
  }) async {
    await destination.parent.create(recursive: true);
    await destination.writeAsString('fake model file from $url');
    await onProgress(32, 32);
  }
}

final class _FailingModelDownloader
    implements TranscriptionModelFileDownloader {
  const _FailingModelDownloader();

  @override
  Future<void> download({
    required Uri url,
    required File destination,
    required FutureOr<void> Function(int receivedBytes, int? totalBytes)
    onProgress,
  }) async {
    await destination.parent.create(recursive: true);
    await destination.writeAsString('partial');
    await onProgress(7, 32);
    throw const SocketException('connection reset');
  }
}
