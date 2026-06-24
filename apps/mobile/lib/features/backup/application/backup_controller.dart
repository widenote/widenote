import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import '../../capture/application/capture_controller.dart';

final backupServiceProvider = Provider<LocalBackupService>((ref) {
  return LocalBackupService(ref.watch(localDatabaseProvider));
});

final backupControllerProvider =
    NotifierProvider<BackupController, BackupState>(BackupController.new);

enum BackupOutcome { idle, exported, imported, failed }

final class BackupState {
  const BackupState({
    this.exportedJson,
    this.recordCounts = const <String, int>{},
    this.importDraft = '',
    this.outcome = BackupOutcome.idle,
    this.errorDetails,
  });

  final String? exportedJson;
  final Map<String, int> recordCounts;
  final String importDraft;
  final BackupOutcome outcome;
  final String? errorDetails;

  bool get canImport => importDraft.trim().isNotEmpty;

  BackupState copyWith({
    String? exportedJson,
    Map<String, int>? recordCounts,
    String? importDraft,
    BackupOutcome? outcome,
    String? errorDetails,
    bool clearError = false,
  }) {
    return BackupState(
      exportedJson: exportedJson ?? this.exportedJson,
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
        recordCounts: backup.manifest.recordCounts,
        outcome: BackupOutcome.exported,
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
      ref.invalidate(captureControllerProvider);
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
}

String _safeBackupError(Object error) {
  return switch (error) {
    FormatException() => 'Invalid backup format.',
    UnsupportedError() => 'Unsupported backup version.',
    StateError() => 'Backup conflicts with local data.',
    _ => 'Unexpected backup error.',
  };
}
