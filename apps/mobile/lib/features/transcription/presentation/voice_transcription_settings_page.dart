import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../transcription_service.dart';
import '../transcription_settings.dart';

class VoiceTranscriptionSettingsPage extends ConsumerStatefulWidget {
  const VoiceTranscriptionSettingsPage({super.key});

  @override
  ConsumerState<VoiceTranscriptionSettingsPage> createState() =>
      _VoiceTranscriptionSettingsPageState();
}

class _VoiceTranscriptionSettingsPageState
    extends ConsumerState<VoiceTranscriptionSettingsPage> {
  final _endpointController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  String? _syncedEndpoint;
  String? _syncedModel;
  bool _downloadingModel = false;
  bool _deletingModel = false;
  bool _retrying = false;

  @override
  void dispose() {
    _endpointController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(
      voiceTranscriptionSettingsControllerProvider,
    );
    return asyncSettings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => ListView(
        key: const Key('voice-transcription-settings-page'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          const _PageHeader(),
          const SizedBox(height: 16),
          _ErrorLine(text: context.l10n.voiceSettingsLoadFailed('$error')),
        ],
      ),
      data: (settings) {
        _syncTextFields(settings);
        return ListView(
          key: const Key('voice-transcription-settings-page'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
          children: [
            const _PageHeader(),
            const SizedBox(height: 16),
            _StatusSurface(settings: settings),
            const SizedBox(height: 12),
            _EngineSurface(settings: settings),
            const SizedBox(height: 12),
            _LocalModelSurface(
              settings: settings,
              downloading: _downloadingModel,
              deleting: _deletingModel,
              onDownload: () => unawaited(_downloadLocalModel()),
              onDelete: () => unawaited(_deleteLocalModel()),
            ),
            const SizedBox(height: 12),
            _PreviewSurface(settings: settings),
            const SizedBox(height: 12),
            _RemoteSurface(
              settings: settings,
              endpointController: _endpointController,
              modelController: _modelController,
              apiKeyController: _apiKeyController,
              onSave: () => unawaited(_saveRemoteSettings(settings)),
            ),
            const SizedBox(height: 12),
            _CorrectionSurface(settings: settings),
            const SizedBox(height: 12),
            _RetrySurface(
              retrying: _retrying,
              onRetry: () => unawaited(_retryFailedTranscripts()),
            ),
          ],
        );
      },
    );
  }

  void _syncTextFields(VoiceTranscriptionSettings settings) {
    if (_syncedEndpoint != settings.mimoAsrEndpoint) {
      _endpointController.text = settings.mimoAsrEndpoint;
      _syncedEndpoint = settings.mimoAsrEndpoint;
    }
    if (_syncedModel != settings.mimoAsrModel) {
      _modelController.text = settings.mimoAsrModel;
      _syncedModel = settings.mimoAsrModel;
    }
  }

  Future<void> _saveRemoteSettings(VoiceTranscriptionSettings settings) async {
    final controller = ref.read(
      voiceTranscriptionSettingsControllerProvider.notifier,
    );
    await controller.saveSettings(
      settings.copyWith(
        mimoAsrEndpoint: _endpointController.text.trim(),
        mimoAsrModel: _modelController.text.trim(),
        clearError: true,
      ),
    );
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      await controller.saveMimoApiKey(apiKey);
      _apiKeyController.clear();
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.voiceSettingsSaved)));
  }

  Future<void> _downloadLocalModel() async {
    if (_downloadingModel) {
      return;
    }
    final manager = ref.read(transcriptionDownloadManagerProvider);
    if (manager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.voiceSettingsModelUnavailable)),
      );
      return;
    }
    setState(() => _downloadingModel = true);
    final l10n = context.l10n;
    try {
      final result = await manager.downloadDefaultModel();
      await ref
          .read(voiceTranscriptionSettingsControllerProvider.notifier)
          .reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.state == LocalTranscriptionModelState.ready
                ? l10n.voiceSettingsModelDownloadReady
                : l10n.voiceSettingsModelDownloadFailed(
                    result.errorMessage ?? result.errorCode ?? 'unknown',
                  ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingModel = false);
      }
    }
  }

  Future<void> _deleteLocalModel() async {
    if (_deletingModel) {
      return;
    }
    final manager = ref.read(transcriptionDownloadManagerProvider);
    if (manager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.voiceSettingsModelUnavailable)),
      );
      return;
    }
    setState(() => _deletingModel = true);
    try {
      await manager.deleteModel();
      await ref
          .read(voiceTranscriptionSettingsControllerProvider.notifier)
          .reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.voiceSettingsModelDeleted)),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingModel = false);
      }
    }
  }

  Future<void> _retryFailedTranscripts() async {
    if (_retrying) {
      return;
    }
    setState(() => _retrying = true);
    final l10n = context.l10n;
    try {
      final summary = await ref
          .read(transcriptionServiceProvider)
          .retryFailedTranscripts();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.voiceSettingsRetrySummary(
              summary.attempted,
              summary.succeeded,
              summary.failed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.voiceSettingsTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.voiceSettingsSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusSurface extends StatelessWidget {
  const _StatusSurface({required this.settings});

  final VoiceTranscriptionSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.graphic_eq_outlined,
      title: l10n.voiceSettingsStatusTitle,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.offline_bolt_outlined,
            title: l10n.voiceSettingsLocalModelTitle,
            value: _modelStateLabel(l10n, settings.localModelState),
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.cloud_upload_outlined,
            title: l10n.voiceSettingsRemoteFallbackTitle,
            value: _engineLabel(l10n, settings.engine),
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.rule_outlined,
            title: l10n.voiceSettingsCorrectionTitle,
            value: _correctionModeLabel(l10n, settings.correctionMode),
          ),
        ],
      ),
    );
  }
}

class _PreviewSurface extends ConsumerWidget {
  const _PreviewSurface({required this.settings});

  final VoiceTranscriptionSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.hearing_outlined,
      title: l10n.voiceSettingsPreviewTitle,
      description: l10n.voiceSettingsPreviewDescription,
      child: SwitchListTile(
        key: const Key('voice-preview-switch'),
        contentPadding: EdgeInsets.zero,
        value: settings.realtimePreviewEnabled,
        title: Text(l10n.voiceSettingsPreviewSwitchTitle),
        subtitle: Text(l10n.voiceSettingsPreviewSwitchSubtitle),
        onChanged: (enabled) => unawaited(
          ref
              .read(voiceTranscriptionSettingsControllerProvider.notifier)
              .saveSettings(settings.copyWith(realtimePreviewEnabled: enabled)),
        ),
      ),
    );
  }
}

class _LocalModelSurface extends StatelessWidget {
  const _LocalModelSurface({
    required this.settings,
    required this.downloading,
    required this.deleting,
    required this.onDownload,
    required this.onDelete,
  });

  final VoiceTranscriptionSettings settings;
  final bool downloading;
  final bool deleting;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isBusy =
        downloading ||
        deleting ||
        settings.localModelState == LocalTranscriptionModelState.downloading ||
        settings.localModelState == LocalTranscriptionModelState.deleting;
    final canDelete =
        settings.localModelState !=
            LocalTranscriptionModelState.notDownloaded &&
        settings.localModelState != LocalTranscriptionModelState.downloading &&
        settings.localModelState != LocalTranscriptionModelState.deleting;
    return _Surface(
      icon: Icons.download_for_offline_outlined,
      title: l10n.voiceSettingsLocalModelManageTitle,
      description: l10n.voiceSettingsLocalModelManageDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (settings.localModelState ==
                  LocalTranscriptionModelState.downloading ||
              downloading) ...[
            LinearProgressIndicator(
              value: settings.downloadProgress <= 0
                  ? null
                  : settings.downloadProgress / 100,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            l10n.voiceSettingsModelProgress(
              _modelStateLabel(l10n, settings.localModelState),
              settings.downloadProgress,
            ),
          ),
          if (settings.lastErrorMessage != null) ...[
            const SizedBox(height: 8),
            _ErrorLine(text: settings.lastErrorMessage!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('voice-download-local-model-button'),
                onPressed: isBusy ? null : onDownload,
                icon: downloading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(
                  downloading
                      ? l10n.voiceSettingsModelDownloading
                      : l10n.voiceSettingsModelDownloadButton,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('voice-delete-local-model-button'),
                onPressed: isBusy || !canDelete ? null : onDelete,
                icon: deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(l10n.voiceSettingsModelDeleteButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EngineSurface extends ConsumerWidget {
  const _EngineSurface({required this.settings});

  final VoiceTranscriptionSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.alt_route_outlined,
      title: l10n.voiceSettingsEngineTitle,
      description: l10n.voiceSettingsEngineDescription,
      child: SegmentedButton<VoiceTranscriptionEngine>(
        key: const Key('voice-transcription-engine-control'),
        segments: [
          ButtonSegment<VoiceTranscriptionEngine>(
            value: VoiceTranscriptionEngine.localSenseVoice,
            icon: const Icon(Icons.offline_bolt_outlined),
            label: Text(l10n.voiceSettingsEngineLocal),
          ),
          ButtonSegment<VoiceTranscriptionEngine>(
            value: VoiceTranscriptionEngine.xiaomiMimo,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(l10n.voiceSettingsEngineMimo),
          ),
          ButtonSegment<VoiceTranscriptionEngine>(
            value: VoiceTranscriptionEngine.disabled,
            icon: const Icon(Icons.block_outlined),
            label: Text(l10n.voiceSettingsEngineDisabled),
          ),
        ],
        selected: <VoiceTranscriptionEngine>{settings.engine},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          final engine = selection.single;
          unawaited(
            ref
                .read(voiceTranscriptionSettingsControllerProvider.notifier)
                .saveSettings(
                  settings.copyWith(
                    engine: engine,
                    remoteConsentGranted:
                        engine == VoiceTranscriptionEngine.xiaomiMimo
                        ? settings.remoteConsentGranted
                        : false,
                  ),
                ),
          );
        },
      ),
    );
  }
}

class _RemoteSurface extends ConsumerWidget {
  const _RemoteSurface({
    required this.settings,
    required this.endpointController,
    required this.modelController,
    required this.apiKeyController,
    required this.onSave,
  });

  final VoiceTranscriptionSettings settings;
  final TextEditingController endpointController;
  final TextEditingController modelController;
  final TextEditingController apiKeyController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.cloud_sync_outlined,
      title: l10n.voiceSettingsRemoteTitle,
      description: l10n.voiceSettingsRemoteDescription,
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('voice-remote-consent-switch'),
            contentPadding: EdgeInsets.zero,
            value: settings.mimoAsrEnabled,
            title: Text(l10n.voiceSettingsRemoteConsentTitle),
            subtitle: Text(l10n.voiceSettingsRemoteConsentSubtitle),
            onChanged: (enabled) => unawaited(
              ref
                  .read(voiceTranscriptionSettingsControllerProvider.notifier)
                  .saveSettings(
                    settings.copyWith(
                      engine: enabled
                          ? VoiceTranscriptionEngine.xiaomiMimo
                          : VoiceTranscriptionEngine.localSenseVoice,
                      remoteConsentGranted: enabled,
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('voice-asr-endpoint-field'),
            controller: endpointController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: true,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(
              labelText: l10n.voiceSettingsEndpointLabel,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('voice-asr-model-field'),
            controller: modelController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: true,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(
              labelText: l10n.voiceSettingsModelLabel,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('voice-asr-api-key-field'),
            controller: apiKeyController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.voiceSettingsApiKeyLabel,
              helperText: l10n.voiceSettingsApiKeyHelper,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('voice-asr-save-button'),
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.saveButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionSurface extends ConsumerWidget {
  const _CorrectionSurface({required this.settings});

  final VoiceTranscriptionSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.spellcheck_outlined,
      title: l10n.voiceSettingsCorrectionTitle,
      description: l10n.voiceSettingsCorrectionDescription,
      child: DropdownButtonFormField<TranscriptCorrectionMode>(
        key: const Key('voice-correction-mode-field'),
        initialValue: settings.correctionMode,
        decoration: InputDecoration(
          labelText: l10n.voiceSettingsCorrectionModeLabel,
        ),
        items: [
          for (final mode in TranscriptCorrectionMode.values)
            DropdownMenuItem(
              value: mode,
              child: Text(_correctionModeLabel(l10n, mode)),
            ),
        ],
        onChanged: (mode) {
          if (mode == null) {
            return;
          }
          unawaited(
            ref
                .read(voiceTranscriptionSettingsControllerProvider.notifier)
                .saveSettings(settings.copyWith(correctionMode: mode)),
          );
        },
      ),
    );
  }
}

class _RetrySurface extends StatelessWidget {
  const _RetrySurface({required this.retrying, required this.onRetry});

  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.replay_outlined,
      title: l10n.voiceSettingsRetryTitle,
      description: l10n.voiceSettingsRetryDescription,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          key: const Key('voice-retry-failed-transcripts-button'),
          onPressed: retrying ? null : onRetry,
          icon: retrying
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_outlined),
          label: Text(
            retrying
                ? l10n.voiceSettingsRetryRunning
                : l10n.voiceSettingsRetryButton,
          ),
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.icon,
    required this.title,
    required this.child,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(title)),
        const SizedBox(width: 8),
        Chip(visualDensity: VisualDensity.compact, label: Text(value)),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

String _modelStateLabel(
  AppLocalizations l10n,
  LocalTranscriptionModelState state,
) {
  return switch (state) {
    LocalTranscriptionModelState.notDownloaded =>
      l10n.voiceSettingsModelStateNotDownloaded,
    LocalTranscriptionModelState.checking =>
      l10n.voiceSettingsModelStateChecking,
    LocalTranscriptionModelState.downloading =>
      l10n.voiceSettingsModelStateDownloading,
    LocalTranscriptionModelState.pausedOrInterrupted =>
      l10n.voiceSettingsModelStateInterrupted,
    LocalTranscriptionModelState.verifying =>
      l10n.voiceSettingsModelStateVerifying,
    LocalTranscriptionModelState.ready => l10n.voiceSettingsModelStateReady,
    LocalTranscriptionModelState.failed => l10n.voiceSettingsModelStateFailed,
    LocalTranscriptionModelState.corrupted =>
      l10n.voiceSettingsModelStateCorrupted,
    LocalTranscriptionModelState.deleting =>
      l10n.voiceSettingsModelStateDeleting,
  };
}

String _correctionModeLabel(
  AppLocalizations l10n,
  TranscriptCorrectionMode mode,
) {
  return switch (mode) {
    TranscriptCorrectionMode.disabled => l10n.voiceSettingsCorrectionDisabled,
    TranscriptCorrectionMode.suggestOnly => l10n.voiceSettingsCorrectionSuggest,
    TranscriptCorrectionMode.autoApplyHighConfidence =>
      l10n.voiceSettingsCorrectionAutoApply,
  };
}

String _engineLabel(AppLocalizations l10n, VoiceTranscriptionEngine engine) {
  return switch (engine) {
    VoiceTranscriptionEngine.localSenseVoice => l10n.voiceSettingsEngineLocal,
    VoiceTranscriptionEngine.xiaomiMimo => l10n.voiceSettingsEngineMimo,
    VoiceTranscriptionEngine.disabled => l10n.voiceSettingsEngineDisabled,
  };
}
