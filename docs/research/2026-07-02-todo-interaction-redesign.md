# Todo Interaction Redesign Research

Date: 2026-07-02

## Scope

This note records the interaction redesign options for WideNote Todos after
reviewing the current implementation, MemeX, Omi, and Kimi feedback.

The review input excluded secrets, raw private records, local databases,
credential-bearing backups, and screenshots.

## Current WideNote Gap

The current Todos page is intentionally narrow but now under-expresses the
state users need to understand:

- Action items and schedule candidates are separate surfaces, but the page has
  no timeline grouping, due bucket, priority, hierarchy, progress, search, or
  editing surface.
- Completing an action item updates its status, then the controller filters it
  out of the page, so completed work disappears instead of becoming visible,
  reviewable, and restorable.
- Schedule candidates have an event icon and no checkbox, which matches the
  current contract, but they do not yet have accept, ignore, convert, or
  expired-state affordances.
- The local `todos` table has only status plus `payload_json` for extensibility,
  so the next redesign can start with payload fields before promoting stable
  fields to a schema migration.

The hard contract remains unchanged: source-linked todos are model-derived
suggestions, schedule candidates are local suggestions, and this surface must
not write system Calendar or Reminder data until a follow-up permission and UX
decision lands.

## MemeX Benchmark

Useful MemeX patterns:

- Treat the page as a schedule briefing: a unified view of pending work,
  calendar-like events, and completed history.
- Model item kind explicitly as todo versus event.
- Keep pending and completed state separate, with completed items carrying
  close time and a recoverable snapshot.
- Represent hierarchy as semantic subtasks, not visual indentation alone.
- Derive in-progress status from subtask progress.
- Group by date and time, while keeping todos from auto-completing just because
  time passed.
- Keep source references on both pending and completed entries.

Patterns not worth copying for the first slice:

- Hero/editorial/quote blocks: these make the screen feel composed, but they are
  heavier than the current interaction problem requires.
- Device-action and system-reminder sync: these conflict with the current
  WideNote schedule-candidate boundary.

## Omi Benchmark

Useful Omi patterns:

- Make action items feel operable: date buckets, completed visibility, search,
  edit sheet, due-date chips, and optimistic state updates.
- Use clear buckets such as overdue, today, tomorrow, later, no deadline, and
  completed.
- Store completed time and allow reopening.
- Keep external app sync as metadata and integration behavior rather than the
  source of task truth.
- Keep calendar-event integrations separate from action-item management.

Patterns to avoid in the first WideNote slice:

- Manual `indent_level` and `sort_order` as the primary hierarchy model. They
  make sense for a task manager, but WideNote tasks are derived from source
  records.
- FAB-first manual task creation, batch selection, swipe delete, and external
  reminder/task-app export. These would move Todos toward a general task
  manager before the derived-output contract is mature.

## Kimi Review

Kimi recommended Candidate B as the right direction, but with a reduced first
slice:

- Use the MemeX-style briefing model as the target.
- Do not ship all hierarchy, hero, and progress affordances at once.
- Borrow Omi date buckets and completed visibility, but avoid Omi manual
  sorting, visual indentation, deletion, and external sync.
- Prefer subtasks and recoverable snapshots for hierarchy and completed-state
  restore.
- Keep schedule candidates visually and behaviorally distinct from completable
  action items.

Kimi's proposed first slice is "B-lite": date buckets, explicit todo/schedule
kind, completed visibility, reopen, priority/time cues, source links, and
localized widget coverage. Subtasks can follow in a second slice.

## Candidate A: Incremental Todo Center

Use when we want the smallest safe improvement.

```text
+------------------------------------------------+
| Todos & Schedule                         filter |
| 3 open actions  .  2 schedule candidates .  5 done |
| [Open] [Schedule] [Done]                       |
|                                                |
| Open actions                                   |
| ( ) Review meeting notes        source  high   |
| ( ) Send Alice the budget draft source  med    |
|                                                |
| Schedule candidates                            |
| <> Tomorrow 10:00 contract follow-up source    |
|                                                |
| Done                                           |
| (v) Confirm backup boundary  Today 09:12 Reopen |
+------------------------------------------------+
```

Strengths:

- Low implementation risk.
- Mostly compatible with the current controller and payload.
- Makes completed items visible and restorable.

Weaknesses:

- Does not truly solve hierarchy.
- Still feels like two lists rather than a better interaction model.
- Risks disappointing users who expect a real redesign.

## Candidate B: MemeX-Style Briefing Timeline

Recommended direction.

```text
+------------------------------------------------+
| Todos & Schedule                               |
| Today: 3 actions . 1 schedule . 2 in progress  |
|                                                |
| Focus                                          |
| ( ) Visa material prep              2/5  High  |
|     [====------]                               |
|     (v) Fill application form                  |
|     ( ) Print confirmation page                |
|     ( ) Book appointment              expand   |
|                                                |
| Today                                          |
| <> 14:30 dentist appointment candidate source  |
| ( ) Publish checklist                    due   |
|                                                |
| This week                                      |
| ( ) Review launch notes                  source |
|                                                |
| Completed                                      |
| (v) Submit budget draft   Today 09:12  Restore |
+------------------------------------------------+
```

Strengths:

- Directly answers the need to distinguish completed work, action items, and
  schedule candidates.
- Supports semantic hierarchy through subtasks.
- Preserves the derived-output and source-linked WideNote boundary.
- Gives the implementation a phased path: B-lite first, subtasks second.

Weaknesses:

- Needs more payload parsing and state grouping.
- Date parsing and timezone behavior require careful tests.
- Subtask restore and progress can grow if attempted in the first PR.

## Candidate C: Omi-Style Task Manager

Use only if WideNote intentionally decides Todos should become a first-class
manual task manager.

```text
+------------------------------------------------+
| Search action items                         ... |
|                                                |
| Overdue 2                                      |
| ( ) Fix login regression              source   |
|   ( ) Add widget test                          |
|   ( ) Review Kimi feedback                     |
|                                                |
| Today 4                                        |
| ( ) Publish checklist                 23:59    |
|   ( ) Update PR description                    |
|                                                |
| Tomorrow 1                                     |
| <> 10:00 product review candidate Convert      |
|                                                |
| No deadline 3                                  |
| Completed 12                                   |
|                                              + |
+------------------------------------------------+
```

Strengths:

- Strong task-management ergonomics.
- Search, edit sheet, due-date buckets, and completed view are familiar.
- A future manual-task mode could reuse parts of this pattern.

Weaknesses:

- Too large for the current contract.
- Manual creation, sorting, indentation, and deletion blur source truth.
- More expensive to test because gestures and editing modes multiply states.

## Candidate D: Briefing Plus Management Mode

Use only after the project confirms both briefing and task-manager behavior are
needed.

```text
+------------------------------------------------+
| Todos & Schedule                               |
| [Briefing] [Manage]                            |
|                                                |
| Briefing: grouped timeline, source-linked work |
| Manage: search, edit sheet, sort, bulk actions |
+------------------------------------------------+
```

Strengths:

- Keeps a calm default while leaving room for power operations.

Weaknesses:

- Mode switching adds cognitive load.
- Both modes must share one state model.
- Too broad for the next implementation slice.

## Recommended First Slice

Build Candidate B-lite:

1. Stop hiding completed rows. Split state into open actions, schedule
   candidates, quiet rows, and completed actions.
2. Add local grouping for action items by overdue, today, later, and no date
   when payload time fields exist.
3. Keep schedule candidates visually separate with event icon, time cue, source
   link, and no checkbox.
4. Add a completed section with reopen.
5. Parse optional payload fields: `due_at`, `scheduled_start`,
   `scheduled_end`, `priority`, and `completed_at`.
6. Keep subtasks out of the first PR unless the payload already contains stable
   subtask data.

## Follow-Up Slice

Add semantic hierarchy:

- Parse `payload.subtasks` as a source-linked child checklist.
- Show progress and derived in-progress status.
- Allow child toggles.
- Move the parent to completed when all subtasks complete.
- Restore the previous child state when reopening from completed.

## Suggested Test Coverage

For the B-lite slice:

- Action items show checkboxes; schedule candidates show event icons and no
  checkbox.
- Completing an action moves it to the completed section instead of making it
  vanish.
- Reopening a completed action moves it back to the open action section.
- Due buckets render overdue, today, later, and no date correctly.
- Schedule candidate time cues render from payload fields.
- Source links still navigate to the timeline source item.
- Completed show/hide behavior works if the UI includes a toggle.
- Priority labels or markers render when present.
- New strings render in English and Chinese locales.

For the subtask slice:

- A parent action shows progress and child rows.
- Toggling one subtask updates the progress.
- Completing all subtasks completes the parent.
- Reopening restores the expected subtask state.
- Long subtask lists collapse and expand predictably.
