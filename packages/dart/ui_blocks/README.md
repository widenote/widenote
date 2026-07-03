# Dart UI Blocks

## Purpose

Flutter rendering for safe, structured UI blocks emitted by Agent Packs. Pack
UI contributions declare where these blocks, settings forms, panels, or actions
can appear in app-owned host surfaces.

## Ownership Boundary

Owns rendering for structured UI block schemas and host-rendered Pack UI
contribution kinds. It must not execute arbitrary plugin UI code in the
store-safe path.

## Public Surface

Future public surfaces include Flutter widgets and renderers for supported UI
block schemas and contribution kinds such as settings forms, panels, inline
status rows, and event-block details.

## Dependencies

May depend on Flutter and generated UI block schema bindings.

## Generated Artifacts

Generated UI block bindings must point back to `packages/schemas`.
