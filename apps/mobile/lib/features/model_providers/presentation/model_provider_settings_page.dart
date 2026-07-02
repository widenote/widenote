import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_model_providers/model_providers.dart';

import '../../../l10n/l10n.dart';
import '../application/model_provider_settings_controller.dart';

const _visibleProviderPresets = <_ProviderPresetOption>[
  _ProviderPresetOption(
    key: 'openai-chat',
    kind: ModelProviderKind.openAi,
    endpoint: 'https://api.openai.com/v1',
    model: 'gpt-4.1-mini',
  ),
  _ProviderPresetOption(
    key: 'openai-responses',
    kind: ModelProviderKind.openAiResponses,
    endpoint: 'https://api.openai.com/v1',
    model: 'gpt-4.1-mini',
  ),
  _ProviderPresetOption(
    key: 'anthropic-api',
    kind: ModelProviderKind.anthropic,
    endpoint: 'https://api.anthropic.com',
    model: 'claude-sonnet-5',
  ),
  _ProviderPresetOption(
    key: 'gemini-api',
    kind: ModelProviderKind.gemini,
    endpoint: 'https://generativelanguage.googleapis.com/v1beta/openai',
    model: 'gemini-3.5-flash',
  ),
  _ProviderPresetOption(
    key: 'openrouter-api',
    kind: ModelProviderKind.openRouter,
    endpoint: 'https://openrouter.ai/api/v1',
    model: 'openrouter/auto',
  ),
  _ProviderPresetOption(
    key: 'deepseek-openai',
    kind: ModelProviderKind.openAiCompatible,
    endpoint: 'https://api.deepseek.com',
    model: 'deepseek-v4-flash',
  ),
  _ProviderPresetOption(
    key: 'deepseek-anthropic',
    kind: ModelProviderKind.deepSeek,
    endpoint: 'https://api.deepseek.com/anthropic',
    model: 'deepseek-v4-flash',
  ),
  _ProviderPresetOption(
    key: 'kimi-global',
    kind: ModelProviderKind.kimi,
    endpoint: 'https://api.moonshot.ai/v1',
    model: 'kimi-k2.6',
  ),
  _ProviderPresetOption(
    key: 'kimi-china',
    kind: ModelProviderKind.kimi,
    endpoint: 'https://api.moonshot.cn/v1',
    model: 'kimi-k2.6',
  ),
  _ProviderPresetOption(
    key: 'kimi-code',
    kind: ModelProviderKind.openAiCompatible,
    endpoint: 'https://api.kimi.com/coding/v1',
    model: 'kimi-k2.7-code',
    accessMode: ModelProviderAccessMode.codingPlan,
  ),
  _ProviderPresetOption(
    key: 'qwen-china',
    kind: ModelProviderKind.qwen,
    endpoint: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-plus',
  ),
  _ProviderPresetOption(
    key: 'qwen-international',
    kind: ModelProviderKind.qwen,
    endpoint: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-plus',
  ),
  _ProviderPresetOption(
    key: 'doubao-api',
    kind: ModelProviderKind.doubao,
    endpoint: 'https://ark.cn-beijing.volces.com/api/v3',
    model: 'doubao-seed-2-0-lite-260428',
  ),
  _ProviderPresetOption(
    key: 'doubao-coding',
    kind: ModelProviderKind.openAiCompatible,
    endpoint: 'https://ark.cn-beijing.volces.com/api/coding/v3',
    model: 'ark-code-latest',
    accessMode: ModelProviderAccessMode.codingPlan,
  ),
  _ProviderPresetOption(
    key: 'zhipu-api',
    kind: ModelProviderKind.zhipu,
    endpoint: 'https://api.z.ai/api/paas/v4',
    model: 'glm-5.2',
  ),
  _ProviderPresetOption(
    key: 'zhipu-coding',
    kind: ModelProviderKind.openAiCompatible,
    endpoint: 'https://api.z.ai/api/coding/paas/v4',
    model: 'glm-5.2',
    accessMode: ModelProviderAccessMode.codingPlan,
  ),
  _ProviderPresetOption(
    key: 'minimax-openai-token',
    kind: ModelProviderKind.openAiCompatible,
    endpoint: 'https://api.minimax.io/v1',
    model: 'MiniMax-M3',
    accessMode: ModelProviderAccessMode.tokenPlan,
  ),
  _ProviderPresetOption(
    key: 'minimax-anthropic-token',
    kind: ModelProviderKind.miniMax,
    endpoint: 'https://api.minimax.io/anthropic',
    model: 'MiniMax-M3',
    accessMode: ModelProviderAccessMode.tokenPlan,
  ),
  _ProviderPresetOption(
    key: 'mimo-openai-api',
    kind: ModelProviderKind.openAiCompatible,
    endpoint: 'https://api.xiaomimimo.com/v1',
    model: 'mimo-v2.5-pro',
  ),
  _ProviderPresetOption(
    key: 'mimo-anthropic-api',
    kind: ModelProviderKind.mimo,
    endpoint: 'https://api.xiaomimimo.com/anthropic',
    model: 'mimo-v2.5-pro',
  ),
  _ProviderPresetOption(
    key: 'mimo-openai-token-cn',
    kind: ModelProviderKind.openAiCompatible,
    endpoint: 'https://token-plan-cn.xiaomimimo.com/v1',
    model: 'mimo-v2.5-pro',
    accessMode: ModelProviderAccessMode.tokenPlan,
  ),
  _ProviderPresetOption(
    key: 'mimo-anthropic-token-cn',
    kind: ModelProviderKind.mimo,
    endpoint: 'https://token-plan-cn.xiaomimimo.com/anthropic',
    model: 'mimo-v2.5-pro',
    accessMode: ModelProviderAccessMode.tokenPlan,
  ),
  _ProviderPresetOption(
    key: 'ollama-local',
    kind: ModelProviderKind.ollama,
    endpoint: 'http://localhost:11434/v1',
    model: 'qwen2.5:7b',
    accessMode: ModelProviderAccessMode.local,
  ),
  _ProviderPresetOption(
    key: 'custom-openai',
    kind: ModelProviderKind.openAiCompatible,
    endpoint: 'https://api.openai.com/v1/chat/completions',
    model: 'openai-compatible-chat',
  ),
  _ProviderPresetOption(
    key: 'custom-anthropic',
    kind: ModelProviderKind.anthropicCompatible,
    endpoint: 'https://api.anthropic.com/v1/messages',
    model: 'anthropic-compatible-chat',
  ),
];

const _customModelValue = '__widenote_custom_model__';

final class _ProviderPresetOption {
  const _ProviderPresetOption({
    required this.key,
    required this.kind,
    required this.endpoint,
    required this.model,
    this.accessMode = ModelProviderAccessMode.apiKey,
  });

  final String key;
  final ModelProviderKind kind;
  final String endpoint;
  final String model;
  final ModelProviderAccessMode accessMode;

  Uri get endpointUri => Uri.parse(endpoint);
}

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
                  _Tag(
                    label: _accessModeLabel(l10n, provider.effectiveAccessMode),
                  ),
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
  late _ProviderPresetOption _preset;
  late final TextEditingController _nameController;
  late final TextEditingController _endpointController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  List<String> _availableModels = const <String>[];
  bool _isFetchingModels = false;
  bool _isTestingDraft = false;
  bool _isCustomModel = false;
  bool _clearSavedKey = false;
  bool _didLocalizeInitialName = false;
  String? _localError;
  ProviderConnectionSnapshot? _draftConnection;

  ModelProviderKind get _kind => _preset.kind;

  ModelProviderAccessMode get _accessMode => _preset.accessMode;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _preset = _presetFor(existing);
    _nameController = TextEditingController(
      text: existing?.displayName ?? _preset.kind.label,
    );
    _endpointController = TextEditingController(
      text: (existing?.endpoint ?? _preset.endpointUri).toString(),
    );
    _modelController = TextEditingController(
      text: existing?.model ?? _preset.model,
    );
    _apiKeyController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLocalizeInitialName || widget.existing != null) {
      return;
    }
    _didLocalizeInitialName = true;
    _nameController.text = _providerPresetLabel(context.l10n, _preset);
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
              DropdownButtonFormField<String>(
                key: const Key('provider-kind-field'),
                initialValue: _preset.key,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.providerFieldProviderType,
                  helperText: l10n.providerPresetSelectionHelper,
                ),
                items: [
                  for (final preset in _visibleProviderPresets)
                    DropdownMenuItem(
                      value: preset.key,
                      child: Text(
                        _providerPresetLabel(l10n, preset),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (key) {
                  final preset = _presetByKey(key);
                  if (preset != null) {
                    _applyPreset(l10n, preset);
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
                  helperText: l10n.providerEndpointPresetHelper,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.providerFieldModel,
                        helperText: l10n.providerModelPresetHelper,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('provider-model-field'),
                          value: _modelDropdownValue,
                          isExpanded: true,
                          items: _modelDropdownItems(l10n),
                          onChanged: (value) {
                            if (value != null) {
                              _selectModel(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton(
                      key: const Key('provider-fetch-models-button'),
                      tooltip: l10n.providerFetchModelsTooltip,
                      onPressed: _isFetchingModels
                          ? null
                          : () => unawaited(_fetchModels()),
                      icon: _isFetchingModels
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
              if (_isCustomModel) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('provider-custom-model-field'),
                  controller: _modelController,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.providerModelCustomOption,
                    helperText: l10n.providerModelCustomHelper,
                  ),
                ),
              ],
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
                  helperText: _apiKeyHelperText(l10n),
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('provider-test-draft-button'),
                  onPressed: _isTestingDraft
                      ? null
                      : () => unawaited(_testDraftProvider()),
                  icon: _isTestingDraft
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: Text(l10n.providerActionTestConnection),
                ),
              ),
              if (_draftConnection != null) ...[
                const SizedBox(height: 8),
                _ConnectionLine(connection: _draftConnection!),
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

  void _applyPreset(AppLocalizations l10n, _ProviderPresetOption preset) {
    setState(() {
      _preset = preset;
      _nameController.text = _providerPresetLabel(l10n, preset);
      _endpointController.text = preset.endpoint;
      _modelController.text = preset.model;
      _availableModels = const <String>[];
      _isCustomModel = false;
      _draftConnection = null;
      _localError = null;
    });
  }

  Future<void> _fetchModels() async {
    if (_isFetchingModels) {
      return;
    }
    final l10n = context.l10n;
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint == null) {
      setState(() => _localError = l10n.providerInvalidEndpoint);
      return;
    }
    final apiKey = _nextApiKey();
    if (_kind.requiresApiKey && apiKey.trim().isEmpty) {
      setState(() => _localError = l10n.providerModelFetchRequiresApiKey);
      return;
    }

    setState(() {
      _isFetchingModels = true;
      _localError = null;
    });
    final result = await ref
        .read(modelProviderModelListServiceProvider)
        .listModels(
          ModelProviderConfig(
            id: widget.existing?.id ?? _newProviderId(_nameController.text),
            kind: _kind,
            displayName: _nameController.text.trim().isEmpty
                ? _providerPresetLabel(l10n, _preset)
                : _nameController.text.trim(),
            endpoint: endpoint,
            model: _modelController.text.trim().isEmpty
                ? _preset.model
                : _modelController.text.trim(),
            apiKey: apiKey,
            accessMode: _accessMode,
          ),
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _isFetchingModels = false;
      if (result.succeeded && result.models.isNotEmpty) {
        _availableModels = result.models;
        final current = _modelController.text.trim();
        _modelController.text = result.models.contains(current)
            ? current
            : result.models.first;
        _isCustomModel = false;
        _localError = null;
        return;
      }
      _localError = result.succeeded
          ? l10n.providerModelFetchEmpty
          : _modelFetchFailureText(l10n, result.errorKind);
    });
  }

  Future<void> _saveProvider() async {
    final l10n = context.l10n;
    final config = _draftConfig(l10n);
    if (config == null) {
      return;
    }
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

  Future<void> _testDraftProvider() async {
    if (_isTestingDraft) {
      return;
    }
    final l10n = context.l10n;
    final config = _draftConfig(l10n);
    if (config == null) {
      return;
    }
    setState(() {
      _isTestingDraft = true;
      _draftConnection = ProviderConnectionSnapshot(
        status: ProviderConnectionStatus.testing,
        message: l10n.providerTestingConnectionMessage,
      );
      _localError = null;
    });
    final result = await ref
        .read(modelProviderSettingsControllerProvider.notifier)
        .testDraftProvider(config);
    if (!mounted) {
      return;
    }
    setState(() {
      _isTestingDraft = false;
      _draftConnection = ProviderConnectionSnapshot(
        status: result.succeeded
            ? ProviderConnectionStatus.succeeded
            : ProviderConnectionStatus.failed,
        message: result.message,
      );
    });
  }

  ModelProviderConfig? _draftConfig(AppLocalizations l10n) {
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint == null) {
      setState(() => _localError = l10n.providerInvalidEndpoint);
      return null;
    }
    return ModelProviderConfig(
      id: widget.existing?.id ?? _newProviderId(_nameController.text),
      kind: _kind,
      displayName: _nameController.text.trim(),
      endpoint: endpoint,
      model: _modelController.text.trim(),
      apiKey: _nextApiKey(),
      accessMode: _accessMode,
    );
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
    final displaySlug = _slug(displayName);
    final presetSlug = _slug(_preset.key);
    final base =
        displaySlug.isEmpty || displaySlug == 'api' || displaySlug == 'plan'
        ? presetSlug
        : displaySlug;
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

  List<String> get _modelOptions {
    final values = <String>[];
    values.addAll(
      _availableModels.isEmpty ? <String>[_preset.model] : _availableModels,
    );
    final current = _modelController.text.trim();
    if (!_isCustomModel && current.isNotEmpty && !values.contains(current)) {
      values.insert(0, current);
    }
    return values;
  }

  String get _modelDropdownValue {
    if (_isCustomModel) {
      return _customModelValue;
    }
    final current = _modelController.text.trim();
    if (current.isNotEmpty) {
      return current;
    }
    return _modelOptions.first;
  }

  List<DropdownMenuItem<String>> _modelDropdownItems(AppLocalizations l10n) {
    return <DropdownMenuItem<String>>[
      for (final model in _modelOptions)
        DropdownMenuItem<String>(
          value: model,
          child: Text(model, overflow: TextOverflow.ellipsis),
        ),
      DropdownMenuItem<String>(
        value: _customModelValue,
        child: Text(l10n.providerModelCustomOption),
      ),
    ];
  }

  void _selectModel(String value) {
    setState(() {
      if (value == _customModelValue) {
        _isCustomModel = true;
      } else {
        _isCustomModel = false;
        _modelController.text = value;
      }
      _localError = null;
    });
  }

  String? _apiKeyHelperText(AppLocalizations l10n) {
    if (!_kind.requiresApiKey) {
      return l10n.providerApiKeyOptionalHelper;
    }
    if (widget.existing != null) {
      return l10n.providerApiKeyKeepSessionHelper;
    }
    return null;
  }

  String _modelFetchFailureText(
    AppLocalizations l10n,
    ModelProviderErrorKind? errorKind,
  ) {
    return switch (errorKind) {
      ModelProviderErrorKind.authentication =>
        l10n.providerModelFetchAuthenticationFailed,
      ModelProviderErrorKind.rateLimited => l10n.providerModelFetchRateLimited,
      ModelProviderErrorKind.timeout => l10n.providerModelFetchTimedOut,
      ModelProviderErrorKind.server => l10n.providerModelFetchServerFailed,
      _ => l10n.providerModelFetchFailed,
    };
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

_ProviderPresetOption _presetFor(ModelProviderConfig? config) {
  if (config == null) {
    return _visibleProviderPresets.first;
  }
  for (final preset in _visibleProviderPresets) {
    if (preset.kind == config.kind &&
        preset.endpointUri.toString() == config.endpoint.toString() &&
        preset.model == config.model &&
        preset.accessMode == config.effectiveAccessMode) {
      return preset;
    }
  }
  for (final preset in _visibleProviderPresets) {
    if (preset.kind == config.kind &&
        preset.accessMode == config.effectiveAccessMode) {
      return preset;
    }
  }
  if (config.kind.usesAnthropicMessages) {
    return _presetByKey('custom-anthropic')!;
  }
  return _presetByKey('custom-openai')!;
}

_ProviderPresetOption? _presetByKey(String? key) {
  if (key == null) {
    return null;
  }
  for (final preset in _visibleProviderPresets) {
    if (preset.key == key) {
      return preset;
    }
  }
  return null;
}

String _providerPresetLabel(
  AppLocalizations l10n,
  _ProviderPresetOption preset,
) {
  return switch (preset.key) {
    'openai-chat' => l10n.providerPresetOpenAiChat,
    'openai-responses' => l10n.providerPresetOpenAiResponses,
    'anthropic-api' => l10n.providerPresetAnthropicApi,
    'gemini-api' => l10n.providerPresetGeminiApi,
    'openrouter-api' => l10n.providerPresetOpenRouterApi,
    'deepseek-openai' => l10n.providerPresetDeepSeekOpenAi,
    'deepseek-anthropic' => l10n.providerPresetDeepSeekAnthropic,
    'kimi-global' => l10n.providerPresetKimiGlobal,
    'kimi-china' => l10n.providerPresetKimiChina,
    'kimi-code' => l10n.providerPresetKimiCode,
    'qwen-china' => l10n.providerPresetQwenChina,
    'qwen-international' => l10n.providerPresetQwenInternational,
    'doubao-api' => l10n.providerPresetDoubaoApi,
    'doubao-coding' => l10n.providerPresetDoubaoCoding,
    'zhipu-api' => l10n.providerPresetZhipuApi,
    'zhipu-coding' => l10n.providerPresetZhipuCoding,
    'minimax-openai-token' => l10n.providerPresetMiniMaxOpenAiToken,
    'minimax-anthropic-token' => l10n.providerPresetMiniMaxAnthropicToken,
    'mimo-openai-api' => l10n.providerPresetMimoOpenAiApi,
    'mimo-anthropic-api' => l10n.providerPresetMimoAnthropicApi,
    'mimo-openai-token-cn' => l10n.providerPresetMimoOpenAiTokenCn,
    'mimo-anthropic-token-cn' => l10n.providerPresetMimoAnthropicTokenCn,
    'ollama-local' => l10n.providerPresetOllamaLocal,
    'custom-openai' => l10n.providerPresetCustomOpenAi,
    'custom-anthropic' => l10n.providerPresetCustomAnthropic,
    _ => preset.kind.label,
  };
}

String _accessModeLabel(
  AppLocalizations l10n,
  ModelProviderAccessMode accessMode,
) {
  return switch (accessMode) {
    ModelProviderAccessMode.apiKey => l10n.providerAccessModeApiKey,
    ModelProviderAccessMode.tokenPlan => l10n.providerAccessModeTokenPlan,
    ModelProviderAccessMode.codingPlan => l10n.providerAccessModeCodingPlan,
    ModelProviderAccessMode.local => l10n.providerAccessModeLocal,
  };
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

class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine({required this.connection});

  final ProviderConnectionSnapshot connection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (connection.status) {
      ProviderConnectionStatus.succeeded => colorScheme.primary,
      ProviderConnectionStatus.failed => colorScheme.error,
      ProviderConnectionStatus.testing => colorScheme.onSurfaceVariant,
      ProviderConnectionStatus.idle => colorScheme.onSurfaceVariant,
    };
    return Row(
      key: const Key('provider-draft-test-result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_connectionIcon(connection.status), size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            localizedProviderConnectionMessage(l10n, connection.message),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

IconData _connectionIcon(ProviderConnectionStatus status) {
  return switch (status) {
    ProviderConnectionStatus.succeeded => Icons.check_circle_outline,
    ProviderConnectionStatus.failed => Icons.error_outline,
    ProviderConnectionStatus.testing => Icons.sync,
    ProviderConnectionStatus.idle => Icons.radio_button_unchecked,
  };
}
