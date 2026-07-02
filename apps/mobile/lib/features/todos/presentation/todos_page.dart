import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/todo_controller.dart';

class TodosPage extends ConsumerWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(todoControllerProvider);

    return ListView(
      key: const Key('todos-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(title: l10n.todosTitle, subtitle: l10n.todosSubtitle),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorLine(text: localizedTodoError(l10n, state.errorMessage!)),
        ],
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.checklist_outlined,
          title: l10n.todoActionsSectionTitle,
          child: _TodoList(
            todos: state.actionItems,
            emptyText: l10n.todoActionsEmpty,
          ),
        ),
        const SizedBox(height: 12),
        _Surface(
          icon: Icons.event_note_outlined,
          title: l10n.todoSchedulesSectionTitle,
          child: _TodoList(
            todos: state.scheduleItems,
            emptyText: l10n.todoSchedulesEmpty,
          ),
        ),
        if (state.quietCount > 0) ...[
          const SizedBox(height: 12),
          _QuietSummary(count: state.quietCount),
        ],
      ],
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({required this.todos, required this.emptyText});

  final List<TodoListItem> todos;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      return Text(
        emptyText,
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

class _TodoRow extends ConsumerWidget {
  const _TodoRow({required this.todo, super.key});

  final TodoListItem todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todo.isAction)
          Checkbox(
            key: Key('todo-checkbox-${todo.id}'),
            value: todo.isCompleted,
            onChanged: (_) => _toggle(ref, todo),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Icon(
              Icons.event_available_outlined,
              key: Key('todo-schedule-icon-${todo.id}'),
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedTodoTitle(l10n, todo.title),
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
                      key: Key('todo-source-${todo.id}'),
                      icon: Icons.link,
                      label: localizedSourceLabel(l10n, todo.sourceLabel),
                      onTap: _sourceTarget(todo) == null
                          ? null
                          : () => context.push(_sourceTarget(todo)!),
                    ),
                    _Tag(
                      icon: Icons.info_outline,
                      label: localizedTodoStatusLabel(l10n, todo.statusLabel),
                    ),
                    if (todo.scheduledAtLabel != null)
                      _Tag(
                        key: Key('todo-schedule-${todo.id}'),
                        icon: Icons.schedule_outlined,
                        label: l10n.todoScheduledForLabel(
                          todo.scheduledAtLabel!,
                        ),
                      ),
                  ],
                ),
                if (todo.isAction) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: Key('todo-toggle-${todo.id}'),
                    onPressed: () => _toggle(ref, todo),
                    icon: Icon(
                      todo.isCompleted
                          ? Icons.refresh_outlined
                          : Icons.check_circle_outline,
                    ),
                    label: Text(
                      todo.isCompleted
                          ? l10n.todoActionReopen
                          : l10n.todoActionComplete,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _toggle(WidgetRef ref, TodoListItem todo) {
    final controller = ref.read(todoControllerProvider.notifier);
    if (todo.isCompleted) {
      controller.reopen(todo.id);
      return;
    }
    controller.complete(todo.id);
  }
}

class _QuietSummary extends StatelessWidget {
  const _QuietSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome_motion_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.todoQuietTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.todoQuietSummary(count),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
}

String? _sourceTarget(TodoListItem todo) {
  final sourceCaptureId = todo.sourceCaptureId;
  if (sourceCaptureId == null || sourceCaptureId.trim().isEmpty) {
    return null;
  }
  return '/timeline/items/${Uri.encodeComponent(sourceCaptureId)}';
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: const Key('todos-error-line'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tag = DecoratedBox(
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
    if (onTap == null) {
      return tag;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: tag,
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
