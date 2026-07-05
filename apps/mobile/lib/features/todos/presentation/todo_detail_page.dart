import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/todo_controller.dart';

class TodoDetailPage extends ConsumerWidget {
  const TodoDetailPage({required this.todoId, super.key});

  final String todoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(todoControllerProvider);
    final todo = state.itemById(todoId);
    if (todo == null) {
      return Scaffold(
        key: const Key('todo-detail-page'),
        appBar: AppBar(title: Text(l10n.todoDetailTitle)),
        body: Center(child: Text(l10n.todoDetailMissing)),
      );
    }

    return Scaffold(
      key: const Key('todo-detail-page'),
      appBar: AppBar(
        title: Text(l10n.todoDetailTitle),
        actions: [
          if (_sourceTarget(todo) != null)
            IconButton(
              key: Key('todo-detail-source-${todo.id}'),
              tooltip: l10n.todoDetailOpenSource,
              onPressed: () => context.push(_sourceTarget(todo)!),
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      body: ListView(
        key: const Key('todo-detail-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Hero(todo: todo),
          if (todo.subtasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: l10n.todoDetailNextSteps,
              icon: Icons.checklist_outlined,
              child: Column(
                children: [
                  for (final subtask in todo.subtasks)
                    _SubtaskRow(
                      key: Key('todo-detail-subtask-${subtask.id}'),
                      subtask: subtask,
                      completed: todo.isCompleted || subtask.completed,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Section(
            title: l10n.todoDetailSource,
            icon: Icons.link,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(
                  icon: Icons.article_outlined,
                  text: localizedSourceLabel(l10n, todo.sourceLabel),
                ),
                if (todo.body != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    todo.body!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_sourceTarget(todo) != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: Key('todo-detail-source-button-${todo.id}'),
                    onPressed: () => context.push(_sourceTarget(todo)!),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.todoDetailOpenSource),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: l10n.todoDetailWhy,
            icon: Icons.auto_awesome_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(
                  icon: todo.isSchedule
                      ? Icons.event_available_outlined
                      : Icons.checklist_outlined,
                  text: todo.isSchedule
                      ? l10n.todoStatusScheduleCandidate
                      : localizedTodoStatusLabel(l10n, todo.statusLabel),
                ),
                const SizedBox(height: 8),
                _InfoLine(
                  icon: Icons.psychology_alt_outlined,
                  text: localizedTodoReasonLabel(l10n, todo.reasonLabel),
                ),
                const SizedBox(height: 8),
                _InfoLine(
                  icon: Icons.speed_outlined,
                  text: localizedConfidenceLabel(l10n, todo.confidenceLabel),
                ),
                if (todo.scheduledAtLabel != null) ...[
                  const SizedBox(height: 8),
                  _InfoLine(
                    icon: Icons.event_outlined,
                    text: l10n.todoScheduledForLabel(todo.scheduledAtLabel!),
                  ),
                ],
                if (todo.hasDue) ...[
                  const SizedBox(height: 8),
                  _InfoLine(
                    icon: Icons.schedule_outlined,
                    text: _dueLabel(l10n, todo),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomAction(todo: todo),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.todo});

  final TodoListItem todo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  icon: todo.isSchedule
                      ? Icons.event_available_outlined
                      : Icons.checklist_outlined,
                  label: todo.isSchedule
                      ? l10n.todoStatusScheduleCandidate
                      : todo.isCompleted
                      ? l10n.todoStatusCompleted
                      : l10n.todoStatusSuggestedAction,
                ),
                if (todo.completedAt != null)
                  _Chip(
                    icon: Icons.done_all_outlined,
                    label: l10n.todoCompletedAtLabel(
                      _dateLabel(todo.completedAt!),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              localizedTodoTitle(l10n, todo.title),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (todo.isSchedule) ...[
              const SizedBox(height: 10),
              Text(
                l10n.todoDetailScheduleNotice,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (todo.isCompleted) ...[
              const SizedBox(height: 10),
              Text(
                l10n.todoDetailCompletedNotice,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.subtask,
    required this.completed,
    super.key,
  });

  final TodoSubtask subtask;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: completed ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtask.title,
              style: TextStyle(
                decoration: completed ? TextDecoration.lineThrough : null,
                color: completed ? colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends ConsumerWidget {
  const _BottomAction({required this.todo});

  final TodoListItem todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!todo.isAction) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: FilledButton.icon(
        key: Key('todo-detail-toggle-${todo.id}'),
        onPressed: () {
          final controller = ref.read(todoControllerProvider.notifier);
          if (todo.isCompleted) {
            controller.reopen(todo.id);
          } else {
            controller.complete(todo.id);
          }
        },
        icon: Icon(
          todo.isCompleted ? Icons.undo_outlined : Icons.check_circle_outline,
        ),
        label: Text(
          todo.isCompleted ? l10n.todoActionReopen : l10n.todoActionComplete,
        ),
      ),
    );
  }
}

String _dueLabel(AppLocalizations l10n, TodoListItem todo) {
  final dueLabel = todo.dueLabel;
  if (dueLabel != null && dueLabel.isNotEmpty) {
    return l10n.todoDueLabel(dueLabel);
  }
  final dueAt = todo.dueAt;
  if (dueAt == null) {
    return l10n.todoDueNone;
  }
  return l10n.todoDueLabel(_dateLabel(dueAt));
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String? _sourceTarget(TodoListItem todo) {
  final sourceCaptureId = todo.sourceCaptureId;
  if (sourceCaptureId == null || sourceCaptureId.trim().isEmpty) {
    return null;
  }
  return '/timeline/items/${Uri.encodeComponent(sourceCaptureId)}';
}
