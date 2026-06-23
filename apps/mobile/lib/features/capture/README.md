# Capture Feature

## Purpose

Owns the home/records tab, Quick Capture UI, and the temporary app-local capture controller.

## Ownership Boundary

This feature can simulate record, Memory, todo, and trace feedback for the UI skeleton. It must not become the durable runtime or schema source of truth.

## Dependencies

- Flutter Material
- `flutter_riverpod`

## Public Surface

- `presentation/HomePage`
- `application/captureControllerProvider`
- lightweight domain view models in `domain/`

## Generated Artifacts

None.
