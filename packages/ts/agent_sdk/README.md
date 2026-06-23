# TypeScript Agent SDK

## Purpose

SDK for writing WideNote Agent Pack tools and runner-side agents.

## Ownership Boundary

Owns developer-facing SDK helpers for TypeScript runner-side agents and tools. It must not own WideNote runtime semantics directly.

## Public Surface

Future public surfaces include SDK APIs, examples, and compatibility helpers.

## Dependencies

May depend on `packages/ts/protocol` and generated schema bindings.

## Generated Artifacts

Generated SDK bindings must point back to `packages/schemas`.
