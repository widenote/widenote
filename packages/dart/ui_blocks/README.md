# Dart UI Blocks

## Purpose

Flutter rendering for safe, structured UI blocks emitted by Agent Packs.

## Ownership Boundary

Owns rendering for structured UI block schemas. It must not execute arbitrary plugin UI code in the store-safe path.

## Public Surface

Future public surfaces include Flutter widgets and renderers for supported UI block schemas.

## Dependencies

May depend on Flutter and generated UI block schema bindings.

## Generated Artifacts

Generated UI block bindings must point back to `packages/schemas`.
