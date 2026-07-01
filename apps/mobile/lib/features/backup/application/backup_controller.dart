import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';
import '../../capture/application/capture_controller.dart';
import '../../memory/application/memory_controller.dart';
import '../../model_providers/application/model_provider_settings_controller.dart';
import '../../timeline/application/timeline_repository.dart';
import '../../todos/application/todo_controller.dart';

final backupServiceProvider = Provider<LocalBackupService>((ref) {
  return LocalBackupService(ref.watch(localDatabaseProvider));
});

final backupFileStoreProvider = Provider<BackupFileStore>((ref) {
  return AppSupportBackupFileStore(
    supportDirectory: ref.watch(appSupportDirectoryProvider),
  );
});

final backupControllerProvider =
    NotifierProvider<BackupController, BackupState>(BackupController.new);

enum BackupOutcome { idle, exported, savedFile, importReady, imported, failed }

final class BackupFileResult {
  const BackupFileResult({
    required this.archivePath,
    this.archiveSizeBytes = 0,
    this.destinationLabel,
  });

  final String archivePath;
  final int archiveSizeBytes;
  final String? destinationLabel;
}

abstract interface class BackupFileStore {
  Future<BackupFileResult> shareExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  });

  Future<BackupFileResult> saveExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  });

  Future<BackupImportPayload> readLatestBackup();

  Future<BackupImportPayload> readArchive(String archivePath);

  Future<BackupImportPayload> pickArchive();

  Future<void> restorePreparedMedia(BackupImportPayload payload);

  Future<void> discardPreparedImport(BackupImportPayload payload);
}

final class BackupImportPayload {
  const BackupImportPayload({
    required this.backup,
    required this.sourceLabel,
    this.stagingDirectory,
    this.mediaFiles = const <LocalBackupDirectoryArchiveExtractedFile>[],
  });

  final LocalDataBackup backup;
  final String sourceLabel;
  final String? stagingDirectory;
  final List<LocalBackupDirectoryArchiveExtractedFile> mediaFiles;
}

final class AppSupportBackupFileStore implements BackupFileStore {
  const AppSupportBackupFileStore({
    Directory? supportDirectory,
    BackupExportPlatform platform = const BackupExportPlatform(),
  }) : _supportDirectory = supportDirectory,
       _platform = platform;

  final Directory? _supportDirectory;
  final BackupExportPlatform _platform;

  @override
  Future<BackupFileResult> shareExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    final result = await _createExportArchive(
      backup: backup,
      createdAt: createdAt,
    );
    await _platform.shareBackup(
      path: result.archivePath,
      displayName: p.basename(result.archivePath),
    );
    return BackupFileResult(
      archivePath: result.archivePath,
      archiveSizeBytes: result.archiveSizeBytes,
      destinationLabel: 'system share sheet',
    );
  }

  @override
  Future<BackupFileResult> saveExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    final result = await _createExportArchive(
      backup: backup,
      createdAt: createdAt,
    );
    final destination = await _platform.saveBackup(
      path: result.archivePath,
      displayName: p.basename(result.archivePath),
    );
    return BackupFileResult(
      archivePath: result.archivePath,
      archiveSizeBytes: result.archiveSizeBytes,
      destinationLabel: destination,
    );
  }

  Future<BackupFileResult> _createExportArchive({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    final directory = await _exportsDirectory();
    final stagingDirectory = await _exportStagingDirectory();
    final stamp = _fileStamp(createdAt);
    final archivePath =
        '${directory.path}/widenote-backup-$stamp'
        '${LocalBackupArchiveCodec.fileExtension}';
    final mediaFiles = await _mediaFilesForBackup(backup);
    final databasePath = await _databasePath();
    try {
      final result = await Isolate.run(
        () => _writeBackupDirectoryArchive(
          _BackupDirectoryArchiveWriteJob(
            sourceDatabasePath: databasePath,
            stagingDirectory: stagingDirectory.path,
            outputPath: archivePath,
            createdAt: createdAt,
            localDbSchemaVersion: backup.manifest.localDbSchemaVersion,
            recordCounts: backup.manifest.recordCounts,
            mediaFiles: mediaFiles,
          ),
        ),
      );
      return BackupFileResult(
        archivePath: result.path,
        archiveSizeBytes: result.archiveSizeBytes,
      );
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  @override
  Future<BackupImportPayload> readLatestBackup() async {
    final directory = await _exportsDirectory();
    final files = _latestBackupFiles(directory);
    if (files.isEmpty) {
      throw const FileSystemException('No WideNote backup file found.');
    }
    return readArchive(files.first.path);
  }

  @override
  Future<BackupImportPayload> readArchive(String archivePath) async {
    final stagingDirectory = await _stagingDirectory();
    try {
      final result = await Isolate.run(
        () => _extractBackupDirectoryArchive(
          _BackupDirectoryArchiveReadJob(
            archivePath: archivePath,
            stagingDirectory: stagingDirectory.path,
          ),
        ),
      );
      final snapshot = WideNoteLocalDatabase.openPath(result.databasePath);
      try {
        final backup = LocalBackupService(
          snapshot,
        ).exportBackup(mode: LocalBackupMode.full);
        return BackupImportPayload(
          backup: backup,
          sourceLabel: archivePath,
          stagingDirectory: stagingDirectory.path,
          mediaFiles: result.mediaFiles,
        );
      } finally {
        snapshot.close();
      }
    } catch (_) {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  @override
  Future<BackupImportPayload> pickArchive() async {
    final path = await _platform.pickBackup();
    if (path == null || path.trim().isEmpty) {
      throw const FileSystemException('No WideNote backup file selected.');
    }
    return readArchive(path);
  }

  @override
  Future<void> restorePreparedMedia(BackupImportPayload payload) async {
    if (payload.mediaFiles.isEmpty) {
      return;
    }
    final documents = await getApplicationDocumentsDirectory();
    for (final mediaFile in payload.mediaFiles) {
      final relative = _captureMediaRelativePath(mediaFile.archivePath);
      final target = File(
        p.joinAll(<String>[
          documents.path,
          'capture_media',
          ...relative.split('/'),
        ]),
      );
      await target.parent.create(recursive: true);
      await File(mediaFile.path).copy(target.path);
    }
  }

  @override
  Future<void> discardPreparedImport(BackupImportPayload payload) async {
    final stagingDirectory = payload.stagingDirectory;
    if (stagingDirectory == null) {
      return;
    }
    final directory = Directory(stagingDirectory);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _exportsDirectory() async {
    final support = await _supportRoot();
    final directory = Directory('${support.path}/local-data/exports');
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _exportStagingDirectory() async {
    final support = await _supportRoot();
    return Directory(
      '${support.path}/local-data/tmp/backup-export-'
      '${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
  }

  Future<Directory> _stagingDirectory() async {
    final support = await _supportRoot();
    return Directory(
      '${support.path}/local-data/tmp/backup-import-'
      '${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
  }

  Future<Directory> _supportRoot() async {
    return _supportDirectory ?? getApplicationSupportDirectory();
  }

  Future<String> _databasePath() async {
    final support = await _supportRoot();
    return p.join(support.path, 'local-data', 'widenote.sqlite');
  }

  Future<List<_BackupDirectoryMediaFile>> _mediaFilesForBackup(
    LocalDataBackup backup,
  ) async {
    final result = <_BackupDirectoryMediaFile>[];
    for (final attachment in backup.attachments) {
      final relativePath = _relativeCaptureMediaStoragePath(
        attachment.storagePath,
      );
      if (relativePath == null) {
        continue;
      }
      final documents = await getApplicationDocumentsDirectory();
      final file = File(
        p.joinAll(<String>[
          documents.path,
          'capture_media',
          ...relativePath.split('/'),
        ]),
      );
      if (!await file.exists()) {
        throw FileSystemException(
          'Backup media file was not found.',
          file.path,
        );
      }
      result.add(
        _BackupDirectoryMediaFile(
          sourcePath: file.path,
          relativePath: 'media/capture_media/$relativePath',
        ),
      );
    }
    return result;
  }
}

final class BackupExportPlatform {
  const BackupExportPlatform();

  static const _methodChannel = MethodChannel('app.widenote/backup_export');

  Future<void> shareBackup({
    required String path,
    required String displayName,
  }) async {
    if (!_supportsPlatformExport) {
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>('shareBackup', <String, Object?>{
        'path': path,
        'displayName': displayName,
      });
    } on MissingPluginException {
      return;
    }
  }

  Future<String?> saveBackup({
    required String path,
    required String displayName,
  }) async {
    if (!_supportsPlatformExport) {
      return path;
    }
    try {
      return _methodChannel.invokeMethod<String>(
        'saveBackup',
        <String, Object?>{'path': path, 'displayName': displayName},
      );
    } on MissingPluginException {
      return path;
    }
  }

  Future<String?> pickBackup() async {
    if (!_supportsPlatformExport) {
      return null;
    }
    try {
      return _methodChannel.invokeMethod<String>('pickBackup');
    } on MissingPluginException {
      return null;
    }
  }
}

bool get _supportsPlatformExport => Platform.isAndroid || Platform.isIOS;

final class BackupState {
  const BackupState({
    this.exportedJson,
    this.exportedArchivePath,
    this.exportedArchiveSizeBytes,
    this.exportDestinationLabel,
    this.recordCounts = const <String, int>{},
    this.importDraft = '',
    this.preparedImport,
    this.importSourceLabel,
    this.lastImportReport,
    this.safeProviderSecretOmissionCount = 0,
    this.outcome = BackupOutcome.idle,
    this.errorDetails,
  });

  final String? exportedJson;
  final String? exportedArchivePath;
  final int? exportedArchiveSizeBytes;
  final String? exportDestinationLabel;
  final Map<String, int> recordCounts;
  final String importDraft;
  final BackupImportPayload? preparedImport;
  final String? importSourceLabel;
  final LocalBackupImportReport? lastImportReport;
  final int safeProviderSecretOmissionCount;
  final BackupOutcome outcome;
  final String? errorDetails;

  bool get canImport => preparedImport != null || importDraft.trim().isNotEmpty;

  BackupState copyWith({
    String? exportedJson,
    String? exportedArchivePath,
    int? exportedArchiveSizeBytes,
    String? exportDestinationLabel,
    Map<String, int>? recordCounts,
    String? importDraft,
    BackupImportPayload? preparedImport,
    String? importSourceLabel,
    LocalBackupImportReport? lastImportReport,
    int? safeProviderSecretOmissionCount,
    BackupOutcome? outcome,
    String? errorDetails,
    bool clearError = false,
    bool clearFilePaths = false,
    bool clearImportReport = false,
    bool clearImportSource = false,
    bool clearPreparedImport = false,
  }) {
    return BackupState(
      exportedJson: exportedJson ?? this.exportedJson,
      exportedArchivePath: clearFilePaths
          ? null
          : exportedArchivePath ?? this.exportedArchivePath,
      exportedArchiveSizeBytes: clearFilePaths
          ? null
          : exportedArchiveSizeBytes ?? this.exportedArchiveSizeBytes,
      exportDestinationLabel: clearFilePaths
          ? null
          : exportDestinationLabel ?? this.exportDestinationLabel,
      recordCounts: recordCounts ?? this.recordCounts,
      importDraft: importDraft ?? this.importDraft,
      preparedImport: clearPreparedImport
          ? null
          : preparedImport ?? this.preparedImport,
      importSourceLabel: clearImportSource
          ? null
          : importSourceLabel ?? this.importSourceLabel,
      lastImportReport: clearImportReport
          ? null
          : lastImportReport ?? this.lastImportReport,
      safeProviderSecretOmissionCount:
          safeProviderSecretOmissionCount ??
          this.safeProviderSecretOmissionCount,
      outcome: outcome ?? this.outcome,
      errorDetails: clearError ? null : errorDetails ?? this.errorDetails,
    );
  }
}

final class BackupController extends Notifier<BackupState> {
  @override
  BackupState build() {
    return const BackupState();
  }

  void updateImportDraft(String value) {
    state = state.copyWith(
      importDraft: value,
      outcome: BackupOutcome.idle,
      clearError: true,
      clearImportReport: true,
      clearImportSource: true,
      clearPreparedImport: true,
    );
  }

  void exportBackup() {
    try {
      final backup = ref
          .read(backupServiceProvider)
          .exportBackup(mode: LocalBackupMode.full);
      state = state.copyWith(
        exportedJson: 'directory-snapshot',
        exportedArchivePath: null,
        exportedArchiveSizeBytes: null,
        recordCounts: backup.manifest.recordCounts,
        safeProviderSecretOmissionCount: 0,
        outcome: BackupOutcome.exported,
        clearError: true,
        clearFilePaths: true,
        clearImportReport: true,
      );
    } catch (error) {
      state = state.copyWith(
        outcome: BackupOutcome.failed,
        errorDetails: _safeBackupError(error),
      );
    }
  }

  Future<void> saveExportedFiles() async {
    await _writeExport(useShareSheet: false);
  }

  Future<void> shareExportedFile() async {
    await _writeExport(useShareSheet: true);
  }

  Future<void> _writeExport({required bool useShareSheet}) async {
    try {
      if (state.exportedJson == null) {
        exportBackup();
      }
      final backup = ref
          .read(backupServiceProvider)
          .exportBackup(mode: LocalBackupMode.full);
      final store = ref.read(backupFileStoreProvider);
      final result = useShareSheet
          ? await store.shareExport(
              backup: backup,
              createdAt: DateTime.now().toUtc(),
            )
          : await store.saveExport(
              backup: backup,
              createdAt: DateTime.now().toUtc(),
            );
      state = state.copyWith(
        exportedArchivePath: result.archivePath,
        exportedArchiveSizeBytes: result.archiveSizeBytes,
        exportDestinationLabel: result.destinationLabel,
        outcome: BackupOutcome.savedFile,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        outcome: BackupOutcome.failed,
        errorDetails: _safeBackupError(error),
      );
    }
  }

  Future<bool> importBackup() async {
    BackupImportPayload? prepared;
    try {
      final store = ref.read(backupFileStoreProvider);
      prepared = state.preparedImport;
      if (prepared != null) {
        await store.restorePreparedMedia(prepared);
      }
      final report = prepared == null
          ? ref
                .read(backupServiceProvider)
                .importJson(
                  state.importDraft,
                  strategy: LocalBackupImportStrategy.replaceAll,
                )
          : ref
                .read(backupServiceProvider)
                .importBackup(
                  prepared.backup,
                  strategy: LocalBackupImportStrategy.replaceAll,
                );
      _refreshImportedData();
      state = state.copyWith(
        lastImportReport: report,
        outcome: BackupOutcome.imported,
        clearError: true,
        clearPreparedImport: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        outcome: BackupOutcome.failed,
        errorDetails: _safeBackupError(error),
      );
      return false;
    } finally {
      if (prepared != null) {
        await ref.read(backupFileStoreProvider).discardPreparedImport(prepared);
      }
    }
  }

  Future<bool> loadLatestSavedFileForImport() async {
    try {
      final payload = await ref
          .read(backupFileStoreProvider)
          .readLatestBackup();
      state = state.copyWith(
        importDraft: '',
        preparedImport: payload,
        importSourceLabel: payload.sourceLabel,
        outcome: BackupOutcome.importReady,
        clearImportReport: true,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        outcome: BackupOutcome.failed,
        errorDetails: _safeBackupError(error),
      );
      return false;
    }
  }

  Future<bool> pickArchiveForImport() async {
    try {
      final payload = await ref.read(backupFileStoreProvider).pickArchive();
      state = state.copyWith(
        importDraft: '',
        preparedImport: payload,
        importSourceLabel: payload.sourceLabel,
        outcome: BackupOutcome.importReady,
        clearImportReport: true,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        outcome: BackupOutcome.failed,
        errorDetails: _safeBackupError(error),
      );
      return false;
    }
  }

  Future<bool> loadArchivePathForImport(String archivePath) async {
    try {
      final payload = await ref
          .read(backupFileStoreProvider)
          .readArchive(archivePath);
      state = state.copyWith(
        importDraft: '',
        preparedImport: payload,
        importSourceLabel: payload.sourceLabel,
        outcome: BackupOutcome.importReady,
        clearImportReport: true,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        outcome: BackupOutcome.failed,
        errorDetails: _safeBackupError(error),
      );
      return false;
    }
  }

  void _refreshImportedData() {
    ref
      ..invalidate(captureControllerProvider)
      ..invalidate(timelineSnapshotProvider)
      ..invalidate(todoControllerProvider)
      ..invalidate(memoryControllerProvider)
      ..invalidate(modelProviderSettingsControllerProvider)
      ..invalidate(modelClientProvider)
      ..invalidate(chatModelClientProvider);
  }
}

String _safeBackupError(Object error) {
  return switch (error) {
    FormatException() => 'Invalid backup format.',
    UnsupportedError() => 'Unsupported backup version.',
    FileSystemException() => 'No saved backup file found.',
    StateError() => 'Backup conflicts with local data.',
    _ => 'Unexpected backup error.',
  };
}

String _fileStamp(DateTime value) {
  return value
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '-');
}

List<File> _latestBackupFiles(Directory directory) {
  final files =
      directory.listSync().whereType<File>().where((file) {
        return LocalBackupArchiveCodec.hasArchiveExtension(file.path);
      }).toList()..sort((a, b) {
        final time = b.lastModifiedSync().compareTo(a.lastModifiedSync());
        return time == 0 ? b.path.compareTo(a.path) : time;
      });
  return files;
}

final class _BackupDirectoryMediaFile {
  const _BackupDirectoryMediaFile({
    required this.sourcePath,
    required this.relativePath,
  });

  final String sourcePath;
  final String relativePath;
}

final class _BackupDirectoryArchiveWriteJob {
  const _BackupDirectoryArchiveWriteJob({
    required this.sourceDatabasePath,
    required this.stagingDirectory,
    required this.outputPath,
    required this.createdAt,
    required this.localDbSchemaVersion,
    required this.recordCounts,
    required this.mediaFiles,
  });

  final String sourceDatabasePath;
  final String stagingDirectory;
  final String outputPath;
  final DateTime createdAt;
  final int localDbSchemaVersion;
  final Map<String, int> recordCounts;
  final List<_BackupDirectoryMediaFile> mediaFiles;
}

final class _BackupDirectoryArchiveWriteResult {
  const _BackupDirectoryArchiveWriteResult({
    required this.path,
    required this.archiveSizeBytes,
  });

  final String path;
  final int archiveSizeBytes;
}

Future<_BackupDirectoryArchiveWriteResult> _writeBackupDirectoryArchive(
  _BackupDirectoryArchiveWriteJob job,
) async {
  final staging = Directory(job.stagingDirectory);
  if (await staging.exists()) {
    await staging.delete(recursive: true);
  }
  await staging.create(recursive: true);
  await LocalBackupDatabaseSnapshotter.writeFullSnapshot(
    sourceDatabasePath: job.sourceDatabasePath,
    outputDatabasePath: p.join(job.stagingDirectory, 'data', 'widenote.sqlite'),
  );
  for (final mediaFile in job.mediaFiles) {
    final target = File(
      p.joinAll(<String>[
        job.stagingDirectory,
        ...mediaFile.relativePath.split('/'),
      ]),
    );
    await target.parent.create(recursive: true);
    await File(mediaFile.sourcePath).copy(target.path);
  }
  final result = await LocalBackupDirectoryArchiveCodec.writeArchive(
    sourceDirectory: job.stagingDirectory,
    outputPath: job.outputPath,
    createdAt: job.createdAt,
    localDbSchemaVersion: job.localDbSchemaVersion,
    recordCounts: job.recordCounts,
    backupMode: LocalBackupMode.full,
    includesSecrets: true,
  );
  return _BackupDirectoryArchiveWriteResult(
    path: result.path,
    archiveSizeBytes: result.sizeBytes,
  );
}

final class _BackupDirectoryArchiveReadJob {
  const _BackupDirectoryArchiveReadJob({
    required this.archivePath,
    required this.stagingDirectory,
  });

  final String archivePath;
  final String stagingDirectory;
}

Future<LocalBackupDirectoryArchiveExtractResult> _extractBackupDirectoryArchive(
  _BackupDirectoryArchiveReadJob job,
) {
  return LocalBackupDirectoryArchiveCodec.extractToDirectory(
    archivePath: job.archivePath,
    stagingDirectory: job.stagingDirectory,
  );
}

String? _relativeCaptureMediaStoragePath(String storagePath) {
  const prefix = 'local://capture_media/';
  if (!storagePath.startsWith(prefix)) {
    return null;
  }
  final relative = storagePath.substring(prefix.length);
  final segments = relative.split('/');
  if (segments.isEmpty ||
      segments.any((segment) {
        return segment.isEmpty || segment == '.' || segment == '..';
      })) {
    return null;
  }
  return segments.join('/');
}

String _captureMediaRelativePath(String archivePath) {
  final prefix = LocalBackupDirectoryArchiveCodec.mediaPrefix;
  if (!archivePath.startsWith(prefix)) {
    throw FormatException(
      'Backup media path is outside capture media: $archivePath.',
    );
  }
  final relative = archivePath.substring(prefix.length);
  final segments = relative.split('/');
  if (segments.isEmpty ||
      segments.any((segment) {
        return segment.isEmpty || segment == '.' || segment == '..';
      })) {
    throw FormatException('Unsafe backup media path: $archivePath.');
  }
  return segments.join('/');
}
