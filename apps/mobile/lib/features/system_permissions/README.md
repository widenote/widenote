# System Permissions Feature

## Purpose

Owns the Settings child page that checks Android and iOS app-level permission
state for WideNote's current platform integrations.

## Ownership Boundary

- Shows the current system permission posture for camera, microphone, foreground
  location, iOS photos, file picker access, and calendar readiness.
- Requests only permissions that already have product use and platform
  declarations: camera, microphone, foreground location, and iOS photos.
- Opens app or location settings so users can manage previously granted or
  blocked permissions.
- Treats Android media access, file access, and calendar access as informational
  rows because current WideNote flows use system pickers and do not own system
  calendar read/write.
- Does not replace capture-time permission prompts. Capture, voice, location,
  backup, and import flows remain responsible for handling permission failures
  at the point of use.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `go_router`
- `permission_handler` for runtime permission status and app settings
- `geolocator` for location-service settings

## Public Surface

- `application/system_permissions_controller.dart`
- `presentation/system_permissions_page.dart`

## Generated Artifacts

None.

## Related Context

- `docs/architecture/current-contracts.md`: local-first ownership, location
  context, Todo and schedule admission, and high-risk permission boundaries.
- `apps/mobile/lib/features/settings/README.md`
