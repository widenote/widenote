import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/todo_controller.dart';

class TodoDetailPage extends ConsumerStatefulWidget {
  const TodoDetailPage({required this.todoId, super.key});

  final String todoId;

  @override
  ConsumerState<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoDetailPageState extends ConsumerState<TodoDetailPage> {
  final TextEditingController _titleController = TextEditingController();
  String? _loadedTodoId;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(todoControllerProvider);
    final now = ref.watch(todoNowProvider);
    final todo = state.itemById(widget.todoId);
    if (todo == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.todoDetailTitle)),
        body: Center(child: Text(l10n.todoDetailMissing)),
      );
    }
    if (_loadedTodoId != todo.id) {
      _loadedTodoId = todo.id;
      _titleController.text = todo.title;
    }

    return Scaffold(
      key: const Key('todo-detail-page'),
      appBar: AppBar(title: Text(l10n.todoDetailTitle)),
      body: ListView(
        key: const Key('todo-detail-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Section(
            title: l10n.todoDetailContent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('todo-detail-title-field'),
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.todoDetailTitleField,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveTitle(todo.id),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('todo-detail-save-title'),
                  onPressed: () => _saveTitle(todo.id),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.todoDetailSaveTitle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: l10n.todoDetailStatus,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: todo.isSchedule
                          ? Icons.event_available_outlined
                          : Icons.checklist_outlined,
                      label: todo.isSchedule
                          ? l10n.todoStatusScheduleCandidate
                          : localizedTodoStatusLabel(l10n, todo.statusLabel),
                    ),
                    if (todo.completedAt != null)
                      _InfoChip(
                        icon: Icons.done_all_outlined,
                        label: l10n.todoCompletedAtLabel(
                          _dateLabel(todo.completedAt!),
                        ),
                      ),
                    if (todo.reasonLabel != null)
                      _InfoChip(
                        icon: Icons.psychology_alt_outlined,
                        label: todo.reasonLabel!,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (todo.isAction)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        key: Key('todo-detail-toggle-${todo.id}'),
                        onPressed: () {
                          final controller = ref.read(
                            todoControllerProvider.notifier,
                          );
                          if (todo.isCompleted) {
                            controller.reopen(todo.id);
                          } else {
                            controller.complete(todo.id);
                          }
                        },
                        icon: Icon(
                          todo.isCompleted
                              ? Icons.undo_outlined
                              : Icons.check_circle_outline,
                        ),
                        label: Text(
                          todo.isCompleted
                              ? l10n.todoActionReopen
                              : l10n.todoActionComplete,
                        ),
                      ),
                      if (todo.isCompleted) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.todoDetailCompletedNotice,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    l10n.todoDetailScheduleNotice,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: l10n.todoDetailMetadata,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(text: l10n.todoDetailPriority),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChoiceChipButton(
                      key: const Key('todo-priority-none'),
                      label: l10n.todoPriorityNone,
                      selected: todo.priority == null,
                      onPressed: () => ref
                          .read(todoControllerProvider.notifier)
                          .setPriority(todo.id, null),
                    ),
                    for (final priority in const ['low', 'medium', 'high'])
                      _ChoiceChipButton(
                        key: Key('todo-priority-$priority'),
                        label: _priorityLabel(l10n, priority),
                        selected: todo.priority == priority,
                        onPressed: () => ref
                            .read(todoControllerProvider.notifier)
                            .setPriority(todo.id, priority),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _Label(text: l10n.todoDetailDue),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChoiceChipButton(
                      key: const Key('todo-due-none'),
                      label: l10n.todoDueNone,
                      selected: todo.dueAt == null,
                      onPressed: () => ref
                          .read(todoControllerProvider.notifier)
                          .setDuePreset(todo.id, TodoDuePreset.none),
                    ),
                    _ChoiceChipButton(
                      key: const Key('todo-due-today'),
                      label: l10n.todoDueToday,
                      selected: _isDuePreset(todo, TodoDuePreset.today, now),
                      onPressed: () => ref
                          .read(todoControllerProvider.notifier)
                          .setDuePreset(todo.id, TodoDuePreset.today),
                    ),
                    _ChoiceChipButton(
                      key: const Key('todo-due-tomorrow'),
                      label: l10n.todoDueTomorrow,
                      selected: _isDuePreset(todo, TodoDuePreset.tomorrow, now),
                      onPressed: () => ref
                          .read(todoControllerProvider.notifier)
                          .setDuePreset(todo.id, TodoDuePreset.tomorrow),
                    ),
                    _ChoiceChipButton(
                      key: const Key('todo-due-later'),
                      label: l10n.todoDueLater,
                      selected: _isDuePreset(todo, TodoDuePreset.later, now),
                      onPressed: () => ref
                          .read(todoControllerProvider.notifier)
                          .setDuePreset(todo.id, TodoDuePreset.later),
                    ),
                  ],
                ),
                if (todo.dueAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.todoDueLabel(_dateLabel(todo.dueAt!)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _StepperRow(
                  label: l10n.todoDetailIndent(todo.indentLevel),
                  decreaseKey: const Key('todo-indent-decrease'),
                  increaseKey: const Key('todo-indent-increase'),
                  onDecrease: () => ref
                      .read(todoControllerProvider.notifier)
                      .decreaseIndent(todo.id),
                  onIncrease: () => ref
                      .read(todoControllerProvider.notifier)
                      .increaseIndent(todo.id),
                ),
                const SizedBox(height: 10),
                _StepperRow(
                  label: l10n.todoDetailSort(todo.sortOrder),
                  decreaseKey: const Key('todo-sort-earlier'),
                  increaseKey: const Key('todo-sort-later'),
                  decreaseIcon: Icons.arrow_upward,
                  increaseIcon: Icons.arrow_downward,
                  onDecrease: () => ref
                      .read(todoControllerProvider.notifier)
                      .moveEarlier(todo.id),
                  onIncrease: () => ref
                      .read(todoControllerProvider.notifier)
                      .moveLater(todo.id),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: l10n.todoDetailSubtasks,
            child: todo.subtasks.isEmpty
                ? Text(
                    l10n.todoDetailNoSubtasks,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: [
                      for (final subtask in todo.subtasks)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            subtask.completed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(
                            subtask.title,
                            key: Key('todo-detail-subtask-${subtask.id}'),
                            style: TextStyle(
                              decoration: todo.isCompleted || subtask.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: todo.isCompleted || subtask.completed
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: l10n.todoDetailSource,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.link,
                      label: localizedSourceLabel(l10n, todo.sourceLabel),
                    ),
                    _InfoChip(
                      icon: Icons.speed_outlined,
                      label: todo.confidenceLabel,
                    ),
                    if (todo.scheduledAtLabel != null)
                      _InfoChip(
                        icon: Icons.event_outlined,
                        label: l10n.todoScheduledForLabel(
                          todo.scheduledAtLabel!,
                        ),
                      ),
                  ],
                ),
                if (_sourceTarget(todo) != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: Key('todo-detail-source-${todo.id}'),
                    onPressed: () => context.push(_sourceTarget(todo)!),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.todoDetailOpenSource),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveTitle(String id) {
    ref
        .read(todoControllerProvider.notifier)
        .updateTitle(id, _titleController.text);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPressed(),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.decreaseKey,
    required this.increaseKey,
    required this.onDecrease,
    required this.onIncrease,
    this.decreaseIcon = Icons.remove,
    this.increaseIcon = Icons.add,
  });

  final String label;
  final Key decreaseKey;
  final Key increaseKey;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final IconData decreaseIcon;
  final IconData increaseIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Label(text: label)),
        IconButton(
          key: decreaseKey,
          onPressed: onDecrease,
          icon: Icon(decreaseIcon),
        ),
        IconButton(
          key: increaseKey,
          onPressed: onIncrease,
          icon: Icon(increaseIcon),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _priorityLabel(AppLocalizations l10n, String? priority) {
  return switch (priority) {
    'high' => l10n.todoPriorityHigh,
    'medium' => l10n.todoPriorityMedium,
    'low' => l10n.todoPriorityLow,
    _ => l10n.todoPriorityNone,
  };
}

bool _isDuePreset(TodoListItem todo, TodoDuePreset preset, DateTime now) {
  final dueAt = todo.dueAt;
  if (dueAt == null || preset == TodoDuePreset.none) {
    return dueAt == null && preset == TodoDuePreset.none;
  }
  final dueDay = _startOfDay(dueAt.toLocal());
  final today = _startOfDay(now);
  return switch (preset) {
    TodoDuePreset.today => dueDay == today,
    TodoDuePreset.tomorrow => dueDay == today.add(const Duration(days: 1)),
    TodoDuePreset.later => dueDay.isAfter(today.add(const Duration(days: 1))),
    TodoDuePreset.none => false,
  };
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
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
