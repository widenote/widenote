# API Service

## Purpose

Optional backend API for:

- Encrypted sync
- Backup and restore
- Device pairing
- Plugin and Agent Pack registry
- Push and scheduling hooks
- Cloud runner coordination

The API service must not be required for core local use.

## Ownership Boundary

The API service owns optional cloud and self-hosted HTTP/API behavior. It does not own local-first product semantics, raw record truth, or Agent Pack schema definitions.

## Public Surface

Future public surfaces may include OpenAPI routes, sync endpoints, registry endpoints, and runner coordination APIs.

## Dependencies

Allowed dependencies should flow through `packages/ts/*` and `packages/schemas`. The API must not depend on mobile-private code.

## Generated Artifacts

Generated OpenAPI specs, clients, migrations, or schema types must document their source of truth and generation command here when introduced.

## Related Context

- `docs/architecture/privacy.md`
- `docs/architecture/technology-stack.md`
- `docs/decisions/0001-use-product-monorepo.md`
