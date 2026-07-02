import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'transcription_settings.dart';

const String defaultSenseVoiceModelDirectory =
    'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17';

const String defaultSenseVoiceHfMirrorBaseUrl =
    'https://hf-mirror.com/csukuangfj/'
    'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main';

const List<TranscriptionModelDownloadFile> defaultSenseVoiceDownloadFiles =
    <TranscriptionModelDownloadFile>[
      TranscriptionModelDownloadFile(
        url: '$defaultSenseVoiceHfMirrorBaseUrl/model.int8.onnx',
        relativePath: '$defaultSenseVoiceModelDirectory/model.int8.onnx',
        expectedMinBytes: 200 * 1024 * 1024,
      ),
      TranscriptionModelDownloadFile(
        url: '$defaultSenseVoiceHfMirrorBaseUrl/tokens.txt',
        relativePath: '$defaultSenseVoiceModelDirectory/tokens.txt',
        expectedMinBytes: 250 * 1024,
      ),
    ];

final class TranscriptionModelDownloadFile {
  const TranscriptionModelDownloadFile({
    required this.url,
    required this.relativePath,
    this.expectedMinBytes,
  });

  final String url;
  final String relativePath;
  final int? expectedMinBytes;
}

abstract interface class TranscriptionModelFileDownloader {
  Future<void> download({
    required Uri url,
    required File destination,
    required FutureOr<void> Function(int receivedBytes, int? totalBytes)
    onProgress,
  });
}

final class DartIoTranscriptionModelFileDownloader
    implements TranscriptionModelFileDownloader {
  const DartIoTranscriptionModelFileDownloader();

  @override
  Future<void> download({
    required Uri url,
    required File destination,
    required FutureOr<void> Function(int receivedBytes, int? totalBytes)
    onProgress,
  }) async {
    final client = HttpClient();
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download failed with HTTP ${response.statusCode}.',
          uri: url,
        );
      }
      await destination.parent.create(recursive: true);
      sink = destination.openWrite();
      var received = 0;
      final total = response.contentLength > 0 ? response.contentLength : null;
      await for (final bytes in response) {
        received += bytes.length;
        sink.add(bytes);
        await onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }
}

final class TranscriptionModelDownloadSnapshot {
  const TranscriptionModelDownloadSnapshot({
    required this.state,
    this.progress = 0,
    this.errorCode,
    this.errorMessage,
  });

  final LocalTranscriptionModelState state;
  final int progress;
  final String? errorCode;
  final String? errorMessage;
}

abstract interface class TranscriptionModelDownloadController {
  Future<TranscriptionModelDownloadSnapshot> downloadDefaultModel({
    FutureOr<void> Function(TranscriptionModelDownloadSnapshot snapshot)?
    onProgress,
  });

  Future<void> deleteModel();
}

final class TranscriptionDownloadManager
    implements TranscriptionModelDownloadController {
  TranscriptionDownloadManager({
    required Directory supportDirectory,
    required VoiceTranscriptionSettingsRepository settingsRepository,
    TranscriptionModelFileDownloader downloader =
        const DartIoTranscriptionModelFileDownloader(),
    List<TranscriptionModelDownloadFile> files = defaultSenseVoiceDownloadFiles,
  }) : _supportDirectory = supportDirectory,
       _settingsRepository = settingsRepository,
       _downloader = downloader,
       _files = files;

  final Directory _supportDirectory;
  final VoiceTranscriptionSettingsRepository _settingsRepository;
  final TranscriptionModelFileDownloader _downloader;
  final List<TranscriptionModelDownloadFile> _files;

  Directory get modelRoot {
    return Directory(
      p.join(_supportDirectory.path, 'local-data', 'models', 'sensevoice'),
    );
  }

  Future<TranscriptionModelDownloadSnapshot> check() async {
    final settings = await _settingsRepository.load();
    final manifest = File(p.join(modelRoot.path, 'manifest.json'));
    final readyMarker = File(p.join(modelRoot.path, 'READY'));
    if (readyMarker.existsSync() && manifest.existsSync()) {
      await _settingsRepository.save(
        settings.copyWith(
          localModelState: LocalTranscriptionModelState.ready,
          downloadProgress: 100,
          clearError: true,
        ),
      );
      return const TranscriptionModelDownloadSnapshot(
        state: LocalTranscriptionModelState.ready,
        progress: 100,
      );
    }
    if (Directory('${modelRoot.path}.part').existsSync()) {
      await _settingsRepository.save(
        settings.copyWith(
          localModelState: LocalTranscriptionModelState.pausedOrInterrupted,
        ),
      );
      return const TranscriptionModelDownloadSnapshot(
        state: LocalTranscriptionModelState.pausedOrInterrupted,
      );
    }
    return TranscriptionModelDownloadSnapshot(
      state: settings.localModelState,
      progress: settings.downloadProgress,
      errorCode: settings.lastErrorCode,
      errorMessage: settings.lastErrorMessage,
    );
  }

  Future<void> markDownloadStarted() async {
    final settings = await _settingsRepository.load();
    await Directory('${modelRoot.path}.part').create(recursive: true);
    await _settingsRepository.save(
      settings.copyWith(
        localModelState: LocalTranscriptionModelState.downloading,
        downloadProgress: 0,
        clearError: true,
      ),
    );
  }

  @override
  Future<TranscriptionModelDownloadSnapshot> downloadDefaultModel({
    FutureOr<void> Function(TranscriptionModelDownloadSnapshot snapshot)?
    onProgress,
  }) async {
    final settings = await _settingsRepository.load();
    final part = Directory('${modelRoot.path}.part');
    if (part.existsSync()) {
      await part.delete(recursive: true);
    }
    await part.create(recursive: true);
    await _settingsRepository.save(
      settings.copyWith(
        localModelState: LocalTranscriptionModelState.downloading,
        downloadProgress: 0,
        clearError: true,
      ),
    );
    await _notifyProgress(
      onProgress,
      const TranscriptionModelDownloadSnapshot(
        state: LocalTranscriptionModelState.downloading,
      ),
    );

    try {
      for (var index = 0; index < _files.length; index += 1) {
        final file = _files[index];
        final destination = File(p.join(part.path, file.relativePath));
        await _downloader.download(
          url: Uri.parse(file.url),
          destination: destination,
          onProgress: (received, total) async {
            final snapshot = await _saveDownloadProgress(
              index,
              received,
              total,
            );
            if (snapshot != null) {
              await _notifyProgress(onProgress, snapshot);
            }
          },
        );
      }
      await _verifyPart(part);
      final verifying = await _settingsRepository.load();
      await _settingsRepository.save(
        verifying.copyWith(
          localModelState: LocalTranscriptionModelState.verifying,
          downloadProgress: 99,
        ),
      );
      await _notifyProgress(
        onProgress,
        const TranscriptionModelDownloadSnapshot(
          state: LocalTranscriptionModelState.verifying,
          progress: 99,
        ),
      );
      if (modelRoot.existsSync()) {
        await modelRoot.delete(recursive: true);
      }
      await part.rename(modelRoot.path);
      await File(p.join(modelRoot.path, 'manifest.json')).writeAsString(
        '{"model":"$defaultSenseVoiceModelDirectory","source":"hf-mirror"}',
      );
      await File(p.join(modelRoot.path, 'READY')).writeAsString('ready');
      final ready = await _settingsRepository.load();
      await _settingsRepository.save(
        ready.copyWith(
          localModelState: LocalTranscriptionModelState.ready,
          downloadProgress: 100,
          clearError: true,
        ),
      );
      const snapshot = TranscriptionModelDownloadSnapshot(
        state: LocalTranscriptionModelState.ready,
        progress: 100,
      );
      await _notifyProgress(onProgress, snapshot);
      return snapshot;
    } on Object catch (error) {
      final failed = await _settingsRepository.load();
      final errorMessage = _safeDownloadError(error);
      await _settingsRepository.save(
        failed.copyWith(
          localModelState: LocalTranscriptionModelState.failed,
          lastErrorCode: 'model_download_failed',
          lastErrorMessage: errorMessage,
        ),
      );
      final snapshot = TranscriptionModelDownloadSnapshot(
        state: LocalTranscriptionModelState.failed,
        progress: failed.downloadProgress,
        errorCode: 'model_download_failed',
        errorMessage: errorMessage,
      );
      await _notifyProgress(onProgress, snapshot);
      return snapshot;
    }
  }

  Future<void> markReadyForTests() async {
    final settings = await _settingsRepository.load();
    await modelRoot.create(recursive: true);
    await File(p.join(modelRoot.path, 'manifest.json')).writeAsString('{}');
    await File(p.join(modelRoot.path, 'READY')).writeAsString('ready');
    await _settingsRepository.save(
      settings.copyWith(
        localModelState: LocalTranscriptionModelState.ready,
        downloadProgress: 100,
        clearError: true,
      ),
    );
  }

  Future<void> markFailed(String code, String message) async {
    final settings = await _settingsRepository.load();
    await _settingsRepository.save(
      settings.copyWith(
        localModelState: LocalTranscriptionModelState.failed,
        lastErrorCode: code,
        lastErrorMessage: message,
      ),
    );
  }

  @override
  Future<void> deleteModel() async {
    final settings = await _settingsRepository.load();
    await _settingsRepository.save(
      settings.copyWith(localModelState: LocalTranscriptionModelState.deleting),
    );
    if (modelRoot.existsSync()) {
      await modelRoot.delete(recursive: true);
    }
    final part = Directory('${modelRoot.path}.part');
    if (part.existsSync()) {
      await part.delete(recursive: true);
    }
    await _settingsRepository.save(
      settings.copyWith(
        localModelState: LocalTranscriptionModelState.notDownloaded,
        downloadProgress: 0,
        clearError: true,
      ),
    );
  }

  Future<TranscriptionModelDownloadSnapshot?> _saveDownloadProgress(
    int fileIndex,
    int received,
    int? total,
  ) async {
    final settings = await _settingsRepository.load();
    final fileShare = 100 / _files.length;
    final fileProgress = total == null || total <= 0
        ? 0
        : (received / total).clamp(0, 1);
    final progress = (fileIndex * fileShare + fileProgress * fileShare)
        .floor()
        .clamp(0, 98);
    if (settings.localModelState == LocalTranscriptionModelState.downloading &&
        settings.downloadProgress == progress &&
        settings.lastErrorCode == null &&
        settings.lastErrorMessage == null) {
      return null;
    }
    await _settingsRepository.save(
      settings.copyWith(
        localModelState: LocalTranscriptionModelState.downloading,
        downloadProgress: progress,
        clearError: true,
      ),
    );
    return TranscriptionModelDownloadSnapshot(
      state: LocalTranscriptionModelState.downloading,
      progress: progress,
    );
  }

  Future<void> _verifyPart(Directory part) async {
    for (final file in _files) {
      final downloaded = File(p.join(part.path, file.relativePath));
      if (!downloaded.existsSync() || downloaded.lengthSync() == 0) {
        throw FileSystemException('Downloaded model file is missing.');
      }
      final expectedMinBytes = file.expectedMinBytes;
      if (expectedMinBytes != null &&
          downloaded.lengthSync() < expectedMinBytes) {
        throw FileSystemException('Downloaded model file is incomplete.');
      }
    }
  }
}

Future<void> _notifyProgress(
  FutureOr<void> Function(TranscriptionModelDownloadSnapshot snapshot)?
  onProgress,
  TranscriptionModelDownloadSnapshot snapshot,
) async {
  if (onProgress == null) {
    return;
  }
  await onProgress(snapshot);
}

String _safeDownloadError(Object error) {
  final text = error.toString();
  return text.length <= 180 ? text : '${text.substring(0, 180)}...';
}
