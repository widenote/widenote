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
  return const AppSupportBackupFileStore();
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
    required String json,
    required String markdown,
    required DateTime createdAt,
  });

  Future<BackupFileResult> saveExport({
    required String json,
    required String markdown,
    required DateTime createdAt,
  });

  Future<String> readLatestJson();

  Future<String> readArchiveJson(String archivePath);

  Future<String> pickArchiveJson();
}

final class AppSupportBackupFileStore implements BackupFileStore {
  const AppSupportBackupFileStore({
    BackupExportPlatform platform = const BackupExportPlatform(),
  }) : _platform = platform;

  final BackupExportPlatform _platform;

  @override
  Future<BackupFileResult> shareExport({
    required String json,
    required String markdown,
    required DateTime createdAt,
  }) async {
    final result = await _createExportArchive(
      json: json,
      markdown: markdown,
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
    required String json,
    required String markdown,
    required DateTime createdAt,
  }) async {
    final result = await _createExportArchive(
      json: json,
      markdown: markdown,
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
    required String json,
    required String markdown,
    required DateTime createdAt,
  }) async {
    final directory = await _exportsDirectory();
    final stamp = _fileStamp(createdAt);
    final archivePath =
        '${directory.path}/widenote-backup-$stamp'
        '${LocalBackupArchiveCodec.fileExtension}';
    final backup = LocalBackupCodec.decode(json);
    final mediaFiles = await _mediaFilesForBackup(backup);
    final result = await Isolate.run(
      () => _writeBackupArchiveFromJson(
        _BackupArchiveWriteJob(
          json: json,
          markdown: markdown,
          outputPath: archivePath,
          mediaFiles: mediaFiles,
        ),
      ),
    );
    return BackupFileResult(
      archivePath: result.path,
      archiveSizeBytes: result.archiveSizeBytes,
    );
  }

  @override
  Future<String> readLatestJson() async {
    final directory = await _exportsDirectory();
    final files = _latestBackupFiles(directory);
    if (files.isEmpty) {
      throw const FileSystemException('No WideNote backup file found.');
    }
    final latest = files.first;
    if (LocalBackupArchiveCodec.hasArchiveExtension(latest.path)) {
      return readArchiveJson(latest.path);
    }
    return latest.readAsString();
  }

  @override
  Future<String> readArchiveJson(String archivePath) async {
    final stagingDirectory = await _stagingDirectory();
    try {
      final result = await Isolate.run(
        () => _extractRestoreJsonFromArchive(
          _BackupArchiveReadJob(
            archivePath: archivePath,
            stagingDirectory: stagingDirectory.path,
          ),
        ),
      );
      final json = await File(result.restoreJsonPath).readAsString();
      if (result.mediaFiles.isEmpty) {
        return json;
      }
      final backup = LocalBackupCodec.decode(json);
      final restored = await _backupWithRestoredMediaRefs(
        backup,
        result.mediaFiles,
      );
      return LocalBackupCodec.encode(restored);
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  @override
  Future<String> pickArchiveJson() async {
    final path = await _platform.pickBackup();
    if (path == null || path.trim().isEmpty) {
      throw const FileSystemException('No WideNote backup file selected.');
    }
    return readArchiveJson(path);
  }

  Future<Directory> _exportsDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/local-data/exports');
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _stagingDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}/local-data/tmp/backup-import-'
      '${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
  }

  Future<List<LocalBackupArchiveMediaFile>> _mediaFilesForBackup(
    LocalDataBackup backup,
  ) async {
    final result = <LocalBackupArchiveMediaFile>[];
    for (final attachment in backup.attachments) {
      final file = await _fileForAttachmentStoragePath(attachment.storagePath);
      if (file == null) {
        continue;
      }
      if (!await file.exists()) {
        throw FileSystemException(
          'Backup media file was not found.',
          file.path,
        );
      }
      result.add(
        LocalBackupArchiveMediaFile(
          originalStoragePath: attachment.storagePath,
          sourcePath: file.path,
          archivePath: _archiveMediaPathForAttachment(attachment, file),
        ),
      );
    }
    return result;
  }

  Future<File?> _fileForAttachmentStoragePath(String storagePath) async {
    if (storagePath.startsWith('local://capture_media/')) {
      final documents = await getApplicationDocumentsDirectory();
      final relative = storagePath.substring('local://capture_media/'.length);
      final segments = relative
          .split('/')
          .where((segment) {
            return segment.isNotEmpty && segment != '.' && segment != '..';
          })
          .toList(growable: false);
      if (segments.isEmpty) {
        return null;
      }
      return File(
        p.joinAll(<String>[documents.path, 'capture_media', ...segments]),
      );
    }
    final file = File(storagePath);
    if (file.isAbsolute && await file.exists()) {
      return file;
    }
    return null;
  }

  String _archiveMediaPathForAttachment(
    AttachmentRecord attachment,
    File file,
  ) {
    final basename = _safeFileName(
      attachment.originalFileName?.trim().isNotEmpty == true
          ? attachment.originalFileName!
          : p.basename(file.path),
    );
    return '${LocalBackupArchiveCodec.rootDirectory}/media/originals/'
        '${_safeFileName(attachment.id)}-$basename';
  }

  Future<LocalDataBackup> _backupWithRestoredMediaRefs(
    LocalDataBackup backup,
    List<LocalBackupArchiveExtractedFile> mediaFiles,
  ) async {
    final restoredByArchivePath = <String, _RestoredMediaRef>{};
    for (final mediaFile in mediaFiles) {
      final restored = await _restoreExtractedMedia(mediaFile);
      restoredByArchivePath[mediaFile.archivePath] = restored;
    }
    return LocalDataBackup(
      manifest: backup.manifest,
      eventLog: backup.eventLog,
      captures: backup.captures,
      attachments: [
        for (final attachment in backup.attachments)
          if (restoredByArchivePath.containsKey(attachment.storagePath))
            attachment.copyWith(
              storagePath:
                  restoredByArchivePath[attachment.storagePath]!.storageRef,
              payload: _payloadWithRestoredMediaRef(
                attachment.payload,
                restoredByArchivePath[attachment.storagePath]!,
              ),
            )
          else
            attachment,
      ],
      derivedArtifacts: backup.derivedArtifacts,
      memoryItems: backup.memoryItems,
      memoryCandidates: backup.memoryCandidates,
      cards: backup.cards,
      insights: backup.insights,
      chatSessions: backup.chatSessions,
      chatMessages: backup.chatMessages,
      modelProviderConfigs: backup.modelProviderConfigs,
      todos: backup.todos,
      runtimeTasks: backup.runtimeTasks,
      runtimeRuns: backup.runtimeRuns,
      packInstallations: backup.packInstallations,
      permissionGrants: backup.permissionGrants,
      contextPacketCaches: backup.contextPacketCaches,
      traceEvents: backup.traceEvents,
    );
  }

  Future<_RestoredMediaRef> _restoreExtractedMedia(
    LocalBackupArchiveExtractedFile mediaFile,
  ) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'capture_media', 'restored'),
    );
    await directory.create(recursive: true);
    final basename = _safeFileName(p.basename(mediaFile.path));
    final target = File(
      p.join(
        directory.path,
        '${DateTime.now().microsecondsSinceEpoch}-$basename',
      ),
    );
    await File(mediaFile.path).copy(target.path);
    return _RestoredMediaRef(
      storageRef: 'local://capture_media/restored/${p.basename(target.path)}',
      localPath: target.path,
    );
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

final class _RestoredMediaRef {
  const _RestoredMediaRef({required this.storageRef, required this.localPath});

  final String storageRef;
  final String localPath;
}

final class BackupState {
  const BackupState({
    this.exportedJson,
    this.exportedMarkdown,
    this.exportedArchivePath,
    this.exportedArchiveSizeBytes,
    this.exportDestinationLabel,
    this.recordCounts = const <String, int>{},
    this.importDraft = '',
    this.importSourceLabel,
    this.lastImportReport,
    this.safeProviderSecretOmissionCount = 0,
    this.outcome = BackupOutcome.idle,
    this.errorDetails,
  });

  final String? exportedJson;
  final String? exportedMarkdown;
  final String? exportedArchivePath;
  final int? exportedArchiveSizeBytes;
  final String? exportDestinationLabel;
  final Map<String, int> recordCounts;
  final String importDraft;
  final String? importSourceLabel;
  final LocalBackupImportReport? lastImportReport;
  final int safeProviderSecretOmissionCount;
  final BackupOutcome outcome;
  final String? errorDetails;

  bool get canImport => importDraft.trim().isNotEmpty;

  BackupState copyWith({
    String? exportedJson,
    String? exportedMarkdown,
    String? exportedArchivePath,
    int? exportedArchiveSizeBytes,
    String? exportDestinationLabel,
    Map<String, int>? recordCounts,
    String? importDraft,
    String? importSourceLabel,
    LocalBackupImportReport? lastImportReport,
    int? safeProviderSecretOmissionCount,
    BackupOutcome? outcome,
    String? errorDetails,
    bool clearError = false,
    bool clearFilePaths = false,
    bool clearImportReport = false,
    bool clearImportSource = false,
  }) {
    return BackupState(
      exportedJson: exportedJson ?? this.exportedJson,
      exportedMarkdown: exportedMarkdown ?? this.exportedMarkdown,
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
    );
  }

  void exportBackup() {
    try {
      final backup = ref.read(backupServiceProvider).exportBackup();
      state = state.copyWith(
        exportedJson: LocalBackupCodec.encode(backup),
        exportedMarkdown: const LocalMarkdownExportService().exportBackup(
          backup,
        ),
        exportedArchivePath: null,
        exportedArchiveSizeBytes: null,
        recordCounts: backup.manifest.recordCounts,
        safeProviderSecretOmissionCount:
            backup.providerConfigsNeedingCredentialReentry.length,
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
      if (state.exportedJson == null || state.exportedMarkdown == null) {
        exportBackup();
      }
      final store = ref.read(backupFileStoreProvider);
      final result = useShareSheet
          ? await store.shareExport(
              json: state.exportedJson!,
              markdown: state.exportedMarkdown!,
              createdAt: DateTime.now().toUtc(),
            )
          : await store.saveExport(
              json: state.exportedJson!,
              markdown: state.exportedMarkdown!,
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

  bool importBackup() {
    try {
      final report = ref
          .read(backupServiceProvider)
          .importJson(
            state.importDraft,
            strategy: LocalBackupImportStrategy.replaceAll,
          );
      _refreshImportedData();
      state = state.copyWith(
        lastImportReport: report,
        outcome: BackupOutcome.imported,
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

  Future<bool> loadLatestSavedFileForImport() async {
    try {
      final json = await ref.read(backupFileStoreProvider).readLatestJson();
      state = state.copyWith(
        importDraft: json,
        importSourceLabel: 'latest local backup file',
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
      final json = await ref.read(backupFileStoreProvider).pickArchiveJson();
      state = state.copyWith(
        importDraft: json,
        importSourceLabel: 'selected .widenote file',
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
      final json = await ref
          .read(backupFileStoreProvider)
          .readArchiveJson(archivePath);
      state = state.copyWith(
        importDraft: json,
        importSourceLabel: archivePath,
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

JsonMap _payloadWithRestoredMediaRef(
  JsonMap payload,
  _RestoredMediaRef restored,
) {
  final rawMetadata = payload['raw_metadata'];
  if (rawMetadata is! Map) {
    return <String, Object?>{
      ...payload,
      'restored_local_path': restored.localPath,
      'restored_storage_ref': restored.storageRef,
    };
  }
  final raw = rawMetadata.cast<String, Object?>();
  final adapterMetadata = raw['adapter_metadata'];
  final updatedRaw = <String, Object?>{
    ...raw,
    'local_path': restored.localPath,
    'storage_ref': restored.storageRef,
    'restored_storage_ref': restored.storageRef,
  };
  if (adapterMetadata is Map) {
    updatedRaw['adapter_metadata'] = <String, Object?>{
      ...adapterMetadata.cast<String, Object?>(),
      'local_path': restored.localPath,
      'storage_ref': restored.storageRef,
      'restored_storage_ref': restored.storageRef,
    };
  }
  return <String, Object?>{
    ...payload,
    'restored_local_path': restored.localPath,
    'restored_storage_ref': restored.storageRef,
    'raw_metadata': updatedRaw,
  };
}

String _safeFileName(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  return sanitized.isEmpty ? 'backup-media' : sanitized;
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
        return LocalBackupArchiveCodec.hasArchiveExtension(file.path) ||
            file.path.endsWith('.json');
      }).toList()..sort((a, b) {
        final time = b.lastModifiedSync().compareTo(a.lastModifiedSync());
        return time == 0 ? b.path.compareTo(a.path) : time;
      });
  return files;
}

final class _BackupArchiveWriteJob {
  const _BackupArchiveWriteJob({
    required this.json,
    required this.markdown,
    required this.outputPath,
    required this.mediaFiles,
  });

  final String json;
  final String markdown;
  final String outputPath;
  final List<LocalBackupArchiveMediaFile> mediaFiles;
}

final class _BackupArchiveWriteResult {
  const _BackupArchiveWriteResult({
    required this.path,
    required this.archiveSizeBytes,
  });

  final String path;
  final int archiveSizeBytes;
}

Future<_BackupArchiveWriteResult> _writeBackupArchiveFromJson(
  _BackupArchiveWriteJob job,
) async {
  final backup = LocalBackupCodec.decode(job.json);
  final result = await LocalBackupArchiveCodec.writeArchive(
    backup: backup,
    ownerMarkdown: job.markdown,
    outputPath: job.outputPath,
    mediaFiles: job.mediaFiles,
  );
  return _BackupArchiveWriteResult(
    path: result.path,
    archiveSizeBytes: result.sizeBytes,
  );
}

final class _BackupArchiveReadJob {
  const _BackupArchiveReadJob({
    required this.archivePath,
    required this.stagingDirectory,
  });

  final String archivePath;
  final String stagingDirectory;
}

Future<LocalBackupArchiveExtractResult> _extractRestoreJsonFromArchive(
  _BackupArchiveReadJob job,
) {
  return LocalBackupArchiveCodec.extractToDirectory(
    archivePath: job.archivePath,
    stagingDirectory: job.stagingDirectory,
  );
}
