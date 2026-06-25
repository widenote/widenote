# Live Model User Journey QA

Date: 2026-06-25

Scope: WideNote mobile dev flavor on Android emulator with the QA MIMO model
client enabled through a transient `WIDENOTE_QA_MIMO_API_KEY` dart define.

The API key was not written to source files, fixtures, generated artifacts, or
this report.

## Environment

- Emulator: `Medium_Phone_API_35`
- Device serial: `emulator-5554`
- Package: `app.widenote.dev`
- Model endpoint: `https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages`
- Build: `flutter build apk --debug --flavor dev`
- Evidence directory: `/tmp/widenote-live-qa/`

## Live Model Result

The live client reached the remote service after the UTF-8 request fix. Both
opt-in live test prompts returned HTTP 429 from the endpoint, so the live test
group records the cases as skipped instead of pretending model output passed.

Validated:

- non-ASCII prompts are encoded as UTF-8 request bytes
- HTTP 429 errors remain sanitized and do not expose the API key
- mobile capture fallback completes after the shorter 1s + 3s retry window
- original raw captures remain available when model output is unavailable

## External Review Attempt

Kimi CLI was invoked in read-only mode with a small prompt scoped to the model
client, capture/todo privacy fix, app theme, and related tests/docs. No API key
or user record was included in the prompt.

The command did not return within the review window and was interrupted. No
external findings were applied from this attempt.

## User Journey

The fixed dev APK was installed with the live model dart define, then app data
was cleared for a new-user journey.

### Ordinary Capture

Input:

```text
Daily QA note: WideNote keeps raw records local and creates source-linked Memory after capture.
```

Observed:

- capture completed under the shortened fallback window
- Memory Review was shown because the live model fell back with low confidence
- accepting the review updated the home counters to one processed capture, one
  accepted Memory item, two cards, and three source-linked insights
- Todos contained one source-linked follow-up for the ordinary capture

### Sensitive Capture

Input:

```text
My token is sk-demo-secret and should go to review.
```

Observed before the fix:

- Memory correctly routed to review as credential/high sensitivity
- the Todo agent still generated a todo containing the sensitive text
- Timeline exposed the sensitive todo even after the Memory item was rejected

Fix:

- high-sensitivity captures no longer emit `todoSuggested`
- the pipeline returns a non-persisted skipped todo state for UI continuity
- the capture controller persists and displays todos only when `isSuggested`
  is true

Observed after the fix:

- the sensitive capture still appears as raw Capture/Card evidence
- Memory Review remains visible with `review_only_type`, `sensitive`, and
  `low_confidence`
- Timeline contains no sensitive Todo rows
- Todos tab contains only the ordinary capture todo
- Backup manifest showed `captures: 2` and `todos: 1`

### Todo and Backup

- Ordinary todo completed and reopened successfully.
- Backup export generated JSON and Markdown files under the app support export
  directory.
- Crash buffer was empty after the journey.

## Follow-ups

- The live endpoint needs a usable quota window before asserting successful
  model-output semantics in CI-like evidence.
- The UI should communicate model fallback/429 status in a user-friendly way
  instead of only surfacing low-confidence Memory Review.
- Consider a privacy review of Timeline raw-capture visibility for credential
  captures. The current behavior preserves originals as required, but the app
  may need an explicit "sensitive raw content" affordance.

## Post-style Smoke

After the Calm Expressive / Quiet Glass Console theme pass, the dev APK was
rebuilt with the live model dart define and installed on the same emulator.

Evidence:

- themed home screenshot: `/tmp/widenote-live-qa/21-themed-home-ready.png`
- themed capture review screenshot:
  `/tmp/widenote-live-qa/23-themed-capture-smoke.png`
- crash buffer after themed launch and capture smoke was empty

The themed quick-capture path still reached Memory Review under HTTP 429
fallback, and review actions remained above the bottom navigation bar.
