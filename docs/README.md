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
- [Engineering Rules](./architecture/engineering-rules.md)
- [Phase One Technical Research](./research/2026-06-23-phase-one-technical-research.md)
- [MemeX Design Critique](./research/2026-06-23-memex-design-critique.md)
- [Kimi Review Follow-Up](./research/2026-06-23-kimi-review-followup.md)

## Active RFCs

- [Memory Model](./rfcs/memory-model.md)
- [Agent Pack Schema](./rfcs/agent-pack-schema.md)

## Context Structure

Project context should be discoverable in layers:

- Root docs explain the whole project.
- Area READMEs explain top-level directories.
- Module READMEs explain ownership boundaries and generated artifacts.
- `agent-context/project-map.md` points to the current context entrypoints.
