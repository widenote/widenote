import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../capture/application/capture_controller.dart';
import '../../capture/domain/capture_models.dart';

class TodosPage extends ConsumerWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final todos = ref.watch(captureControllerProvider).todos;

    return ListView(
      key: const Key('todos-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(title: l10n.todosTitle, subtitle: l10n.todosSubtitle),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.checklist_outlined,
          title: l10n.todosSurfaceTitle,
          child: _TodoList(todos: todos),
        ),
      ],
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({required this.todos});

  final List<SourceTodo> todos;

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      return Text(
        context.l10n.todosEmpty,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < todos.length; index++) ...[
          if (index > 0) const Divider(height: 20),
          _TodoRow(key: Key('todo-row-${todos[index].id}'), todo: todos[index]),
        ],
      ],
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo, super.key});

  final SourceTodo todo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: false, onChanged: null),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localizedTodoTitle(l10n, todo.title),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Tag(
                      icon: Icons.link,
                      label: _localizedTodoSourceLabel(l10n, todo.sourceLabel),
                    ),
                    _Tag(
                      icon: Icons.info_outline,
                      label: _localizedTodoStatusLabel(l10n, todo.statusLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _localizedTodoTitle(AppLocalizations l10n, String title) {
  if (title.startsWith('Follow up: ')) {
    return l10n.todoFollowUpTitle(title.substring('Follow up: '.length));
  }
  return switch (title) {
    'Review generated Memory before export' => l10n.todoSeedReviewMemory,
    'Confirm backup permission boundary' => l10n.todoSeedConfirmBackup,
    _ => title,
  };
}

String _localizedTodoSourceLabel(AppLocalizations l10n, String sourceLabel) {
  if (sourceLabel.startsWith('source: ')) {
    final sourceId = sourceLabel.substring('source: '.length);
    return l10n.todoSourceLabel(sourceId);
  }
  return sourceLabel;
}

String _localizedTodoStatusLabel(AppLocalizations l10n, String statusLabel) {
  return switch (statusLabel) {
    'needs explicit permission' => l10n.todoStatusNeedsExplicitPermission,
    'suggested by agent' => l10n.todoStatusSuggestedByAgent,
    _ => statusLabel,
  };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
