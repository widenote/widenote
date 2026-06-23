import 'package:flutter/material.dart';

class PluginsPage extends StatelessWidget {
  const PluginsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('plugins-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _PageHeader(
          title: '插件',
          subtitle:
              'Pack controls for permissions, models, backup, and traces.',
        ),
        SizedBox(height: 16),
        _ControlList(),
      ],
    );
  }
}

class _ControlList extends StatelessWidget {
  const _ControlList();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: Icons.extension_outlined,
      title: 'Control entries',
      child: Column(
        children: const [
          _ControlRow(
            icon: Icons.inventory_2_outlined,
            title: 'Pack Library',
            subtitle: 'Install, inspect, and disable Agent Packs.',
            status: 'placeholder',
          ),
          Divider(height: 20),
          _ControlRow(
            icon: Icons.verified_user_outlined,
            title: 'Permission Gate',
            subtitle: 'Review sensitive capabilities before a pack can run.',
            status: 'explicit',
          ),
          Divider(height: 20),
          _ControlRow(
            icon: Icons.memory_outlined,
            title: 'Model Provider',
            subtitle: 'Configure local or BYOK model access.',
            status: 'not connected',
          ),
          Divider(height: 20),
          _ControlRow(
            icon: Icons.backup_outlined,
            title: 'Backup',
            subtitle: 'Prepare optional sync and export controls.',
            status: 'local-first',
          ),
          Divider(height: 20),
          _ControlRow(
            icon: Icons.account_tree_outlined,
            title: 'Trace Console',
            subtitle: 'Inspect pack runs, permissions, and generated outputs.',
            status: 'trace-ready',
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
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
