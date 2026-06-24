import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

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
      BackupOutcome.imported => (
        l10n.backupImportDoneStatus,
        Theme.of(context).colorScheme.primary,
      ),
      BackupOutcome.failed => (
        l10n.backupFailedStatus(state.errorDetails ?? ''),
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
          _WarningLine(text: l10n.backupSecretWarning),
          const SizedBox(height: 12),
          if (state.exportedJson == null)
            Text(l10n.backupExportEmpty)
          else ...[
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
                _CopyButton(
                  buttonKey: const Key('backup-copy-json-button'),
                  text: state.exportedJson!,
                  label: l10n.backupCopyJsonButton,
                ),
                if (state.exportedMarkdown != null)
                  _CopyButton(
                    buttonKey: const Key('backup-copy-markdown-button'),
                    text: state.exportedMarkdown!,
                    label: l10n.backupCopyMarkdownButton,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.backupExportJsonTitle,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _JsonPreview(text: state.exportedJson!),
            if (state.exportedMarkdown != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.backupExportMarkdownTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _TextPreview(
                key: const Key('backup-export-markdown'),
                text: state.exportedMarkdown!,
              ),
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
          TextField(
            key: const Key('backup-import-field'),
            minLines: 4,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            onChanged: ref
                .read(backupControllerProvider.notifier)
                .updateImportDraft,
            decoration: InputDecoration(hintText: l10n.backupImportHint),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('backup-import-button'),
            onPressed: state.canImport
                ? () =>
                      ref.read(backupControllerProvider.notifier).importBackup()
                : null,
            icon: const Icon(Icons.download_done_outlined),
            label: Text(l10n.backupImportButton),
          ),
          if (state.outcome == BackupOutcome.imported ||
              state.outcome == BackupOutcome.failed) ...[
            const SizedBox(height: 8),
            _InlineOutcome(state: state),
          ],
        ],
      ),
    );
  }
}

class _InlineOutcome extends StatelessWidget {
  const _InlineOutcome({required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFailure = state.outcome == BackupOutcome.failed;
    return Text(
      isFailure
          ? l10n.backupFailedStatus(state.errorDetails ?? '')
          : l10n.backupImportDoneStatus,
      key: const Key('backup-inline-outcome'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: isFailure
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('backup-secret-warning'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline,
          size: 18,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.buttonKey,
    required this.text,
    required this.label,
  });

  final Key buttonKey;
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: () {
        unawaited(Clipboard.setData(ClipboardData(text: text)));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.backupCopiedStatus)));
        }
      },
      icon: const Icon(Icons.copy),
      label: Text(label),
    );
  }
}

class _JsonPreview extends StatelessWidget {
  const _JsonPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('backup-export-json'),
      constraints: const BoxConstraints(maxHeight: 220),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: ExcludeSemantics(
          child: SelectableText(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ),
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
