# Capture Feature

## Purpose

Owns the home/records tab, Quick Capture UI, app-local capture read model, and
Memory review surface.

## Ownership Boundary

This feature presents record, Memory, todo, and trace feedback from the local
runtime. It must not become the durable runtime, policy, persistence, or schema
source of truth.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `packages/dart/agent_runtime`
- `packages/dart/memory`

## Public Surface

- `presentation/HomePage`
- `application/captureControllerProvider`
- `application/captureOrchestratorProvider`
- lightweight domain view models in `domain/`

## Generated Artifacts

None.
