import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../l10n/l10n.dart';
import '../application/backup_controller.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(backupControllerProvider);
    return ListView(
      key: const Key('backup-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        _PageHeader(title: l10n.backupTitle, subtitle: l10n.backupSubtitle),
        const SizedBox(height: 16),
        _StatusLine(state: state),
        const SizedBox(height: 16),
        _ExportSurface(state: state),
        const SizedBox(height: 16),
        _ImportSurface(state: state),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (text, color) = switch (state.outcome) {
      BackupOutcome.idle => (l10n.backupIdleStatus, null),
      BackupOutcome.exported => (
        l10n.backupExportReadyStatus,
        Theme.of(context).colorScheme.primary,
      ),
      BackupOutcome.savedFile => (
        l10n.backupSavedFileStatus,
        Theme.of(context).colorScheme.primary,
      ),
      BackupOutcome.importReady => (
        l10n.backupImportReadyStatus,
        Theme.of(context).colorScheme.primary,
      ),
      BackupOutcome.imported => (
        l10n.backupImportDoneStatus,
        Theme.of(context).colorScheme.primary,
      ),
      BackupOutcome.failed => (
        l10n.backupFailedStatus(
          localizedBackupErrorDetails(l10n, state.errorDetails ?? ''),
        ),
        Theme.of(context).colorScheme.error,
      ),
    };
    return Text(
      text,
      key: const Key('backup-status-line'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
    );
  }
}

class _ExportSurface extends ConsumerWidget {
  const _ExportSurface({required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.file_upload_outlined,
      title: l10n.backupExportSectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            key: const Key('backup-export-button'),
            onPressed: () =>
                ref.read(backupControllerProvider.notifier).exportBackup(),
            icon: const Icon(Icons.upload_file),
            label: Text(l10n.backupExportButton),
          ),
          const SizedBox(height: 12),
          _BoundaryLine(
            lineKey: const Key('backup-safe-restore-boundary'),
            icon: Icons.restore_outlined,
            text: l10n.backupSafeRestoreBoundary,
          ),
          const SizedBox(height: 8),
          _BoundaryLine(
            lineKey: const Key('backup-owner-export-boundary'),
            icon: Icons.folder_zip_outlined,
            text: l10n.backupOwnerExportBoundary,
          ),
          const SizedBox(height: 8),
          _BoundaryLine(
            lineKey: const Key('backup-full-secret-boundary'),
            icon: Icons.lock_outline,
            text: l10n.backupFullSecretBoundary,
          ),
          const SizedBox(height: 8),
          _BoundaryLine(
            lineKey: const Key('backup-secret-warning'),
            icon: Icons.security_outlined,
            text: l10n.backupSecretWarning,
          ),
          const SizedBox(height: 12),
          if (state.exportedJson == null)
            Text(l10n.backupExportEmpty)
          else ...[
            if (state.safeProviderSecretOmissionCount > 0) ...[
              Text(
                l10n.backupSafeOmittedProviderKeys(
                  state.safeProviderSecretOmissionCount,
                ),
                key: const Key('backup-safe-provider-key-omissions'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              l10n.backupManifestCountsTitle,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('backup-counts'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _sortedCounts(state.recordCounts))
                  _Tag(label: l10n.backupCount(entry.key, entry.value)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('backup-open-share-file-button'),
                  onPressed: () => ref
                      .read(backupControllerProvider.notifier)
                      .shareExportedFile(),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: Text(l10n.backupOpenShareFileButton),
                ),
                OutlinedButton.icon(
                  key: const Key('backup-save-files-button'),
                  onPressed: () => ref
                      .read(backupControllerProvider.notifier)
                      .saveExportedFiles(),
                  icon: const Icon(Icons.save_alt_outlined),
                  label: Text(l10n.backupSaveFilesButton),
                ),
              ],
            ),
            if (state.exportedArchivePath != null) ...[
              const SizedBox(height: 12),
              _FilePathLine(
                label: l10n.backupSavedArchivePath,
                path: state.exportedArchivePath!,
              ),
              if (state.exportDestinationLabel != null) ...[
                const SizedBox(height: 4),
                _FilePathLine(
                  label: l10n.backupExportDestination,
                  path: state.exportDestinationLabel!,
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _ImportSurface extends ConsumerWidget {
  const _ImportSurface({required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.file_download_outlined,
      title: l10n.backupImportSectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.backupImportHint),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('backup-import-file-button'),
            onPressed: () => ref
                .read(backupControllerProvider.notifier)
                .pickArchiveForImport(),
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(l10n.backupImportFileButton),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('backup-import-button'),
            onPressed: state.canImport
                ? () => _confirmReplaceAllImport(context, ref)
                : null,
            icon: const Icon(Icons.download_done_outlined),
            label: Text(l10n.backupImportButton),
          ),
          if (state.outcome == BackupOutcome.importReady ||
              state.outcome == BackupOutcome.imported ||
              state.outcome == BackupOutcome.failed) ...[
            const SizedBox(height: 8),
            _InlineOutcome(state: state),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmReplaceAllImport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.backupConfirmReplaceTitle),
          content: Text(l10n.backupConfirmReplaceBody),
          actions: [
            TextButton(
              key: const Key('backup-confirm-cancel-button'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.backupConfirmReplaceCancel),
            ),
            FilledButton(
              key: const Key('backup-confirm-replace-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.backupConfirmReplaceAction),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      unawaited(ref.read(backupControllerProvider.notifier).importBackup());
    }
  }
}

class _InlineOutcome extends StatelessWidget {
  const _InlineOutcome({required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFailure = state.outcome == BackupOutcome.failed;
    final isReady = state.outcome == BackupOutcome.importReady;
    final reportText = isFailure
        ? null
        : _importReportText(l10n, state.lastImportReport);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFailure
              ? l10n.backupFailedStatus(
                  localizedBackupErrorDetails(l10n, state.errorDetails ?? ''),
                )
              : isReady
              ? l10n.backupImportReadyInline
              : l10n.backupImportDoneStatus,
          key: const Key('backup-inline-outcome'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isFailure
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        if (reportText != null) ...[
          const SizedBox(height: 4),
          Text(
            reportText,
            key: const Key('backup-import-report'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (isReady && state.importSourceLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            '${l10n.backupImportSourcePath}: ${state.importSourceLabel}',
            key: const Key('backup-import-source-path'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }
}

String? _importReportText(
  AppLocalizations l10n,
  LocalBackupImportReport? report,
) {
  if (report == null) {
    return null;
  }
  if (report.requiresCredentialReentry) {
    return l10n.backupImportNeedsProviderKeys(
      report.providerConfigsNeedingCredentialReentry,
    );
  }
  if (report.includesSecrets) {
    return l10n.backupImportSecretsRestored;
  }
  return l10n.backupImportNoProviderKeysNeeded;
}

class _FilePathLine extends StatelessWidget {
  const _FilePathLine({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $path',
      key: Key('backup-file-path-$label'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFamily: 'monospace',
      ),
    );
  }
}

class _BoundaryLine extends StatelessWidget {
  const _BoundaryLine({
    required this.lineKey,
    required this.icon,
    required this.text,
  });

  final Key lineKey;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      key: lineKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

List<MapEntry<String, int>> _sortedCounts(Map<String, int> counts) {
  final entries = counts.entries.toList();
  entries.sort((a, b) => a.key.compareTo(b.key));
  return entries;
}
