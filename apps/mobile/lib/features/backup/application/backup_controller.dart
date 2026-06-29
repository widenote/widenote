import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

enum BackupOutcome { idle, exported, savedFile, imported, failed }

final class BackupFileResult {
  const BackupFileResult({
    required this.archivePath,
    this.archiveSizeBytes = 0,
  });

  final String archivePath;
  final int archiveSizeBytes;
}

abstract interface class BackupFileStore {
  Future<BackupFileResult> saveExport({
    required String json,
    required String markdown,
    required DateTime createdAt,
  });

  Future<String> readLatestJson();

  Future<String> readArchiveJson(String archivePath);
}

final class AppSupportBackupFileStore implements BackupFileStore {
  const AppSupportBackupFileStore();

  @override
  Future<BackupFileResult> saveExport({
    required String json,
    required String markdown,
    required DateTime createdAt,
  }) async {
    final directory = await _exportsDirectory();
    final stamp = _fileStamp(createdAt);
    final archivePath =
        '${directory.path}/widenote-backup-$stamp'
        '${LocalBackupArchiveCodec.fileExtension}';
    final result = await Isolate.run(
      () => _writeBackupArchiveFromJson(
        _BackupArchiveWriteJob(
          json: json,
          markdown: markdown,
          outputPath: archivePath,
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
      return Isolate.run(
        () => _extractRestoreJsonFromArchive(
          _BackupArchiveReadJob(
            archivePath: archivePath,
            stagingDirectory: stagingDirectory.path,
          ),
        ),
      );
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
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
}

final class BackupState {
  const BackupState({
    this.exportedJson,
    this.exportedMarkdown,
    this.exportedArchivePath,
    this.exportedArchiveSizeBytes,
    this.recordCounts = const <String, int>{},
    this.importDraft = '',
    this.lastImportReport,
    this.safeProviderSecretOmissionCount = 0,
    this.outcome = BackupOutcome.idle,
    this.errorDetails,
  });

  final String? exportedJson;
  final String? exportedMarkdown;
  final String? exportedArchivePath;
  final int? exportedArchiveSizeBytes;
  final Map<String, int> recordCounts;
  final String importDraft;
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
    Map<String, int>? recordCounts,
    String? importDraft,
    LocalBackupImportReport? lastImportReport,
    int? safeProviderSecretOmissionCount,
    BackupOutcome? outcome,
    String? errorDetails,
    bool clearError = false,
    bool clearFilePaths = false,
    bool clearImportReport = false,
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
      recordCounts: recordCounts ?? this.recordCounts,
      importDraft: importDraft ?? this.importDraft,
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
    try {
      if (state.exportedJson == null || state.exportedMarkdown == null) {
        exportBackup();
      }
      final result = await ref
          .read(backupFileStoreProvider)
          .saveExport(
            json: state.exportedJson!,
            markdown: state.exportedMarkdown!,
            createdAt: DateTime.now().toUtc(),
          );
      state = state.copyWith(
        exportedArchivePath: result.archivePath,
        exportedArchiveSizeBytes: result.archiveSizeBytes,
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
          .importJson(state.importDraft);
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

  Future<bool> importLatestSavedFile() async {
    try {
      final json = await ref.read(backupFileStoreProvider).readLatestJson();
      final report = ref.read(backupServiceProvider).importJson(json);
      _refreshImportedData();
      state = state.copyWith(
        importDraft: json,
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

  Future<bool> importArchivePath(String archivePath) async {
    try {
      final json = await ref
          .read(backupFileStoreProvider)
          .readArchiveJson(archivePath);
      final report = ref.read(backupServiceProvider).importJson(json);
      _refreshImportedData();
      state = state.copyWith(
        importDraft: json,
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
  });

  final String json;
  final String markdown;
  final String outputPath;
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

Future<String> _extractRestoreJsonFromArchive(_BackupArchiveReadJob job) {
  return LocalBackupArchiveCodec.extractRestoreJson(
    archivePath: job.archivePath,
    stagingDirectory: job.stagingDirectory,
  );
}
