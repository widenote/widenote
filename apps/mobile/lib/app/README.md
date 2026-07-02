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

- Home children: `/timeline`, `/memory`, `/recap`, `/settings`
- Timeline children: `/timeline/search`, `/timeline/cards/:cardId`,
  `/timeline/items/:itemId`
- Settings children: `/settings/permissions`,
  `/settings/system-permissions`, `/settings/model-providers`,
  `/settings/transcription`, `/settings/location`, `/settings/backup`,
  `/settings/traces`
- Plugins children: `/plugins/packs`, `/plugins/permissions`,
  `/plugins/model-providers`, `/plugins/backup`, `/plugins/traces`

UI controls that open direct child pages should use push-style navigation.
Shortcuts that skip an intermediate parent should construct the declared parent
stack. Bottom tab switches should use replacement-style navigation. Direct
links to child pages must still return through the declared parent on system
back. Contextual source links may preserve the visible source page as the
immediate back target.

## Generated Artifacts

None.

## Related Context

- `docs/decisions/0015-use-hierarchical-mobile-navigation.md`
