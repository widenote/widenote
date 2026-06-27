# Local Semantic Rule Audit

Date: 2026-06-27

## Principle

WideNote core must not read user natural-language content and then use keyword,
regular expression, substring, or stop-word heuristics to infer, classify, mask,
rank, route, or answer.

Model-backed work must fail visibly or wait for retry/configuration when no
model is available. Tests may inject fake models, but those fakes must not
become runtime fallback behavior.

## Current State Before This Fix

### Violations

- `apps/mobile/lib/features/chat/application/chat_context.dart` ranked local
  Chat sources by splitting the user question into terms, checking substrings,
  using stop words, and applying kind/intent boosts.
- `apps/mobile/lib/features/chat/application/chat_assistant.dart` returned a
  deterministic local template answer when no model was configured, when no
  sources were available, when the model returned empty text, or when the model
  threw.
- Provider settings copy described Chat as covered by local deterministic
  fallback, which no longer matches the intended product boundary.
- Capture used keyword lists for secret/token/password, health, finance, and
  location terms to set `memory_type`, `confidence`, and `sensitivity`.
- Capture used keyword-derived sensitivity to skip Todo suggestion.
- Capture used `previewText` as a summary when the model failed.
- `LocalChatContextSource` used core regular expressions to redact secrets,
  prompt-injection-like text, and local paths from user content.
- `ContextPacketBuilder` used core regular expressions to redact secrets from
  Memory, capture, card, insight, Todo, and attachment filename text.
- `RuntimeKernel` used core key-name and text regular expressions to redact
  trace details.
- Safe backup used recursive key and string matching to redact provider payload
  content.
- Timeline browse search used query token splitting and substring matching over
  cards, Memory, captures, todos, source links, and metadata.
- Memory management search used query token splitting and substring matching
  over Memory body, type, status, source label, confidence, and sensitivity.

## Changes in This Fix

- Chat source selection no longer inspects the question. It preserves Context
  Packet disclosure order and applies only a prompt-budget limit.
- Chat uses a dedicated model client path that does not fall back to the local
  summary client.
- Without a configured model provider or QA model client, Chat marks the user
  message failed with a model-required error and keeps retry available.
- Model request failures and empty model responses become retryable Chat
  failures, not local template answers.
- Provider settings copy now says Chat/model-backed work requires a configured
  provider while raw capture remains local-first.
- Capture composer text drafts now persist locally and clear after successful
  submit.
- Capture no longer assigns Memory type, sensitivity, confidence, or Todo
  branching from keyword hits in the capture body.
- Capture model failure no longer falls back to `previewText`; the agent task
  fails and the raw capture remains locally saved by the caller.
- Chat local context no longer redacts user text with core secret/path/prompt
  regular expressions.
- Context Packet generation no longer applies generic secret/token/password
  text redaction to user content.
- Runtime trace details no longer use core secret/token/password key or text
  matching. Trace strings are length-limited only.
- Safe backup no longer recursively scans provider payload text or keys; the
  safe mode keeps explicit provider metadata and omits the rest of the payload.
- Timeline no longer uses local text token/substring matching. The local
  surface keeps type filtering and shows a retriever-required state for text
  queries until embedding/model-backed retrieval exists.
- Memory management no longer uses local text token/substring matching. Text
  queries show a retriever-required state while normal local browse/edit/delete
  flows remain available after clearing the query.
