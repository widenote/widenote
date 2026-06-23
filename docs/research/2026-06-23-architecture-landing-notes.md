# 2026-06-23 Architecture Landing Notes

This research note summarizes the first architecture landing discussion.

## Topics

- Whether the client, backend, runner, schemas, Agent Packs, and docs should live in one repository.
- Whether Flutter is still the right client stack.
- Whether the project needs a structured decision history.
- Whether event-driven Agent Pack execution requires a standalone Agent engine.

## Conclusions

- Start with one product monorepo and split ecosystem repositories later.
- Use Flutter + Dart for the mobile-first client.
- Use SQLite + Drift for the local-first data layer.
- Use TypeScript + Fastify + PostgreSQL for the optional backend foundation.
- Build a lightweight WideNote Agent Runtime Kernel.
- Treat external frameworks as runner adapters or integration targets.
- Maintain `docs/decisions`, `docs/rfcs`, `docs/research`, and `docs/agent-context` from the first commit.

## External References

- Dart Pub Workspaces: https://dart.dev/tools/pub/workspaces
- Melos: https://melos.invertase.dev/
- Nx monorepo guidance: https://nx.dev/docs/concepts/decisions/why-monorepos
- Turborepo repository structure: https://turborepo.com/docs/crafting-your-repository/structuring-a-repository
- Flutter supported platforms: https://docs.flutter.dev/reference/supported-platforms
- Flutter offline-first guide: https://docs.flutter.dev/app-architecture/design-patterns/offline-first
- Drift: https://drift.simonbinder.eu/
- SQLite FTS5: https://sqlite.org/fts5.html
- MongoDB Atlas Device SDK deprecation: https://www.mongodb.com/docs/atlas/app-services/deprecation/
- ADR resources: https://adr.github.io/
- Write the Docs docs-as-code: https://www.writethedocs.org/guide/docs-as-code/
- OpenAI Agents SDK: https://developers.openai.com/api/docs/guides/agents
- LangGraph overview: https://docs.langchain.com/oss/python/langgraph/overview
- Temporal workflow execution: https://docs.temporal.io/workflow-execution
- Inngest docs: https://www.inngest.com/docs
- Hatchet docs: https://docs.hatchet.run/
