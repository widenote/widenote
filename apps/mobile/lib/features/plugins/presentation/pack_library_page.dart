import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../application/pack_catalog.dart';

class PackLibraryPage extends StatelessWidget {
  const PackLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            children: [
              for (var index = 0; index < builtInPacks.length; index++) ...[
                if (index > 0) const Divider(height: 20),
                _PackRow(pack: builtInPacks[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack});

  final BuiltInPackInfo pack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      key: Key('pack-row-${pack.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.extension_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pack.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(pack.description, style: _mutedStyle(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Tag(label: pack.id),
                  _Tag(label: l10n.packLibraryVersion(pack.version)),
                  _Tag(label: pack.status),
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
                ],
              ),
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

TextStyle? _mutedStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
