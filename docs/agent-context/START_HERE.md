# Start Here

This is the orientation entrypoint for AI agents working on WideNote.

Use this page for first-time repository orientation, broad planning, or recovery
when the right area is unclear. For ordinary coding work, prefer the narrower
path in `AGENTS.md`: current contracts, project map when needed, nearest module
README, then related ADRs or RFCs only when the task calls for them.

Broad orientation path:

1. `README.md`
2. `docs/architecture/current-contracts.md`
3. `docs/decisions/index.md`
4. `docs/product/positioning.md`
5. `docs/architecture/overview.md`
6. `docs/architecture/context-structure.md`
7. `docs/architecture/project-structure.md`
8. `docs/architecture/engineering-rules.md`
9. `docs/agent-context/project-map.md`
10. `docs/agent-context/open-questions.md`
11. `widenote_project_brief.md` when deeper product context is needed

## Current Foundation

WideNote is a local-first personal record, memory, and agent runtime.

The default loop is:

```text
quick capture -> timeline / cards -> memory -> insight
```

Backend services, sync, runners, exports, todos, documents, graphical agent
flows, external tools, and continuous-capture surfaces are planned extension
surfaces. They must enhance the local-first core instead of becoming
prerequisites for capture, local persistence, Memory, trace review, and the
first user experience.

## Context Shape

Use `docs/architecture/current-contracts.md` for the current target-state
contracts agents should maintain by default. Use ADRs and RFCs for decision
history, tradeoffs, provenance, or when changing a contract.

Use `docs/agent-context/project-map.md` to locate the right area and module documents. Module READMEs are part of the source of truth, not decorative documentation.

Use `docs/architecture/engineering-rules.md` for collaboration, test gates, complexity budgets, external review boundaries, and serialized Android emulator validation.
