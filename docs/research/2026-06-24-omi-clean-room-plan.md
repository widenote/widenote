# Omi Clean-Room Reference Plan

Status: implemented slice; Android QA is tracked in
`docs/research/2026-06-24-omi-android-qa.md`.

Date: 2026-06-24

Scope: research BasedHardware/Omi as a public product and interaction reference,
then implement a small WideNote-owned slice that improves capture-first UI and
voice input readiness without copying Omi code, schemas, prompts, or assets.

## Reference Inputs

- Public Omi repository: <https://github.com/BasedHardware/omi>
- Public Omi docs:
  - <https://docs.omi.me/doc/developer/apps/Introduction>
  - <https://docs.omi.me/doc/developer/apps/AudioStreaming>
  - <https://docs.omi.me/doc/developer/backend/transcription>
- Local clean-room clone for inspection only: `/tmp/omi-cleanroom`
- WideNote sources, ADRs, RFCs, and phase-one scope in this repository.

Clean-room rule: this report uses product concepts, navigation shape, and
interaction patterns only. WideNote implementation must use WideNote-owned
state, widgets, strings, tests, and runtime semantics.

## External Review Disposition

Kimi reviewed the proposal before implementation and flagged three concrete
risks:

| Risk | Disposition |
| --- | --- |
| Clean-room leakage risk from inspecting the Omi clone. | Accepted. Implementation must not copy Omi strings, identifiers, prompts, widget names, assets, schemas, or tests. The Omi clone remains outside the workspace, and final review must run a targeted text scan for obvious Omi-only terms. |
| Voice UI could mislead users into thinking real streaming/recording is already active. | Accepted. This slice must avoid "live" or "streaming" labels in product UI. Use "voice draft" and "transcript review" wording until a real permissioned recorder lands. |
| Missing accessibility, locale, and permission-nonrequest tests. | Accepted. Add widget tests for mode semantics/tooltips/labels, at least one zh visual path or assertion, and a unit/widget guard that mode switching does not call capture adapters until the explicit action is tapped. |

## Omi Concepts Worth Learning

| Omi concept | Why it is useful | WideNote translation |
| --- | --- | --- |
| Capture-first home | The product opens around capturing life/context, not around settings. | Make WideNote Home feel like a capture console first, with downstream state summarized rather than dumped. |
| Voice as first-class capture | Phone mic, wearable, live transcript, and transcribe-later modes are visible product ideas. | Add a capture mode UI and state for text, voice draft, and import. Keep real mic/ASR deferred behind permissions. |
| Conversations / Tasks / Apps tab split | User-facing outputs are separated by intent. | Keep WideNote's Home / Chat / Todos / Packs split, but make Home less crowded and clearer about what each output lane means. |
| Live transcript status | Omi makes listening, muted, waiting, transcript, and processing states explicit. | Add explicit voice draft state copy and review-before-saving behavior to WideNote's fake voice adapter path. |
| App/plugin capabilities | Omi apps can customize prompts, memory processing, live transcripts, chat tools, and audio streaming. | Map this to Agent Pack capabilities: `capture.voice_transcript`, `transcript.observe`, `memory.propose`, `chat.tool`, and future `audio.stream.user_granted`. |
| Developer audio streaming | Omi treats raw audio streaming as a configurable developer capability. | Defer raw audio streaming; model it as a high-risk Pack permission, not a default app feature. |
| Modern dark/purple product feel | The UI is tactile, focused, and less form-heavy. | Use a restrained WideNote design refresh: stronger capture surface, compact mode chips, better section hierarchy. Do not copy palette/assets. |

## Concepts To Reject Or Defer

- Default continuous listening or screen capture. This conflicts with
  WideNote's "not a default full-surveillance lifelog" boundary.
- Cloud/backend dependency for core capture. WideNote must remain useful
  without account or official backend.
- Wearable/BLE device setup in this slice. It belongs behind future platform
  adapters and explicit permissions.
- Raw audio streaming in the default app. It should become a declared
  Agent Pack capability with clear storage/network consent.
- Omi app-store monetization mechanics. WideNote needs Agent Pack contracts
  first; commerce is not phase-one core.

## Proposed Implementation Slice

Implement a small, product-visible slice:

1. Add `CaptureMode` to the capture input state.
   - Modes: `text`, `voice`, `import`.
   - The mode is UI state only; it does not request platform permissions.
   - Unit test mode transitions and busy-state behavior.

2. Extract Quick Capture from `home_page.dart` into a new presentation widget.
   - `home_page.dart` is already over the source-file budget.
   - New widget: `CaptureConsole`.
   - Home remains the route/read-model owner.

3. Redesign the capture surface as a WideNote-owned "capture console".
   - Top: compact mode chips for Text / Voice / Import.
   - Text mode: plain low-friction text input.
   - Voice mode: shows "Voice draft" and "Transcript review" copy only,
     backed by the existing fake voice transcript adapter. Do not claim real
     recording, streaming, or live transcription in this slice.
   - Import mode: foregrounds photo/share import actions.
   - Existing attachment review, blocked attachment behavior, and Record
     button semantics stay intact.

4. Localize all new user-visible strings in `en` and `zh`.

5. Add tests.
   - Unit: capture mode state transitions.
   - Widget: mode switching, voice draft review, import/photo affordances,
     and no regressions to capture submit.
   - Accessibility/permission guard: switching modes must not call media
     adapters or platform permissions; only explicit action buttons add
     attachments.
   - Visual: golden tests for the new capture console at fixed mobile size in
     both English and Chinese locales, or an English golden plus a Chinese
     widget assertion if the checked-in golden surface becomes too costly.

6. Android emulator QA.
   - Real taps across text, voice, import, review, and capture submit.
   - No real model key is required for the UI-only mode-switching proof. If an
     end-to-end agent capture run is included, use the same temporary
     dart-define key handling as prior QA and delete it after validation.

## Implemented Slice

- Added `CaptureMode` as UI-only capture input state for `text`, `voice`, and
  `import`.
- Extracted the home capture surface into `CaptureConsole` and kept `HomePage`
  as the route/read-model owner.
- Added localized English and Chinese mode labels, mode hints, voice-draft copy,
  import actions, attachment status lines, and header tooltips.
- Kept voice input in the existing transcript-draft adapter path. The UI avoids
  live/streaming wording and states that no microphone permission starts here.
- Added unit/widget guards that switching modes does not call media adapters;
  explicit voice/import/photo actions still drive attachments and review.
- Added a visual golden baseline for the voice draft console at mobile size.
- Final short Kimi review after emulator fixes found no P0/P1 blocking risk.

## Future Follow-Ups

- Real microphone permission, recording lifecycle, local WAV/PCM metadata, and
  ASR provider abstraction.
- Voice activity detection and chunking policy.
- Transcript segment model with speaker/time/source refs.
- Agent Pack permissions for live transcript observation and raw audio export.
- Capture device adapters for phone, wearable, desktop, or share extension.
- Daily recap / context digest cards generated from WideNote Memory rather than
  conversation-only history.

## Acceptance Gates

- `flutter analyze` in `apps/mobile`
- `flutter test` in `apps/mobile`
- New golden test passes from checked-in golden
- Kimi review of this plan and final diff, excluding secrets and private data
- Serialized Android emulator smoke for the new capture UI
