import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';
import '../../capture/application/capture_controller.dart';
import '../../location/application/location_settings_controller.dart';
import '../../location/domain/location_context.dart';
import '../../memory/application/memory_controller.dart';
import '../../model_providers/application/model_provider_settings_controller.dart';
import '../../timeline/application/timeline_repository.dart';
import '../../todos/application/todo_controller.dart';
import '../../transcription/transcription_service.dart';
import '../../transcription/transcription_settings.dart';

final backupServiceProvider = Provider<LocalBackupService>((ref) {
  return LocalBackupService(ref.watch(localDatabaseProvider));
});

final backupFileStoreProvider = Provider<BackupFileStore>((ref) {
  return AppSupportBackupFileStore(
    supportDirectory: ref.watch(appSupportDirectoryProvider),
    includeDiagnosticLogs: ref.watch(backupDiagnosticLogsEnabledProvider),
    supportSettingsLoader: () async {
      final locationSettings = await ref
          .read(locationSettingsRepositoryProvider)
          .load();
      final voiceSettings = await ref
          .read(voiceTranscriptionSettingsRepositoryProvider)
          .load();
      final mimoApiKey = await ref
          .read(transcriptionCredentialStoreProvider)
          .readMimoAsrApiKey();
      return BackupSupportSettingsBundle(
        locationSettings: locationSettings,
        hasVoiceTranscriptionSettings: true,
        voiceTranscriptionSettings: voiceSettings.copyWith(
          localModelState: LocalTranscriptionModelState.notDownloaded,
          downloadProgress: 0,
          clearError: true,
        ),
        hasMimoAsrApiKey: mimoApiKey != null && mimoApiKey.trim().isNotEmpty,
        mimoAsrApiKey: mimoApiKey?.trim(),
      );
    },
  );
});

final backupDiagnosticLogsEnabledProvider = Provider<bool>((_) {
  return shouldIncludeBackupDiagnosticLogs(
    flavor: appFlavor,
    isReleaseMode: kReleaseMode,
  );
});

const _formalReleaseFlavors = <String>{
  'prod',
  'production',
  'official',
  'release',
  'store',
};

bool shouldIncludeBackupDiagnosticLogs({
  required String? flavor,
  required bool isReleaseMode,
}) {
  if (!isReleaseMode) {
    return true;
  }
  final normalizedFlavor = flavor?.trim().toLowerCase();
  return normalizedFlavor != null &&
      normalizedFlavor.isNotEmpty &&
      !_formalReleaseFlavors.contains(normalizedFlavor);
}

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
    this.supportSettings = const BackupSupportSettingsBundle(),
  });

  final LocalDataBackup backup;
  final String sourceLabel;
  final String? stagingDirectory;
  final List<LocalBackupDirectoryArchiveExtractedFile> mediaFiles;
  final BackupSupportSettingsBundle supportSettings;
}

typedef BackupSupportSettingsLoader =
    Future<BackupSupportSettingsBundle> Function();

const _backupLocationSettingsPath = 'config/location_context.wnconfig';
const _backupVoiceSettingsPath = 'config/voice_transcription.wnconfig';
const _backupMimoSecretPath = 'secrets/voice_transcription_mimo.wnsecret';
const _backupDiagnosticsExportInfoPath = 'diagnostics/export-info.txt';
const _backupDiagnosticsEventLogPath = 'diagnostics/event_log.log';
const _backupDiagnosticsRuntimeTasksPath = 'diagnostics/runtime_tasks.log';
const _backupDiagnosticsRuntimeRunsPath = 'diagnostics/runtime_runs.log';
const _backupDiagnosticsTraceEventsPath = 'diagnostics/trace_events.log';

final class BackupSupportSettingsBundle {
  const BackupSupportSettingsBundle({
    this.locationSettings,
    this.hasVoiceTranscriptionSettings = false,
    this.voiceTranscriptionSettings,
    this.hasMimoAsrApiKey = false,
    this.mimoAsrApiKey,
  });

  final LocationCaptureSettings? locationSettings;
  final bool hasVoiceTranscriptionSettings;
  final VoiceTranscriptionSettings? voiceTranscriptionSettings;
  final bool hasMimoAsrApiKey;
  final String? mimoAsrApiKey;

  bool get isEmpty =>
      locationSettings == null &&
      !hasVoiceTranscriptionSettings &&
      !hasMimoAsrApiKey;

  Map<String, String> toSupportFiles() {
    final files = <String, String>{};
    final location = locationSettings;
    if (location != null) {
      files[_backupLocationSettingsPath] = jsonEncode(
        location.toJson(includeSecrets: true),
      );
    }
    final voice = voiceTranscriptionSettings;
    if (hasVoiceTranscriptionSettings && voice != null) {
      files[_backupVoiceSettingsPath] = jsonEncode(voice.toJson());
    }
    final mimoKey = mimoAsrApiKey?.trim();
    if (hasMimoAsrApiKey && mimoKey != null && mimoKey.isNotEmpty) {
      files[_backupMimoSecretPath] = jsonEncode(<String, Object?>{
        'mimo_asr_api_key': mimoKey,
      });
    }
    return files;
  }

  static Future<BackupSupportSettingsBundle> readFromDirectory(
    String stagingDirectory,
  ) async {
    final location = await _readJsonMapFile(
      p.join(stagingDirectory, _backupLocationSettingsPath),
    );
    final voice = await _readJsonMapFile(
      p.join(stagingDirectory, _backupVoiceSettingsPath),
    );
    final mimo = await _readJsonMapFile(
      p.join(stagingDirectory, _backupMimoSecretPath),
    );
    return BackupSupportSettingsBundle(
      locationSettings: location == null
          ? null
          : LocationCaptureSettings.fromJson(location),
      hasVoiceTranscriptionSettings: voice != null,
      voiceTranscriptionSettings: voice == null
          ? null
          : VoiceTranscriptionSettings.fromJson(voice),
      hasMimoAsrApiKey: mimo != null,
      mimoAsrApiKey: _stringValue(mimo?['mimo_asr_api_key']),
    );
  }
}

final class AppSupportBackupFileStore implements BackupFileStore {
  AppSupportBackupFileStore({
    Directory? supportDirectory,
    BackupExportPlatform platform = const BackupExportPlatform(),
    BackupSupportSettingsLoader? supportSettingsLoader,
    bool? includeDiagnosticLogs,
    String? buildFlavor,
    String? buildMode,
  }) : _supportDirectory = supportDirectory,
       _platform = platform,
       _supportSettingsLoader = supportSettingsLoader,
       _includeDiagnosticLogs =
           includeDiagnosticLogs ??
           shouldIncludeBackupDiagnosticLogs(
             flavor: buildFlavor ?? appFlavor,
             isReleaseMode: kReleaseMode,
           ),
       _buildFlavor = buildFlavor ?? appFlavor,
       _buildMode = buildMode ?? _currentBuildMode();

  final Directory? _supportDirectory;
  final BackupExportPlatform _platform;
  final BackupSupportSettingsLoader? _supportSettingsLoader;
  final bool _includeDiagnosticLogs;
  final String? _buildFlavor;
  final String _buildMode;

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
    final supportSettings =
        await _supportSettingsLoader?.call() ??
        const BackupSupportSettingsBundle();
    final extraFiles = <String, String>{
      ...supportSettings.toSupportFiles(),
      if (_includeDiagnosticLogs)
        ..._diagnosticLogFilesForBackup(
          backup: backup,
          createdAt: createdAt,
          buildFlavor: _buildFlavor,
          buildMode: _buildMode,
        ),
    };
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
            supportFiles: extraFiles,
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
      final supportSettings =
          await BackupSupportSettingsBundle.readFromDirectory(
            stagingDirectory.path,
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
          supportSettings: supportSettings,
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
    this.legacyProviderCredentialReentryCount = 0,
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
  final int legacyProviderCredentialReentryCount;
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
    int? legacyProviderCredentialReentryCount,
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
      legacyProviderCredentialReentryCount:
          legacyProviderCredentialReentryCount ??
          this.legacyProviderCredentialReentryCount,
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
        legacyProviderCredentialReentryCount: 0,
        outcome: BackupOutcome.exported,
        clearError: true,
        clearFilePaths: true,
        clearImportReport: true,
      );
    } catch (error) {
      state = state.copyWith(
        outcome: BackupOutcome.failed,
        errorDetails: _backupErrorDetails(error),
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
        errorDetails: _backupErrorDetails(error),
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
        await _restoreSupportSettings(prepared.supportSettings);
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
        errorDetails: _backupErrorDetails(error),
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
        errorDetails: _backupErrorDetails(error),
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
        errorDetails: _backupErrorDetails(error),
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
        errorDetails: _backupErrorDetails(error),
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
      ..invalidate(locationSettingsControllerProvider)
      ..invalidate(voiceTranscriptionSettingsControllerProvider)
      ..invalidate(modelClientProvider)
      ..invalidate(chatModelClientProvider);
  }

  Future<void> _restoreSupportSettings(
    BackupSupportSettingsBundle supportSettings,
  ) async {
    if (supportSettings.isEmpty) {
      return;
    }
    final locationSettings = supportSettings.locationSettings;
    if (locationSettings != null) {
      await ref.read(locationSettingsRepositoryProvider).save(locationSettings);
    }
    if (supportSettings.hasVoiceTranscriptionSettings) {
      final settings = supportSettings.voiceTranscriptionSettings;
      if (settings != null) {
        await ref
            .read(voiceTranscriptionSettingsRepositoryProvider)
            .save(settings);
      }
    }
    if (supportSettings.hasMimoAsrApiKey) {
      final key = supportSettings.mimoAsrApiKey?.trim();
      if (key != null && key.isNotEmpty) {
        await ref
            .read(transcriptionCredentialStoreProvider)
            .writeMimoAsrApiKey(key);
      } else {
        await ref
            .read(transcriptionCredentialStoreProvider)
            .deleteMimoAsrApiKey();
      }
    } else if (supportSettings.hasVoiceTranscriptionSettings) {
      await ref
          .read(transcriptionCredentialStoreProvider)
          .deleteMimoAsrApiKey();
    }
  }
}

String _backupErrorDetails(Object error) {
  return switch (error) {
    FormatException() => 'Invalid backup format.',
    UnsupportedError() => 'Unsupported backup version.',
    FileSystemException() => 'No saved backup file found.',
    StateError() => 'Backup conflicts with local data.',
    _ => 'Unexpected backup error.',
  };
}

Future<Map<String, Object?>?> _readJsonMapFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, Object?>();
  }
  throw FormatException('Backup support file is not an object: $path.');
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String _currentBuildMode() {
  if (kReleaseMode) {
    return 'release';
  }
  if (kProfileMode) {
    return 'profile';
  }
  return 'debug';
}

Map<String, String> _diagnosticLogFilesForBackup({
  required LocalDataBackup backup,
  required DateTime createdAt,
  required String? buildFlavor,
  required String buildMode,
}) {
  final normalizedFlavor = buildFlavor?.trim();
  final info = StringBuffer()
    ..writeln('kind=widenote.non_formal_backup_diagnostics')
    ..writeln('created_at=${createdAt.toUtc().toIso8601String()}')
    ..writeln(
      'build_flavor=${normalizedFlavor == null || normalizedFlavor.isEmpty ? 'unflavored' : normalizedFlavor}',
    )
    ..writeln('build_mode=$buildMode')
    ..writeln('database_snapshot=data/widenote.sqlite')
    ..writeln('event_log_rows=${backup.eventLog.length}')
    ..writeln('runtime_task_rows=${backup.runtimeTasks.length}')
    ..writeln('runtime_run_rows=${backup.runtimeRuns.length}')
    ..writeln('trace_event_rows=${backup.traceEvents.length}');
  return <String, String>{
    _backupDiagnosticsExportInfoPath: info.toString(),
    _backupDiagnosticsEventLogPath: _jsonLines(
      backup.eventLog.map(_eventDiagnosticJson),
    ),
    _backupDiagnosticsRuntimeTasksPath: _jsonLines(
      backup.runtimeTasks.map(_runtimeTaskDiagnosticJson),
    ),
    _backupDiagnosticsRuntimeRunsPath: _jsonLines(
      backup.runtimeRuns.map(_runtimeRunDiagnosticJson),
    ),
    _backupDiagnosticsTraceEventsPath: _jsonLines(
      backup.traceEvents.map(_traceEventDiagnosticJson),
    ),
  };
}

String _jsonLines(Iterable<Map<String, Object?>> rows) {
  final encoded = rows.map(jsonEncode).join('\n');
  return encoded.isEmpty ? '' : '$encoded\n';
}

Map<String, Object?> _eventDiagnosticJson(EventLogEntry event) {
  return <String, Object?>{
    'created_at': event.createdAt.toUtc().toIso8601String(),
    'id': event.id,
    'type': event.type,
    'actor': event.actor,
    'status': event.status,
    'privacy': event.privacy,
    'source_capture_id': event.sourceCaptureId,
    'source_event_id': event.sourceEventId,
    'subject_kind': event.subjectKind,
    'subject_id': event.subjectId,
    'subject_ref': event.subjectRef,
    'pack_id': event.packId,
    'agent_id': event.agentId,
    'device_id': event.deviceId,
    'causation_id': event.causationId,
    'correlation_id': event.correlationId,
    'payload': event.payload,
  };
}

Map<String, Object?> _runtimeTaskDiagnosticJson(RuntimeTaskRecord task) {
  return <String, Object?>{
    'created_at': task.createdAt.toUtc().toIso8601String(),
    'updated_at': task.updatedAt.toUtc().toIso8601String(),
    'id': task.id,
    'pack_id': task.packId,
    'pack_version': task.packVersion,
    'agent_id': task.agentId,
    'handler_id': task.handlerId,
    'subscription_id': task.subscriptionId,
    'trigger_event_id': task.triggerEventId,
    'identity_key': task.effectiveIdentityKey,
    'status': task.status,
    'attempts': task.attempts,
    'max_attempts': task.maxAttempts,
    'lease_owner': task.leaseOwner,
    'leased_until': task.leasedUntil?.toUtc().toIso8601String(),
    'error': task.error,
    'payload': task.payload,
  };
}

Map<String, Object?> _runtimeRunDiagnosticJson(RuntimeRunRecord run) {
  return <String, Object?>{
    'started_at': run.startedAt.toUtc().toIso8601String(),
    'completed_at': run.completedAt?.toUtc().toIso8601String(),
    'id': run.id,
    'task_id': run.taskId,
    'pack_id': run.packId,
    'pack_version': run.packVersion,
    'agent_id': run.agentId,
    'handler_id': run.handlerId,
    'status': run.status,
    'attempt': run.attempt,
    'output_event_ids': run.outputEventIds,
    'error': run.error,
    'payload': run.payload,
  };
}

Map<String, Object?> _traceEventDiagnosticJson(TraceEventRecord trace) {
  return <String, Object?>{
    'created_at': trace.createdAt.toUtc().toIso8601String(),
    'id': trace.id,
    'name': trace.name,
    'level': trace.level,
    'trace_type': trace.traceType,
    'run_id': trace.runId,
    'severity': trace.severity,
    'message': trace.message,
    'source_event_id': trace.sourceEventId,
    'source_run_id': trace.sourceRunId,
    'source_task_id': trace.sourceTaskId,
    'pack_id': trace.packId,
    'agent_id': trace.agentId,
    'parent_trace_id': trace.parentTraceId,
    'duration_ms': trace.durationMs,
    'status': trace.status,
    'payload': trace.payload,
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
    required this.supportFiles,
  });

  final String sourceDatabasePath;
  final String stagingDirectory;
  final String outputPath;
  final DateTime createdAt;
  final int localDbSchemaVersion;
  final Map<String, int> recordCounts;
  final List<_BackupDirectoryMediaFile> mediaFiles;
  final Map<String, String> supportFiles;
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
  for (final entry in job.supportFiles.entries) {
    final target = File(
      p.joinAll(<String>[job.stagingDirectory, ...entry.key.split('/')]),
    );
    await target.parent.create(recursive: true);
    await target.writeAsString(entry.value);
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
