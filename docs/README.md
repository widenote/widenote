# WideNote Docs

This directory is the project memory for humans and agents.

```text
product/          Product positioning, users, default experience, and roadmap.
architecture/     Runtime, data, privacy, project structure, and technical design.
decisions/        Accepted, rejected, superseded, and deprecated ADRs.
rfcs/             Open design proposals for major changes.
research/         External research and summarized discussion evidence.
agent-context/    Entry points for future AI agents working in this repo.
templates/        Reusable ADR, RFC, and conversation-summary templates.
```

For current decisions, start with [decisions/index.md](./decisions/index.md).

## Current Phase-One Plans

- [Phase One Technical Plan](./architecture/phase-one-technical-plan.md)
- [Phase One Module Plan](./architecture/phase-one-module-plan.md)
- [Engineering Rules](./architecture/engineering-rules.md) for complexity budgets, test gates, subagent collaboration, external review boundaries, and emulator validation
- [Phase One Technical Research](./research/2026-06-23-phase-one-technical-research.md)
- [MemeX Design Critique](./research/2026-06-23-memex-design-critique.md)
- [Kimi Review Follow-Up](./research/2026-06-23-kimi-review-followup.md)
- [External Review Follow-Up](./research/2026-06-24-external-review-followup.md)
- [Android Emulator QA](./research/2026-06-24-android-emulator-qa.md)
- [MemeX Phase-One Parity Gap Audit](./research/2026-06-24-memex-phase-one-gap-audit.md)

## Active RFCs

- [Memory Model](./rfcs/memory-model.md)
- [Agent Pack Schema](./rfcs/agent-pack-schema.md)
- [Model Provider Settings](./rfcs/model-provider-settings.md)
- [Phase-One Product Scope](./rfcs/phase-one-product-scope.md)

## Contract Sources

- [Schema sources](../packages/schemas/README.md)
- [Official default Agent Pack manifest](../packs/official/default/manifest.json)
- [Official todo Agent Pack manifest](../packs/official/todo/manifest.json)

## Contract Validation

Validate phase-one official Agent Pack manifests with the lightweight validator:

```sh
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json
```

This is a lightweight validator, not a complete JSON Schema validator.

## Context Structure

Project context should be discoverable in layers:

- Root docs explain the whole project.
- Area READMEs explain top-level directories.
- Module READMEs explain ownership boundaries and generated artifacts.
- `agent-context/project-map.md` points to the current context entrypoints.
