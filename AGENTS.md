# Agent Instructions

This repository is the foundation for WideNote / 广记: a local-first personal record, memory, and agent runtime.

Before making architectural or product changes, read:

1. `docs/agent-context/START_HERE.md`
2. `docs/decisions/index.md`
3. Any ADR or RFC related to the files you plan to touch
4. `widenote_project_brief.md` when product intent is unclear

## Durable Constraints

- Core usage must work without an account or official backend.
- The mobile client owns the immediate capture experience and local data.
- Original user records must be preserved; AI output must not overwrite raw input.
- Backend services enhance sync, backup, scheduling, runner execution, and ecosystem features.
- Agent Packs must depend on public schemas and SDK boundaries, not private app tables.
- Sensitive or high-risk capabilities belong behind explicit permissions and may be community-edition only.

## Structure Constraints

- Keep code structure clear, bounded, and navigable by humans and agents.
- Every durable module or package must have a `README.md` that states its purpose, ownership boundary, dependencies, public surface, and generated artifacts.
- When adding, moving, or deleting a module, update its parent directory README and `docs/agent-context/project-map.md`.
- Generated files must have a documented source of truth and generation command. Do not hand-edit generated artifacts.
- Public runtime contracts belong in `packages/schemas` unless an ADR says otherwise.

## Decision Hygiene

If a change affects schema, runtime, memory, sync, privacy, plugin permissions, Agent Packs, technology stack, licensing, or default UX, update or create an ADR/RFC.

Do not treat raw conversation history as an authoritative decision. Summarize it into `docs/research/`, then link it from ADRs or RFCs.
