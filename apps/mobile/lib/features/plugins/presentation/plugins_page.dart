import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../model_providers/application/model_provider_settings_controller.dart';
import 'agent_platform_panel.dart';

class PluginsPage extends StatelessWidget {
  const PluginsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('plugins-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(title: l10n.pluginsTitle, subtitle: l10n.pluginsSubtitle),
        const SizedBox(height: 16),
        const _ControlList(),
        const SizedBox(height: 16),
        const AgentPlatformPanel(),
      ],
    );
  }
}

class _ControlList extends ConsumerWidget {
  const _ControlList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final providerState = ref
        .watch(modelProviderSettingsControllerProvider)
        .valueOrNull;
    return _Surface(
      icon: Icons.extension_outlined,
      title: l10n.pluginsControlEntriesTitle,
      child: Column(
        children: [
          _ControlRow(
            icon: Icons.inventory_2_outlined,
            title: l10n.pluginsPackLibraryTitle,
            subtitle: l10n.pluginsPackLibrarySubtitle,
            status: l10n.pluginsPackLibraryStatus,
          ),
          const Divider(height: 20),
          _ControlRow(
            icon: Icons.verified_user_outlined,
            title: l10n.pluginsPermissionGateTitle,
            subtitle: l10n.pluginsPermissionGateSubtitle,
            status: l10n.pluginsPermissionGateStatus,
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('model-provider-entry'),
            icon: Icons.memory_outlined,
            title: l10n.pluginsModelProviderTitle,
            subtitle: l10n.pluginsModelProviderSubtitle,
            status: _providerStatus(l10n, providerState),
            onTap: () => context.go('/plugins/model-providers'),
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('backup-entry'),
            icon: Icons.backup_outlined,
            title: l10n.pluginsBackupTitle,
            subtitle: l10n.pluginsBackupSubtitle,
            status: l10n.pluginsBackupStatus,
            onTap: () => context.go('/plugins/backup'),
          ),
          const Divider(height: 20),
          _ControlRow(
            icon: Icons.account_tree_outlined,
            title: l10n.pluginsTraceConsoleTitle,
            subtitle: l10n.pluginsTraceConsoleSubtitle,
            status: l10n.pluginsTraceConsoleStatus,
          ),
        ],
      ),
    );
  }

  String _providerStatus(
    AppLocalizations l10n,
    ModelProviderSettingsState? state,
  ) {
    if (state == null || state.providers.isEmpty) {
      return l10n.pluginsModelProviderStatus;
    }
    final hasConnectedProvider = state.connectionResults.values.any(
      (connection) => connection.status == ProviderConnectionStatus.succeeded,
    );
    if (hasConnectedProvider) {
      return l10n.providerConnectionConnected;
    }
    return l10n.pluginsModelProviderConfigured(state.providers.length);
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Chip(visualDensity: VisualDensity.compact, label: Text(status)),
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: row,
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
