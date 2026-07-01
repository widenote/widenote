# Location Feature

## Purpose

Owns opt-in location context for capture records. When enabled, WideNote saves
a single foreground device GPS snapshot with new records and can separately use
AMap Web Service reverse geocoding to attach geocoded place facts and a coarse
address summary.

## Ownership Boundary

This feature owns mobile settings, one-shot foreground location capture,
AMap reverse-geocode calls, and presentation of redacted location status. It
does not own public schemas, Memory policy, backup codecs, runtime events, or
background location.

Precise GPS coordinates and geocoded place names are stored on the local
capture payload as user record facts. The raw context lives in
`location_context`; the query/visualization projection lives in
`fact_metadata.location`. The coordinate entry is marked as the source
coordinate, while the AMap place entry is marked as a provider-derived place
with source refs back to the capture. Runtime event payloads do not duplicate
coordinates. AMap API keys are stored in Flutter secure storage and must not
enter `.widenote` backups, Owner Export, logs, screenshots, fixtures, external
review prompts, or PR text.

AMap reverse geocoding has a separate user-visible switch because it sends the
record coordinate to a third-party Web Service. The local GPS switch can be used
without AMap.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `flutter_secure_storage`
- `geolocator`
- `packages/dart/local_db` for clearing saved capture-location metadata
- `apps/mobile/lib/features/timeline` for fact-backed location display

## Public Surface

- `domain/location_context.dart`
- `application/location_capture_service.dart`
- `application/location_settings_controller.dart`
- `presentation/LocationSettingsPage`

## Generated Artifacts

None.

## Related Context

- `docs/architecture/current-contracts.md`
- `docs/architecture/privacy.md`
- `docs/architecture/engineering-rules.md`
- `apps/mobile/lib/features/capture/README.md`
- `apps/mobile/lib/features/settings/README.md`
