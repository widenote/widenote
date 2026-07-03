# Mobile Features

## Purpose

Feature-owned mobile UI slices for the WideNote phase-one mobile runtime.

## Ownership Boundary

Features may own presentation and temporary app-local controllers. Durable runtime contracts, persistence, model providers, permissions, and Agent Pack execution belong in shared packages or explicit integration layers.

## Dependencies

- Flutter Material
- `flutter_riverpod` where feature state is required

## Public Surface

- `capture`: home/records tab, quick capture state, Memory review surface, and
  source-linked card/insight previews.
- `timeline`: local browse, search, card detail, item detail, and source-ref
  inspection for captures, cards, insights, Memory, and todos.
- `recap`: Daily Recap second-level page built from local object truth.
- `insights`: source-linked insight list, detail, evidence inspection, and
  local archive/restore review controls.
- `memory`: accepted Memory list, edit, tombstone delete, restore, and source
  metadata.
- `chat`: local sessions, messages, provider-backed assistant bridge,
  source-linked context, model-required failure states, and retry UI.
- `todos`: source-linked todo list.
- `settings`: Settings / Privacy hub for permissions, model providers,
  backup/restore, log center, and display status.
- `system_permissions`: Android and iOS app-level permission status, request,
  and settings handoff surface.
- `transcription`: voice transcription settings, explicit ASR engine
  selection, local SenseVoice model state, MiMo ASR, retry, and correction
  orchestration.
- `location`: opt-in foreground GPS capture, separate AMap reverse geocoding,
  fact-backed place metadata, redacted location display, and saved-location
  clearing.
- `backup`: full `.widenote` directory archive export/import UI; legacy safe
  JSON and Markdown projections remain local DB compatibility/export surfaces.
- `agent_status`: global read-only current Agent execution status overlay,
  detail sheet, and privacy-safe platform notification/Live Activity status
  sync.
- `plugins`: pack, permission, model, backup, and log control entries.
- `model_providers`: provider setup, fake connection tests, and default-provider
  local state.
- `traces`: read-only local Agent Runtime log center.

## Generated Artifacts

None.
