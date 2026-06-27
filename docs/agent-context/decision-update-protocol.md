# Decision Update Protocol

When a discussion changes project direction:

1. Summarize the discussion or research in `docs/research/`.
2. Create or update an RFC if the design is still open.
3. Create a new ADR when the decision is accepted or rejected.
4. Update `docs/decisions/index.md`.
5. Update `docs/architecture/current-contracts.md` if the accepted decision
   changes the target state that agents and modules should maintain by default.
6. Update module READMEs that implement the changed contract.
7. Update `docs/agent-context/project-map.md` if the decision changes
   repository structure or adds a new current contract entrypoint.
8. Update `docs/agent-context/START_HERE.md` if the decision changes onboarding context.
9. Add or update executable proof where practical: tests, schema validation,
   pack validation, docs checks, integration QA, or a documented skipped check.

Do not rewrite an accepted ADR to hide history. If a decision changes, create a new ADR and mark the old one as superseded.
