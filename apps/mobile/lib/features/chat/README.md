# Chat Feature

## Purpose

Owns the first local conversation surface for WideNote.

The feature lets users create local chat sessions, append messages, ask a
deterministic offline assistant, and inspect source-linked citations produced
from local Context Packets.

## Ownership Boundary

This feature owns mobile chat domain models, controller state, presentation,
context selection, deterministic local assistant behavior, and the mobile
adapters that map chat sessions/messages and packet-derived source refs onto
`widenote_local_db` DAOs.

It does not own model-provider settings, companion/persona behavior, public
conversation schemas, or backup/export contracts. The current
`chat_sessions` and `chat_messages` tables are package-owned by
`packages/dart/local_db` and included in the local backup format.

## Dependencies

- Flutter Material
- Riverpod
- Mobile localization (`apps/mobile/lib/l10n`)
- `widenote_local_db` for local SQLite access and `ContextPacketBuilder`

## Public Surface

- `domain/ChatSession`, `ChatMessage`, `ChatSource`, and related value objects
- `application/ChatRepository`
- `application/ChatContextSource`
- `application/ChatAssistant`
- `application/chatControllerProvider`
- `presentation/ChatPage`

## Generated Artifacts

None.

Localization generated files live in `apps/mobile/lib/l10n/generated/` and are
owned by the localization module.

## Tests

Run from `apps/mobile`:

```sh
flutter test test/chat_controller_test.dart test/chat_page_test.dart
```
