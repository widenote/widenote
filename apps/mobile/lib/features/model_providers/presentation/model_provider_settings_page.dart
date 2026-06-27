import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_model_providers/model_providers.dart';

import '../../../l10n/l10n.dart';
import '../application/model_provider_settings_controller.dart';

const _visibleProviderKinds = <ModelProviderKind>[
  ModelProviderKind.openAiCompatible,
  ModelProviderKind.anthropicCompatible,
  ModelProviderKind.mimo,
  ModelProviderKind.kimi,
];

class ModelProviderSettingsPage extends ConsumerWidget {
  const ModelProviderSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(modelProviderSettingsControllerProvider);

    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => ListView(
        key: const Key('model-provider-settings-page'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          const _PageHeader(),
          const SizedBox(height: 16),
          _ErrorLine(
            text: localizedProviderSettingsError(context.l10n, '$error'),
          ),
        ],
      ),
      data: (state) => ListView(
        key: const Key('model-provider-settings-page'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          const _PageHeader(),
          const SizedBox(height: 16),
          if (state.errorMessage != null) ...[
            _ErrorLine(
              text: localizedProviderSettingsError(
                context.l10n,
                state.errorMessage!,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('provider-add-button'),
              onPressed: () => _showProviderDialog(context),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.providerSettingsAdd),
            ),
          ),
          const SizedBox(height: 16),
          _RuntimeStatusSurface(state: state),
          const SizedBox(height: 12),
          _ProviderList(state: state),
          const SizedBox(height: 12),
          _ModelRolesSurface(state: state),
          const SizedBox(height: 12),
          _CapabilitiesSurface(state: state),
        ],
      ),
    );
  }

  void _showProviderDialog(
    BuildContext context, {
    ModelProviderConfig? provider,
  }) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => _ProviderFormDialog(existing: provider),
      ),
    );
  }
}

class _ProviderList extends ConsumerWidget {
  const _ProviderList({required this.state});

  final ModelProviderSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (state.providers.isEmpty) {
      return _Surface(
        icon: Icons.memory_outlined,
        title: l10n.providerSettingsListTitle,
        child: Text(l10n.providerSettingsEmpty),
      );
    }

    return _Surface(
      icon: Icons.memory_outlined,
      title: l10n.providerSettingsListTitle,
      child: Column(
        children: [
          for (var index = 0; index < state.providers.length; index++) ...[
            if (index > 0) const Divider(height: 20),
            _ProviderRow(
              provider: state.providers[index],
              isDefault: state.providers[index].id == state.defaultProviderId,
              connection: state.connectionFor(state.providers[index].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuntimeStatusSurface extends StatelessWidget {
  const _RuntimeStatusSurface({required this.state});

  final ModelProviderSettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = state.defaultProvider;
    return _Surface(
      icon: Icons.radio_button_checked,
      title: l10n.providerSettingsStatusTitle,
      description: provider == null
          ? l10n.providerSettingsStatusDescriptionOffline
          : l10n.providerSettingsStatusDescriptionConfigured,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider == null
                ? l10n.providerSettingsStatusNotConfigured
                : l10n.providerSettingsStatusConfigured(provider.displayName),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Tag(
                label: l10n.providerSettingsProviderCount(
                  state.providers.length,
                ),
              ),
              if (provider != null) _Tag(label: provider.model),
              if (provider == null)
                _Tag(label: l10n.providerSettingsCapabilityOfflineFallback),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelRolesSurface extends StatelessWidget {
  const _ModelRolesSurface({required this.state});

  final ModelProviderSettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = state.defaultProvider;
    final roleValue = provider == null
        ? l10n.providerSettingsRoleFallback
        : '${provider.displayName} / ${provider.model}';
    return _Surface(
      icon: Icons.tune_outlined,
      title: l10n.providerSettingsRolesTitle,
      description: l10n.providerSettingsRolesDescription,
      child: Column(
        children: [
          _RoleTile(
            icon: Icons.notes_outlined,
            title: l10n.providerSettingsTextRoleTitle,
            description: l10n.providerSettingsTextRoleDescription,
            value: roleValue,
          ),
          const Divider(height: 20),
          _RoleTile(
            icon: Icons.account_tree_outlined,
            title: l10n.providerSettingsAgentRoleTitle,
            description: l10n.providerSettingsAgentRoleDescription,
            value: provider == null
                ? l10n.providerSettingsRoleFallback
                : l10n.providerSettingsDefaultTag,
          ),
        ],
      ),
    );
  }
}

class _CapabilitiesSurface extends StatelessWidget {
  const _CapabilitiesSurface({required this.state});

  final ModelProviderSettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = state.defaultProvider;
    final capabilityLabels = provider == null
        ? <String>[l10n.providerSettingsCapabilityOfflineFallback]
        : provider.capabilities
              .map((capability) {
                return _capabilityLabel(l10n, capability);
              })
              .toList(growable: false);
    return _Surface(
      icon: Icons.privacy_tip_outlined,
      title: l10n.providerSettingsCapabilitiesTitle,
      description: l10n.providerSettingsCapabilitiesDescription,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final label in capabilityLabels) _Tag(label: label),
          _Tag(label: l10n.providerSettingsCapabilityByok),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String description;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [_Tag(label: value)]),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderRow extends ConsumerWidget {
  const _ProviderRow({
    required this.provider,
    required this.isDefault,
    required this.connection,
  });

  final ModelProviderConfig provider;
  final bool isDefault;
  final ProviderConnectionSnapshot connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Row(
      key: Key('provider-row-${provider.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.hub_outlined, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.displayName,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${provider.model} · ${_endpointLabel(provider.endpoint)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Tag(label: provider.kind.label),
                  if (isDefault) _Tag(label: l10n.providerSettingsDefaultTag),
                  for (final capability in provider.capabilities)
                    _Tag(label: _capabilityLabel(l10n, capability)),
                  _Tag(label: _connectionLabel(l10n, connection)),
                ],
              ),
              if (connection.message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  localizedProviderConnectionMessage(l10n, connection.message),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ProviderActions(provider: provider),
      ],
    );
  }

  String _connectionLabel(
    AppLocalizations l10n,
    ProviderConnectionSnapshot connection,
  ) {
    return switch (connection.status) {
      ProviderConnectionStatus.idle => l10n.providerConnectionUntested,
      ProviderConnectionStatus.testing => l10n.providerConnectionTesting,
      ProviderConnectionStatus.succeeded => l10n.providerConnectionConnected,
      ProviderConnectionStatus.failed => l10n.providerConnectionFailed,
    };
  }
}

class _ProviderActions extends ConsumerWidget {
  const _ProviderActions({required this.provider});

  final ModelProviderConfig provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(
      modelProviderSettingsControllerProvider.notifier,
    );
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          key: Key('provider-default-${provider.id}'),
          tooltip: l10n.providerActionSetDefault,
          onPressed: () =>
              unawaited(controller.setDefaultProvider(provider.id)),
          icon: const Icon(Icons.star_outline),
        ),
        IconButton(
          key: Key('provider-test-${provider.id}'),
          tooltip: l10n.providerActionTestConnection,
          onPressed: () => unawaited(controller.testProvider(provider.id)),
          icon: const Icon(Icons.network_check),
        ),
        IconButton(
          key: Key('provider-edit-${provider.id}'),
          tooltip: l10n.providerActionEdit,
          onPressed: () => unawaited(
            showDialog<void>(
              context: context,
              builder: (context) => _ProviderFormDialog(existing: provider),
            ),
          ),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: Key('provider-delete-${provider.id}'),
          tooltip: l10n.providerActionDelete,
          onPressed: () => unawaited(_confirmDeleteProvider(context, ref)),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteProvider(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.providerDeleteTitle),
        content: Text(l10n.providerDeleteBody(provider.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: Key('provider-confirm-delete-${provider.id}'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.memoryActionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await ref
        .read(modelProviderSettingsControllerProvider.notifier)
        .deleteProvider(provider.id);
  }
}

class _ProviderFormDialog extends ConsumerStatefulWidget {
  const _ProviderFormDialog({this.existing});

  final ModelProviderConfig? existing;

  @override
  ConsumerState<_ProviderFormDialog> createState() =>
      _ProviderFormDialogState();
}

class _ProviderFormDialogState extends ConsumerState<_ProviderFormDialog> {
  late ModelProviderKind _kind;
  late final TextEditingController _nameController;
  late final TextEditingController _endpointController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  bool _clearSavedKey = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final existingKind = existing?.kind;
    _kind = existingKind != null && _visibleProviderKinds.contains(existingKind)
        ? existingKind
        : ModelProviderKind.openAiCompatible;
    _nameController = TextEditingController(
      text: existing?.displayName ?? _kind.label,
    );
    _endpointController = TextEditingController(
      text: (existing?.endpoint ?? _kind.defaultEndpoint).toString(),
    );
    _modelController = TextEditingController(
      text: existing?.model ?? _kind.defaultModel,
    );
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _endpointController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? l10n.providerDialogAddTitle
            : l10n.providerDialogEditTitle,
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ModelProviderKind>(
                key: const Key('provider-kind-field'),
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: l10n.providerFieldProviderType,
                ),
                items: [
                  for (final kind in _visibleProviderKinds)
                    DropdownMenuItem(value: kind, child: Text(kind.label)),
                ],
                onChanged: (kind) {
                  if (kind != null) {
                    _applyKind(kind);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('provider-name-field'),
                controller: _nameController,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.providerFieldDisplayName,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('provider-endpoint-field'),
                controller: _endpointController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: true,
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(
                  labelText: l10n.providerFieldEndpoint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('provider-model-field'),
                controller: _modelController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(labelText: l10n.providerFieldModel),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('provider-api-key-field'),
                controller: _apiKeyController,
                enabled: !_clearSavedKey,
                keyboardType: TextInputType.text,
                autocorrect: false,
                enableSuggestions: true,
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(
                  labelText: l10n.providerFieldApiKey,
                  helperText: widget.existing == null
                      ? null
                      : l10n.providerApiKeyKeepSessionHelper,
                ),
              ),
              if (_hasSavedApiKey) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const Key('provider-clear-key-checkbox'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _clearSavedKey,
                  title: Text(l10n.providerClearKeyTitle),
                  subtitle: Text(l10n.providerClearKeySubtitle),
                  onChanged: (value) {
                    setState(() {
                      _clearSavedKey = value ?? false;
                      if (_clearSavedKey) {
                        _apiKeyController.clear();
                      }
                    });
                  },
                ),
              ],
              if (_localError != null) ...[
                const SizedBox(height: 12),
                _ErrorLine(
                  text: localizedProviderSettingsError(l10n, _localError!),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('provider-save-button'),
          onPressed: () => unawaited(_saveProvider()),
          child: Text(l10n.saveButton),
        ),
      ],
    );
  }

  void _applyKind(ModelProviderKind kind) {
    setState(() {
      _kind = kind;
      _nameController.text = kind.label;
      _endpointController.text = kind.defaultEndpoint.toString();
      _modelController.text = kind.defaultModel;
      _localError = null;
    });
  }

  Future<void> _saveProvider() async {
    final l10n = context.l10n;
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint == null) {
      setState(() => _localError = l10n.providerInvalidEndpoint);
      return;
    }

    final config = ModelProviderConfig(
      id: widget.existing?.id ?? _newProviderId(_nameController.text),
      kind: _kind,
      displayName: _nameController.text.trim(),
      endpoint: endpoint,
      model: _modelController.text.trim(),
      apiKey: _nextApiKey(),
    );
    final saved = await ref
        .read(modelProviderSettingsControllerProvider.notifier)
        .saveProvider(config, requireApiKey: !_clearSavedKey);
    if (saved && mounted) {
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) {
      return;
    }

    final state = ref.read(modelProviderSettingsControllerProvider).valueOrNull;
    setState(() {
      _localError = state?.errorMessage ?? l10n.providerSaveFailed;
    });
  }

  String _nextApiKey() {
    if (_clearSavedKey) {
      return '';
    }
    final nextKey = _apiKeyController.text.trim();
    if (nextKey.isNotEmpty) {
      return nextKey;
    }
    return widget.existing?.apiKey ?? '';
  }

  String _newProviderId(String displayName) {
    final providers =
        ref
            .read(modelProviderSettingsControllerProvider)
            .valueOrNull
            ?.providers ??
        const <ModelProviderConfig>[];
    final base = _slug(displayName).isEmpty ? 'provider' : _slug(displayName);
    var candidate = base;
    var suffix = 2;
    while (providers.any((provider) => provider.id == candidate)) {
      candidate = '$base-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  String _slug(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  bool get _hasSavedApiKey =>
      widget.existing?.apiKey.trim().isNotEmpty ?? false;
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
          l10n.providerSettingsTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.providerSettingsSubtitle,
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
    this.description,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? description;

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
              const SizedBox(height: 6),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

String _endpointLabel(Uri endpoint) {
  if (endpoint.host.isNotEmpty) {
    return endpoint.host;
  }
  return endpoint.toString();
}

String _capabilityLabel(AppLocalizations l10n, ModelCapability capability) {
  return switch (capability) {
    ModelCapability.chat => l10n.providerSettingsCapabilityChat,
    ModelCapability.completion => l10n.providerSettingsCapabilityCompletion,
    _ => capability.name,
  };
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
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
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
