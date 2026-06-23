# Default Agent Pack

## Purpose

The default pack should support the first product loop:

```text
capture.created -> card extraction -> memory candidates -> lightweight insight
```

It should not enable todos, document generation, external export, or graphical agent flow by default.

## Ownership Boundary

Owns the default product capability bundle. It must stay conservative and store-safe.

## Public Surface

Future public surfaces include the default Agent Pack manifest, subscriptions, prompt definitions, permission requests, and UI/output declarations.

## Dependencies

May depend on public Agent Pack, Event, Memory, Permission, Tool, and UI Block schemas.

## Generated Artifacts

Generated pack indexes or manifest docs must point back to the pack manifest source when introduced.

## Related Context

- `docs/product/positioning.md`
- `docs/architecture/runtime.md`
