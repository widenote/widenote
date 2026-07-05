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
    final now = ref.watch(todoNowProvider);
    final split = _splitFlowItems(state, now);
    final focus = _focusItem(split.todayActions, state.actionItems);

    return RefreshIndicator(
      onRefresh: ref.read(todoControllerProvider.notifier).refresh,
      child: ListView(
        key: const Key('todos-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PageHeader(
            title: l10n.todosTitle,
            subtitle: l10n.todoFocusSubtitle(
              state.totalOpenActionCount,
              state.totalScheduleCount,
            ),
          ),
          const SizedBox(height: 12),
          _SearchField(
            onChanged: ref.read(todoControllerProvider.notifier).setSearchQuery,
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorLine(text: localizedTodoError(l10n, state.errorMessage!)),
          ],
          if (!state.hasVisibleItems && state.hasSearch) ...[
            const SizedBox(height: 16),
            _EmptyLine(text: l10n.todoNoMatches),
          ] else ...[
            const SizedBox(height: 16),
            _FocusCard(focus: focus),
            const SizedBox(height: 16),
            _FlowSection(
              key: const Key('todo-flow-today'),
              title: l10n.todoFlowToday,
              count: split.todayItems.length,
              items: split.todayItems,
              emptyText: state.hasSearch ? null : l10n.todoFlowTodayEmpty,
            ),
            _FlowSection(
              key: const Key('todo-flow-later'),
              title: l10n.todoFlowLater,
              count: split.laterItems.length,
              items: split.laterItems,
              emptyText: state.hasSearch ? null : l10n.todoFlowLaterEmpty,
            ),
            _FlowSection(
              key: const Key('todo-flow-completed'),
              title: l10n.todoBucketCompleted,
              count: state.completedItems.length,
              items: state.completedItems,
              emptyText: state.hasSearch ? null : l10n.todoCompletedEmpty,
            ),
          ],
          if (state.quietCount > 0) ...[
            const SizedBox(height: 12),
            _QuietSummary(count: state.quietCount),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      key: const Key('todo-search-field'),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: context.l10n.todoSearchHint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({required this.focus});

  final TodoListItem? focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final focus = this.focus;
    return DecoratedBox(
      key: const Key('todo-focus-card'),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: focus == null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.task_alt_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.todoFocusEmptyTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.todoFocusEmptyBody,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_outlined, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.todoFocusLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    localizedTodoTitle(l10n, focus.title),
                    key: Key('todo-focus-title-${focus.id}'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.todoFocusSourceLinkedBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: Key('todo-focus-open-${focus.id}'),
                        onPressed: () => context.push(
                          '/todos/${Uri.encodeComponent(focus.id)}',
                        ),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(l10n.todoFocusOpenAction),
                      ),
                      OutlinedButton.icon(
                        key: Key('todo-focus-complete-${focus.id}'),
                        onPressed: () => ref
                            .read(todoControllerProvider.notifier)
                            .complete(focus.id),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(l10n.todoActionComplete),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _FlowSection extends StatelessWidget {
  const _FlowSection({
    required this.title,
    required this.count,
    required this.items,
    this.emptyText,
    super.key,
  });

  final String title;
  final int count;
  final List<TodoListItem> items;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyText == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Divider(height: 1, color: colorScheme.outlineVariant),
              ),
              const SizedBox(width: 10),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _EmptyLine(text: emptyText!)
          else
            _TodoList(todos: items),
        ],
      ),
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({required this.todos});

  final List<TodoListItem> todos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < todos.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isCompleted = todo.isCompleted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/todos/${Uri.encodeComponent(todo.id)}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todo.isAction)
                Checkbox(
                  key: Key('todo-checkbox-${todo.id}'),
                  value: todo.isCompleted,
                  onChanged: (_) => _toggle(ref, todo),
                  visualDensity: VisualDensity.compact,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Icon(
                    Icons.event_available_outlined,
                    key: Key('todo-schedule-icon-${todo.id}'),
                    size: 22,
                    color: colorScheme.primary,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedTodoTitle(l10n, todo.title),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationThickness: isCompleted ? 2 : null,
                          color: isCompleted
                              ? colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                      if (todo.body != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          todo.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationThickness: isCompleted ? 2 : null,
                              ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (todo.isSchedule)
                            _Tag(
                              icon: Icons.event_available_outlined,
                              label: l10n.todoStatusScheduleCandidate,
                            ),
                          if (todo.completedAt != null)
                            _Tag(
                              key: Key('todo-completed-at-${todo.id}'),
                              icon: Icons.done_all_outlined,
                              label: l10n.todoCompletedAtLabel(
                                _dateLabel(todo.completedAt!),
                              ),
                            ),
                          if (todo.hasDue)
                            _Tag(
                              key: Key('todo-due-${todo.id}'),
                              icon: Icons.schedule_outlined,
                              label: _dueLabel(l10n, todo),
                            ),
                          if (todo.scheduledAtLabel != null)
                            _Tag(
                              key: Key('todo-schedule-${todo.id}'),
                              icon: Icons.event_outlined,
                              label: l10n.todoScheduledForLabel(
                                todo.scheduledAtLabel!,
                              ),
                            ),
                          _Tag(
                            icon: Icons.link,
                            label: localizedSourceLabel(l10n, todo.sourceLabel),
                          ),
                          if (todo.subtasks.isNotEmpty)
                            _Tag(
                              key: Key('todo-subtasks-${todo.id}'),
                              icon: Icons.checklist_outlined,
                              label: l10n.todoSubtaskProgress(
                                todo.subtasks
                                    .where((subtask) => subtask.completed)
                                    .length,
                                todo.subtasks.length,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isCompleted)
                IconButton(
                  key: Key('todo-reopen-${todo.id}'),
                  tooltip: l10n.todoActionReopen,
                  onPressed: () =>
                      ref.read(todoControllerProvider.notifier).reopen(todo.id),
                  icon: const Icon(Icons.undo_outlined),
                  color: colorScheme.primary,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
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
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, super.key});

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
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

_FlowSplit _splitFlowItems(TodoState state, DateTime now) {
  final todaySchedules = <TodoListItem>[];
  final laterSchedules = <TodoListItem>[];
  for (final item in state.scheduleItems) {
    if (_isSameLocalDay(item.scheduledStart, now)) {
      todaySchedules.add(item);
    } else {
      laterSchedules.add(item);
    }
  }
  final todayActions = <TodoListItem>[
    ...state.overdueItems,
    ...state.todayItems,
  ];
  return _FlowSplit(
    todayActions: todayActions,
    todayItems: <TodoListItem>[...todayActions, ...todaySchedules],
    laterItems: <TodoListItem>[
      ...state.tomorrowItems,
      ...state.laterItems,
      ...state.noDeadlineItems,
      ...laterSchedules,
    ],
  );
}

TodoListItem? _focusItem(
  List<TodoListItem> todayActions,
  List<TodoListItem> actionItems,
) {
  if (todayActions.isNotEmpty) {
    return todayActions.first;
  }
  if (actionItems.isNotEmpty) {
    return actionItems.first;
  }
  return null;
}

bool _isSameLocalDay(DateTime? value, DateTime now) {
  if (value == null) {
    return false;
  }
  final local = value.toLocal();
  final today = now.toLocal();
  return local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
}

final class _FlowSplit {
  const _FlowSplit({
    required this.todayActions,
    required this.todayItems,
    required this.laterItems,
  });

  final List<TodoListItem> todayActions;
  final List<TodoListItem> todayItems;
  final List<TodoListItem> laterItems;
}
