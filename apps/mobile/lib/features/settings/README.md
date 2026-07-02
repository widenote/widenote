# Settings Feature

## Purpose

Owns the phase-one Settings / Privacy hub for WideNote mobile. It gives users a
single control surface for privacy posture, permissions, model providers,
backup/restore, log inspection, and display status.

## Ownership Boundary

- Owns the Settings hub presentation and navigation entries.
- Owns the `/settings/...` route parent for permission review, model providers,
  voice transcription, location, backup/restore, and trace inspection pages.
- Summarizes privacy state from accepted product rules: local-first core,
  revocable/deferred permissions, and safe-export secret boundaries.
- Shows lightweight local status from existing read models: built-in/deferred
  permission counts, provider configuration state, backup state, log counts,
  and current locale.
- Links to existing feature pages for permission review, provider setup,
  system permission review, voice transcription settings, backup/restore, and
  log center instead of duplicating their behavior.
- Does not own backup codecs, model-provider persistence, permission schemas,
  trace storage, or locale persistence.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `go_router`
- `features/system_permissions` for app-level permission status
- `features/model_providers` for provider status chips
- `features/transcription` for voice transcription status and settings
- Existing `plugins`, `backup`, and `traces` read models and presentation pages

## Public Surface

- `presentation/settings_page.dart`

## Generated Artifacts

None.
