# Dart Core

## Purpose

Core Dart models and pure runtime utilities.

This package should not depend on Flutter UI.

## Ownership Boundary

Owns pure Dart primitives that are shared by local runtime packages. It must not own app wiring, persistence migrations, or UI rendering.

## Public Surface

Future public surfaces include pure Dart model helpers and runtime-neutral utilities.

## Dependencies

May depend on generated schema bindings. Must not depend on Flutter packages or app-private code.

## Generated Artifacts

Generated Dart models should normally come from `packages/schemas`, not this package.
