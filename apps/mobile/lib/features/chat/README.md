# Chat Feature

## Purpose

Owns the first local conversation surface for WideNote.

The feature lets users create local chat sessions, append messages, ask a
model-backed assistant, and inspect source-linked citations produced from local
Context Packets.

The model-backed path runs as a local `read_only` chat run. Models may request
declared local read tools with strict JSON `tool_calls`; Chat validates the
declared read-tool allowlist, denies malformed, undeclared, write, external, or
high-risk tools in a model-visible tool result, and then asks the model for the
final cited answer.

## Ownership Boundary

This feature owns mobile chat domain models, controller state, presentation,
hard-boundary context packet adaptation, model-required assistant behavior, and
the mobile adapters that map chat sessions/messages and packet-derived source
refs onto `widenote_local_db` DAOs.

It does not own model-provider settings, companion/persona behavior, public
conversation schemas, or backup/export contracts. The current
`chat_sessions` and `chat_messages` tables are package-owned by
`packages/dart/local_db` and included in the local backup format.
Assistant messages may store the read-only `run_id` and compact tool summary in
the existing message payload JSON, alongside source refs.

Local code must not rank Chat sources or generate Chat answers with
hand-written keyword rules or local template fallback. Source selection
preserves Context Packet order and prompt-budget limits until a model-backed
retriever exists. Without a configured model provider, Chat should show a
retryable model-required state. The composer disables autocorrect,
suggestions, smart dashes, and smart quotes so literal questions, commands, and
source identifiers are not rewritten before persistence or model calls.
Empty model responses and provider failures remain retryable model errors; they
must not fall back to local template answers.

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
