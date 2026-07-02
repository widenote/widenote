# Todo Manager Tab Plan

Date: 2026-07-03

## Scope

Implement Candidate C for the WideNote Todos tab as a local-first, source-linked
task manager surface. The tab can feel operational like Omi, but it must still
respect WideNote's current contracts:

- Todos remain derived, source-linked outputs from captures and agent events.
- Schedule candidates remain local suggestions only.
- This slice does not write system Calendar, Reminder, notification, or external
  task-app data.
- Core semantic admission remains model-governed; the UI must not classify
  natural-language captures with local keyword rules.

## Interaction Design

### List Root

The `/todos` tab becomes an operational list:

- Header summary: open actions, schedule candidates, completed count.
- Search field: filters title, source label, due labels, priority, and
  user-visible metadata already stored on each todo.
- Bucketed list:
  - Overdue
  - Today
  - Tomorrow
  - Later
  - No deadline
  - Schedule candidates
  - Completed
- Action rows show a checkbox.
- Schedule rows show an event icon and no checkbox.
- Completed rows stay visible and have a restore action.
- Rows retain source chips so users and models can trace the original record.
- Indentation is rendered from structured metadata, but drag-to-indent is not in
  this first PR. The detail page can adjust hierarchy metadata explicitly.

### Detail Subpage

`/todos/:todoId` owns detail/edit interactions:

- Title section with item type and status.
- Action controls:
  - Complete / Reopen for action items.
  - Restore for completed action items.
  - Schedule candidates expose view/source metadata, not a completion checkbox.
- Editable local metadata:
  - Due label / ISO due date when available.
  - Priority.
  - Indent level.
  - Sort order.
- Readable source metadata:
  - Source capture/event refs.
  - Suggestion confidence and reason.
  - Schedule time cue.
- Optional subtask preview:
  - This PR can read and display `payload.subtasks`.
  - Toggling subtasks is deferred unless the payload schema becomes stable in
    tests.

The detail page is a child route under `/todos` so system back returns to the
Todos tab rather than exiting the app.

## Payload Schema

The first slice stores task-manager metadata in `TodoRecord.payload` rather
than adding a table migration. Stable fields can be promoted later.

```json
{
  "todo_schema_version": 1,
  "title": "Review launch checklist",
  "body": "Optional detail",
  "suggestion_kind": "action",
  "suggestion_confidence": "high",
  "suggestion_reason": "explicit_action",
  "source_label": "source: capture-123",
  "source_refs": [{ "kind": "capture", "id": "capture-123" }],
  "due_at": "2026-07-03T16:00:00Z",
  "due_label": "Today 16:00",
  "scheduled_at_label": "tomorrow 10:00",
  "scheduled_start": "2026-07-04T02:00:00Z",
  "scheduled_end": null,
  "priority": "high",
  "sort_order": 1200,
  "indent_level": 1,
  "completed_at": "2026-07-03T09:12:00Z",
  "completed_by": "user",
  "user_overrides": ["due_at", "priority"],
  "subtasks": [
    { "id": "subtask-1", "title": "Add widget test", "completed": false }
  ]
}
```

Rules:

- `suggestion_kind` remains the model-selected type.
- `due_at` is for action deadlines.
- `scheduled_start` / `scheduled_end` are for schedule candidates.
- `scheduled_at_label` is preserved for legacy and fuzzy model cues.
- `completed_at` is set when an action is completed and cleared when reopened.
- `indent_level` is clamped from 0 to 3.
- `sort_order` is optional and only affects stable UI ordering inside buckets.
- `user_overrides` records local edits so future agents do not silently replace
  user-tuned metadata.

## LLM Compatibility

The model needs awareness through structured fields, not UI-only state:

- The Todo agent prompt remains backward-compatible but may emit optional
  `priority`, `due_label`, `scheduled_start`, `scheduled_end`, and `subtasks`
  values.
- The capture orchestrator stores recognized optional fields in the todo event
  payload without making them required.
- `todo.suggest` and read-only knowledge outputs should expose task-manager
  metadata: `suggestion_kind`, `due_at`, `due_label`, `scheduled_start`,
  `scheduled_end`, `scheduled_at_label`, `priority`, `sort_order`,
  `indent_level`, `completed_at`, and `subtasks`.
- Context packets should include a concise structured todo summary so chat and
  agent surfaces can distinguish open actions, completed actions, schedule
  candidates, deadlines, and user overrides.
- No local keyword heuristics should infer priority or due dates from raw
  natural-language title text.

## MemeX Pitfalls To Avoid

Fresh PR evidence from `memex-lab/memex`:

- PR #238 fixed schedule completion matching by `itemId` after source-fact
  matching caused unrelated items from the same source to merge incorrectly.
- PR #213 added completed restore with a pending snapshot because completed rows
  originally lost context.
- PR #247 fixed missing array item schemas in schedule aggregation tools.
- PR #149 preserved subtasks in schedule schemas and tests because flattening
  hid task progress.
- PR #152 added a structural no-op path for empty schedule windows to avoid
  agent loops.
- PR #112 recomputed relative labels across local-day boundaries.
- PR #170 fixed completion sync being overwritten by stale aggregation state.

WideNote avoidance checklist:

- Match todo identity by `TodoRecord.id`, not source capture id.
- Keep completed rows restorable and preserve metadata in payload.
- Add tests for malformed optional arrays such as `subtasks`.
- Do not flatten hierarchy into text-only rows.
- Make empty buckets a UI state, not a model retry trigger.
- Compute due buckets from stored structured dates and an injectable clock in
  tests.
- Persist completion metadata in the same local record update that changes
  status.

## First Implementation Slice

This PR should implement:

1. `TodoListItem` metadata parsing and bucketing.
2. Search and bucketed list UI in `TodosPage`.
3. `/todos/:todoId` detail page.
4. Complete/reopen with `completed_at` payload updates.
5. Metadata edit methods for priority, due label/date, indent, and sort order.
6. LLM/context output of structured todo metadata.
7. English and Chinese localization.
8. Controller, context-packet, and widget tests.

Deferred:

- Drag-and-drop reorder gestures.
- Swipe delete.
- External reminder/calendar/task-app sync.
- Manual task creation FAB.
- Subtask mutation.
