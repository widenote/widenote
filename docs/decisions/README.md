# Decision Records

This directory contains Architecture Decision Records for WideNote.

Use ADRs for decisions that affect future architecture, product boundaries, schemas, runtime behavior, privacy, sync, plugin permissions, licensing, or default UX.

Do not use ADRs for ordinary todos, one-off bug fixes, temporary brainstorming, or raw conversation logs.

ADRs are the historical decision log: they preserve context, tradeoffs,
rationale, and supersession history. Day-to-day implementation should start
from the current target-state view in
[`docs/architecture/current-contracts.md`](../architecture/current-contracts.md),
then open linked ADRs when changing a contract or needing the history.

## Status Values

- `proposed`
- `accepted`
- `rejected`
- `superseded`
- `deprecated`

Accepted ADRs should not be heavily rewritten. If a decision changes, create a new ADR and mark the previous one as superseded.

When an accepted ADR changes the current target state, update
`docs/architecture/current-contracts.md` and the affected module READMEs in the
same change.
