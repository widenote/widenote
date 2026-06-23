# TypeScript Protocol

## Purpose

Generated and hand-written protocol helpers for WideNote schemas.

## Ownership Boundary

Owns TypeScript helpers for shared schemas. It must not own API route behavior or runner execution.

## Public Surface

Future public surfaces include generated TypeScript types, validators, and protocol helper functions.

## Dependencies

Should depend on `packages/schemas` outputs. Must not depend on app-private code.

## Generated Artifacts

Generated protocol helpers must document schema source paths and generation commands when introduced.
