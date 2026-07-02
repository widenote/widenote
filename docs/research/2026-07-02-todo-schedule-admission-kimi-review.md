# Todo And Schedule Admission Kimi Review

Date: 2026-07-02

## Scope

This note records the first-slice correction for source-linked todo admission
and the Actions UI. The review input excluded the user backup file, raw private
records, local databases, credentials, and screenshots.

## Backup Evidence

The inspected `.widenote` archive contained a SQLite backup with:

- 6 capture rows.
- 6 todo rows.
- 6 `wn.todo.suggested` events.
- 6 todo rows with a source capture reference.

That 1:1 shape showed the old native todo handler emitted a todo suggestion for
every capture. The private capture text was not copied into this note.

## Memex Reference

The relevant Memex pattern is the local system-action flow:

- `SystemActionSkill` only creates a pending action when the user clearly asks
  for a reminder or schedule-like action.
- `SystemActionService` stores pending local actions and supports accept,
  update, cancel, and completion without treating every record as actionable.
- `SystemActionCard` visually separates calendar-like actions from reminders.
  Schedule candidates are not rendered as checkbox todos.
- `ActionCenterSheet` gives pending actions a dedicated review surface.

The useful WideNote takeaway is the separation of action admission, schedule
candidate display, and later system-side writes. A schedule candidate can be
source-linked and visible without immediately writing Calendar or Reminder data.

## Kimi Findings

Kimi agreed with the first-slice boundary:

- Stop emitting `wn.todo.suggested` for ordinary diary, status, observation, or
  product-note captures.
- Split action items from schedule candidates in the UI.
- Do not add system Calendar or Reminder writes in this slice.
- Reuse `TodoRecord.payload` for minimal grouping metadata before introducing a
  broader system-action table.
- Keep skipped captures quiet rather than building a second timeline.

This design must follow ADR-0010: WideNote core must not use keyword, regular
expression, substring, or stop-word heuristics over user natural-language
content to decide action, schedule, or quiet admission.

## First-Slice Resolution

The implementation uses the Todo agent itself as the model-backed semantic
decision point:

- `pack.todo` has `model.complete` permission and prompt
  `todo.suggestion.v1`.
- New captures emit `wn.todo.suggested` only when the Todo agent returns
  `kind: action` or `kind: schedule`.
- Todo payloads carry `suggestion_kind`, confidence, reason, and optional
  `scheduled_at_label`.
- Legacy todo rows without `suggestion_kind` are not reclassified locally from
  their title/body. They are treated as quiet/unclassified by the current UI
  until a model-backed migration or reprocessing flow exists.
- The Actions page displays completable action items separately from schedule
  candidates. Schedule candidates use an event icon and have no completion
  checkbox.
- Quiet legacy rows only contribute to a compact summary.

No explicit local classifier sits in front of the Todo agent.

## Follow-Up Kimi Review

Kimi reviewed the implementation diff after the no-classifier decision was
reconfirmed. It agreed with the Todo agent as the single model-backed decision
point and did not find residual local keyword/regex/substring/stop-word
admission logic in the todo/schedule path. The review flagged one consistency
issue: malformed or legacy `wn.todo.suggested` events missing
`suggestion_kind` should not fall back to action. The implementation now treats
missing `suggestion_kind` as quiet in both `SourceTodo` defaults and
orchestrator event projection.

## Decision Points

- Should schedule candidates gain Memex-style accept/ignore controls before any
  system Calendar or Reminder write?
- Should users get a lightweight "promote to action" feedback affordance for
  quiet captures, or should quiet captures remain timeline-only?
- Should schedule candidates eventually move into a dedicated system-action
  table, or is `TodoRecord.payload` enough until real system integrations land?
- Should legacy backups get a model-backed reprocess/migration command for old
  `wn.todo.suggested` rows that lack `suggestion_kind`?

## Validation

- `flutter analyze` from `apps/mobile`.
- `flutter test` from `apps/mobile`.
- Targeted `dart analyze` and `dart test` for `packages/dart/agent_runtime`.
- `node tools/pack_validator/validate_test.mjs`.
- `node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json`.
- `git diff --check` from the repository root.
