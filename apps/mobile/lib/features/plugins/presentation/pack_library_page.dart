import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/pack_catalog.dart';

class PackLibraryPage extends ConsumerWidget {
  const PackLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(packLibraryControllerProvider);
    final controller = ref.read(packLibraryControllerProvider.notifier);
    return ListView(
      key: const Key('pack-library-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.packLibraryTitle,
          subtitle: l10n.packLibrarySubtitle,
        ),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.inventory_2_outlined,
          title: l10n.packLibraryInstalledTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(label: l10n.packLibraryEnabledCount(state.enabledCount)),
                  _Tag(
                    label: l10n.packLibraryDisabledCount(state.disabledCount),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.packLibraryDisableImpact, style: _mutedStyle(context)),
              const SizedBox(height: 12),
              for (var index = 0; index < state.packs.length; index++) ...[
                if (index > 0) const Divider(height: 20),
                _PackRow(
                  pack: state.packs[index],
                  onToggle: (enabled) {
                    controller.setEnabled(state.packs[index].id, enabled);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack, required this.onToggle});

  final PackLibraryPack pack;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = pack.lastFailure;
    return Row(
      key: Key('pack-row-${pack.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          pack.isEnabled ? Icons.extension_outlined : Icons.extension_off,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _packName(l10n, pack),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    key: Key('pack-toggle-${pack.id}'),
                    value: pack.isEnabled,
                    onChanged: onToggle,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_packDescription(l10n, pack), style: _mutedStyle(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Tag(label: pack.id),
                  _Tag(label: l10n.packLibraryVersion(pack.version)),
                  _Tag(
                    key: Key('pack-status-${pack.id}'),
                    label: _packStatusLabel(l10n, pack.status),
                  ),
                  _Tag(label: _runtimeStatusLabel(l10n, pack.runtimeStatus)),
                  _Tag(label: l10n.packLibraryPublisher(pack.publisher)),
                  _Tag(label: l10n.packLibraryEdition(pack.edition)),
                  _Tag(
                    key: Key('pack-marketplace-source-${pack.id}'),
                    label: l10n.packLibraryMarketplaceSource(
                      pack.marketplaceSource,
                    ),
                  ),
                  _Tag(
                    key: Key('pack-trust-${pack.id}'),
                    label: l10n.packLibraryTrustLevel(pack.trustLevel),
                  ),
                  if (pack.categories.isNotEmpty)
                    _Tag(
                      key: Key('pack-categories-${pack.id}'),
                      label: l10n.packLibraryCategories(
                        pack.categories.join(', '),
                      ),
                    ),
                  if (pack.capabilities.isNotEmpty)
                    _Tag(
                      key: Key('pack-capabilities-${pack.id}'),
                      label: l10n.packLibraryCapabilities(
                        pack.capabilities.join(', '),
                      ),
                    ),
                  if (pack.replacementSlots.isNotEmpty)
                    _Tag(
                      key: Key('pack-replacement-slots-${pack.id}'),
                      label: l10n.packLibraryReplacementSlots(
                        pack.replacementSlots.join(', '),
                      ),
                    ),
                  if (pack.additiveSlots.isNotEmpty)
                    _Tag(
                      key: Key('pack-additive-slots-${pack.id}'),
                      label: l10n.packLibraryAdditiveSlots(
                        pack.additiveSlots.join(', '),
                      ),
                    ),
                  _Tag(label: l10n.packLibraryEntrypoint(pack.entrypointKind)),
                  _Tag(
                    label: l10n.packLibraryPermissionCount(
                      pack.permissions.length,
                    ),
                  ),
                  _Tag(
                    label: l10n.packLibraryOutputCount(
                      pack.outputEvents.length,
                    ),
                  ),
                  _Tag(
                    label: l10n.packLibrarySubscriptionCount(
                      pack.enabledSubscriptionCount,
                    ),
                  ),
                  _Tag(label: l10n.packLibraryFailureCount(pack.failureCount)),
                  _Tag(
                    label: l10n.packLibraryPermissionDecisionSummary(
                      pack.permissionDecisionCounts.granted,
                      pack.permissionDecisionCounts.denied,
                      pack.permissionDecisionCounts.revoked,
                    ),
                  ),
                ],
              ),
              if (failure != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.packLibraryLastFailure(
                    failure.isRedacted
                        ? l10n.traceConsoleRedactedValue
                        : failure.message,
                  ),
                  key: Key('pack-last-failure-${pack.id}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
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
        Text(subtitle, style: _mutedStyle(context)),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, super.key});

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

String _packName(AppLocalizations l10n, PackLibraryPack pack) {
  return switch (pack.id) {
    'pack.default' => l10n.packDefaultName,
    'pack.todo' => l10n.packTodoName,
    _ => pack.name,
  };
}

String _packDescription(AppLocalizations l10n, PackLibraryPack pack) {
  return switch (pack.id) {
    'pack.default' => l10n.packDefaultDescription,
    'pack.todo' => l10n.packTodoDescription,
    _ => pack.description,
  };
}

String _packStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'enabled' => l10n.packLibraryStatusEnabled,
    'disabled' => l10n.packLibraryStatusDisabled,
    _ => l10n.packLibraryStatusUnknown(status),
  };
}

String _runtimeStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'idle' => l10n.packLibraryRuntimeIdle,
    'queued' => l10n.packLibraryRuntimeQueued,
    'running' => l10n.packLibraryRuntimeRunning,
    'succeeded' => l10n.packLibraryRuntimeSucceeded,
    'failed' => l10n.packLibraryRuntimeFailed,
    'denied' => l10n.packLibraryRuntimeDenied,
    'canceled' => l10n.packLibraryRuntimeCanceled,
    'blocked' => l10n.packLibraryRuntimeBlocked,
    _ => l10n.packLibraryRuntimeUnknown(status),
  };
}

TextStyle? _mutedStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
