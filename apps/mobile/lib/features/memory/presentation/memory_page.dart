import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/memory_controller.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(memoryControllerProvider);
    final query = _searchController.text;
    return ListView(
      key: const Key('memory-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.memoryPageTitle,
          subtitle: l10n.memoryPageSubtitle,
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorLine(text: state.errorMessage!),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('memory-search-field'),
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.memorySearchHint,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _MemorySection(
          title: l10n.memoryActiveSectionTitle,
          emptyText: l10n.memoryActiveEmpty,
          items: _filter(state.activeItems, query),
          showRestore: false,
          onEdit: _editMemory,
          onDelete: _deleteMemory,
          onRestore: _restoreMemory,
        ),
        const SizedBox(height: 16),
        _MemorySection(
          title: l10n.memoryDeletedSectionTitle,
          emptyText: l10n.memoryDeletedEmpty,
          items: _filter(state.deletedItems, query),
          showRestore: true,
          onEdit: _editMemory,
          onDelete: _deleteMemory,
          onRestore: _restoreMemory,
        ),
      ],
    );
  }

  List<MemoryListItem> _filter(List<MemoryListItem> items, String query) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return items;
    }
    return items
        .where((item) {
          final haystack = [
            item.key,
            item.body,
            item.status,
            item.sourceLabel,
            item.memoryType,
            item.confidence,
            item.sensitivity,
          ].join(' ').toLowerCase();
          return tokens.every(haystack.contains);
        })
        .toList(growable: false);
  }

  Future<void> _editMemory(MemoryListItem item) async {
    final nextBody = await showDialog<String>(
      context: context,
      builder: (context) => _MemoryEditDialog(initialBody: item.body),
    );
    if (!mounted || nextBody == null) {
      return;
    }
    ref.read(memoryControllerProvider.notifier).editMemory(item.id, nextBody);
  }

  void _deleteMemory(MemoryListItem item) {
    ref.read(memoryControllerProvider.notifier).deleteMemory(item.id);
  }

  void _restoreMemory(MemoryListItem item) {
    ref.read(memoryControllerProvider.notifier).restoreMemory(item.id);
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.showRestore,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final String title;
  final String emptyText;
  final List<MemoryListItem> items;
  final bool showRestore;
  final ValueChanged<MemoryListItem> onEdit;
  final ValueChanged<MemoryListItem> onDelete;
  final ValueChanged<MemoryListItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: showRestore
          ? Icons.restore_from_trash_outlined
          : Icons.psychology_alt_outlined,
      title: title,
      child: items.isEmpty
          ? Text(emptyText, style: _mutedStyle(context))
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  _MemoryRow(
                    item: items[index],
                    showRestore: showRestore,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onRestore: onRestore,
                  ),
                ],
              ],
            ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({
    required this.item,
    required this.showRestore,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final MemoryListItem item;
  final bool showRestore;
  final ValueChanged<MemoryListItem> onEdit;
  final ValueChanged<MemoryListItem> onDelete;
  final ValueChanged<MemoryListItem> onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      key: Key('memory-list-row-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          showRestore ? Icons.delete_outline : Icons.auto_awesome_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.body,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Tag(label: item.memoryType),
                  _Tag(label: item.confidence),
                  _Tag(label: item.sensitivity),
                  _Tag(label: item.sourceLabel),
                  _Tag(label: l10n.memoryRevisionLabel(item.revision)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    key: Key('memory-edit-${item.id}'),
                    onPressed: showRestore ? null : () => onEdit(item),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.memoryActionEdit),
                  ),
                  if (showRestore)
                    FilledButton.icon(
                      key: Key('memory-restore-${item.id}'),
                      onPressed: () => onRestore(item),
                      icon: const Icon(Icons.restore_outlined),
                      label: Text(l10n.memoryActionRestore),
                    )
                  else
                    TextButton.icon(
                      key: Key('memory-delete-${item.id}'),
                      onPressed: () => onDelete(item),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.memoryActionDelete),
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

class _MemoryEditDialog extends StatefulWidget {
  const _MemoryEditDialog({required this.initialBody});

  final String initialBody;

  @override
  State<_MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<_MemoryEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.memoryEditTitle),
      content: TextField(
        key: const Key('memory-edit-field'),
        controller: _controller,
        minLines: 3,
        maxLines: 6,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const Key('memory-edit-save'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.saveButton),
        ),
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
      key: const Key('memory-error-line'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
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
