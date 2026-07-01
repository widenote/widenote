# Location Context AMap And Kimi Review

Date: 2026-07-01

## Scope

This note records the first-slice design for opt-in location context on capture
records. The review input excluded API keys, local databases, backups, private
records, screenshots, and other user data.

## Memex Reference

The Memex implementation uses a settings object with enablement, provider,
AMap key, display granularity, and freshness controls. It records raw device
GPS as WGS84 input metadata, uses Geolocator with short timeouts and recent
last-known fallback, and calls AMap Web Service reverse geocoding after
converting WGS84 GPS into the AMap GCJ-02 coordinate system.

The useful pieces for WideNote are:

- Keep raw GPS and reverse-geocoded address as separate fields.
- Do not block record creation when permission, GPS, network, or AMap fails.
- Store provider failures as structured status/reason data.
- Test the AMap URL, response parsing, missing-key path, and coordinate
  conversion separately from real live API calls.

## AMap Documentation Checked

Official AMap Web Service documentation says geocoding/reverse geocoding uses
HTTP/HTTPS and requires a Web Service Key. Reverse geocoding uses
`https://restapi.amap.com/v3/geocode/regeo`, with `key` and `location`
required. `location` is longitude first, latitude second, comma-separated, and
should not exceed 6 decimal places. `extensions=base` returns basic structured
address data; `extensions=all` returns heavier nearby POI/road data. AMap also
documents coordinate conversion from GPS/WGS84-like input into AMap's GCJ-02
coordinate system.

Primary references:

- <https://lbs.amap.com/api/webservice/guide/api/georegeo>
- <https://lbs.amap.com/api/webservice/guide/api/convert>

## Kimi Findings

Kimi agreed with the modular direction but flagged four P0 changes before
shipping:

- Split local GPS capture from AMap reverse geocoding because AMap receives
  record coordinates.
- Treat GPS plus timestamp plus note as sensitive behavioral data and avoid
  copying it into logs, fixtures, external review prompts, or event payloads.
- Ensure capture timing does not create a saved record that silently misses
  location because the app was closed during a fire-and-forget lookup.
- Default UI display should be coarse/redacted and historical saved locations
  need a user-visible clearing path.

## Resolution

The implementation follows those findings:

- Settings has separate switches for local GPS and AMap reverse geocoding.
- AMap API keys are stored in Flutter secure storage.
- Capture performs the short location attempt before persisting the pending
  record, while still saving the record when location is unavailable.
- Full coordinates and geocoded place names are stored as record facts under
  `captures.payload_json.location_context` and the structured
  `captures.payload_json.fact_metadata.location` projection. Runtime capture
  event payloads do not duplicate full coordinates.
- Timeline metadata reads the location fact projection so current UI and future
  visualization work can share one source for latitude, longitude, coordinate
  system, provider, and place name.
- Home and timeline surfaces display only coarse address summaries or status
  chips by default.
- Settings includes a clear-saved-locations action for existing capture
  facts.

## Validation Plan

- Unit tests for location JSON, AMap request/parse/failure paths, and
  coordinate conversion.
- Widget tests for Settings entry, location switches, AMap key field,
  granularity, testing status, and clear-saved-locations flow.
- Capture tests proving coordinates and geocoded place names persist to capture
  fact metadata and timeline metadata but not event payload.
- Android/iOS manifest tests proving foreground-only location permissions.
- Android emulator QA for the settings and capture user flow when an emulator
  is available.

## Validation Completed

- `flutter analyze` from `apps/mobile`.
- `flutter test` from `apps/mobile`.
- `./gradlew :app:assembleDevDebug --console=plain` from `apps/mobile/android`.
- Android emulator API 35:
  - Verified the Settings entry, Location Context page, separate GPS and AMap
    switches, disabled AMap key field before GPS is enabled, and coarse display
    copy.
  - Verified the Android foreground location permission prompt. The app asks
    for while-using location, not background location.
  - Verified `Test location` can reach `Location captured`, `GPS coordinates
    saved on the local record`, and `AMap lookup is off` after injecting a
    simulator GPS fix.
  - Verified record capture still saves when location is unavailable and that a
    later capture can display `GPS saved` when a fresh simulator GPS fix is
    available.
  - Crash buffer was empty after the emulator flows.

## Final Kimi Review

Kimi's final review repeated the core privacy concerns and flagged a few
possible P0/P1 gaps. WideNote-specific follow-up:

- `CurrentLocationContext.toSystemReminderContent()` and
  `location_context_reminder` do not exist in this codebase, so the reminder
  leakage concern was a Memex/generic-path false positive.
- AMap keys are stored by `FlutterSecureStorage`, not `SharedPreferences`.
- There is no reverse-geocode cache in this slice; clear saved locations removes
  both `location_context` and `fact_metadata.location` directly from capture
  payloads.
- The remaining real follow-up areas are backup/export policy for sensitive
  location fact metadata, optional TTL/retention controls, and future
  downstream derived-output invalidation if location facts are allowed to feed
  Memory, insights, or agent prompts. This first slice exposes location facts
  to UI/timeline/visualization paths but does not automatically feed them into
  Memory or insight generation.

## Fact-Layer Follow-Up Review

After product clarification, Kimi reviewed the updated fact-layer direction.
WideNote-specific result:

- The revised `fact_metadata.location` projection satisfies the requirement
  that coordinates and geocoded place names enter the record fact layer for UI
  and future visualization.
- The review correctly flagged that AMap place data should not be treated as
  raw user truth. The implementation marks the coordinate as
  `source_coordinate`, marks the AMap result as `derived_place`, preserves the
  provider, and keeps provider-specific AMap fields under
  `provider_specific.amap`.
- The review correctly flagged provenance for future derived outputs. The
  location fact now carries source refs back to the capture and
  `payload.location_context`.
- The review repeated a few already-covered items: ADR/current-contracts/privacy
  docs exist in this PR, GPS and AMap are separate switches, and user-facing
  copy is localized through ARB.
- Remaining follow-ups stay the same: encrypted backup/export/sync policy,
  optional storage precision or retention controls, and explicit invalidation
  rules before Memory, insights, or agent prompts depend on location facts.
