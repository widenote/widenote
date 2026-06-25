import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import '../../capture/application/capture_controller.dart';
import '../../memory/application/memory_controller.dart';
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
  const BackupFileResult({required this.jsonPath, this.markdownPath});

  final String jsonPath;
  final String? markdownPath;
}

abstract interface class BackupFileStore {
  Future<BackupFileResult> saveExport({
    required String json,
    required String markdown,
    required DateTime createdAt,
  });

  Future<String> readLatestJson();
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
    final jsonFile = File('${directory.path}/widenote-backup-$stamp.json');
    final markdownFile = File('${directory.path}/widenote-backup-$stamp.md');
    await jsonFile.writeAsString(json);
    await markdownFile.writeAsString(markdown);
    return BackupFileResult(
      jsonPath: jsonFile.path,
      markdownPath: markdownFile.path,
    );
  }

  @override
  Future<String> readLatestJson() async {
    final directory = await _exportsDirectory();
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) {
            final time = b.lastModifiedSync().compareTo(a.lastModifiedSync());
            return time == 0 ? b.path.compareTo(a.path) : time;
          });
    if (files.isEmpty) {
      throw const FileSystemException('No WideNote backup file found.');
    }
    return files.first.readAsString();
  }

  Future<Directory> _exportsDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/local-data/exports');
    await directory.create(recursive: true);
    return directory;
  }
}

final class BackupState {
  const BackupState({
    this.exportedJson,
    this.exportedMarkdown,
    this.exportedJsonPath,
    this.exportedMarkdownPath,
    this.recordCounts = const <String, int>{},
    this.importDraft = '',
    this.outcome = BackupOutcome.idle,
    this.errorDetails,
  });

  final String? exportedJson;
  final String? exportedMarkdown;
  final String? exportedJsonPath;
  final String? exportedMarkdownPath;
  final Map<String, int> recordCounts;
  final String importDraft;
  final BackupOutcome outcome;
  final String? errorDetails;

  bool get canImport => importDraft.trim().isNotEmpty;

  BackupState copyWith({
    String? exportedJson,
    String? exportedMarkdown,
    String? exportedJsonPath,
    String? exportedMarkdownPath,
    Map<String, int>? recordCounts,
    String? importDraft,
    BackupOutcome? outcome,
    String? errorDetails,
    bool clearError = false,
    bool clearFilePaths = false,
  }) {
    return BackupState(
      exportedJson: exportedJson ?? this.exportedJson,
      exportedMarkdown: exportedMarkdown ?? this.exportedMarkdown,
      exportedJsonPath: clearFilePaths
          ? null
          : exportedJsonPath ?? this.exportedJsonPath,
      exportedMarkdownPath: clearFilePaths
          ? null
          : exportedMarkdownPath ?? this.exportedMarkdownPath,
      recordCounts: recordCounts ?? this.recordCounts,
      importDraft: importDraft ?? this.importDraft,
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
        exportedJsonPath: null,
        exportedMarkdownPath: null,
        recordCounts: backup.manifest.recordCounts,
        outcome: BackupOutcome.exported,
        clearError: true,
        clearFilePaths: true,
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
        exportedJsonPath: result.jsonPath,
        exportedMarkdownPath: result.markdownPath,
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
      ref.read(backupServiceProvider).importJson(state.importDraft);
      _refreshImportedData();
      state = state.copyWith(outcome: BackupOutcome.imported, clearError: true);
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
      ref.read(backupServiceProvider).importJson(json);
      _refreshImportedData();
      state = state.copyWith(
        importDraft: json,
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
      ..invalidate(memoryControllerProvider);
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
