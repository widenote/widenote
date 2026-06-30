# WideNote Mobile UI Implementation-Ready Plan

Status: ready for implementation discussion

Date: 2026-06-30

Scope: final product/UX direction for the phase-one mobile layout pass

## Decision

Adopt **Today Home + Record Sheet + Source-First Details** as the next mobile UI
direction.

The default app loop stays:

```text
quick capture -> timeline / cards -> Memory -> insight
```

The home screen should not be an infinite card stream and should not feel like
an agent control console. It is the daily return surface: what happened today,
what was recently recorded, and how to continue recording quickly.

## Final Information Architecture

| Level | Surface | Role |
| --- | --- | --- |
| Bottom nav | Home | Today surface: daily recap, recent records, lightweight insight teasers, entry to full records. |
| Bottom nav | Chat | Unified source-linked conversation. Insight follow-up questions open here with context. |
| Bottom nav center action | Record | Opens the same Compose Sheet from anywhere. This is an action, not a destination tab. |
| Bottom nav | Todos | Source-linked open actions. Completed history is explicit and not home-default. |
| Bottom nav | Packs | Agent Pack market and installed pack management only. |
| Top right | Insights | Opens insight overview from Home without adding a fifth content tab. |
| Top right | Settings | Privacy, permissions, providers, backup, trace, and advanced controls. |
| Secondary | Records | Full timeline/card stream entered from Home's recent-records header or record detail paths. |
| Detail | Source-first record detail | Original source first, derived sections after it with inline provenance. |

## Kimi Review Summary

Kimi was run in read-only print mode with a sanitized design summary only. No
secrets, private records, local databases, or API keys were sent.

Kimi supported the direction and flagged these issues:

- P0: Avoid confusing dual navigation where bottom Home is active but an
  in-home `Today / Insights / Records` segmented control looks like primary
  navigation.
- P0: Bottom record button and Home `Continue recording` CTA must share the
  same behavior.
- P1: Insight follow-up questions must define how they enter Chat and carry
  context.
- P1: Background voice should not force context entry before preserving the
  source audio.
- P1: Record details should not expand every derived object at once.

Disposition:

- The final preview removes the top segmented control from the Home default.
- Records is a secondary page entered through the Recent Records header.
- Insights is a top-right icon entry and has explicit follow-up-to-Chat flow.
- All record entry triggers open the same Compose Sheet.
- Background voice saves source audio first, then offers optional context.
- Record details use source-first layout with derived sections folded by
  default except summary and actionable todos.

## Final Home Layout

First screen order:

1. App header
   - Title: `广记`
   - Subtitle: current date and local status, for example `6月30日 周二 · 本地保存`
   - Actions: Insights, Search or Records shortcut when needed, Settings
2. Daily Recap card
   - Height target: about 35-40% of first viewport content area.
   - Includes today's record count, Memory count, open todo count, and 1-2 topic
     chips.
   - Opens Daily Recap detail.
3. Recent Records
   - 2-3 compact rows, each 72-88 px target height.
   - Row shows source type, excerpt, time, and derived status chips.
   - Section header has `全部` / `All` action into Records.
4. Lightweight Insight Teaser
   - 1-2 compact prompts or topic chips.
   - Opens Insights, or a follow-up opens Chat with context.
5. Continue Recording CTA
   - Text/link-style secondary CTA.
   - Uses same Compose Sheet as the bottom center Record action.

Home does not show:

- Memory confirmation queues by default.
- Todo lists, because Todos is a first-level tab.
- Trace/debug panels.
- Provider, backup, or permission controls.

## Compose Sheet Contract

Entry points:

- Bottom center Record action.
- Home `Continue recording`.
- Empty states in Records / Recap where appropriate.

All entry points open the same sheet.

Sheet layout:

- Header: New Record, close button.
- Main input: text area, focused by default.
- Source row: camera, gallery, file, voice attachment/state.
- Attachment review row when needed.
- Save button enabled only when text or attachment exists.

Background voice:

- Starting voice recording is an independent quick action.
- Stopping voice creates/preserves a source audio object first.
- The user is invited, not forced, to add context in the Compose Sheet.
- Uncontextualized audio should still be visible in Records with a generated
  safe title such as voice note time and duration.

## Records Page Contract

The Records page is the complete browse surface.

Layout:

- Header: Records, search icon, filter icon.
- Search collapses by default; expands on demand.
- Filter chips: All, Captures, Cards, Memory, Insights, Todos.
- Timeline grouped by day.
- Rows use a quiet list style with a 3 px left color strip by source/object
  kind.

Search:

- Phase one can keep exact/local browse behavior honest.
- Do not imply semantic search is available until retriever/vector/model-backed
  search exists.

## Insight Surface Contract

Insight is visible but not a bottom tab.

Layout:

- Entry: top-right Home action and Daily Recap/teaser links.
- First screen has three compact sections:
  - Topics or themes.
  - Trends or counts.
  - Follow-up questions.
- Empty state is small: short explanation plus `去记录`.

Interaction:

- Tapping a follow-up question opens Chat.
- Chat receives context metadata: insight id/title, source refs, and suggested
  user prompt text.
- The user can edit before sending if the implementation chooses a composer
  prefill instead of immediate send.

## Source-First Detail Contract

Default section states:

| Section | Default state | Notes |
| --- | --- | --- |
| Original source | Expanded | Source truth. Text records show full text; media shows preview plus metadata. |
| AI summary/card | Expanded | Main derived reading surface. |
| Memory | Collapsed chips unless review needed | Review-needed Memory expands and highlights why. |
| Todo | Expanded when present | Hide if no todos exist. |
| Insight | Collapsed | Show count/title summary. |
| Trace/source chain | Inline provenance | Do not make it a large default card. Link to advanced trace from Settings. |

## Packs And Settings Boundary

Packs tab:

- Pack marketplace/catalog.
- Installed Packs.
- Pack capability, source access, permissions summary.
- Enable/disable built-in packs.

Settings:

- Privacy posture.
- Permissions.
- Model providers.
- Backup/restore.
- Trace console.
- Advanced/developer controls.

## MVP Implementation Slices

### Slice 1: Navigation And Today Home

Goal: make the app feel like the final information architecture without
rewiring every derived object.

Includes:

- Bottom nav with center Record action.
- Home header with Insights and Settings actions.
- Today card using existing recap/read-model data where available, otherwise
  current local projections.
- Recent Records section with `All` entry into Records.
- Continue Recording CTA opening the same Compose Sheet.
- Keep existing Compose Sheet behavior, but unify entry points.

Expected validation:

- Widget tests for bottom nav selection, center Record action, Home CTA opening
  the sheet, Settings/Insights navigation, and Recent Records `All` navigation.
- `cd apps/mobile && flutter analyze`
- Targeted `cd apps/mobile && flutter test ...` for changed widgets.

### Slice 2: Records Page And Source-First Detail

Goal: turn Timeline/detail into the final Records mental model.

Includes:

- Rename/position Timeline as Records in UI copy while preserving route
  compatibility if needed.
- Day-grouped rows with compact source/object strips.
- Collapsible source-first detail sections.
- Inline provenance rows instead of large Trace cards.

Expected validation:

- Widget tests for Records empty/data/filter/search states.
- Widget tests for detail section default expanded/collapsed state and source
  navigation.
- Existing timeline/detail tests updated rather than discarded.

### Slice 3: Insights To Chat And Settings/Packs Split

Goal: finish the cross-surface flow and reduce control-console leakage.

Includes:

- Insight overview with topic/trend/follow-up question sections.
- Follow-up question opens Chat with context/prefill.
- Packs tab limited to marketplace/installed pack management.
- Settings owns providers, backup, permissions, trace, and advanced controls.

Expected validation:

- Widget tests for insight empty/data states and question-to-chat transition.
- Widget tests for Packs vs Settings entry relocation.
- Localization updates in English and Chinese ARB files.

## Deferred

- Full semantic/vector search.
- Full native file picker/share-sheet ingestion.
- Community remote Pack install.
- Dark mode polish.
- Tablet/two-pane navigation rail.
- Rich charts for Insights.
- Global Trace visualization beyond the Settings advanced surface.

## Open Decisions Before Coding

These should be answered before Slice 1 implementation starts:

1. Should the center Record action visually occupy a bottom-nav slot, or float
   above the nav while the labels remain four content destinations?
2. Should Insights open as a full page, a Home subpage, or a modal sheet?
3. Should `Timeline` be renamed to `Records` in route names now, or only in
   user-visible copy for a low-risk first slice?
4. When a voice recording stops, should the app automatically open the Compose
   Sheet or show a snackbar/action first?
5. Should the first implementation move Settings out of Packs immediately, or
   keep duplicate entries for one transitional slice?
