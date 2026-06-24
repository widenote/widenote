# Mobile Localization

## Purpose

Owns Flutter localization resources for the WideNote mobile client.

## Ownership Boundary

This module owns app-local user-visible strings and generated Flutter
localization bindings. Runtime schemas, stored user records, provider behavior,
and pack outputs are not localized here.

## Dependencies

- Flutter `gen-l10n`
- `flutter_localizations`
- `intl`

## Public Surface

- `app_en.arb`: English source strings and placeholder metadata.
- `app_zh.arb`: Simplified Chinese translations for the current app shell.
- `l10n.dart`: convenience export and `BuildContext` accessor.

## Generated Artifacts

Generated files live in `generated/` and must not be hand-edited.

Source of truth:

- `app_en.arb`
- `app_zh.arb`
- `l10n.yaml`

Generation command:

```sh
flutter gen-l10n
```
