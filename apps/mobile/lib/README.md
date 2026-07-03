# Mobile Dart Source

## Purpose

Flutter source for the WideNote mobile client.

## Ownership Boundary

This tree owns app composition, feature UI, local runtime wiring, and app-local
read state used by the mobile shell. Shared schemas, runtime logic, and local
database code live under `packages/`.

## Dependencies

- Flutter Material widgets
- `flutter_riverpod` for local state wiring
- `go_router` for tab routing
- `path_provider` for production database location
- `sqlite3_flutter_libs` for packaged SQLite on Flutter targets
- `packages/dart/local_db` for local runtime event and trace persistence
- `packages/dart/model_providers` for provider setup contracts and fake
  connection tests

## Public Surface

- `main.dart`
- `app/WideNoteMobileBootstrap`
- `app/localDatabaseProvider`
- `app/WideNoteApp`
- feature pages under `features/*/presentation`
- `features/backup/BackupPage`
- `features/insights/InsightsPage` and `InsightDetailPage`
- `features/agent_status/AgentExecutionStatusLayer`
- `features/model_providers/ModelProviderSettingsPage`
- `features/transcription/VoiceTranscriptionSettingsPage`
- `features/traces/TraceConsolePage` and `TraceRawLogsPage`
- `features/usage_stats/UsageStatsPage`
- localizations under `l10n/`

The app shell shows bottom tabs only for the four peer route roots: `/`,
`/chat`, `/todos`, and `/plugins`. All other pages under this tree are
hierarchical child pages and should render without bottom tabs while preserving
their parent back stack.

## Generated Artifacts

Flutter localization bindings are generated into `l10n/generated/` from ARB
files in `l10n/`.

Generation command:

```sh
flutter gen-l10n
```
