# Dart Packages

Dart packages used by the Flutter app and local runtime.

## Ownership Boundary

Dart packages own reusable client-side logic. Flutter app assembly belongs in `apps/mobile`.

## Module Map

| Module | Context | Purpose |
| --- | --- | --- |
| Core | `core/README.md` | Pure Dart models and utilities |
| Local DB | `local_db/README.md` | Drift and SQLite data layer |
| Agent Runtime | `agent_runtime/README.md` | Local Agent Runtime Kernel |
| UI Blocks | `ui_blocks/README.md` | Structured UI block rendering |
| Memory | `memory/README.md` | Pure Dart Memory lifecycle and write policy |
| Model Providers | `model_providers/README.md` | Pure Dart model provider contracts and fakes |
