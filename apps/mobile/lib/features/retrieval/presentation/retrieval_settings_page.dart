import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_model_providers/model_providers.dart';

import '../../../l10n/l10n.dart';
import '../application/embedding_settings_controller.dart';
import '../application/local_search_service.dart';

class RetrievalSettingsPage extends ConsumerStatefulWidget {
  const RetrievalSettingsPage({super.key});

  @override
  ConsumerState<RetrievalSettingsPage> createState() =>
      _RetrievalSettingsPageState();
}

class _RetrievalSettingsPageState extends ConsumerState<RetrievalSettingsPage> {
  final _displayNameController = TextEditingController();
  final _endpointController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _batchSizeController = TextEditingController();
  String? _loadedProviderId;

  @override
  void dispose() {
    _displayNameController.dispose();
    _endpointController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _batchSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(embeddingSettingsControllerProvider);
    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Shell(
        child: _ErrorLine(text: context.l10n.retrievalSettingsError('$error')),
      ),
      data: (state) {
        _syncControllers(state.provider);
        return _Shell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusSurface(state: state),
              const SizedBox(height: 12),
              _ProviderSurface(
                displayNameController: _displayNameController,
                endpointController: _endpointController,
                modelController: _modelController,
                apiKeyController: _apiKeyController,
                batchSizeController: _batchSizeController,
                state: state,
                onSave: () => _save(state),
                onTest: () => _test(state),
                onRebuild: _rebuildEmbeddings,
                onDelete: state.provider == null
                    ? null
                    : () => ref
                          .read(embeddingSettingsControllerProvider.notifier)
                          .deleteProvider(),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorLine(text: state.errorMessage!),
              ],
            ],
          ),
        );
      },
    );
  }

  void _syncControllers(EmbeddingProviderConfig? provider) {
    final providerId = provider?.id ?? '<new>';
    if (_loadedProviderId == providerId) {
      return;
    }
    _loadedProviderId = providerId;
    final preset = provider ?? _defaultProvider();
    _displayNameController.text = preset.displayName;
    _endpointController.text = preset.endpoint.toString();
    _modelController.text = preset.model;
    _apiKeyController.text = '';
    _batchSizeController.text = preset.batchSize.toString();
  }

  EmbeddingProviderConfig _draft(EmbeddingSettingsState state) {
    final existing = state.provider;
    final endpoint =
        Uri.tryParse(_endpointController.text.trim()) ??
        EmbeddingProviderKind.openRouter.defaultEndpoint;
    final batchSize = int.tryParse(_batchSizeController.text.trim()) ?? 16;
    final apiKey = _apiKeyController.text.trim().isEmpty
        ? existing?.apiKey ?? ''
        : _apiKeyController.text.trim();
    return EmbeddingProviderConfig(
      id: existing?.id ?? defaultEmbeddingProviderId,
      kind: EmbeddingProviderKind.openRouter,
      displayName: _displayNameController.text.trim().isEmpty
          ? EmbeddingProviderKind.openRouter.label
          : _displayNameController.text.trim(),
      endpoint: endpoint,
      model: _modelController.text.trim().isEmpty
          ? EmbeddingProviderKind.openRouter.defaultModel
          : _modelController.text.trim(),
      apiKey: apiKey,
      batchSize: batchSize <= 0 ? 16 : batchSize,
    );
  }

  Future<void> _save(EmbeddingSettingsState state) async {
    final saved = await ref
        .read(embeddingSettingsControllerProvider.notifier)
        .saveProvider(_draft(state));
    if (!mounted || !saved) {
      return;
    }
    _apiKeyController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.retrievalSettingsSaved)),
    );
  }

  Future<void> _test(EmbeddingSettingsState state) async {
    await ref
        .read(embeddingSettingsControllerProvider.notifier)
        .testProvider(_draft(state));
  }

  Future<void> _rebuildEmbeddings() async {
    final result = await ref
        .read(localSearchServiceProvider)
        .rebuildEmbeddings(limit: 500);
    if (!mounted) {
      return;
    }
    final l10n = context.l10n;
    final message = result.providerConfigured
        ? l10n.retrievalSettingsRebuildDone(result.indexedChunks)
        : l10n.retrievalSettingsRebuildNeedsProvider;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

EmbeddingProviderConfig _defaultProvider() {
  return EmbeddingProviderConfig.preset(
    id: defaultEmbeddingProviderId,
    kind: EmbeddingProviderKind.openRouter,
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('retrieval-settings-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('retrieval-settings-back'),
              tooltip: l10n.timelineBackTooltip,
              onPressed: () => _goBack(context),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.retrievalSettingsTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.retrievalSettingsSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _StatusSurface extends StatelessWidget {
  const _StatusSurface({required this.state});

  final EmbeddingSettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              state.isConfigured
                  ? Icons.travel_explore_outlined
                  : Icons.manage_search_outlined,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.isConfigured
                        ? l10n.retrievalSettingsConfiguredTitle
                        : l10n.retrievalSettingsUnconfiguredTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusBody(l10n, state),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusBody(AppLocalizations l10n, EmbeddingSettingsState state) {
    final provider = state.provider;
    if (provider == null) {
      return l10n.retrievalSettingsUnconfiguredBody;
    }
    return l10n.retrievalSettingsConfiguredBody(provider.model);
  }
}

class _ProviderSurface extends StatelessWidget {
  const _ProviderSurface({
    required this.displayNameController,
    required this.endpointController,
    required this.modelController,
    required this.apiKeyController,
    required this.batchSizeController,
    required this.state,
    required this.onSave,
    required this.onTest,
    required this.onRebuild,
    required this.onDelete,
  });

  final TextEditingController displayNameController;
  final TextEditingController endpointController;
  final TextEditingController modelController;
  final TextEditingController apiKeyController;
  final TextEditingController batchSizeController;
  final EmbeddingSettingsState state;
  final VoidCallback onSave;
  final VoidCallback onTest;
  final VoidCallback onRebuild;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.retrievalSettingsProviderTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('embedding-display-name-field'),
              controller: displayNameController,
              decoration: InputDecoration(
                labelText: l10n.retrievalSettingsDisplayNameLabel,
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('embedding-endpoint-field'),
              controller: endpointController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.retrievalSettingsEndpointLabel,
                prefixIcon: const Icon(Icons.link_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('embedding-model-field'),
              controller: modelController,
              decoration: InputDecoration(
                labelText: l10n.retrievalSettingsModelLabel,
                prefixIcon: const Icon(Icons.hub_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('embedding-api-key-field'),
              controller: apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.retrievalSettingsApiKeyLabel,
                hintText: state.provider?.apiKey.trim().isNotEmpty ?? false
                    ? l10n.retrievalSettingsApiKeyKeptHint
                    : null,
                prefixIcon: const Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('embedding-batch-size-field'),
              controller: batchSizeController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: l10n.retrievalSettingsBatchSizeLabel,
                prefixIcon: const Icon(Icons.view_stream_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('embedding-save-button'),
                  onPressed: onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.saveButton),
                ),
                OutlinedButton.icon(
                  key: const Key('embedding-test-button'),
                  onPressed:
                      state.connection.status ==
                          EmbeddingConnectionStatus.testing
                      ? null
                      : onTest,
                  icon: const Icon(Icons.network_check_outlined),
                  label: Text(l10n.retrievalSettingsTestAction),
                ),
                OutlinedButton.icon(
                  key: const Key('embedding-rebuild-button'),
                  onPressed: onRebuild,
                  icon: const Icon(Icons.refresh_outlined),
                  label: Text(l10n.retrievalSettingsRebuildAction),
                ),
                if (onDelete != null)
                  TextButton.icon(
                    key: const Key('embedding-delete-button'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.retrievalSettingsDeleteAction),
                  ),
              ],
            ),
            if (state.connection.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                state.connection.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      state.connection.status ==
                          EmbeddingConnectionStatus.failed
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
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
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/settings');
}
