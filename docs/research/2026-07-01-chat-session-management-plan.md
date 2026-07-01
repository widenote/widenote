# Chat Session Management Plan

Status: implemented slice under review

Date: 2026-07-01

Scope: improve the second mobile tab so users can start a new chat, switch
between chats, rename chats, and delete local chat history without leaving the
Chat tab.

## Reference Inputs

- WideNote current contracts and chat module:
  - `docs/architecture/current-contracts.md`
  - `apps/mobile/lib/features/chat/README.md`
  - `apps/mobile/lib/features/chat/**`
  - `packages/dart/local_db/lib/src/daos_chat.dart`
- MemeX local clean-room reference:
  - `/Users/guangmo/.codex/worktrees/7bc6/memex`
  - observed commit: `bf67d0b`
  - high-signal files:
    - `lib/ui/chat/widgets/agent_chat_dialog.dart`
    - `lib/ui/chat/widgets/chat_history_screen.dart`
    - `lib/ui/chat/view_models/chat_viewmodel.dart`
    - `lib/data/services/chat_service.dart`
    - `lib/data/repositories/chat.dart`
    - `lib/ui/character/widgets/persona_chat_screen.dart`
    - `lib/data/services/persona_chat_service.dart`
- Omi public clean-room reference:
  - `https://github.com/BasedHardware/omi`
  - local temporary clone: `/tmp/omi-chat-reference`
  - observed commit: `bebb3861a2ca0db3d867bd51d634f06984815b02`
  - high-signal files:
    - `app/lib/pages/chat/page.dart`
    - `app/lib/providers/message_provider.dart`
    - `app/lib/backend/http/api/messages.dart`
    - `app/lib/pages/conversations/conversations_page.dart`
    - `app/lib/providers/conversation_provider.dart`
    - `backend/routers/chat.py`
    - `backend/routers/chat_sessions.py`
    - `backend/routers/conversations.py`
    - `backend/database/chat.py`

Clean-room rule: MemeX and Omi are product-flow and interaction references
only. WideNote must keep WideNote-owned storage, UI, strings, tests, runtime
semantics, and source-link policies.

## Current WideNote Gap

WideNote already has `chat_sessions` and `chat_messages` in the local DB, and
`ChatController.sendMessage` implicitly creates a session for the first user
message. The user-facing Chat tab still made session management feel hidden:

- No explicit "new chat" entry.
- Session switching was a chip row, which worked for a few chats but did not
  read as durable management.
- No rename or delete affordance.
- A manually started blank chat could not exist, so the second tab felt like
  "one current conversation" until history accumulated.

The implementation already uses model-required local chat, Context Packet
source refs, retryable model failures, and read-only local tool calls. This
slice should not change answer generation, source selection, permissions, or
model fallback behavior.

## MemeX Interaction Inventory

| Surface | Entry and levels | User action | UI result | Background / storage logic |
| --- | --- | --- | --- | --- |
| `AgentChatDialog` | Level 1 modal chat surface, opened from assistant/chat entrypoints or from history with `initialSessionId`. | User sends a message in the composer. | User message appears immediately; AI response streams as response/thought/tool items; current session id is updated when created. | `MemexRouter.sendMessage` delegates to `ChatService.sendMessage`. If `sessionId` is empty, `_createSession` creates a YAML session file. It yields `ChatSessionCreatedEvent`, appends the user message, logs `user_chat`, initializes the configured agent, streams agent events, appends the AI message, and updates session usage/metadata. |
| `AgentChatDialog` history button | Level 2 navigation from dialog header to chat history route. | User taps the history icon. | Opens `ChatHistoryScreen`. Closing a restored dialog reloads history. | No new storage path; history reloads from repository endpoints after modal close. |
| `ChatHistoryScreen` | Dedicated list page. | Page opens. | Shows loading, empty state, or cards with title, last preview, relative time, message count, and quick-query badge. | `ChatViewModel.loadSessions` calls `MemexRouter.fetchChatSessions`, which reads session files, filters by `agentName`, sorts by file modified time, and computes preview/count metadata. |
| `ChatHistoryScreen` session row | Level 2 list item -> Level 1 dialog. | User taps a row. | Opens `AgentChatDialog(initialSessionId: sessionId)` for that session. | Dialog fetches session detail, reconstructs display items from persisted messages, restores total token usage, and restores quick-query/read-only mode. |
| `ChatHistoryScreen` delete action | Inline destructive action with confirmation dialog. | User taps delete, confirms. | Row is removed; success/failure toast is shown. | `ChatViewModel.deleteSession` calls `MemexRouter.deleteChatSession`, then removes the item from local list. Repository endpoint physically deletes the session file. |
| Read-only / quick query mode | Toggle in dialog before normal send. | User switches mode, then sends. | Mode is locked after a normal-mode message; restored from session metadata later. | `ChatService.sendMessage(isQuickQuery: true)` persists `is_quick_query` on the session and initializes the agent with filtered read-only skills. |
| Persona chat | Separate 1:1 character chat surface opened by persona avatar. | User opens a character, sends a message, leaves the screen. | Messages display in a character-specific thread; unread count is marked read. | `PersonaChatService` reads/writes Drift `personaChatMessages` by `characterId`. On send it saves user text, streams `CompanionAgent.chat`, saves character reply, and on dispose runs companion memory update in the background. |

MemeX lesson for WideNote: a separate history page works, but it adds a second
place to manage chats. For WideNote's second tab, inline session management is
clearer and lighter because the tab itself is already the durable chat surface.

## Omi Interaction Inventory

| Surface | Entry and levels | User action | UI result | Background / storage logic |
| --- | --- | --- | --- | --- |
| Mobile `ChatPage` | Level 1 full-screen chat page. | Page opens. | Loads cached/server messages, fetches enabled chat apps, pre-connects optional agent WebSocket, focuses text unless voice mode is requested. | `MessageProvider.refreshMessages` calls `getMessagesServer(appId, dropdownSelected)`, then sorts messages by `createdAt` and updates cache. |
| Mobile app selector drawer | Level 1 chat page -> end drawer. | User taps extension icon. | Drawer shows clear chat, enable apps, Omi default, and enabled chat-capable apps. | Selecting an app updates `AppProvider.selectedChatAppId`, refreshes app-scoped messages, and sends an initial app message when the target has no messages. |
| Mobile clear chat | Drawer action -> confirmation dialog. | User taps clear chat and confirms. | Current app-scoped feed is cleared/replaced by server response. | `MessageProvider.clearChat` calls `DELETE /v2/messages?app_id=...`. This is feed/app scoped, not multi-session management. |
| Mobile composer | Chat page bottom input. | User types, attaches files, records voice, or sends. | Human message is inserted locally; AI placeholder streams chunks; jump-to-latest handles reader scroll state. | `sendMessageStreamToServer` calls streaming `POST /v2/messages`; files are uploaded first; voice path records/transcribes then sends. Quota errors become a visible AI reply or plans sheet. |
| Mobile conversations page | Separate primary product surface for recorded/transcribed conversations. | User searches, filters, opens folders, watches processing, merges/moves recordings. | Shows date-grouped recorded conversations, processing capture state, folders, goals, summaries, search results. | `ConversationProvider` calls conversation APIs; backend `GET /v1/conversations` lists processing/completed recording objects and redacts list fields. This is not chat history. |
| Backend chat v2 sessions | API surface mainly used by desktop/newer clients. | Client creates/lists/patches/deletes chat sessions. | Session list supports title, preview, message count, starred, and pagination. | `backend/routers/chat_sessions.py` exposes `/v2/chat-sessions`; `database/chat.py` stores Firestore `users/{uid}/chat_sessions` with `title`, `preview`, `message_count`, `starred`, `app_id`, `plugin_id`, `created_at`, `updated_at`. |
| Backend desktop messages | Persistence-only session messages. | Client saves/list/deletes/rates messages by session. | Messages are tied to a `chat_session_id`. | `save_message` auto-acquires a session when missing, writes a message, increments session `message_count`, updates `preview`, and keeps `app_id`/`plugin_id` for compatibility. |
| Backend title generation | API helper. | Client asks for title after messages exist. | Short generated session title. | `/v2/chat/generate-title` runs an LLM on up to 10 messages and patches session title, falling back to `New Chat`. |

Omi lesson for WideNote: Omi's mobile chat page is app-scoped, while its newer
backend chat-session API is closer to the target management model. The recorded
`conversation` product is a separate object family and should not be copied into
WideNote Chat.

## WideNote Implementation Choice

This slice implements the smallest complete local-first chat management layer:

1. Keep one second-tab Chat page, not a separate history route.
2. Add a visible `New chat` button inside the session panel.
3. Show sessions as a vertical management list with active-state, message count,
   switch affordance, and per-session action menu.
4. Add rename and delete actions with confirmation for delete.
5. Preserve current model-required answering, source refs, retry, and read-only
   tool-loop behavior.
6. Keep `chat_sessions` and `chat_messages` as SQLite truth. `messageCount` is
   a derived UI/domain value computed by the repository, not a schema migration.
7. Store the internal default title as stable `New chat`; render it through
   localization when the session is still empty.
8. Delete removes the local session and messages on this device. It does not
   mutate captures, Memory, cards, todos, traces, or source truth.

Deferred intentionally:

- Search across chat sessions.
- Star/pin/archive folders.
- LLM-generated session titles.
- Bulk delete/export.
- Per-session model/provider choice.
- Separate companion/persona mode.

Those are useful later, but this slice fixes the missing core controls without
changing public contracts or model/runtime behavior.

## Test Plan

Checks run:

- `dart test test/local_db_test.dart` from `packages/dart/local_db`: passed.
- `flutter analyze` from `apps/mobile`: passed.
- `flutter test test/chat_controller_test.dart test/chat_page_test.dart` from
  `apps/mobile`: passed with proxy variables unset for `flutter_tester`.
- `flutter test` from `apps/mobile`: passed with proxy variables unset;
  live-provider QA remained skipped because the required dart-define keys were
  not provided.
- Android emulator QA on `Medium_Phone_API_35`: passed.
  - `:app:installDevDebug` built the APK but Gradle install hit an ADB sync
    `EOF`; direct `adb install -r -d app-dev-debug.apk` succeeded.
  - Opened Chat tab and verified `Conversations`, `New chat`, empty state, and
    composer.
  - Sent a message with no model configured and verified local session creation,
    `1 message`, and retryable model configuration failure.
  - Created a new blank chat and verified it became the active empty session
    while the previous session stayed in the list.
  - Switched back to the previous session and verified its failed message was
    restored.
  - Opened per-session actions, renamed the session, and verified the list title
    updated.
  - Deleted the renamed session through confirmation and verified only the blank
    `New chat` session remained active, with `Chat deleted.` feedback.
  - Logcat showed no app fatal exception or crash during the flow.

## Kimi Review

Kimi review was run on a sanitized implementation summary after two larger
diff-based attempts stalled without final findings. No API keys, private
records, local databases, credentials, or secret-bearing artifacts were sent.

Result: no blocking P0/P1 issue found.

Non-blocking observations and local disposition:

- `messageCount` is derived from messages. The local schema already has
  `chat_messages_session_created_at_idx` on `(session_id, created_at)`, so the
  current list/count path has a session-id index available.
- Delete cleanup should avoid orphan chat-owned data. Chat source refs and
  tool-loop summaries are stored inside `chat_messages`; the DAO deletes
  messages before deleting the session, and the schema also has
  `FOREIGN KEY(session_id) ... ON DELETE CASCADE`. Capture, Memory, cards,
  todos, artifacts, and traces are source truth or independent derived records
  and are intentionally not deleted by chat history management.
- Rename persistence should survive process restart. `renameSession` calls
  `ChatRepository.saveSession`; `LocalChatRepository.saveSession` upserts the
  local `chat_sessions` row, and the repository test now verifies a renamed
  title reloads from the local DB before deletion.
