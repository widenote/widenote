# Marketplace and PKM Pack Implementation Plan

Status: implementation plan under review

Date: 2026-06-28

Scope: GitHub-first Agent Pack marketplace slice, replacement-slot contract,
and a PKM personal knowledge base example Pack.

## Decision Context

WideNote should follow Omi's marketplace breadth, not its default dependency
shape. Omi's app system combines prompt apps, external webhooks, chat tools,
MCP integrations, hosted registry state, ratings, review, and public Web
marketplace pages. WideNote should keep the same capability vocabulary but
stage it through local-first contracts:

- GitHub-first Pack registry before a hosted app store.
- Manifest, permission, trace, and revocation contracts before community
  installation at scale.
- Native and declarative Pack contracts before script, webhook, MCP, or remote
  execution.
- Derived artifacts and Memory remain source-linked outputs; raw captures stay
  source truth.

## Target Shape

The marketplace slice introduces a manifest-first registry model:

- `packs/marketplace/index.json` is the GitHub-first catalog source of truth.
- Official, community, and local-dev Pack manifests keep using the public Agent
  Pack schema.
- Marketplace metadata lives in manifest metadata and the catalog index, not in
  mobile-private tables.
- Mobile Pack Library reads installed Pack records and shows source, category,
  capabilities, trust, and replacement-slot metadata.
- Install records keep storing full manifest snapshots so later GitHub updates
  and hosted registries can be compared safely.

## Replacement Slots

Some Packs can extend the core loop, while a smaller set may replace a named
stage. Replacement is intentionally narrow:

| Slot | Purpose | Phase |
| --- | --- | --- |
| `capture.memory_extractor` | Alternative capture-to-Memory proposal logic | Reserved |
| `memory.write_policy` | Alternative proposal acceptance/review policy | Reserved |
| `agent.orchestrator` | Alternative event-to-agent orchestration policy | Reserved |

Rules:

- Slot declarations are metadata contracts in this slice.
- Only one Pack can be active for an exclusive replacement slot in a future
  enablement flow.
- Slot Packs still require source refs, permission checks, trace output, and
  rollback by disable/uninstall.
- This PR does not make arbitrary community Packs replace core behavior.
- The validator rejects reserved replacement slots for `community` or `store`
  Packs in this slice. Only `official` and `local_dev` manifests may declare
  them while the runtime semantics are still reserved.

## Additive Capability Slots

Additive capability slots describe extension areas that do not replace the core
loop:

| Slot | Purpose | Phase |
| --- | --- | --- |
| `knowledge.organization` | Derived organization views, including PKM profile entries | Implemented as additive |

Additive slots may produce derived artifacts, cards, insights, todos, or review
requests. They must not claim exclusivity over source truth or over Memory
write policy.

## PKM Example Pack

`pack.pkm_library` is an official native Pack used as the first marketplace
example. It is not a new source-truth model. It creates a derived personal
knowledge base artifact from the capture event and keeps source refs back to the
raw capture/event.

Behavior:

- Subscribes to `wn.capture.created`.
- Uses the same live model client as the capture Pack.
- Requests `model.complete` and `artifact.write`.
- Emits `wn.artifact.created`.
- Persists a derived artifact with `artifact_kind = pkm_profile_entry`.
- Leaves accepted Memory and raw captures untouched.
- Routes low-structure or sensitive model output into a source-linked artifact
  rather than auto-updating any canonical PKM table.

`artifact.write` is a derived-output permission. It allows a Pack to request a
source-linked artifact write through the runtime pipeline. It does not grant raw
capture mutation, Memory mutation, card mutation, private table access, broad
filesystem access, or export access.

The model prompt asks for compact JSON:

- `title`
- `summary`
- `topics[]`
- `people[]`
- `projects[]`
- `source_excerpt`
- `confidence`
- `sensitivity`

The local writer validates source refs and stores a readable Markdown-ish body
plus structured payload fields.

## Product Experience

The first UI is still the Pack Library, not a landing page:

- Installed official Packs appear together with the PKM example Pack.
- Each row shows category, source, trust level, capability tags, and slot tags.
- GitHub/community installation is visible as a deferred capability.
- Users can disable PKM; disabling stops future PKM tasks but keeps existing
  derived artifacts for review.

## Implementation Plan

1. Extend Agent Pack schema and validator with marketplace metadata,
   capabilities, source, trust, and replacement slot declarations.
2. Add `packs/official/pkm_library/manifest.json` and README.
3. Add `packs/marketplace/index.json` and validator coverage.
4. Embed the PKM manifest in mobile's official manifest bridge.
5. Register a native PKM agent in `CaptureOrchestrator`.
6. Persist `wn.artifact.created` output through `CaptureKnowledgeSink`.
7. Update Pack Library UI, localization, and widget tests.
8. Add runtime/orchestration tests and an opt-in DeepSeek live journey test with
   two personas and 20 inputs per persona.
9. Add developer docs for marketplace Pack authoring.

## Risks For Review

- Marketplace creep: a GitHub catalog can quietly become a cloud marketplace
  before trust, update, and revocation contracts are ready.
- PKM creep: a PKM Pack can become an alternate source-truth system unless it is
  enforced as derived artifacts over Memory/captures.
- Slot ambiguity: replacement slots need an exclusivity and rollback story
  before community Packs can use them.
- Permission drift: `artifact.write` must be treated as a derived-output write,
  not as raw database mutation permission.
- Model nondeterminism: live DeepSeek output needs structural validation and
  loose assertions anchored on source refs, not exact wording.
- Secret handling: provider keys must never enter docs, fixtures, traces, logs,
  screenshots, or PR text.
- UI overpromise: Pack Library must not imply arbitrary community install or
  live external execution is available in this slice.
- Validator gaps: lightweight validation is not full JSON Schema validation; it
  must still block high-risk live execution and malformed registry entries.

## Kimi Review Notes

Kimi CLI review was run with `--thinking` in read-only print mode against this
plan and the current architecture/Pack/runtime decision files. No API keys,
private records, local database contents, or secret-bearing artifacts were sent
to the prompt.

Initial verdict: No-Go as written; Conditional Go after P0 fixes.

Blocking findings resolved into this implementation:

- Removed `knowledge.organization` from replacement slots and made it an
  additive capability slot.
- Added a validator guard that reserved replacement slots are only allowed for
  `official` and `local_dev` manifests in this slice.
- Defined `artifact.write` as a low-risk derived-output permission that cannot
  mutate raw captures, accepted Memory, or private tables.
- Kept live DeepSeek QA opt-in and environment-gated, with source-ref and
  structure assertions rather than exact-output assertions.
- Added marketplace index schema and validator scope to the implementation
  plan.

Remaining non-blocking recommendations:

- Mark trust labels as provisional UI metadata until signatures or verified
  publisher policy lands.
- Consider a future rename of `CaptureKnowledgeSink` if it grows beyond capture
  cards, insights, and artifacts.
- Promote the marketplace slice into an accepted RFC if later work opens real
  community install, hosted registry, HTTP, MCP, webhook, or script execution.
