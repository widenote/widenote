# ADR-0014: Accept Location Capture Boundaries

Status: accepted

Date: 2026-07-01

## Context

WideNote needs optional location context for records. The requested first slice
should capture device GPS when the user has enabled the capability and should
support AMap reverse geocoding for human-readable place context.

Location tied to timestamps and personal records is sensitive behavioral data.
Reverse geocoding also sends coordinates to a third-party service. The feature
must preserve WideNote's local-first source-truth model while making third-party
sharing explicit and reviewable.

## Decision

- Local GPS capture is opt-in and uses foreground one-shot location only.
- AMap reverse geocoding is a separate opt-in switch because it sends the record
  coordinate to AMap Web Service.
- Raw device coordinates are saved as source metadata on the local capture
  payload and projected into `fact_metadata.location`. They remain tied to the
  original record and are not AI output.
- AMap address fields and the geocoded place name are contextual facts derived
  from the source coordinate. They are saved in `location_context` and the
  structured `fact_metadata.location.place` projection with provider and
  provider-specific fields marked separately. Reverse geocode failure must not
  block saving the record.
- Location facts carry source references back to the capture so future maps,
  insights, or Memory-derived outputs can preserve provenance when they depend
  on record location.
- Runtime event payloads must not duplicate full coordinates. The local capture
  row is the authoritative storage location for precise record coordinates and
  place facts.
- User-facing lists default to coarse location display. Detailed addresses or
  coordinates must not be shown by default in timeline rows or settings status.
- Users must be able to stop future capture and clear saved capture-location
  facts from existing records.
- AMap API keys are credentials. They live in secure storage and must not enter
  SQLite safe backups, Owner Export, logs, fixtures, screenshots, automated
  review prompts, PR descriptions, or generated docs.

## Consequences

- Capture can take a short foreground-location timeout before the local record
  is fully persisted. If location is unavailable, the record is still saved with
  no coordinate or with an unavailable status.
- AMap setup requires Settings copy that explains third-party coordinate
  sharing.
- Backup/export and future sync work must treat location context as sensitive
  user data and preserve the credential boundary.
- Future map, route, insight, or Agent Pack behavior should consume
  `fact_metadata.location` or a future public schema derived from it rather
  than reading private UI state.

## Alternatives Considered

- Enable reverse geocoding automatically when local GPS is enabled. Rejected:
  it hides third-party coordinate sharing behind a local-sounding switch.
- Store full coordinates in both event log and capture payload. Rejected:
  duplicate sensitive storage increases the leak surface without adding source
  truth value.
- Use AMap platform SDKs for the first slice. Rejected: Web Service keeps the
  integration narrower, easier to fake in tests, and aligned with Memex's
  configuration pattern.

## References

- `docs/research/2026-07-01-location-context-amap-kimi-review.md`
- `apps/mobile/lib/features/location/README.md`
