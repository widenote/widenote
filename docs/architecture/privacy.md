# Privacy Model

WideNote is local-first. Core use must work without registration and without an official backend.

## Privacy Tiers

| Tier | Capability | Server visibility |
| --- | --- | --- |
| Local only | Records, memory, local agents, insight | Nothing |
| Encrypted sync | Multi-device sync and backup | Ciphertext and limited metadata |
| Self-hosted runner | Scheduled and long tasks | User-controlled runtime may see plaintext |
| Official cloud runner | Hosted long tasks and integrations | Cloud runtime may see authorized plaintext |
| Confidential cloud runner | Future trusted execution | Intended to reduce operator visibility |

## Sync Direction

Sync raw events, memory, configuration, attachments, and selected outputs as encrypted objects. Rebuild full-text and vector indexes per device where possible.

## Permission Direction

Plugins and Agent Packs must declare permissions. Sensitive permissions require explicit user approval and must be revocable.

## Location Context

Location tied to a record is sensitive user data. WideNote treats it as opt-in
local record fact metadata:

- Local GPS capture uses foreground one-shot permission only.
- AMap reverse geocoding is a separate switch because it sends coordinates to a
  third-party Web Service.
- Runtime event payloads do not duplicate full coordinates; the local capture
  payload is the authoritative precise-location and place-fact store.
- Coordinates and geocoded place names are exposed through
  `fact_metadata.location` for UI and future visualization features. AMap place
  data is marked as a provider-derived fact, not raw user truth.
- User-facing lists default to coarse display and users can clear saved
  capture-location facts.
- AMap API keys are credentials and must stay out of backups, Owner Export,
  logs, fixtures, external review prompts, PR descriptions, and generated docs.
