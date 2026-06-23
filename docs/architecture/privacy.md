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
