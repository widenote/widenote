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

    return RefreshIndicator(
      onRefresh: ref.read(todoControllerProvider.notifier).refresh,
      child: ListView(
        key: const Key('todos-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PageHeader(title: l10n.todosTitle, subtitle: l10n.todosSubtitle),
          const SizedBox(height: 12),
          TextField(
            key: const Key('todo-search-field'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.todoSearchHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: ref.read(todoControllerProvider.notifier).setSearchQuery,
          ),
          const SizedBox(height: 12),
          _SummaryRow(state: state),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorLine(text: localizedTodoError(l10n, state.errorMessage!)),
          ],
          if (!state.hasVisibleItems && state.hasSearch) ...[
            const SizedBox(height: 16),
            _EmptyLine(text: l10n.todoNoMatches),
          ] else ...[
            const SizedBox(height: 16),
            _BucketSection(
              key: const Key('todo-bucket-overdue'),
              icon: Icons.warning_amber_outlined,
              title: l10n.todoBucketOverdue,
              items: state.overdueItems,
              color: Theme.of(context).colorScheme.error,
            ),
            _BucketSection(
              key: const Key('todo-bucket-today'),
              icon: Icons.today_outlined,
              title: l10n.todoBucketToday,
              items: state.todayItems,
            ),
            _BucketSection(
              key: const Key('todo-bucket-tomorrow'),
              icon: Icons.event_outlined,
              title: l10n.todoBucketTomorrow,
              items: state.tomorrowItems,
            ),
            _BucketSection(
              key: const Key('todo-bucket-later'),
              icon: Icons.date_range_outlined,
              title: l10n.todoBucketLater,
              items: state.laterItems,
            ),
            _BucketSection(
              key: const Key('todo-bucket-no-deadline'),
              icon: Icons.inbox_outlined,
              title: l10n.todoBucketNoDeadline,
              items: state.noDeadlineItems,
            ),
            _BucketSection(
              key: const Key('todo-bucket-schedule'),
              icon: Icons.event_available_outlined,
              title: l10n.todoBucketScheduleCandidates,
              items: state.scheduleItems,
              emptyText: state.hasSearch ? null : l10n.todoSchedulesEmpty,
            ),
            _BucketSection(
              key: const Key('todo-bucket-completed'),
              icon: Icons.check_circle_outline,
              title: l10n.todoBucketCompleted,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.state});

  final TodoState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _Metric(
            value: state.totalOpenActionCount.toString(),
            label: l10n.todoSummaryOpen,
            icon: Icons.checklist_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            value: state.totalScheduleCount.toString(),
            label: l10n.todoSummarySchedule,
            icon: Icons.event_note_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            value: state.totalCompletedCount.toString(),
            label: l10n.todoSummaryCompleted,
            icon: Icons.done_all_outlined,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

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
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketSection extends StatelessWidget {
  const _BucketSection({
    required this.icon,
    required this.title,
    required this.items,
    this.emptyText,
    this.color,
    super.key,
  });

  final IconData icon;
  final String title;
  final List<TodoListItem> items;
  final String? emptyText;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyText == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = color ?? colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    items.length.toString(),
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
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isCompleted = todo.isCompleted;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/todos/${Uri.encodeComponent(todo.id)}'),
      child: Padding(
        padding: EdgeInsets.only(left: 16.0 * todo.indentLevel),
        child: Row(
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
                  color: colorScheme.primary,
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                        _Tag(
                          key: Key('todo-source-${todo.id}'),
                          icon: Icons.link,
                          label: localizedSourceLabel(l10n, todo.sourceLabel),
                          onTap: _sourceTarget(todo) == null
                              ? null
                              : () => context.push(_sourceTarget(todo)!),
                        ),
                        _Tag(
                          icon: todo.isSchedule
                              ? Icons.event_available_outlined
                              : Icons.info_outline,
                          label: localizedTodoStatusLabel(
                            l10n,
                            todo.statusLabel,
                          ),
                        ),
                        if (todo.completedAt != null)
                          _Tag(
                            key: Key('todo-completed-at-${todo.id}'),
                            icon: Icons.done_all_outlined,
                            label: l10n.todoCompletedAtLabel(
                              _dateLabel(todo.completedAt!),
                            ),
                          ),
                        if (todo.priority != null)
                          _Tag(
                            key: Key('todo-priority-${todo.id}'),
                            icon: Icons.flag_outlined,
                            label: _priorityLabel(l10n, todo.priority),
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
                        if (todo.subtasks.isNotEmpty)
                          _Tag(
                            key: Key('todo-subtasks-${todo.id}'),
                            icon: Icons.account_tree_outlined,
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
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
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

String? _sourceTarget(TodoListItem todo) {
  final sourceCaptureId = todo.sourceCaptureId;
  if (sourceCaptureId == null || sourceCaptureId.trim().isEmpty) {
    return null;
  }
  return '/timeline/items/${Uri.encodeComponent(sourceCaptureId)}';
}

String _priorityLabel(AppLocalizations l10n, String? priority) {
  return switch (priority) {
    'high' => l10n.todoPriorityHigh,
    'medium' => l10n.todoPriorityMedium,
    'low' => l10n.todoPriorityLow,
    _ => l10n.todoPriorityNone,
  };
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
  final local = dueAt.toLocal();
  return l10n.todoDueLabel(
    '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}',
  );
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
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
  const _Tag({required this.icon, required this.label, this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tag = DecoratedBox(
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
