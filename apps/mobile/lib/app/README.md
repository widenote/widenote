# App Shell

## Purpose

Owns the Flutter application root, Material theme, top-level tab routing,
production local database bootstrap providers, and the app support-directory
provider used by app-local UI state.

## Ownership Boundary

This module composes feature pages and app-level providers. It does not own
feature state, public schemas, local database table semantics, or runtime
orchestration behavior.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `go_router`
- `path_provider`
- `packages/dart/local_db`
- `packages/dart/memory`

## Public Surface

- `WideNoteApp`
- `WideNoteAppTheme`
- `appRouter`
- `mobileParentPathFor`
- `WideNoteShell`
- `WideNoteMobileBootstrap`
- `appSupportDirectoryProvider`
- `localDatabaseProvider`
- `localEventStoreProvider`
- `localTraceSinkProvider`
- `localMemoryRepositoryProvider`

## Navigation Contract

The app shell owns the mobile route hierarchy.

Bottom tab roots are peers:

- `/`: Home / quick capture
- `/chat`: Chat
- `/todos`: Todos
- `/plugins`: Agent Packs and runtime controls

The center Record item is an action that opens capture from Home, not a route.

All other pages are child pages:

- Home children: `/timeline`, `/memory`, `/recap`, `/insights`,
  `/settings`
- Timeline children: `/timeline/search`, `/timeline/cards/:cardId`,
  `/timeline/items/:itemId`
- Insights children: `/insights/:insightId`
- Chat children: `/chat/session/:sessionId`
- Todos children: `/todos/:todoId`
- Settings children: `/settings/permissions`,
  `/settings/system-permissions`, `/settings/model-providers`,
  `/settings/transcription`, `/settings/location`, `/settings/backup`,
  `/settings/traces`, `/settings/traces/agents`,
  `/settings/traces/events`, `/settings/traces/raw`,
  `/settings/traces/raw/:traceId`
- Plugins children: `/plugins/packs`

UI controls that open direct child pages should use push-style navigation.
Shortcuts that skip an intermediate parent should construct the declared parent
stack. Bottom tab switches should use replacement-style navigation. Direct
links to child pages must still return through the declared parent on system
back. Contextual source links may preserve the visible source page as the
immediate back target.

The shell also keeps a parent-route fallback for non-root pages. If a child
page is opened as a single-page stack by a platform entrypoint or future
shortcut, system back uses the declared parent path instead of delegating
directly to platform exit.

The Plugins tab may surface visual shortcuts for permissions, model providers,
backup, and traces, but those shortcuts navigate to the Settings-owned
`/settings/...` routes instead of declaring duplicate `/plugins/...` pages.
The legacy `/settings/traces/events` path redirects to the canonical raw-log
list at `/settings/traces/raw`.

## Generated Artifacts

None.

## Related Context

- `docs/decisions/0015-use-hierarchical-mobile-navigation.md`
