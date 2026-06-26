# Settings Feature

## Purpose

Owns the phase-one Settings / Privacy hub for WideNote mobile. It gives users a
single control surface for privacy posture, permissions, model providers,
backup/restore, trace inspection, and display status.

## Ownership Boundary

- Owns the Settings hub presentation and navigation entries.
- Summarizes privacy state from accepted product rules: local-first core,
  revocable/deferred permissions, and safe-export secret boundaries.
- Shows lightweight local status from existing read models: built-in/deferred
  permission counts, provider configuration state, backup state, trace counts,
  and current locale.
- Links to existing feature pages for permission review, provider setup,
  backup/restore, and trace console instead of duplicating their behavior.
- Does not own backup codecs, model-provider persistence, permission schemas,
  trace storage, or locale persistence.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `go_router`
- `features/model_providers` for provider status chips
- Existing `plugins`, `backup`, and `traces` read models and presentation routes

## Public Surface

- `presentation/settings_page.dart`

## Generated Artifacts

None.
