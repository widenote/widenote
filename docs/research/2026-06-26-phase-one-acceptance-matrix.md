# Phase-One Acceptance Matrix

Status: review-subagent accepted baseline
Date: 2026-06-26
Scope: module acceptance criteria before implementation workers begin

## Overall Gate

Phase one cannot pass acceptance just because screens are clickable. It must
prove:

- local object truth is preserved
- raw user records are not overwritten by AI output
- derived objects keep source refs
- core usage works without an account or official backend
- zh/en localization paths are covered
- permissions can be denied and revoked
- Kimi/external review inputs exclude secrets and real private user data
- unit/widget/orchestration tests and simulator evidence exist

## Module Acceptance And QA

| Module | Acceptance standard | User manual checks | Simulator QA path | Edge cases |
| --- | --- | --- | --- | --- |
| Home / Capture | Home is a daily return surface. Capture saves raw input locally before async derivation. AI failure never hides raw records. | Open Compose Sheet, submit text/media entry, see raw record plus pending/failed/processed state and source detail. | Cold start -> create capture -> open timeline/detail -> simulate failure/offline -> raw remains visible -> restart -> record remains. | Empty text, long text, duplicate submit, permission denied, low storage, restart mid-run, cross-time-zone capture date. |
| Context Packet / Conversation | Context Packet is rebuildable. Chat persists local sessions and answers from local context with citations. | Ask about local records, see cited records/Memory/Todos, retry failures, propose answer as Memory/Todo through policy path. | Create capture -> Chat -> ask -> inspect citation chips -> model failure retry -> save derived proposal. | Source edit/delete/permission revoke invalidates packet; generator upgrade; empty context; prompt injection; offline mode. |
| Memory / Card / Insight / Recap | Memory is editable/deletable/source-linked durable knowledge. Cards, insights, and recaps are source-linked derived objects. | View Memory, card detail, daily recap; accept/edit/reject/merge Memory; delete and restore. | Capture -> low-risk Memory/card/insight -> detail/source -> edit Memory -> tombstone delete -> restore. | Credentials/health/finance/location review-only; conflicts; low confidence; source soft-deleted; cross-time-zone recap; stale derived object. |
| Todo Pack | Todo is a separate official pack. Todo status is durable and source-linked. | See empty/enable-pack state, inbox/today/future/completed, complete/reopen Todo, open source record. | Capture triggers todo suggestion -> Todos tab -> complete/reopen -> source backlink -> restart validates state. | Duplicate events, fuzzy due date, source deleted, pack disabled, dependency failure, permission denied. |
| Plugin / Permission / Pack Library | Official packs also go through manifest and capability broker. High-risk capability is not default-granted. | Open Packs/Permissions, inspect default/todo packs, grant/deny/revoke permissions. | Packs tab -> pack detail -> permission review -> deny high-risk -> grant low-risk -> revoke -> future task blocked. | Missing manifest fields, invalid dependency graph, agent permission exceeds pack, script runtime rejected, official pack bypass, revoke after queued task. |
| Backup / Owner Export / Restore | Backup restores app state. Owner Export moves/inspects data and excludes secrets by default. | Export backup/export, see secret warning, import valid file, malformed file shows recoverable error. | Configure provider + capture + Memory + todo -> backup -> restore -> data/settings usable; Owner Export has no key. | Unsupported version, malformed JSON, missing sections, missing attachment, checksum mismatch, stale/missing context cache, tombstone not revived. |
| Model Providers | BYOK provider config is local. Fake/OpenAI-compatible/Anthropic/MIMO/Kimi shapes are covered. CI uses fake providers. | Add/edit provider, masked key, test connection, set default, restart persistence. | Settings/Packs -> Model Providers -> add fake provider -> success/failure tests -> set default -> restart. | Auth/rate-limit/timeout/network/server/malformed/missing text; key leak in logs/toString/safe JSON; deleting default provider. |
| Storage / Local DB / Events | SQLite/Drift object truth. Events are append-only audit/routing/idempotency evidence. Raw input is preserved through revisions. | Use offline, restart, inspect Trace, delete/restore. | Offline start -> capture -> restart -> timeline/Memory/Todo/Trace -> delete/restore/purge path. | Migration failure, old version upgrade, duplicate at-least-once events, transaction interruption, FTS/cache rebuild, purge leaves minimal tombstone. |
| Settings / Privacy | Settings covers locale, privacy, permissions, providers, backup, traces. Core loop needs no account. | Switch zh/en, revoke permission, inspect trace/audit, see privacy copy and dangerous-action warnings. | Settings -> locale zh/en -> revoke permission -> trace review -> backup warning -> offline no-account core loop. | Locale not persisted, remote capability overreach, external review leak, wrong permission state after restore, sensitive action without confirmation. |

## Required Tests And Kimi Review Inputs

| Module | Unit tests | Widget tests | Orchestration tests | Kimi input rules |
| --- | --- | --- | --- | --- |
| Home / Capture | Capture port/DAO saves raw first, attachment metadata/hash, AI failure does not mutate raw, event appended. | Compose Sheet, submit, pending/error/success, permission denied, zh/en. | capture -> event -> default pack -> Memory/card/insight -> trace/source link. | Use synthetic captures only. No real photos, audio, or user records. |
| Context Packet / Conversation | Packet schema, source refs, source hash/version, policy/generator invalidation, message repository, retry/failure. | Empty chat, messages, citations, retry, save-as proposal, zh/en. | local context packet -> deterministic assistant -> citation -> proposed Memory/Todo via policy. | No real chat, DB dump, or full raw packet. Use redacted fixtures. |
| Memory / Card / Insight / Recap | Auto-accept policy, accept/edit/reject/merge, revision/tombstone, source refs, daily local date. | Memory list/detail/edit/delete/restore, card detail, recap empty/loading/error/source. | capture -> candidate -> policy -> accepted Memory/card/recap -> timeline/detail/source. | No real personal Memory, especially health/finance/location/credential content. |
| Todo Pack | Pack subscription, todo suggestion, complete/reopen persistence, idempotency, source metadata. | Empty/enable-pack, todo rows, complete/reopen, source backlink, completed view. | capture event -> todo pack -> durable todo -> trace -> source detail. | Synthetic todos and due dates only. |
| Plugin / Permission / Pack Library | Manifest validator, subscription graph, permission subset, broker grant/deny/revoke, high-risk classification, script reject. | Pack library/detail, permission review, grant/deny/revoke dialogs, high-risk deferred state. | install/review -> runtime check -> denied task terminal -> revoked future task blocked. | No secrets, private pack bundles, or unpublished plugin code. Use manifest summaries and test results. |
| Backup / Owner Export / Restore | Manifest/version/counts, round trip, unsupported/malformed/missing/migration, secret include/exclude, stale cache tolerance. | Backup/export mode choice, secret warning, file save/import success/failure, restore preview. | full synthetic dataset -> backup -> restore -> provider/settings/packs/data usable; Owner Export no secrets. | Never send real backup, API keys, SQLite DB, or user data. Use synthetic fixtures. |
| Model Providers | Request builders, fake HTTP, error taxonomy, safe JSON/toString redaction, default persistence, backup includes credential branch. | Add/edit/test/default, masked key, failure states, delete/default fallback, zh/en. | provider config -> default -> fake model call -> trace/usage -> backup/restore. | No API key, endpoint secret, or raw logs. Live provider results only as redacted summaries. |
| Storage / Local DB / Events | Migrations, DAO transactions, raw immutability/versioning, event idempotency, purge/tombstone, index/cache rebuild. | User-visible persistence/error/trace/recovery surfaces only. | capture -> event -> task -> output -> trace; restart/restore consistency. | No SQLite files, full traces, or user data dumps. Use schema diff and synthetic rows. |
| Settings / Privacy | Settings/locale persistence, permission revoke effects, privacy tier flags, log/review prompt redaction. | Settings hub, locale switch, privacy warning, permission revoke, trace/backup/provider entries. | revoke permission -> runtime denied; locale persists after restart; offline no-account core path. | Review prompt contains ADR/RFC, redacted screenshots, and test summaries only. |

## Highest-Risk Misses

- Backup / Owner Export secrets boundary.
- Context Packet cache invalidation.
- Soft delete and purge semantics.
- Accepted Memory provenance.
- Official packs bypassing permission broker.
- Missing widget tests for visible UI states.
