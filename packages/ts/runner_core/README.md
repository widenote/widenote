# TypeScript Runner Core

## Purpose

Reusable runner execution primitives.

## Ownership Boundary

Owns runner-side primitives shared by runner hosts. It must not own public schema definitions or API service route wiring.

## Public Surface

Future public surfaces include task execution primitives, checkpoint interfaces, trace helpers, and tool execution boundaries.

## Dependencies

May depend on `packages/ts/protocol` and generated schema bindings.

## Generated Artifacts

Generated runner bindings must point back to `packages/schemas`.
